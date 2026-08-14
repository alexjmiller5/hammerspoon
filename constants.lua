local M = {}

local home = os.getenv("HOME")

M.hyperKeyMods = { "cmd", "alt", "ctrl", "shift" }

-- Application Bundle IDs
M.appBundleIds = {
  ghostty        = "com.mitchellh.ghostty",
  notes          = "com.apple.Notes",
  vscode         = "com.microsoft.VSCode",
  spotify        = "com.spotify.client",
  hammerspoon    = "org.hammerspoon.Hammerspoon",
  systemSettings = "com.apple.systempreferences",
  zoom           = "us.zoom.xos",
  slack          = "com.tinyspeck.slackmacgap",
  chrome         = "com.google.Chrome",
  xcode          = "com.apple.dt.Xcode",
  claude         = "com.anthropic.claudefordesktop",
  preview        = "com.apple.Preview",
}

M.paths = {
  searchClipWindow    = home .. "/.hammerspoon/scripts/search_from_clipboard_in_new_window.sh",
  searchClipIncognito = home .. "/.hammerspoon/scripts/search_incognito_from_clipboard.sh",
  -- yabai is nix-installed (services.yabai in nix-config) — NOT in /opt/homebrew
  yabai               = "/run/current-system/sw/bin/yabai",
}

return M
