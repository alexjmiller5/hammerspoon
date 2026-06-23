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

-- Hyperkey: disabled — using Karabiner-Elements to remap Caps Lock instead.
-- The hidutil-based fallback module is kept on disk at ./hyperkey.lua in case
-- Karabiner needs to be bypassed again. To re-enable:
--   1. Run: hidutil property --set '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x70000006E}]}'
--   2. Uncomment the two lines below.
-- HyperKey = require("hyperkey")
-- HyperKey.start()

hs.alert.show("Hammerspoon Config Loaded")