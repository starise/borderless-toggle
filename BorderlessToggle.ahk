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
global SETTINGS_FILE := A_ScriptDir "\settings.ini"
global ICONS_DIR := A_ScriptDir "\icons"
; Default hotkey: CTRL+ALT+F11
global DEFAULT_HOTKEY := "^!F11"

; ── State ─────────────────────────────────────────────────────────────
global currentHotkey := IniRead(SETTINGS_FILE, "Settings", "Hotkey", DEFAULT_HOTKEY)
global isSuspended := false
global borderlessStates := Map()
global currentTheme := GetWindowsTheme()
global optionsGui := 0
global optionsControls := Map()

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
OnMessage(0x001A, WM_SETTINGCHANGE)
RegisterHotkey(currentHotkey)
UpdateTray()

; ══════════════════════════════════════════════════════════════════════
; BORDERLESS LOGIC
; ══════════════════════════════════════════════════════════════════════

RegisterHotkey(hk) {
  if hk = ""
    return
  try Hotkey(hk, ToggleBorderless, "On")
  catch as e
    MsgBox("Could not register shortcut '" hk "'`n" e.Message,
      APP_NAME " – Error", "Icon! T5")
}

ToggleBorderless(*) {
  global borderlessStates
  hwnd := WinExist("A")
  if !hwnd
    return

  winTitle := "ahk_id " hwnd

  if borderlessStates.Has(hwnd) {
    RestoreWindow(hwnd, borderlessStates[hwnd])
    borderlessStates.Delete(hwnd)
  } else {
    WinGetPos(&x, &y, &w, &h, winTitle)
    borderlessStates[hwnd] := {
      x: x,
      y: y,
      w: w,
      h: h,
      style: WinGetStyle(winTitle),
      minMax: WinGetMinMax(winTitle)
    }

    bounds := GetWindowMonitorBounds(hwnd)
    WinSetStyle("-0xC40000", winTitle)
    WinMove(bounds.x, bounds.y, bounds.w, bounds.h, winTitle)
  }
}

RestoreAll(*) {
  global borderlessStates
  for hwnd, state in borderlessStates.Clone() {
    if WinExist("ahk_id " hwnd) {
      RestoreWindow(hwnd, state)
    }
    borderlessStates.Delete(hwnd)
  }
}

RestoreWindow(hwnd, state) {
  winTitle := "ahk_id " hwnd

  if state.minMax = 1
    try WinRestore(winTitle)

  WinSetStyle(Format("0x{:X}", state.style), winTitle)
  WinMove(state.x, state.y, state.w, state.h, winTitle)

  if state.minMax = 1
    WinMaximize(winTitle)
}

GetWindowMonitorBounds(hwnd) {
  WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
  centerX := x + (w // 2)
  centerY := y + (h // 2)

  try {
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
  global isSuspended, currentHotkey, AppMenu
  if currentHotkey = ""
    return
  isSuspended := !isSuspended
  if isSuspended {
    try Hotkey(currentHotkey, "Off")
    AppMenu.Rename("Suspend", "Resume")
    AppMenu.Default := "Resume"
  } else {
    try Hotkey(currentHotkey, "On")
    AppMenu.Rename("Resume", "Suspend")
    AppMenu.Default := "Suspend"
  }
  UpdateTray()
}

; ══════════════════════════════════════════════════════════════════════
; TRAY & ICON
; ══════════════════════════════════════════════════════════════════════

UpdateTray() {
  global currentHotkey, isSuspended, APP_NAME
  if currentHotkey = "" {
    SetTrayStateIcon("Inactive")
    A_IconTip := APP_NAME "`nInactive – no shortcut set"
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
    TraySetIcon(A_ScriptFullPath, iconIds[state "|" theme])
  } else {
    TraySetIcon(ICONS_DIR "\BorderlessToggle-" state "-" theme ".ico")
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
  global currentHotkey, isSuspended, SETTINGS_FILE
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
    global currentHotkey, isSuspended, SETTINGS_FILE, AppMenu
    newHk := hkCtrl.Value

    if currentHotkey != ""
      try Hotkey(currentHotkey, "Off")

    if newHk = "" {
      currentHotkey := ""
      isSuspended := false
      IniWrite("", SETTINGS_FILE, "Settings", "Hotkey")
      try AppMenu.Rename("Resume", "Suspend")
      AppMenu.Default := "Suspend"
      UpdateTray()
      DestroyOptions()
      return
    }

    try {
      Hotkey(newHk, ToggleBorderless, isSuspended ? "Off" : "On")
      currentHotkey := newHk
      IniWrite(newHk, SETTINGS_FILE, "Settings", "Hotkey")
      UpdateTray()
      DestroyOptions()
    } catch as e {
      MsgBox("Invalid shortcut or already in use by another program.`n`n" e.Message,
        "Error", "Icon! T6")
      if currentHotkey != "" and !isSuspended
        try Hotkey(currentHotkey, ToggleBorderless, "On")
    }
  }
}
