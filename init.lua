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

-- Global Variables

PreviewSidebarVisible = false

-- WorkspaceSnapshot Spoon — hotkeys defined in globalHotkeys.lua. Vendored in
-- Spoons/ like every spoon (its dev home is the workspace-snapshot repo —
-- change it there, then re-copy here). pcall: a broken/missing spoon must not
-- kill the rest of the config.
local spoonOk, spoonErr = pcall(function() hs.loadSpoon("WorkspaceSnapshot"):start() end)
if not spoonOk then
  log.w("WorkspaceSnapshot spoon failed to load: " .. tostring(spoonErr))
end

hs.alert.show("Hammerspoon Config Loaded")