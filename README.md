# hammerspoon

My [Hammerspoon](https://www.hammerspoon.org/) configuration: app launchers,
context-aware per-app hotkeys, window management, and Chrome tab control,
organized around a runtime **profile system** so one repo serves machines with
different roles.

## Install

```sh
git clone https://github.com/alexjmiller5/hammerspoon ~/.hammerspoon
echo personal > ~/.config/hammerspoon-profile   # or: work
brew install --cask hammerspoon
```

Launch Hammerspoon, grant Accessibility, and reload after changes with
`hs -c "hs.reload()"` (install the CLI once via `hs.ipc.cliInstall()` in the
Hammerspoon console).

## Profiles

The base config (`init.lua` + top-level modules) loads everywhere; then
`profiles/<name>/` extends it. The active profile is chosen per machine by
`~/.config/hammerspoon-profile` (one line: `personal` or `work`; defaults to
`personal`) - the repo itself carries no machine identity.

- **personal** - native apps + Chrome PWAs
- **work** - drives a Chrome tab group (Gmail/Calendar/Tasks/Jira/Slack web)
  via in-process AppleScript; machine/company-specific values come from
  `~/.config/hammerspoon/work-local.lua`, never from the repo

Both profiles use Option+A for Apple Notes and Option+B for a new Chrome
window. Option+G opens the configured Gemini Chrome PWA on work and is
unbound on personal. If the work PWA has a different bundle ID, set
`appBundleIds.gemini` in the machine-local override file.

The work profile uses Cmd+Shift+\ for site panels in Docs, Confluence, and
Slack. In Gmail, U clicks a visible Undo notification; it types normally in
text fields, when the page lacks focus, or when no Undo is available.

## Optional dependencies

File-backed actions report missing dependencies or execution failures:
Raycast (clipboard/emoji/file search). Chrome's View > Developer > "Allow
JavaScript from Apple Events" is needed for the work profile's in-page JS
hotkeys.

## Hyper key (Caps Lock)

Hyper (`Cmd+Alt+Ctrl+Shift` in the definitions) needs no remapping app. Caps
Lock is mapped to F19 at the HID level, and `hyperKey.lua` holds every Hyper
binding in a hotkey modal while F19 is down; a quick tap still toggles Caps
Lock. Window placement (Hyper+Up/Left/Right/Down and the corners) is shared by
every profile, so a machine only needs the key itself:

1. Map Caps Lock to F19, now and at every login (hidutil mappings do not
   survive a reboot):
   ```sh
   hidutil property --matching '{"PrimaryUsagePage":1,"PrimaryUsage":6}' \
     --set '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":30064771129,"HIDKeyboardModifierMappingDst":30064771182}]}'
   ```
   The Nix-managed machines declare this through nix-config's exported
   `macos-hyper-key` module (`macos.hyperKey.enable = true`), which also
   installs the login job. Elsewhere, put the same command in a LaunchAgent.
2. Create the marker `~/.config/hammerspoon/native-hyper` (any content). With
   the marker, Hyper definitions bind inside the F19 modal; without it they
   bind as plain four-modifier hotkeys for a machine whose Hyper comes from
   another remapper. The Nix module writes the marker.
3. Remove any other Caps Lock remap (Karabiner, System Settings > Modifier
   Keys) and log out once: macOS caches its native modifier remap until the
   next login, so Caps keeps arriving as the old key until then.

Architecture, hotkey table format, and conventions: see [AGENTS.md](AGENTS.md).

## File-backed actions

Sounds, scripts, executables, and folders are checked when used. Charger audio
uses the current system output. Clipboard search passes literal text over stdin
and preserves Unicode and complete URLs. Optional local configuration can be
absent, while invalid existing configuration is reported.

On the personal profile, Hyper+T toggles the existing Tailscale connection
without changing its settings. A 30-second deadline bounds the whole toggle,
including the initial status query. Sign in to the native app first on each machine;
`HAMMERSPOON_TAILSCALE_BIN` can override the executable location. Cmd+F7/F8/F9
control Spotify through its native AppleScript interface. Cmd with the
top-row previous/play/next media keys also works without Fn/Globe. Plain media
keys retain their normal system behavior.

Regression checks run through `hs -c` using `scripts/test-*.lua`; they substitute
UI and process effects so they do not operate on your current app. Run the
clipboard CLI tests with `python3 scripts/test-search-clipboard.py`.
