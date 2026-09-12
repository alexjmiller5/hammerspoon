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
├── windowManagement.lua # Native menu placement, geometry, resizing and Spaces navigation
├── appBasedHotkeys.lua  # Context-aware hotkeys (active only in specific apps)
├── scripts/             # Shell scripts invoked by hotkeys
├── Spoons/              # Vendored spoons, ALL committed (installed software
│                        # lives in the repo)
├── activeProfile.lua    # Reads ~/.config/hammerspoon-profile, resolves the active profile
└── profiles/            # Machine-role profiles (selected at runtime, default: personal)
    ├── personal/        # init.lua, constants.lua, globalHotkeys.lua,
    │                    # appBasedHotkeys.lua, watcherFunctions.lua, scripts/,
    │                    # otp.lua (Cmd+Shift+O: types the latest 2FA code from
    │                    # Messages - reads chat.db via hs.sqlite3, so
    │                    # Hammerspoon needs Full Disk Access), otpMail.lua
    │                    # (Alt+Shift+O: same from Gmail via the gog CLI -
    │                    # 1Password-backed, so it prompts Touch ID)
    └── work/            # same shape (+ chrome.lua). Targets Chrome TABS (one
                         # always-alive tab group: Gmail/Calendar/Tasks/Jira/
                         # Slack web), not PWAs, via in-process AppleScript
                         # (hs.osascript - never shell out per keypress; a
                         # spawned chrome-cli/osascript cost seconds, this
                         # costs ~100ms).
                         # Company-specific URLs/paths never live in this
                         # public repo - they come from the machine-local
                         # override file ~/.config/hammerspoon/work-local.lua
                         # (see profiles/work/constants.lua for its shape)
```

### Key Patterns

**Charger sound**: The personal profile plays `assets/mario-waow.mp3` when
power changes from battery to AC. Resolve bundled assets through
`hs.configdir` so playback does not depend on external folders or iCloud.

**File access**: Validate files and directories at the point of use with
`helpers.requirePath`; launch external commands with `helpers.runTask` and
separate argv. Missing dependencies and failed processes produce a concise
alert without logging subprocess output. Audio uses the current system output
unless an explicit device is supplied. Optional profile files may be absent;
existing invalid files produce an error and fall back safely. Native named
image resources are not filesystem paths. The Dock lookup remains a short
synchronous `defaults export` so its live preferences are read through cfprefsd.

Use `alt`, `option`, or `⌥` for the Option modifier. `opt` is silently ignored
by the installed Hammerspoon API and must not be used in definitions.

**Personal actions**: Hyper+B is global, including while Chrome is focused
with no windows. It focuses a Chrome window on the current Space, or creates
one when none exists. Cmd+Shift+S queues its current tab URL in
Receptor via the installed Shortcut. Hyper+T toggles an already enrolled
Tailscale connection. Cmd+F7/F8/F9 control Spotify directly. The personal
profile's `ProfileSpotifyMediaKeyWatcher` also handles Cmd with the
physical previous/play/next media keys, so Fn is unnecessary in media-key
mode. Plain media keys pass through. Claimed presses consume their repeats
and releases to prevent a second system action. Check with
`scripts/test-spotify-media-keys.lua` using native unposted events.

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

**Pass-through pattern**: When an app-based hotkey needs to temporarily let the original keystroke through (e.g. the work profile's `passThrough` re-sends the very keystroke that triggered it, which would otherwise re-trigger itself), use `helperFunctions.disableHotkeysForApp()` before sending the keystroke, then `enableHotkeysForApp()` in a `hs.timer.doAfter()` callback.

**Profile System**: `profiles/<name>/` dirs extend the base config; the active one is chosen at runtime by `activeProfile.lua`, which reads `~/.config/hammerspoon-profile` (one line: `personal` or `work` - written per machine by nix-config; defaults to `personal` if absent). The selected `profiles/<name>/init.lua` loads after the main init and adds hotkeys to the same global `AppBasedHotkeyRegistry`, via `pcall` so a broken profile doesn't crash the config. Main-config modules that need the active profile's constants use `require("activeProfile").require("constants")`.

**Shared launchers**: Option+A opens Apple Notes; Option+B creates a Chrome
window. Option+G launches the configured Gemini PWA only in the work profile;
the personal profile leaves it unbound. Gemini's Cmd+Shift+D DevTools binding
also belongs to the work profile.

**Work web hotkeys**: Cmd+Shift+\ toggles the active site's panel in Docs,
Confluence, or Slack. Slack's web button owns its toggle; sending Cmd+Shift+D
would collide with Chrome hotkeys. Unmodified U clicks Gmail's visible Undo
notification only while the page has focus and no editor/search field does.
Otherwise U passes through. Test dispatch and personal-profile compatibility
with `scripts/test-work-hotkeys.lua` through the hs CLI. Run
`bun scripts/test-work-web-hotkeys.mjs <page-CDP-WebSocket-URL>` against a
disposable `about:blank` tab for the browser DOM checks.

**Copy confirmation**: The shared `CopyConfirmationWatcher` shows a half-second
fading "Text Copied" badge at the focused screen's bottom-right corner for
nonempty text clipboard updates while Ghostty is frontmost. It never displays
or stores the copied text. This detects clipboard
changes, including copies from programs inside Ghostty, rather than their source.
Run its behavior check with
`hs -c 'print(pcall(dofile, hs.configdir .. "/scripts/test-copy-confirmation.lua"))'`.

**Windowless app reaper**: `WindowlessAppReaper` quits any app that shows a Dock
icon while running (`app:kind() == 1`), is not pinned to the Dock, and has no
windows - Preview and Shortcuts otherwise sit in the Dock forever after their
last window closes. It is an `hs.application.watcher` with no timer of its own:
every `deactivated` event schedules one check 1s later.

- **The check looks at every running app, not just the one focus left.** An app
  can lose its last window while already in the background, and no switch away
  from it will ever follow.
- **The 1s delay is what makes it correct, not just polite.** Window counts are
  not trustworthy at the instant focus leaves - LibreOffice still reports phantom
  windows then - so nothing is judged on window count until the delay is up.
- **An app that launched in the last 15s is deferred, not skipped**; its check is
  rescheduled for when the grace expires, because nothing else will come back to
  look at it.
- **Nothing happens without a focus switch.** An app that goes windowless while
  you keep using it is reaped the moment you switch away, which is also the first
  moment its stale Dock tile is in your way.

Pinned apps come from the live Dock prefs (`defaults export com.apple.dock`,
which reads through cfprefsd, so a tile pinned seconds ago already counts). That
subprocess costs ~25ms, so it is read only once an app has proven windowless -
an ordinary switch between apps with windows never pays for it - and a failed
read aborts rather than being treated as "nothing is pinned". Menu-bar-only
agents never reach `kind == 1`, so they are never candidates; Finder and
Hammerspoon are explicitly exempt. It quits with `app:kill()` (Quit AppleEvent,
save prompts intact). Run its behavior check with
`hs -c 'print(pcall(dofile, hs.configdir .. "/scripts/test-windowless-app-reaper.lua"))'`.

**Herdr shortcuts**: `herdrHotkeys.lua` gives Herdr the macOS shortcuts
(Cmd+T, Cmd+Shift+[/], Cmd+1..9, splits, sidebar, detach, ...) by typing its
ctrl+b prefix plus the matching key. Ghostty's own key table could do this, but
an active key table paints an indicator pill Ghostty has no option to hide.

- **Scoped per window, not per app.** The hotkeys are enabled only while a
  marked window is focused, so ordinary Ghostty windows keep Cmd+T, Cmd+W and
  the rest of their native shortcuts.
- **`herdr-window` claims its window with a sentinel file**
  (`$XDG_STATE_HOME/herdr-window/pending`, consumed by the `windowCreated`
  subscription) rather than an `hs -c` call, so opening a terminal never waits
  on - or fails with - the IPC port. A sentinel older than 30s is ignored.
- **Marked ids persist in `hs.settings`** and are pruned at load; a window
  closed while Hammerspoon was off can leave a stale id, which only matters if
  macOS hands that id to a new Ghostty window.
- **Adopt a herdr window that predates the marks** (or one opened another way)
  by focusing it and running
  `hs -c 'require("herdrHotkeys").markFocusedWindow()'`.
- **The prefix keys it types are pinned in nix-config's `home/herdr.nix`**, so
  a changed Herdr default cannot silently move a shortcut; `herdr config check`
  validates the pairs. Change one side, change the other.

Run its behavior check with
`hs -c 'print(pcall(dofile, hs.configdir .. "/scripts/test-herdr-hotkeys.lua"))'`.

**Ghostty links**: `GhosttyCommandClickWatcher` adds Shift to Command-only
left-click and hover events in Ghostty so native link opening bypasses Herdr's
mouse capture. Keyboard events and other modifier combinations pass through.
Run `scripts/test-ghostty-command-click.lua` through the hs CLI.

### Adding New Hotkeys

1. **Global hotkey**: Add action function to `actions` table in `globalHotkeys.lua`, then add definition to `M.definitions`
2. **App-specific hotkey**: Add action to `actions` table in `appBasedHotkeys.lua`, then add to `M.definitions` with `only` or `except` containing bundle IDs from `constants.appBundleIds`
3. **Profile-specific**: Same pattern in `profiles/<name>/globalHotkeys.lua` or `profiles/<name>/appBasedHotkeys.lua`, using that profile's `constants` for profile-only bundle IDs
4. **New bundle ID**: Add to `constants.appBundleIds` (shared) or `profiles/<name>/constants.appBundleIds` (profile-only)

**Whenever a hotkey is added, changed, or removed here, mirror it in the Notion Hotkeys DB** (data_source_id `1bb03953-a8af-801d-8436-000b25e00006` - see the `notion` skill). That DB is the documentation of every binding; an edit to the Lua config isn't done until the corresponding Notion entry is created/updated/archived too.

### Hyper Key

The "Hyper" modifier (`Cmd+Alt+Ctrl+Shift`) is defined in
`constants.hyperKeyMods`. Nix's exported `macos-hyper-key` module maps Caps
Lock to Right Control through macOS and creates
`~/.config/hammerspoon/native-hyper`. When that marker exists, `hyperKey.lua`
adds all four modifiers to each event carrying physical Right Control.
Right Control is reserved for Hyper. Start its event tap last, so the other
watchers receive the transformed flags first. No modifier-down events are
latched. A quick unused tap toggles Caps Lock; a chord or long hold does not.

Secure Input blocks the Hammerspoon transformation, so Caps behaves as Right
Control in that context. It requires Hammerspoon's Accessibility grant and
does not operate before login. Test native unposted events with
`scripts/test-hyper-key.lua`; also smoke-test a real Caps chord after setup.

The personal `ProfileAppInputRemapWatcher` prepends Cmd+K to Mail Escape and
adds Shift to WhatsApp Cmd+U. It preserves optional modifiers, ignores its
own generated Escape, and passes unrelated typing through. Verify with
`scripts/test-app-input-remaps.lua`.

### Window Management

`windowManagement.lua` owns window controls for both profiles. Placement tries
native Window menu items, then uses Hammerspoon geometry for halves, quarters,
and maximize. Resize changes both dimensions in 5% screen increments, centered
and bounded by the usable screen. Native Control-arrow handles adjacent Spaces;
generated arrow events include the Function flag, matching macOS defaults.
Nix's exported `macos-window-management` module declares those native shortcuts.

Finder keeps its native Cmd+Plus/Minus icon sizing and Cmd+Shift+Period hidden
files toggle. Window resize bindings and the work profile's right-placement
alias are disabled in Finder. Verify those exclusions with
`scripts/test-finder-shortcuts.lua`.

The same interface is available through the installed CLI:
`hs -c 'require("windowManagement").place("left")'` or
`hs -c 'require("windowManagement").resize(0.05)'`.
Run `scripts/test-window-management.lua` through the hs CLI for isolated tests.

**Contacts**: Cmd+E selects its native Edit > Edit Card menu. Cmd+S remains
the native save shortcut. The edit alias is scoped to Contacts and never
launches it. Verify with `scripts/test-contacts-hotkey.lua`.

## External Dependencies

- **Raycast**: Profile uses Raycast deep links for clipboard history, emoji search, file search, bluetooth management
- **Full Disk Access** (personal profile only): the OTP hotkey reads `~/Library/Messages/chat.db` in-process; without the grant it logs an error and does nothing
- **Chrome**: Several scripts target Chrome specifically; the personal profile uses Chrome PWAs (identified by `com.google.Chrome.app.*` bundle IDs)
- **"Allow JavaScript from Apple Events"** (work profile only): the work profile's in-page JS hotkeys (`chrome.js`) require Chrome's View > Developer > "Allow JavaScript from Apple Events"; no external binaries needed
- **hs CLI**: Enabled via `require("hs.ipc")` for terminal commands like `hs -c "..."`
