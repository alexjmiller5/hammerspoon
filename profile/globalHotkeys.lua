local log = hs.logger.new("Profile Global Hotkeys", "debug")

local profileConstants = require("profile.constants")
local constants = require("constants")
local helpers = require("helperFunctions")

local M = {}

local actions = {
  -- App Launchers
  launchGoogleMaps = function() hs.application.launchOrFocusByBundleID(profileConstants.appBundleIds.googleMaps) end,
  launchHomeAssistant = function() hs.application.launchOrFocusByBundleID(profileConstants.appBundleIds.homeAssistant) end,
  launchKarabiner = function() hs.application.launchOrFocusByBundleID(profileConstants.appBundleIds.karabiner) end,
  launchLegcord = function() hs.application.launchOrFocusByBundleID(profileConstants.appBundleIds.legcord) end,
  launchMail = function() hs.application.launchOrFocusByBundleID(profileConstants.appBundleIds.mail) end,
  launchMessages = function() hs.application.launchOrFocusByBundleID(profileConstants.appBundleIds.messages) end,
  launchNotion = function() hs.application.launchOrFocusByBundleID(profileConstants.appBundleIds.notion) end,
  launchNotionCalendar = function() hs.application.launchOrFocusByBundleID(profileConstants.appBundleIds.notionCalendar) end,
  launchPhotos = function() hs.application.launchOrFocusByBundleID(profileConstants.appBundleIds.photos) end,
  launchWhatsApp = function() hs.application.launchOrFocusByBundleID(profileConstants.appBundleIds.whatsapp) end,
  launchOnePassword = function() hs.application.launchOrFocusByBundleID(profileConstants.appBundleIds.onePassword) end,
  launchNotes = function() hs.application.launchOrFocusByBundleID(constants.appBundleIds.notes) end,
  launchTelegram = function() hs.application.launchOrFocusByBundleID(profileConstants.appBundleIds.telegram) end,

  openHomeAssistantConfig = function()
    hs.execute(
      "/usr/bin/open 'vscode://vscode-remote/ssh-remote+home-assistant-tailscale/homeassistant?windowId=_blank'")
  end,

  -- Specific Chrome Launcher from Karabiner
  launchChromeNewWindow = function()
    hs.task.new("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", nil, { "--new-window" }):start()
  end,

  -- Home Assistant Actions
  toggleLights = function()
    os.execute("curl -X POST http://home-assistant:8123/api/webhook/-yUrGzgTyzR953PAr3ndMGQaD")
  end,
  toggleCurtains = function()
    os.execute("curl -X POST http://home-assistant:8123/api/webhook/-O-SiE-KQqWSyyT8qolHlwsb1")
  end,
  toggleACUnit = function()
    os.execute("/usr/bin/shortcuts run 'Toggle AC Unit'")
  end,


  -- Raycast Extensions
  openClipboardHistory = function()
    os.execute(
      "/usr/bin/open 'raycast-x://extensions/raycast/clipboard-history/clipboard-history'")
  end,
  pasteLatestOtpCode = function()
    os.execute(
      "/usr/bin/open 'raycast-x://extensions/thomaslombart/messages/paste-latest-otp-code'")
  end,
  searchEmojisAndSymbols = function()
    os.execute(
      "/usr/bin/open 'raycast-x://extensions/raycast/emoji-symbols/search-emoji-symbols'")
  end,
  searchFiles = function() os.execute("/usr/bin/open 'raycast-x://extensions/raycast/file-search/search-files'") end,
  manageBluetoothConnections = function()
    os.execute(
      "/usr/bin/open 'raycast-x://extensions/VladCuciureanu/toothpick/manage-bluetooth-connections'")
  end,
  listRepos = function() hs.execute("/usr/bin/open 'raycast-x://extensions/moored/git-repos/list'") end,

  -- Shortcuts
  shazamToSpotify = function() os.execute("/usr/bin/shortcuts run 'Shazam → Spotify'") end,
  receptor = function() os.execute("/usr/bin/shortcuts run 'Receptor 💭'") end,

  -- Spotify Media Control Remaps
  spotifyNext = function() hs.eventtap.keyStroke({ "ctrl", "alt", "cmd" }, "0") end,
  spotifyPlayPause = function() hs.eventtap.keyStroke({ "ctrl", "alt", "cmd" }, "9") end,
  spotifyPrev = function() hs.eventtap.keyStroke({ "ctrl", "alt", "cmd" }, "8") end,

  -- Window Management
  windowMakeLarger = function() hs.execute("/opt/homebrew/bin/yabai -m window --ratio rel:0.05") end,
  windowMakeSmaller = function() hs.execute("/opt/homebrew/bin/yabai -m window --ratio rel:-0.05") end,
  nextDesktop = function() hs.execute("/opt/homebrew/bin/yabai -m space --focus next") end,
  prevDesktop = function() hs.execute("/opt/homebrew/bin/yabai -m space --focus prev") end,

  -- MacOS Clipboard History
  -- openClipboardHistory = function()
  --   hs.eventtap.keyStroke({ "alt" }, "space")
  --   hs.eventtap.keyStroke({ "cmd" }, "4")
  -- end,
}

-- Hotkey Definitions Table
M.definitions = {
  -- App Launchers
  { mods = { "alt" },                 key = "k",  action = actions.launchKarabiner },
  { mods = { "alt" },                 key = "d",  action = actions.launchLegcord },
  { mods = { "alt" },                 key = "m",  action = actions.launchMail },
  { mods = { "alt" },                 key = "n",  action = actions.launchNotion },
  { mods = { "alt" },                 key = "c",  action = actions.launchNotionCalendar },
  { mods = { "alt" },                 key = "p",  action = actions.launchPhotos },
  { mods = { "alt" },                 key = "w",  action = actions.launchWhatsApp },
  { mods = { "alt" },                 key = "1",  action = actions.launchOnePassword },
  { mods = { "alt" },                 key = "a",  action = actions.launchNotes },
  { mods = { "alt" },                 key = "b",  action = actions.launchChromeNewWindow },
  { mods = { "alt" },                 key = "h",  action = actions.launchHomeAssistant },
  { mods = { "alt", "shift" },        key = "g",  action = actions.launchGoogleMaps },
  { mods = { "alt", "shift" },        key = "m",  action = actions.launchMessages },
  { mods = { "alt", "shift" },        key = "t",  action = actions.launchTelegram },
  { mods = { "cmd", "alt", "shift" }, key = "h",  action = actions.openHomeAssistantConfig },

  -- Home Assistant Actions
  { mods = constants.hyperKeyMods,    key = "l",  action = actions.toggleLights },
  { mods = constants.hyperKeyMods,    key = "c",  action = actions.toggleCurtains },
  { mods = constants.hyperKeyMods,    key = "a",  action = actions.toggleACUnit },

  -- Raycast Extensions
  { mods = { "cmd", "shift" },        key = "h",  action = actions.openClipboardHistory },
  { mods = { "cmd", "shift" },        key = "e",  action = actions.searchEmojisAndSymbols },
  { mods = { "cmd", "shift" },        key = "f",  action = actions.searchFiles },
  -- { mods = { "cmd", "shift" },        key = "b",  action = actions.manageBluetoothConnections },
  { mods = { "cmd", "shift" },        key = "l",  action = actions.listRepos },

  -- Shortcuts
  { mods = constants.hyperKeyMods,    key = "s",  action = actions.shazamToSpotify },
  { mods = constants.hyperKeyMods,    key = "r",  action = actions.receptor },
  { mods = constants.hyperKeyMods,    key = "q",  action = actions.receptor }, -- Added to match Karabiner

  -- Media Remaps
  { mods = { "cmd", "shift" },        key = "f9", action = actions.spotifyNext },
  { mods = { "cmd", "shift" },        key = "f8", action = actions.spotifyPlayPause },
  { mods = { "cmd", "shift" },        key = "f7", action = actions.spotifyPrev },

}

return M