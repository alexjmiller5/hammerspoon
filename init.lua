local log = hs.logger.new("Init", "debug")

-- Activate the hammerspoon cli

require("hs.ipc")

-- Require modules

local helperFunctions = require("helperFunctions")
local watcherFunctions = require("watcherFunctions")
local globalDefHotkeyDefinitions = require("globalHotkeys").definitions
local AppBasedHotkeyDefintions = require("appBasedHotkeys").definitions

-- Bind hotkeys

AppBasedHotkeyRegistry = {}

helperFunctions.bindGlobalHotkeys(globalDefHotkeyDefinitions)
helperFunctions.registerAppBasedHotkeys(AppBasedHotkeyRegistry, AppBasedHotkeyDefintions)

-- Load profile: runtime-selected via ~/.config/hammerspoon-profile (see
-- activeProfile.lua); profiles live in profiles/<name>/.

local activeProfile = require("activeProfile")
local status, err = pcall(activeProfile.require, "init")
if not status then
    log.w("Profile '" .. activeProfile.name .. "' failed to load: " .. tostring(err))
end

-- Instantiate and start watchers

-- 1. App Based Hotkey Watcher
helperFunctions.updateActiveAppHotkeys(hs.application.frontmostApplication(), AppBasedHotkeyRegistry, nil)
MainAppWatcher = watcherFunctions.createAppBasedHotkeyWatcher(AppBasedHotkeyRegistry)
MainAppWatcher:start()

CopyConfirmationWatcher = watcherFunctions.createCopyConfirmationWatcher()
GhosttyCommandClickWatcher = watcherFunctions.createGhosttyCommandClickWatcher():start()

-- Global Variables

PreviewSidebarVisible = false

hs.alert.show("Hammerspoon Config Loaded")
