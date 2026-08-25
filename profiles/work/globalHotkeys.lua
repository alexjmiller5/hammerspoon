local constants = require("profiles.work.constants")
local chrome = require("profiles.work.chrome")

local M = {}

local actions = {
  -- Tab-group jumps (Chrome tabs, not PWAs — see chrome.lua)
  focusGmail    = function() chrome.focusTab(constants.tabs.gmail) end,
  focusCalendar = function() chrome.focusTab(constants.tabs.calendar) end,
  focusTasks    = function() chrome.focusTab(constants.tabs.tasks) end,
  focusDrive    = function() chrome.focusTab(constants.tabs.drive) end,
  focusSlack    = function() chrome.focusTab(constants.tabs.slack) end,
  focusJira     = function()
    if constants.tabs.jira.url == "" then
      hs.alert.show("Set tabs.jira in ~/.config/hammerspoon/work-local.lua")
    end
    chrome.focusTab(constants.tabs.jira)
  end,

  openChromePasswords = function()
    hs.osascript.applescript([[
      tell application "Google Chrome" to make new window
      tell application "Google Chrome" to set URL of active tab of front window to "chrome://password-manager/passwords"
      tell application "Google Chrome" to activate
    ]])
  end,
}

M.definitions = {
  { mods = { "alt" },          key = "m", action = actions.focusGmail },
  { mods = { "alt" },          key = "c", action = actions.focusCalendar },
  { mods = { "alt" },          key = "h", action = actions.focusDrive },
  { mods = { "alt" },          key = "j", action = actions.focusJira },
  { mods = { "alt" },          key = "l", action = actions.openChromePasswords },
  { mods = { "alt", "shift" }, key = "n", action = actions.focusTasks },
  { mods = { "alt", "shift" }, key = "m", action = actions.focusSlack },
}

return M
