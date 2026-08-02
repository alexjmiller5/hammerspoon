# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Hammerspoon configuration for macOS automation. Hammerspoon is a Lua-based automation tool that provides system-level control over windows, hotkeys, applications, and events.

## Reloading Configuration

After making changes, reload Hammerspoon config:
- Press `Hyper + H` (Cmd+Alt+Ctrl+Shift+H)
- Or press `Cmd+R` when Hammerspoon console is focused
- Or run `hs -c "hs.reload()"` from terminal

## Architecture

### Module Structure

```
init.lua                 # Entry point - loads modules, binds hotkeys, starts watchers
├── constants.lua        # Shared constants (bundle IDs, paths, hyperKeyMods)
├── helperFunctions.lua  # Utility functions for hotkey binding and app control
├── watcherFunctions.lua # Event watcher factories (app activation, mouse events)
├── globalHotkeys.lua    # System-wide hotkey definitions
├── appBasedHotkeys.lua  # Context-aware hotkeys (active only in specific apps)
├── scripts/             # Shell scripts and AppleScripts invoked by hotkeys
├── hyperkey.lua         # F19 → Hyper key conversion (disabled, use Karabiner instead)
├── keylogger.lua        # Diagnostic key event logger (disabled by default)
├── activeProfile.lua    # Reads ~/.config/hammerspoon-profile, resolves the active profile
└── profiles/            # Machine-role profiles (selected at runtime, default: personal)
    ├── personal/        # init.lua, constants.lua, globalHotkeys.lua,
    │                    # appBasedHotkeys.lua, watcherFunctions.lua, scripts/
    └── work/            # same shape (+ Spoons/, spoons.lua); untested since the
                         # blueprint era — verify when the work machine adopts it
```

### Key Patterns

**Hotkey Definition Format**: All hotkeys use a consistent table structure. Each hotkey module has a local `actions` table (action functions) and an exported `M.definitions` list (keybinding specs):
```lua
-- Global hotkey
{ mods = { "alt" }, key = "t", action = actions.launchGhostty }

-- App-based hotkey (active only in listed apps)
{ mods = { "cmd" }, key = "\\", action = actions.toggleSidebar, only = { bundleID } }

-- App-based hotkey (active everywhere except listed apps)
{ mods = { "cmd" }, key = "b", action = actions.focusChrome, except = { bundleID } }
```

**Global vs App-Based Hotkeys**:
- Global hotkeys (globalHotkeys.lua): Always active, bound via `hs.hotkey.bind()`
- App-based hotkeys (appBasedHotkeys.lua): Use `only` or `except` bundle ID lists. `only` hotkeys are enabled when that app is frontmost; `except` hotkeys are enabled everywhere except those apps. The `AppBasedHotkeyRegistry` (a global table) tracks these, and an `hs.application.watcher` swaps enabled/disabled state on app focus changes.

**Pass-through pattern**: When an app-based hotkey needs to temporarily let the original keystroke through (e.g., `quitFromLastWindow` sends `Cmd+W` which would re-trigger itself), use `helperFunctions.disableHotkeysForApp()` before sending the keystroke, then `enableHotkeysForApp()` in a `hs.timer.doAfter()` callback.

**Profile System**: `profiles/<name>/` dirs extend the base config; the active one is chosen at runtime by `activeProfile.lua`, which reads `~/.config/hammerspoon-profile` (one line: `personal` or `work` — written per machine by nix-config; defaults to `personal` if absent). The selected `profiles/<name>/init.lua` loads after the main init and adds hotkeys to the same global `AppBasedHotkeyRegistry`, via `pcall` so a broken profile doesn't crash the config. Main-config modules that need the active profile's constants use `require("activeProfile").require("constants")`.

### Adding New Hotkeys

1. **Global hotkey**: Add action function to `actions` table in `globalHotkeys.lua`, then add definition to `M.definitions`
2. **App-specific hotkey**: Add action to `actions` table in `appBasedHotkeys.lua`, then add to `M.definitions` with `only` or `except` containing bundle IDs from `constants.appBundleIds`
3. **Profile-specific**: Same pattern in `profiles/<name>/globalHotkeys.lua` or `profiles/<name>/appBasedHotkeys.lua`, using that profile's `constants` for profile-only bundle IDs
4. **New bundle ID**: Add to `constants.appBundleIds` (shared) or `profiles/<name>/constants.appBundleIds` (profile-only)

### Hyper Key

The "Hyper" modifier (`Cmd+Alt+Ctrl+Shift`) is defined in `constants.hyperKeyMods`. Use Karabiner-Elements externally to map Caps Lock → F19, then Karabiner can convert F19 to the hyper combination. The built-in `hyperkey.lua` exists but is not currently used.

### Window Management

Window management uses yabai (must be installed separately). Functions in `globalHotkeys.lua` shell out to `/opt/homebrew/bin/yabai` for positioning. Some window actions attempt native macOS menu items first via `helpers.tryMenuItem()` before falling back to yabai.

## External Dependencies

- **yabai**: Window manager, expected at `/opt/homebrew/bin/yabai`
- **Karabiner-Elements**: For Caps Lock → Hyper key mapping (optional)
- **Raycast**: Profile uses Raycast deep links for clipboard history, emoji search, file search, bluetooth management
- **Chrome**: Several scripts target Chrome specifically; profile uses Chrome PWAs (identified by `com.google.Chrome.app.*` bundle IDs)
- **hs CLI**: Enabled via `require("hs.ipc")` for terminal commands like `hs -c "..."`