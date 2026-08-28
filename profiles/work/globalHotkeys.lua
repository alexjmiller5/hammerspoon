local constants = require("profiles.work.constants")
local chrome = require("profiles.work.chrome")
local helpers = require("helperFunctions")

local M = {}

local actions = {
  -- Window movers: native macOS menu items first, hs geometry fallback
  -- (no yabai on the work machine)
  windowMaximize = function()
    if not helpers.tryMenuItem({ "Window", "Fill" }) then
      local win = hs.window.focusedWindow()
      if win then win:maximize() end
    end
  end,
  windowLeft = function()
    if not helpers.tryMenuItem({ "Window", "Move & Resize", "Left" }) then
      local win = hs.window.focusedWindow()
      if win then win:moveToUnit({ x = 0, y = 0, w = 0.5, h = 1 }) end
    end
  end,
  windowRight = function()
    if not helpers.tryMenuItem({ "Window", "Move & Resize", "Right" }) then
      local win = hs.window.focusedWindow()
      if win then win:moveToUnit({ x = 0.5, y = 0, w = 0.5, h = 1 }) end
    end
  end,

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
  { mods = { "cmd", "shift" }, key = "m", action = actions.windowMaximize },
  { mods = { "cmd", "shift" }, key = ",", action = actions.windowLeft },
  { mods = { "cmd", "shift" }, key = ".", action = actions.windowRight },
  { mods = { "alt" },          key = "m", action = actions.focusGmail },
  { mods = { "alt" },          key = "c", action = actions.focusCalendar },
  { mods = { "alt" },          key = "n", action = actions.focusDrive },
  { mods = { "alt" },          key = "j", action = actions.focusJira },
  { mods = { "alt" },          key = "l", action = actions.openChromePasswords },
  { mods = { "alt", "shift" }, key = "n", action = actions.focusTasks },
  { mods = { "alt", "shift" }, key = "m", action = actions.focusSlack },
}

return M
