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
`personal`) — the repo itself carries no machine identity.

- **personal** — native apps + Chrome PWAs
- **work** — drives a Chrome tab group (Gmail/Calendar/Tasks/Jira/Slack web)
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

Missing ones degrade gracefully (their hotkeys just don't fire): yabai (window
management), Karabiner-Elements (Caps Lock → Hyper), Raycast (clipboard/emoji/
file search). Chrome's View > Developer > "Allow
JavaScript from Apple Events" is needed for the work profile's in-page JS
hotkeys.

Architecture, hotkey table format, and conventions: see [AGENTS.md](AGENTS.md).
