# <img src="images/BorderlessToggle-App.png" width="24"> Borderless Toggle

**Borderless Toggle** is a lightweight Windows utility to put apps & games into **borderless fullscreen mode**. Just toggle it On or Off with a **customizable keyboard shortcut** instead of digging through settings menus of other apps.

Alt-tab instantly, move across monitors and keep your desktop workflow intact. Ideal for older games, poorly optimized apps, or anyone who prefers fast, keyboard-driven controls. Zero setup, zero clutter.

## How to build

Requirements:

- Windows
- Node.js >= 24
- pnpm >= 10.x

```powershell
# Install prerequisites
$ winget install Volta.Volta
$ volta install node@24

# Check node version
$ node --version
v24.15.0

# Install pnpm
$ npm install -g pnpm@latest-10
```

### Compile & Build

```powershell
# Install all dependencies
$ pnpm install

# Download build tools (AutoHotkey v2, Ahk2Exe & UPX)
$ pnpm run setup

# Compile AHK to EXE & Build ZIP archive
$ pnpm run build
```
