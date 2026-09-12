local log = hs.logger.new("Profile Init", "debug")

-- Require modules

local helperFunctions = require("helperFunctions")
local profileGlobalHotkeyDefinitions = require("profiles.personal.globalHotkeys").definitions
local profileAppBasedHotkeyDefinitions = require("profiles.personal.appBasedHotkeys").definitions
local profileWatcherFunctions = require("profiles.personal.watcherFunctions")
local profileConstants = require("profiles.personal.constants")

-- Bind hotkeys

helperFunctions.bindGlobalHotkeys(profileGlobalHotkeyDefinitions)
-- We access the 'AppBasedHotkeyRegistry' Global defined in the main init.lua
helperFunctions.registerAppBasedHotkeys(AppBasedHotkeyRegistry, profileAppBasedHotkeyDefinitions)

-- Instantiate and start watchers

ProfileSpotifyMediaKeyWatcher = profileWatcherFunctions.createSpotifyMediaKeyWatcher():start()
ProfileAppInputRemapWatcher = profileWatcherFunctions.createAppInputRemapWatcher():start()

ProfilePowerWatcher = profileWatcherFunctions.createWatcherOnPowerConnect(function()
  helperFunctions.playAudioFileByPath(profileConstants.paths.marioWaowAudioFilePath)
end)

if ProfilePowerWatcher then
  ProfilePowerWatcher:start()
end

log.i(profileConstants.profileName .. " profile Loaded")
