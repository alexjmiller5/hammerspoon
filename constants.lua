local M = {}

M.hyperKeyMods = { "cmd", "alt", "ctrl", "shift" }

-- Application Bundle IDs
M.appBundleIds = {
  ghostty        = "com.mitchellh.ghostty",
  notes          = "com.apple.Notes",
  contacts       = "com.apple.AddressBook",
  finder         = "com.apple.finder",
  vscode         = "com.microsoft.VSCode",
  spotify        = "com.spotify.client",
  hammerspoon    = "org.hammerspoon.Hammerspoon",
  systemSettings = "com.apple.systempreferences",
  zoom           = "us.zoom.xos",
  slack          = "com.tinyspeck.slackmacgap",
  chrome         = "com.google.Chrome",
  island         = "io.island.Island",
  xcode          = "com.apple.dt.Xcode",
  claude         = "com.anthropic.claudefordesktop",
  preview        = "com.apple.Preview",
}

M.paths = {
  searchClipboard = hs.configdir .. "/scripts/search-clipboard.py",
  python = os.getenv("HAMMERSPOON_PYTHON") or "/usr/bin/python3",
  chrome = os.getenv("HAMMERSPOON_CHROME") or "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
}

return M
