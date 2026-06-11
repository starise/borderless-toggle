; BorderlessToggle.ahk
; Toggle borderless mode for any window with a keyboard shortcut
; Author: Andrea Brandi <https://andreabrandi.com>

;@Ahk2Exe-Let version=__APP_VERSION__
;@Ahk2Exe-SetVersion %U_version%
;@Ahk2Exe-SetProductVersion %U_version%
;@Ahk2Exe-SetName Borderless Toggle
;@Ahk2Exe-SetDescription Toggle borderless mode for any window
;@Ahk2Exe-SetCopyright Copyright (c) 2026`, Andrea Brandi
;@Ahk2Exe-SetLanguage 0x0409
;@Ahk2Exe-SetMainIcon .\icons\BorderlessToggle-App.ico
;@Ahk2Exe-AddResource .\icons\BorderlessToggle-Active-Light.ico, 201
;@Ahk2Exe-AddResource .\icons\BorderlessToggle-Inactive-Light.ico, 202
;@Ahk2Exe-AddResource .\icons\BorderlessToggle-Active-Dark.ico, 211
;@Ahk2Exe-AddResource .\icons\BorderlessToggle-Inactive-Dark.ico, 212

#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; ── Constants ─────────────────────────────────────────────────────────
global APP_NAME := "Borderless Toggle"
global APP_VERSION := "__APP_VERSION__"
global AUTHOR_NAME := "Andrea Brandi"
global AUTHOR_URL := "https://andreabrandi.com"
global REPO_URL := "https://github.com/starise/borderless-toggle"
global PORTABLE_SETTINGS_FILE := A_ScriptDir "\settings.ini"
global APPDATA_SETTINGS_DIR := A_AppData "\BorderlessToggle"
global APPDATA_SETTINGS_FILE := APPDATA_SETTINGS_DIR "\settings.ini"
global SETTINGS_FILE := ResolveSettingsFile()
global ICONS_DIR := A_ScriptDir "\icons"
; Default hotkey: CTRL+ALT+F11
global DEFAULT_HOTKEY := "^!F11"

; ── State ─────────────────────────────────────────────────────────────
global currentHotkey := ReadSavedHotkey()
global isHotkeyRegistered := false
global isSuspended := false
global borderlessStates := Map()
global currentTheme := GetWindowsTheme()
global optionsGui := 0
global optionsControls := Map()
global windowDestroyCallback := CallbackCreate(HandleWindowDestroyed, "", 7)
global windowDestroyHook := DllCall("user32\SetWinEventHook",
  "uint", 0x8001, "uint", 0x8001, "ptr", 0, "ptr", windowDestroyCallback,
  "uint", 0, "uint", 0, "uint", 0, "ptr")

; ── Tray menu ─────────────────────────────────────────────────────────
global AppMenu := A_TrayMenu
AppMenu.Delete()
AppMenu.Add("Options", OpenOptions)
AppMenu.Add()
AppMenu.Add("Suspend", ToggleSuspend)
AppMenu.Add()
AppMenu.Add("Restore all", RestoreAll)
AppMenu.Add()
AppMenu.Add("Exit", (*) => ExitApp())
AppMenu.Default := "Suspend"
AppMenu.ClickCount := 1

; ── Startup ───────────────────────────────────────────────────────────
OnExit(RestoreAll)
OnExit(CleanupWindowDestroyHook)
OnMessage(0x001A, WM_SETTINGCHANGE)
isHotkeyRegistered := RegisterHotkey(currentHotkey)
UpdateTray()

; ══════════════════════════════════════════════════════════════════════
; BORDERLESS LOGIC
; ══════════════════════════════════════════════════════════════════════

RegisterHotkey(hk) {
  if hk = ""
    return false

  try {
    Hotkey(hk, ToggleBorderless, "On")
    return true
  } catch as e {
    MsgBox("Could not register shortcut '" hk "'`n" e.Message,
      APP_NAME " – Error", "Icon! T5")
  }

  return false
}

ResolveSettingsFile() {
  global PORTABLE_SETTINGS_FILE, APPDATA_SETTINGS_FILE

  if FileExist(PORTABLE_SETTINGS_FILE) || CanWriteFileInScriptDir()
    return PORTABLE_SETTINGS_FILE

  return APPDATA_SETTINGS_FILE
}

CanWriteFileInScriptDir() {
  testFile := A_ScriptDir "\.borderless-toggle-write-test"

  try {
    FileAppend("", testFile)
    FileDelete(testFile)
    return true
  } catch {
    try FileDelete(testFile)
  }

  return false
}

ReadSavedHotkey() {
  global SETTINGS_FILE, DEFAULT_HOTKEY

  try return IniRead(SETTINGS_FILE, "Settings", "Hotkey", DEFAULT_HOTKEY)
  catch
    return DEFAULT_HOTKEY
}

WriteSavedHotkey(hk) {
  global APPDATA_SETTINGS_DIR, APPDATA_SETTINGS_FILE, SETTINGS_FILE

  if SETTINGS_FILE = APPDATA_SETTINGS_FILE
    try DirCreate(APPDATA_SETTINGS_DIR)

  IniWrite(hk, SETTINGS_FILE, "Settings", "Hotkey")
}

ToggleBorderless(*) {
  global borderlessStates
  hwnd := WinExist("A")
  if !hwnd
    return

  if borderlessStates.Has(hwnd) {
    if !IsTrackedWindow(hwnd, borderlessStates[hwnd]) {
      borderlessStates.Delete(hwnd)
    } else {
      if RestoreWindow(hwnd, borderlessStates[hwnd])
        borderlessStates.Delete(hwnd)
      return
    }
  }

  state := CaptureWindowState(hwnd)
  if !IsObject(state)
    return

  if ApplyBorderlessWindow(hwnd, state) {
    borderlessStates[hwnd] := state
  }
}

CaptureWindowState(hwnd) {
  winTitle := "ahk_id " hwnd

  try {
    WinGetPos(&x, &y, &w, &h, winTitle)
    return {
      x: x,
      y: y,
      w: w,
      h: h,
      style: WinGetStyle(winTitle),
      minMax: WinGetMinMax(winTitle),
      identity: GetWindowIdentity(hwnd)
    }
  } catch as e {
    NotifyWindowError("Could not read window state.", e)
  }

  return 0
}

GetWindowIdentity(hwnd) {
  winTitle := "ahk_id " hwnd

  try {
    return {
      pid: WinGetPID(winTitle),
      processName: WinGetProcessName(winTitle),
      class: WinGetClass(winTitle)
    }
  }

  return 0
}

IsTrackedWindow(hwnd, state) {
  try storedIdentity := state.identity
  catch
    return true

  currentIdentity := GetWindowIdentity(hwnd)
  if !IsObject(currentIdentity)
    return false

  return currentIdentity.pid = storedIdentity.pid
    && currentIdentity.processName = storedIdentity.processName
    && currentIdentity.class = storedIdentity.class
}

ApplyBorderlessWindow(hwnd, state) {
  winTitle := "ahk_id " hwnd

  try {
    bounds := GetWindowMonitorBounds(hwnd)
    WinSetStyle("-0xC40000", winTitle)
    WinMove(bounds.x, bounds.y, bounds.w, bounds.h, winTitle)
    return true
  } catch as e {
    RestoreWindow(hwnd, state, false)
    NotifyWindowError("Could not apply borderless mode.", e)
  }

  return false
}

NotifyWindowError(message, error) {
  global APP_NAME

  try TrayTip(message "`n" error.Message, APP_NAME)
}

RestoreAll(*) {
  global borderlessStates
  for hwnd, state in borderlessStates.Clone() {
    if WinExist("ahk_id " hwnd) && IsTrackedWindow(hwnd, state) && !RestoreWindow(hwnd, state) {
      continue
    }
    borderlessStates.Delete(hwnd)
  }
}

HandleWindowDestroyed(hook, event, hwnd, idObject, idChild, eventThread, eventTime) {
  global borderlessStates

  if idObject != 0 || idChild != 0
    return

  if borderlessStates.Has(hwnd)
    borderlessStates.Delete(hwnd)
}

CleanupWindowDestroyHook(*) {
  global windowDestroyHook, windowDestroyCallback

  if windowDestroyHook
    DllCall("user32\UnhookWinEvent", "ptr", windowDestroyHook)

  if windowDestroyCallback
    CallbackFree(windowDestroyCallback)
}

RestoreWindow(hwnd, state, showError := true) {
  winTitle := "ahk_id " hwnd

  try {
    if state.minMax = 1
      WinRestore(winTitle)

    WinSetStyle(Format("0x{:X}", state.style), winTitle)
    WinMove(state.x, state.y, state.w, state.h, winTitle)

    if state.minMax = 1
      WinMaximize(winTitle)

    return true
  } catch as e {
    if showError
      NotifyWindowError("Could not restore window.", e)
  }

  return false
}

GetWindowMonitorBounds(hwnd) {
  try {
    WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
    centerX := x + (w // 2)
    centerY := y + (h // 2)

    monitorCount := MonitorGetCount()
    Loop monitorCount {
      MonitorGet(A_Index, &left, &top, &right, &bottom)
      if centerX >= left && centerX < right && centerY >= top && centerY < bottom {
        return {
          x: left,
          y: top,
          w: right - left,
          h: bottom - top
        }
      }
    }

    primary := MonitorGetPrimary()
    MonitorGet(primary, &left, &top, &right, &bottom)
    return {
      x: left,
      y: top,
      w: right - left,
      h: bottom - top
    }
  }

  return { x: 0, y: 0, w: A_ScreenWidth, h: A_ScreenHeight }
}

; ══════════════════════════════════════════════════════════════════════
; SUSPEND
; ══════════════════════════════════════════════════════════════════════

ToggleSuspend(*) {
  global isSuspended, isHotkeyRegistered, currentHotkey
  if currentHotkey = "" || !isHotkeyRegistered
    return
  isSuspended := !isSuspended
  if isSuspended {
    try Hotkey(currentHotkey, "Off")
  } else {
    try Hotkey(currentHotkey, "On")
  }
  UpdateSuspendMenu()
  UpdateTray()
}

UpdateSuspendMenu() {
  global isSuspended, AppMenu

  if isSuspended {
    try AppMenu.Rename("Suspend", "Resume")
    AppMenu.Default := "Resume"
  } else {
    try AppMenu.Rename("Resume", "Suspend")
    AppMenu.Default := "Suspend"
  }
}

; ══════════════════════════════════════════════════════════════════════
; TRAY & ICON
; ══════════════════════════════════════════════════════════════════════

UpdateTray() {
  global currentHotkey, isHotkeyRegistered, isSuspended, APP_NAME
  if currentHotkey = "" {
    SetTrayStateIcon("Inactive")
    A_IconTip := APP_NAME "`nInactive – no shortcut set"
  } else if !isHotkeyRegistered {
    SetTrayStateIcon("Inactive")
    A_IconTip := APP_NAME "`nInactive – shortcut unavailable"
  } else if isSuspended {
    SetTrayStateIcon("Suspended")
    A_IconTip := APP_NAME "`nSuspended – click to resume"
  } else {
    SetTrayStateIcon("Active")
    A_IconTip := APP_NAME "`nActive – " currentHotkey
  }
}

SetTrayStateIcon(state) {
  global ICONS_DIR
  theme := GetWindowsTheme().system
  if A_IsCompiled {
    iconIds := Map(
      "Active|Light", -201,
      "Inactive|Light", -202,
      "Suspended|Light", -202,
      "Active|Dark", -211,
      "Inactive|Dark", -212,
      "Suspended|Dark", -212
    )
    try TraySetIcon(A_ScriptFullPath, iconIds[state "|" theme])
  } else {
    if state = "Suspended"
      state := "Inactive"

    iconPath := ICONS_DIR "\BorderlessToggle-" state "-" theme ".ico"
    if FileExist(iconPath)
      try TraySetIcon(iconPath)
  }
}

; ══════════════════════════════════════════════════════════════════════
; WINDOWS THEME
; ══════════════════════════════════════════════════════════════════════

GetWindowsTheme() {
  personalizeKey := "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"

  try appsUseLight := RegRead(personalizeKey, "AppsUseLightTheme", 1)
  catch
    appsUseLight := 1

  try systemUseLight := RegRead(personalizeKey, "SystemUsesLightTheme", 1)
  catch
    systemUseLight := 1

  return {
    app: appsUseLight ? "Light" : "Dark",
    system: systemUseLight ? "Light" : "Dark"
  }
}

GetThemePalette(themeName) {
  if themeName = "Dark" {
    return {
      background: "202020",
      text: "FFFFFF",
      muted: "B8B8B8",
      link: "6AB0FF"
    }
  }

  return {
    background: "F0F0F0",
    text: "000000",
    muted: "666666",
    link: "0066CC"
  }
}

ApplyWindowTheme(hwnd, themeName) {
  dark := themeName = "Dark" ? 1 : 0

  if DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", 20, "int*", dark, "int", 4) != 0 {
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", 19, "int*", dark, "int", 4)
  }
}

ApplyControlTheme(ctrl, themeName) {
  themeClass := themeName = "Dark" ? "DarkMode_Explorer" : "Explorer"
  try DllCall("uxtheme\SetWindowTheme", "ptr", ctrl.Hwnd, "str", themeClass, "ptr", 0)
}

ApplyOptionsTheme(guiObj, themeName) {
  global optionsControls
  palette := GetThemePalette(themeName)

  try guiObj.BackColor := palette.background

  if optionsControls.Has("text") {
    for ctrl in optionsControls["text"]
      try ctrl.SetFont("c" palette.text)
  }

  if optionsControls.Has("muted") {
    for ctrl in optionsControls["muted"]
      try ctrl.SetFont("c" palette.muted)
  }

  if optionsControls.Has("link") {
    for ctrl in optionsControls["link"]
      try ctrl.SetFont("c" palette.link)
  }

  if optionsControls.Has("native") {
    for ctrl in optionsControls["native"]
      ApplyControlTheme(ctrl, themeName)
  }

  try ApplyWindowTheme(guiObj.Hwnd, themeName)
  try WinRedraw("ahk_id " guiObj.Hwnd)
}

WM_SETTINGCHANGE(wParam, lParam, msg, hwnd) {
  if lParam {
    setting := StrGet(lParam)
    if setting != "ImmersiveColorSet" && setting != "WindowsThemeElement"
      return
  }

  SetTimer(HandleThemeChanged, -150)
}

HandleThemeChanged() {
  global currentTheme, optionsGui
  newTheme := GetWindowsTheme()

  if newTheme.system != currentTheme.system
    UpdateTray()

  currentTheme := newTheme

  if IsObject(optionsGui)
    ApplyOptionsTheme(optionsGui, newTheme.app)
}

; ══════════════════════════════════════════════════════════════════════
; OPTIONS GUI
; ══════════════════════════════════════════════════════════════════════

OpenOptions(*) {
  global currentHotkey, isSuspended
  global APP_NAME, APP_VERSION, AUTHOR_NAME, AUTHOR_URL, REPO_URL, AppMenu
  global optionsGui, optionsControls

  if WinExist(APP_NAME " – Options")
    return WinActivate(APP_NAME " – Options")

  theme := GetWindowsTheme().app
  palette := GetThemePalette(theme)

  btGUI := Gui("+AlwaysOnTop +ToolWindow", APP_NAME " – Options")
  btGUI.SetFont("s9", "Segoe UI")
  btGUI.BackColor := palette.background
  btGUI.MarginX := 16
  btGUI.MarginY := 14
  optionsGui := btGUI
  optionsControls := Map("text", [], "muted", [], "link", [], "native", [])

  ; ── Shortcut ──────────────────────────────────────────────────────
  shortcutLabel := btGUI.Add("Text", "xm w268", "Shortcut to toggle borderless mode:")
  optionsControls["text"].Push(shortcutLabel)
  hkCtrl := btGUI.Add("Hotkey", "xm w268 y+6 vHotkey", currentHotkey)
  optionsControls["native"].Push(hkCtrl)
  shortcutHelp := btGUI.Add("Text", "xm w268 y+8",
    "Use Ctrl, Alt, Shift, Win + a key.`nLeave empty to disable the shortcut.")
  optionsControls["muted"].Push(shortcutHelp)

  ; ── Buttons ───────────────────────────────────────────────────────
  saveButton := btGUI.Add("Button", "xm w268 y+14 h28 Default", "Save")
  saveButton.OnEvent("Click", SaveAndClose)
  optionsControls["native"].Push(saveButton)

  ; ── Credits ───────────────────────────────────────────────────────
  divider := btGUI.Add("Text", "xm w268 y+16 h1 0x10")
  optionsControls["muted"].Push(divider)
  authorLink := btGUI.Add("Link", "xm w268 y+12",
    APP_NAME ' ' APP_VERSION ' by <a href="' AUTHOR_URL '">' AUTHOR_NAME '</a>.')
  optionsControls["link"].Push(authorLink)
  repoLink := btGUI.Add("Link", "xm w268 y+4",
    '<a href="' REPO_URL '">' REPO_URL '</a>')
  optionsControls["link"].Push(repoLink)

  btGUI.MarginY := 14
  btGUI.OnEvent("Close", DestroyOptions)
  ApplyOptionsTheme(btGUI, theme)
  btGUI.Show("AutoSize")
  ApplyOptionsTheme(btGUI, theme)

  ; ── Destroy ───────────────────────────────────────────────────────
  DestroyOptions(*) {
    global optionsGui, optionsControls
    optionsGui := 0
    optionsControls := Map()
    btGUI.Destroy()
  }

  ; ── Save & close ──────────────────────────────────────────────────
  SaveAndClose(*) {
    global currentHotkey, isHotkeyRegistered, isSuspended
    newHk := hkCtrl.Value
    oldHk := currentHotkey
    oldRegistered := isHotkeyRegistered
    oldSuspended := isSuspended

    if oldHk != "" && oldRegistered
      try Hotkey(currentHotkey, "Off")

    try {
      if newHk = "" {
        WriteSavedHotkey("")
        currentHotkey := ""
        isHotkeyRegistered := false
        isSuspended := false
        UpdateSuspendMenu()
        UpdateTray()
        DestroyOptions()
        return
      }

      Hotkey(newHk, ToggleBorderless, isSuspended ? "Off" : "On")
      WriteSavedHotkey(newHk)
      currentHotkey := newHk
      isHotkeyRegistered := true
      UpdateTray()
      DestroyOptions()
    } catch as e {
      if newHk != ""
        try Hotkey(newHk, "Off")

      currentHotkey := oldHk
      isHotkeyRegistered := oldRegistered
      isSuspended := oldSuspended

      if oldHk != "" && oldRegistered
        try Hotkey(oldHk, ToggleBorderless, oldSuspended ? "Off" : "On")

      UpdateSuspendMenu()
      UpdateTray()
      MsgBox("Could not save shortcut.`n`n" e.Message,
        "Error", "Icon! T6")
    }
  }
}
