local log = hs.logger.new("Profile Init", "debug")

-- Require modules

local helperFunctions = require("helperFunctions")
local profileGlobalHotkeyDefinitions = require("profiles.work.globalHotkeys").definitions
local profileAppBasedHotkeyDefinitions = require("profiles.work.appBasedHotkeys").definitions
local profileConstants = require("profiles.work.constants")

-- Bind hotkeys

helperFunctions.bindGlobalHotkeys(profileGlobalHotkeyDefinitions)
-- We access the 'AppBasedHotkeyRegistry' Global defined in the main init.lua
helperFunctions.registerAppBasedHotkeys(AppBasedHotkeyRegistry, profileAppBasedHotkeyDefinitions)

log.i(profileConstants.profileName .. " profile Loaded")
