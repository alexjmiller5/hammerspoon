local log = hs.logger.new("Init", "debug")

-- Activate the hammerspoon cli

require("hs.ipc")

-- Load the diagnostic key logger based on config

-- require("keylogger"):start()

-- Require modules

local helperFunctions = require("helperFunctions")
local watcherFunctions = require("watcherFunctions")
local globalDefHotkeyDefinitions = require("globalHotkeys").definitions
local AppBasedHotkeyDefintions = require("appBasedHotkeys").definitions

-- Bind hotkeys

AppBasedHotkeyRegistry = {}

helperFunctions.bindGlobalHotkeys(globalDefHotkeyDefinitions)
helperFunctions.registerAppBasedHotkeys(AppBasedHotkeyRegistry, AppBasedHotkeyDefintions)

-- Load profile

local status, err = pcall(require, "profile.init")
if not status then
    log.w("No profile found: " .. tostring(err))
end

-- Instantiate and start watchers

-- 1. App Based Hotkey Watcher
helperFunctions.updateActiveAppHotkeys(hs.application.frontmostApplication(), AppBasedHotkeyRegistry, nil)
MainAppWatcher = watcherFunctions.createAppBasedHotkeyWatcher(AppBasedHotkeyRegistry)
MainAppWatcher:start()

-- -- 2. Mouse Watcher
-- MainMouseWatcher = watcherFunctions.createMouseWatcher()
-- MainMouseWatcher:start()

-- Global Variables

PreviewSidebarVisible = false

-- WorkspaceSnapshot Spoon — hotkeys defined in globalHotkeys.lua
hs.loadSpoon("WorkspaceSnapshot"):start()

hs.alert.show("Hammerspoon Config Loaded")