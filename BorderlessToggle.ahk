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
;@Ahk2Exe-AddResource .\icons\BorderlessToggle-Suspended-Light.ico, 203
;@Ahk2Exe-AddResource .\icons\BorderlessToggle-Active-Dark.ico, 211
;@Ahk2Exe-AddResource .\icons\BorderlessToggle-Inactive-Dark.ico, 212
;@Ahk2Exe-AddResource .\icons\BorderlessToggle-Suspended-Dark.ico, 213

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
; Default hotkey: CTRL+SHIFT+F11
global DEFAULT_HOTKEY := "^+F11"

; ── State ─────────────────────────────────────────────────────────────
global currentHotkey := ReadSavedHotkey()
global isHotkeyRegistered := false
global isSuspended := false
global borderlessStates := Map()
global currentTheme := GetWindowsTheme()
SetMenuTheme(currentTheme.app)
global optionsGui := 0
global optionsControls := Map()
; EVENT_OBJECT_DESTROY lets us drop state when a tracked window closes.
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
FlushMenuThemes()

; ── Startup ───────────────────────────────────────────────────────────
OnExit(RestoreAll)
OnExit(CleanupWindowDestroyHook)
; WM_SETTINGCHANGE notifies us when Windows theme colors change.
OnMessage(0x001A, WM_SETTINGCHANGE)
isHotkeyRegistered := RegisterHotkey(currentHotkey)
UpdateTray()

; ══════════════════════════════════════════════════════════════════════
; BORDERLESS LOGIC
; ══════════════════════════════════════════════════════════════════════

RegisterHotkey(hotkeyName) {
  if hotkeyName = ""
    return false

  try {
    Hotkey(hotkeyName, ToggleBorderless, "On")
    return true
  } catch as e {
    MsgBox("Could not register shortcut '" hotkeyName "'`n" e.Message,
      APP_NAME " – Error", "Icon! T5")
  }

  return false
}

ResolveSettingsFile() {
  global PORTABLE_SETTINGS_FILE, APPDATA_SETTINGS_FILE

  ; Prefer portable settings, but fall back when the app folder is read-only.
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

WriteSavedHotkey(hotkeyName) {
  global APPDATA_SETTINGS_DIR, APPDATA_SETTINGS_FILE, SETTINGS_FILE

  if SETTINGS_FILE = APPDATA_SETTINGS_FILE
    try DirCreate(APPDATA_SETTINGS_DIR)

  IniWrite(hotkeyName, SETTINGS_FILE, "Settings", "Hotkey")
}

ToggleBorderless(*) {
  global borderlessStates
  hwnd := WinExist("A")
  if !hwnd
    return

  if !IsSupportedTargetWindow(hwnd)
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

IsSupportedTargetWindow(hwnd) {
  global optionsGui
  ; Avoid toggling shell surfaces or the app's own options window.
  static blockedClasses := Map(
    "Progman", true,
    "WorkerW", true,
    "Shell_TrayWnd", true,
    "Shell_SecondaryTrayWnd", true
  )

  if IsObject(optionsGui) && hwnd = optionsGui.Hwnd
    return false

  if !DllCall("user32\IsWindowVisible", "ptr", hwnd)
    return false

  try className := WinGetClass("ahk_id " hwnd)
  catch
    return false

  return !blockedClasses.Has(className)
}

CaptureWindowState(hwnd) {
  windowSelector := "ahk_id " hwnd

  try {
    WinGetPos(&x, &y, &w, &h, windowSelector)
    return {
      x: x,
      y: y,
      w: w,
      h: h,
      style: WinGetStyle(windowSelector),
      exStyle: WinGetExStyle(windowSelector),
      minMax: WinGetMinMax(windowSelector),
      identity: GetWindowIdentity(hwnd)
    }
  } catch as e {
    NotifyWindowError("Could not read window state.", e)
  }

  return 0
}

GetWindowIdentity(hwnd) {
  windowSelector := "ahk_id " hwnd

  try {
    return {
      pid: WinGetPID(windowSelector),
      processName: WinGetProcessName(windowSelector),
      class: WinGetClass(windowSelector)
    }
  }

  return 0
}

IsTrackedWindow(hwnd, state) {
  try storedIdentity := state.identity
  catch
    return true

  ; Window handles can be reused after a window is closed.
  currentIdentity := GetWindowIdentity(hwnd)
  if !IsObject(currentIdentity)
    return false

  return currentIdentity.pid = storedIdentity.pid
    && currentIdentity.processName = storedIdentity.processName
    && currentIdentity.class = storedIdentity.class
}

ApplyBorderlessWindow(hwnd, state) {
  ; Remove caption/thick-frame and extended edge styles.
  static BORDERLESS_STYLE_MASK := "-0xC40000"
  static BORDERLESS_EX_STYLE_MASK := "-0x20301"
  windowSelector := "ahk_id " hwnd

  try {
    bounds := GetWindowMonitorBounds(hwnd)
    WinSetStyle(BORDERLESS_STYLE_MASK, windowSelector)
    WinSetExStyle(BORDERLESS_EX_STYLE_MASK, windowSelector)
    RefreshWindowFrame(hwnd)
    WinMove(bounds.x, bounds.y, bounds.w, bounds.h, windowSelector)
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
    ; Keep state tracked if restore fails, so the user can retry.
    if WinExist("ahk_id " hwnd) && IsTrackedWindow(hwnd, state) && !RestoreWindow(hwnd, state) {
      continue
    }
    borderlessStates.Delete(hwnd)
  }
}

HandleWindowDestroyed(hook, event, hwnd, idObject, idChild, eventThread, eventTime) {
  global borderlessStates

  ; Only top-level window destroy events carry the tracked HWND.
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
  windowSelector := "ahk_id " hwnd

  try {
    if state.minMax = 1
      WinRestore(windowSelector)

    WinSetStyle(Format("0x{:X}", state.style), windowSelector)
    WinSetExStyle(Format("0x{:X}", state.exStyle), windowSelector)
    RefreshWindowFrame(hwnd)
    WinMove(state.x, state.y, state.w, state.h, windowSelector)

    if state.minMax = 1
      WinMaximize(windowSelector)

    return true
  } catch as e {
    if showError
      NotifyWindowError("Could not restore window.", e)
  }

  return false
}

RefreshWindowFrame(hwnd) {
  ; Apply pending style changes to the frame.
  static SWP_FRAMECHANGED := 0x20
  ; Keep geometry, z-order and activation unchanged.
  static SWP_NOMOVE := 0x2
  static SWP_NOSIZE := 0x1
  static SWP_NOZORDER := 0x4
  static SWP_NOACTIVATE := 0x10

  DllCall("user32\SetWindowPos",
    "ptr", hwnd,
    "ptr", 0,
    "int", 0,
    "int", 0,
    "int", 0,
    "int", 0,
    "uint", SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE)
}

GetWindowMonitorBounds(hwnd) {
  try {
    WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
    centerX := x + (w // 2)
    centerY := y + (h // 2)

    ; Use the monitor containing the window center.
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
    ; Negative IDs load icon resources embedded by Ahk2Exe.
    iconIds := Map(
      "Active|Light", -201,
      "Inactive|Light", -202,
      "Suspended|Light", -203,
      "Active|Dark", -211,
      "Inactive|Dark", -212,
      "Suspended|Dark", -213
    )
    try TraySetIcon(A_ScriptFullPath, iconIds[state "|" theme])
  } else {
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

  ; DWMWA_USE_IMMERSIVE_DARK_MODE is 20, with 19 as older Windows fallback.
  if DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", 20, "int*", dark, "int", 4) != 0 {
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", 19, "int*", dark, "int", 4)
  }
}

ApplyControlTheme(ctrl, themeName) {
  ; Native controls follow Explorer's themed common-control styles.
  themeClass := themeName = "Dark" ? "DarkMode_Explorer" : "Explorer"
  try DllCall("uxtheme\SetWindowTheme", "ptr", ctrl.Hwnd, "str", themeClass, "ptr", 0)
}

SetMenuTheme(themeName) {
  ; PreferredAppMode affects Win32 popup menus, including the tray menu.
  mode := themeName = "Dark" ? 2 : 3

  try {
    hModule := DllCall("kernel32\LoadLibrary", "str", "uxtheme.dll", "ptr")
    setPreferredAppMode := DllCall("kernel32\GetProcAddress", "ptr", hModule, "ptr", 135, "ptr")
    if setPreferredAppMode
      DllCall(setPreferredAppMode, "int", mode)
    if hModule
      DllCall("kernel32\FreeLibrary", "ptr", hModule)
  }
}

FlushMenuThemes() {
  try {
    hModule := DllCall("kernel32\LoadLibrary", "str", "uxtheme.dll", "ptr")
    flushMenuThemes := DllCall("kernel32\GetProcAddress", "ptr", hModule, "ptr", 136, "ptr")
    if flushMenuThemes
      DllCall(flushMenuThemes)
    if hModule
      DllCall("kernel32\FreeLibrary", "ptr", hModule)
  }
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

  ; Theme messages can arrive in bursts while Windows updates colors.
  SetTimer(HandleThemeChanged, -150)
}

HandleThemeChanged() {
  global currentTheme, optionsGui
  newTheme := GetWindowsTheme()

  if newTheme.system != currentTheme.system
    UpdateTray()

  if newTheme.app != currentTheme.app {
    SetMenuTheme(newTheme.app)
    FlushMenuThemes()
  }

  currentTheme := newTheme

  if IsObject(optionsGui)
    ApplyOptionsTheme(optionsGui, newTheme.app)
}

; ══════════════════════════════════════════════════════════════════════
; OPTIONS GUI
; ══════════════════════════════════════════════════════════════════════

OpenOptions(*) {
  global currentHotkey
  global APP_NAME, APP_VERSION, AUTHOR_NAME, AUTHOR_URL, REPO_URL
  global optionsGui, optionsControls

  if WinExist(APP_NAME " – Options")
    return WinActivate(APP_NAME " – Options")

  theme := GetWindowsTheme().app

  btGUI := Gui("+AlwaysOnTop +ToolWindow", APP_NAME " – Options")
  btGUI.SetFont("s9", "Segoe UI")
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
    newHotkey := hkCtrl.Value
    previousHotkey := currentHotkey
    wasHotkeyRegistered := isHotkeyRegistered
    wasSuspended := isSuspended

    if previousHotkey != "" && wasHotkeyRegistered
      try Hotkey(previousHotkey, "Off")

    try {
      if newHotkey = "" {
        WriteSavedHotkey("")
        currentHotkey := ""
        isHotkeyRegistered := false
        isSuspended := false
        UpdateSuspendMenu()
        UpdateTray()
        DestroyOptions()
        return
      }

      Hotkey(newHotkey, ToggleBorderless, isSuspended ? "Off" : "On")
      WriteSavedHotkey(newHotkey)
      currentHotkey := newHotkey
      isHotkeyRegistered := true
      UpdateTray()
      DestroyOptions()
    } catch as e {
      ; Restore the old shortcut if the new one cannot be registered or saved.
      if newHotkey != ""
        try Hotkey(newHotkey, "Off")

      currentHotkey := previousHotkey
      isHotkeyRegistered := wasHotkeyRegistered
      isSuspended := wasSuspended

      if previousHotkey != "" && wasHotkeyRegistered
        try Hotkey(previousHotkey, ToggleBorderless, wasSuspended ? "Off" : "On")

      UpdateSuspendMenu()
      UpdateTray()
      MsgBox("Could not save shortcut.`n`n" e.Message,
        "Error", "Icon! T6")
    }
  }
}
