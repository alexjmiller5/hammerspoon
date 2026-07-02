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
  finder         = "com.apple.finder",
  xcode          = "com.apple.dt.Xcode",
  claude         = "com.anthropic.claudefordesktop",
  preview        = "com.apple.Preview",
}

M.paths = {
  searchClipTab       = home .. "/.hammerspoon/scripts/search_from_clipboard_in_new_tab.sh",
  searchClipWindow    = home .. "/.hammerspoon/scripts/search_from_clipboard_in_new_window.sh",
  searchClipIncognito = home .. "/.hammerspoon/scripts/search_incognito_from_clipboard.sh",
  chromeJsInjector    = home .. "/.hammerspoon/scripts/chrome_js_injector.applescript",
  hsConfig            = home .. "/.hammerspoon"
}

return M
