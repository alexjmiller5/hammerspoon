# AGENTS.md

This file provides guidance to coding agents when working with code in this repository.

## Overview

This is a Hammerspoon configuration for macOS automation. Hammerspoon is a Lua-based automation tool that provides system-level control over windows, hotkeys, applications, and events.

## Reloading Configuration

After making changes, reload Hammerspoon config:
- Press `Hyper + H` (Cmd+Alt+Ctrl+Shift+H)
- Or press `Cmd+R` when Hammerspoon console is focused
- Or run `hs -c "hs.reload()"` from terminal

Ad-hoc `hs -c` chunks: keep `hs.timer` objects in globals (locals are GC'd
before they fire) and wrap calls in `pcall` (an uncaught error hangs the CLI
instead of printing).

## Architecture

### Module Structure

```
init.lua                 # Entry point - loads modules, binds hotkeys, starts watchers
├── constants.lua        # Shared constants (bundle IDs, paths, hyperKeyMods)
├── helperFunctions.lua  # Utility functions for hotkey binding and app control
├── watcherFunctions.lua # Event watcher factories (app activation, mouse events)
├── globalHotkeys.lua    # System-wide hotkey definitions
├── appBasedHotkeys.lua  # Context-aware hotkeys (active only in specific apps)
├── scripts/             # Shell scripts invoked by hotkeys
├── Spoons/              # Vendored spoons, ALL committed (installed software
│                        # lives in the repo). WorkspaceSnapshot's dev home is
│                        # the workspace-snapshot repo — change it there first,
│                        # then re-copy the .spoon dir here
├── activeProfile.lua    # Reads ~/.config/hammerspoon-profile, resolves the active profile
└── profiles/            # Machine-role profiles (selected at runtime, default: personal)
    ├── personal/        # init.lua, constants.lua, globalHotkeys.lua,
    │                    # appBasedHotkeys.lua, watcherFunctions.lua, scripts/,
    │                    # otp.lua (Cmd+Shift+O: types the latest 2FA code from
    │                    # Messages — reads chat.db via hs.sqlite3, so
    │                    # Hammerspoon needs Full Disk Access)
    └── work/            # same shape (+ chrome.lua). Targets Chrome TABS (one
                         # always-alive tab group: Gmail/Calendar/Tasks/Jira/
                         # Slack web), not PWAs, via in-process AppleScript
                         # (hs.osascript — never shell out per keypress; a
                         # spawned chrome-cli/osascript cost seconds, this
                         # costs ~100ms).
                         # Company-specific URLs/paths never live in this
                         # public repo — they come from the machine-local
                         # override file ~/.config/hammerspoon/work-local.lua
                         # (see profiles/work/constants.lua for its shape)
```

`profiles/personal/scripts/toggle_messages_sidebar` is a compiled Swift
binary and is gitignored — rebuild it with the `swiftc` command in the
comment above `toggleMessagesSidebar` in `profiles/personal/appBasedHotkeys.lua`.

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

**Whenever a hotkey is added, changed, or removed here, mirror it in the Notion Hotkeys DB** (data_source_id `1bb03953-a8af-801d-8436-000b25e00006` — see the `notion` skill). That DB is the documentation of every binding; an edit to the Lua config isn't done until the corresponding Notion entry is created/updated/archived too.

### Hyper Key

The "Hyper" modifier (`Cmd+Alt+Ctrl+Shift`) is defined in `constants.hyperKeyMods`. Karabiner-Elements maps Caps Lock → F19 → the hyper combination.

### Window Management

Window management uses yabai (nix-installed via nix-config `services.yabai`). Functions in `globalHotkeys.lua` shell out to `constants.paths.yabai` for positioning. Some window actions attempt native macOS menu items first via `helpers.tryMenuItem()` before falling back to yabai.

## External Dependencies

- **yabai**: Window manager, nix-installed (`services.yabai` in nix-config) — path in `constants.paths.yabai` (`/run/current-system/sw/bin/yabai`)
- **Karabiner-Elements**: For Caps Lock → Hyper key mapping (optional)
- **Raycast**: Profile uses Raycast deep links for clipboard history, emoji search, file search, bluetooth management
- **Full Disk Access** (personal profile only): the OTP hotkey reads `~/Library/Messages/chat.db` in-process; without the grant it logs an error and does nothing
- **Chrome**: Several scripts target Chrome specifically; the personal profile uses Chrome PWAs (identified by `com.google.Chrome.app.*` bundle IDs)
- **"Allow JavaScript from Apple Events"** (work profile only): the work profile's in-page JS hotkeys (`chrome.js`) require Chrome's View > Developer > "Allow JavaScript from Apple Events"; no external binaries needed
- **hs CLI**: Enabled via `require("hs.ipc")` for terminal commands like `hs -c "..."`