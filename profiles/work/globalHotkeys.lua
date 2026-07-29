local log = hs.logger.new("Profile Global Hotkeys", "debug")

local constants = require("profiles.work.constants")

local M = {}

local actions = {
  -- App Launchers
  launchGmail = function() hs.application.launchOrFocusByBundleID(constants.appBundleIds.gmail) end,
  launchGoogleCalendar = function() hs.application.launchOrFocusByBundleID(constants.appBundleIds.googleCalendar) end,
  launchGoogleTasks = function() hs.application.launchOrFocusByBundleID(constants.appBundleIds.googleTasks) end,
  launchSlack = function() hs.application.launchOrFocusByBundleID(constants.appBundleIds.slack) end,
  launchGoogleDrive = function() hs.application.launchOrFocusByBundleID(constants.appBundleIds.googleDrive) end,
  
  -- Scripts / Specific Actions
  openArtifactoryInVscode = function()
    hs.task.new("/usr/bin/open", nil, { "vscode://file/" .. constants.paths.artifactoryRepo .. "?windowId=_blank" }):start()
  end,
  openChromePasswords = function()
    hs.osascript.applescriptFromFile(constants.paths.openGooglePasswordsManager)
  end,
}

-- Hotkey Definitions Table
M.definitions = {
  { mods = { "alt" },          key = "m", action = actions.launchGmail },
  { mods = { "alt" },          key = "c", action = actions.launchGoogleCalendar },
  { mods = { "alt" },          key = "h", action = actions.launchGoogleDrive },
  { mods = { "alt" },          key = "l", action = actions.openChromePasswords },
  { mods = { "alt", "shift" }, key = "n", action = actions.launchGoogleTasks },
  { mods = { "alt", "shift" }, key = "m", action = actions.launchSlack },
  { mods = { "alt", "shift" }, key = "a", action = actions.openArtifactoryInVscode },
}

return M