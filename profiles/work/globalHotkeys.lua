local constants = require("profiles.work.constants")
local browser = require("profiles.work.browser")
local helpers = require("helperFunctions")

local M = {}

local actions = {
  -- Tab-group jumps (browser tabs, not PWAs — see browser.lua)
  focusGemini   = function() browser.focusTab(constants.tabs.gemini) end,
  focusYouTube  = function() browser.focusTab(constants.tabs.youtube) end,
  focusGmail    = function() browser.focusTab(constants.tabs.gmail) end,
  focusCalendar = function() browser.focusTab(constants.tabs.calendar) end,
  focusTasks    = function() browser.focusTab(constants.tabs.tasks) end,
  focusDrive    = function() browser.focusTab(constants.tabs.drive) end,
  focusSlack    = function() browser.focusTab(constants.tabs.slack) end,
  focusJira     = function()
    if constants.tabs.jira.url == "" then
      hs.alert.show("Set tabs.jira in ~/.config/hammerspoon/work-local.lua")
    end
    browser.focusTab(constants.tabs.jira)
  end,

  openPasswords = function() browser.openWindow("chrome://password-manager/passwords") end,
  -- Personal binds alt+shift+W to Raycast's Downloads Manager instead
  openDownloadsFolder = function() helpers.openFolder(constants.paths.downloadsFolder) end,
}

-- Option+Y overrides the shared YouTube PWA launcher (profile bindings win).
M.definitions = {
  { mods = { "alt" },          key = "g", action = actions.focusGemini },
  { mods = { "alt" },          key = "y", action = actions.focusYouTube },
  { mods = { "alt" },          key = "m", action = actions.focusGmail },
  { mods = { "alt" },          key = "c", action = actions.focusCalendar },
  { mods = { "alt" },          key = "n", action = actions.focusDrive },
  { mods = { "alt" },          key = "j", action = actions.focusJira },
  { mods = { "alt" },          key = "l", action = actions.openPasswords },
  { mods = { "alt", "shift" }, key = "n", action = actions.focusTasks },
  { mods = { "alt", "shift" }, key = "m", action = actions.focusSlack },
  { mods = { "alt", "shift" }, key = "w", action = actions.openDownloadsFolder },
}

return M
