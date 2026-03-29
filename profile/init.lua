local log = hs.logger.new("Profile Init", "debug")

-- Require modules

local helperFunctions = require("helperFunctions")
local profileGlobalHotkeyDefinitions = require("profile.globalHotkeys").definitions
local profileAppBasedHotkeyDefinitions = require("profile.appBasedHotkeys").definitions
local profileWatcherFunctions = require("profile.watcherFunctions")
local profileConstants = require("profile.constants")

-- Bind hotkeys

helperFunctions.bindGlobalHotkeys(profileGlobalHotkeyDefinitions)
-- We access the 'AppBasedHotkeyRegistry' Global defined in the main init.lua
helperFunctions.registerAppBasedHotkeys(AppBasedHotkeyRegistry, profileAppBasedHotkeyDefinitions)

-- Instantiate and start watchers

ProfilePowerWatcher = profileWatcherFunctions.createWatcherOnPowerConnect(function()
  helperFunctions.playAudioFileByPath(profileConstants.paths.marioWaowAudioFilePath)
end)

if ProfilePowerWatcher then
  ProfilePowerWatcher:start()
end

log.i(profileConstants.profileName .. " profile Loaded")
