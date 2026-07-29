local log = hs.logger.new("Profile App Based Hotkeys", "debug")

local constants = require("profiles.work.constants")

local M = {}

local actions = {
  -- PWA Actions
  pwaCloseWindow = function()
    hs.eventtap.keyStroke({ "cmd" }, "h")
  end,
  pwaDevTools = function()
    hs.eventtap.keyStroke({ "cmd", "alt" }, "i")
  end,
  
  -- Application-Specific Actions
  slackSearch = function()
    hs.eventtap.keyStroke({ "cmd" }, "g")
  end,
  slackToggleSidebar = function()
    hs.eventtap.keyStroke({ "cmd", "shift" }, "d")
  end
}

M.definitions = {
  [constants.appBundleIds.googleTasks]    = { 
    { mods = { "cmd" }, key = "w", action = actions.pwaCloseWindow }, 
    { mods = { "cmd", "shift" }, key = "d", action = actions.pwaDevTools } 
  },
  [constants.appBundleIds.googleCalendar] = { 
    { mods = { "cmd" }, key = "w", action = actions.pwaCloseWindow }, 
    { mods = { "cmd", "shift" }, key = "d", action = actions.pwaDevTools } 
  },
  [constants.appBundleIds.gmail]          = { 
    { mods = { "cmd" }, key = "w", action = actions.pwaCloseWindow }, 
    { mods = { "cmd", "shift" }, key = "d", action = actions.pwaDevTools } 
  },
  [constants.appBundleIds.googleDrive]    = { 
    { mods = { "cmd" }, key = "w", action = actions.pwaCloseWindow }, 
    { mods = { "cmd", "shift" }, key = "d", action = actions.pwaDevTools } 
  },
  [constants.appBundleIds.slack]          = {
    { mods = { "cmd" }, key = "\\", action = actions.slackToggleSidebar },
    { mods = { "cmd" }, key = "k",  action = actions.slackSearch }
  }
}

return M