local log = hs.logger.new("Profile Global Hotkeys", "debug")

local profileConstants = require("profiles.personal.constants")
local constants = require("constants")
local helpers = require("helperFunctions")
local otp = require("profiles.personal.otp")
local otpMail = require("profiles.personal.otpMail")
local tailscale = require("profiles.personal.tailscale")

local M = {}

-- Run a macOS Shortcut asynchronously so a long-running shortcut
-- doesn't block Hammerspoon's main thread (and every other hotkey)
local function runShortcut(name)
  helpers.runTask("/usr/bin/shortcuts", { "run", name })
end

local actions = {
  focusChrome = function()
    local space = hs.spaces.focusedSpace()
    if not space then
      helpers.reportError("Could not determine the current Space")
      return
    end
    local app = hs.application.get(constants.appBundleIds.chrome)
    local existing = {}
    for _, win in ipairs(app and app:allWindows() or {}) do
      existing[win:id()] = true
      if win:isStandard() and not win:isMinimized() then
        for _, windowSpace in ipairs(hs.spaces.windowSpaces(win:id()) or {}) do
          if windowSpace == space then win:focus(); return end
        end
      end
    end
    local ok = hs.osascript.applescript(
      'tell application id "com.google.Chrome" to make new window')
    if not ok then helpers.reportError("Could not create a Chrome window"); return end
    -- Chrome's script window IDs differ from native window IDs. Wait for the
    -- new native window, then enforce the requested Space before focusing it.
    local function focusCreated(attempt)
      local chrome = hs.application.get(constants.appBundleIds.chrome)
      for _, win in ipairs(chrome and chrome:allWindows() or {}) do
        if not existing[win:id()] and win:isStandard() then
          local onSpace = false
          for _, id in ipairs(hs.spaces.windowSpaces(win:id()) or {}) do
            if id == space then onSpace = true end
          end
          if not onSpace and not hs.spaces.moveWindowToSpace(win, space) then
            helpers.reportError("Could not move the new Chrome window to this Space")
            return
          end
          win:focus()
          return
        end
      end
      if attempt < 10 then
        hs.timer.doAfter(0.1, function() focusCreated(attempt + 1) end)
      else
        helpers.reportError("Chrome's new window is not available yet")
      end
    end
    focusCreated(1)
  end,

  -- App Launchers
  launchGoogleMaps = function() hs.application.launchOrFocusByBundleID(profileConstants.appBundleIds.googleMaps) end,
  launchKarabiner = function() hs.application.launchOrFocusByBundleID(profileConstants.appBundleIds.karabiner) end,
  launchLegcord = function() hs.application.launchOrFocusByBundleID(profileConstants.appBundleIds.legcord) end,
  launchMail = function() hs.application.launchOrFocusByBundleID(profileConstants.appBundleIds.mail) end,
  launchMessages = function() hs.application.launchOrFocusByBundleID(profileConstants.appBundleIds.messages) end,
  launchNotion = function() hs.application.launchOrFocusByBundleID(profileConstants.appBundleIds.notion) end,
  launchNotionCalendar = function() hs.application.launchOrFocusByBundleID(profileConstants.appBundleIds.notionCalendar) end,
  launchPhotos = function() hs.application.launchOrFocusByBundleID(profileConstants.appBundleIds.photos) end,
  launchWhatsApp = function() hs.application.launchOrFocusByBundleID(profileConstants.appBundleIds.whatsapp) end,
  launchOnePassword = function() hs.application.launchOrFocusByBundleID(profileConstants.appBundleIds.onePassword) end,
  launchTelegram = function() hs.application.launchOrFocusByBundleID(profileConstants.appBundleIds.telegram) end,

  -- Raycast Extensions
  openClipboardHistory = function()
    hs.urlevent.openURL("raycast://extensions/raycast/clipboard-history/clipboard-history")
  end,
  searchEmojisAndSymbols = function()
    hs.urlevent.openURL("raycast://extensions/raycast/emoji-symbols/search-emoji-symbols")
  end,
  searchFiles = function() hs.urlevent.openURL("raycast://extensions/raycast/file-search/search-files") end,
  listRepos = function() hs.urlevent.openURL("raycast://extensions/moored/git-repos/list") end,
  manageDownloads = function()
    hs.urlevent.openURL("raycast://extensions/thomas/downloads-manager/manage-downloads")
  end,
  -- macOS built-in dictation; the menu item is only enabled with a text field focused
  dictate = function() helpers.tryMenuItem({ "Edit", "Start Dictation" }) end,
  -- Types the latest incoming 2FA code from Messages + Return (see otp.lua)
  pasteLatestOtp = otp.pasteLatest,
  -- Same, from Gmail via gog (Touch ID for 1Password) (see otpMail.lua)
  pasteLatestMailOtp = otpMail.pasteLatest,

  -- Shortcuts
  shazamToSpotify = function() runShortcut("Shazam → Spotify") end,
  receptor = function() runShortcut("Receptor 💭") end,

  toggleTailscale = tailscale.toggle,

  -- Control Spotify directly, regardless of which app has focus.
  spotifyNext = function() hs.spotify.next() end,
  spotifyPlayPause = function() hs.spotify.playpause() end,
  spotifyPrev = function() hs.spotify.previous() end,
}

-- Hotkey Definitions Table
M.definitions = {
  -- App Launchers
  { mods = constants.hyperKeyMods,    key = "b",  action = actions.focusChrome },
  { mods = { "alt" },                 key = "k",  action = actions.launchKarabiner },
  { mods = { "alt" },                 key = "d",  action = actions.launchLegcord },
  { mods = { "alt" },                 key = "m",  action = actions.launchMail },
  { mods = { "alt" },                 key = "n",  action = actions.launchNotion },
  { mods = { "alt" },                 key = "c",  action = actions.launchNotionCalendar },
  { mods = { "alt" },                 key = "p",  action = actions.launchPhotos },
  { mods = { "alt" },                 key = "w",  action = actions.launchWhatsApp },
  { mods = { "alt" },                 key = "1",  action = actions.launchOnePassword },
  { mods = { "alt", "shift" },        key = "g",  action = actions.launchGoogleMaps },
  { mods = { "alt", "shift" },        key = "m",  action = actions.launchMessages },
  { mods = { "alt", "shift" },        key = "t",  action = actions.launchTelegram },
  -- Raycast Extensions
  { mods = { "cmd", "shift" },        key = "h",  action = actions.openClipboardHistory },
  { mods = { "cmd", "shift" },        key = "e",  action = actions.searchEmojisAndSymbols },
  { mods = { "cmd", "shift" },        key = "f",  action = actions.searchFiles },
  { mods = { "cmd", "shift" },        key = "l",  action = actions.listRepos },
  { mods = { "alt", "shift" },        key = "w",  action = actions.manageDownloads },
  { mods = constants.hyperKeyMods,    key = "d",  action = actions.dictate },
  { mods = constants.hyperKeyMods,    key = "t",  action = actions.toggleTailscale },
  { mods = { "cmd", "shift" },        key = "o",  action = actions.pasteLatestOtp },
  { mods = { "alt", "shift" },        key = "o",  action = actions.pasteLatestMailOtp },

  -- Shortcuts
  { mods = constants.hyperKeyMods,    key = "s",  action = actions.shazamToSpotify },
  { mods = constants.hyperKeyMods,    key = "r",  action = actions.receptor },
  { mods = constants.hyperKeyMods,    key = "q",  action = actions.receptor }, -- Added to match Karabiner

  -- Media Remaps
  { mods = { "cmd" },                 key = "f9", action = actions.spotifyNext },
  { mods = { "cmd" },                 key = "f8", action = actions.spotifyPlayPause },
  { mods = { "cmd" },                 key = "f7", action = actions.spotifyPrev },

}

return M
