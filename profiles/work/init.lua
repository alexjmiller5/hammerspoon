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

-- TextClipboardHistory spoon: Alex's customized fork of the official spoon
-- (full-text dedupe/paste, preview rows), committed at
-- Spoons/TextClipboardHistory.spoon. pcall so a checkout missing it (or a
-- broken spoon) still loads the rest of the profile.
local spoonOk = pcall(function()
  hs.loadSpoon("TextClipboardHistory")
  spoon.TextClipboardHistory:start()
  spoon.TextClipboardHistory:bindHotkeys({ toggle_clipboard = { { "cmd", "shift" }, "h" } })
end)
if not spoonOk then log.i("TextClipboardHistory spoon not installed; skipping") end

log.i(profileConstants.profileName .. " profile Loaded")
