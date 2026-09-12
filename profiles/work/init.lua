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
local spoonOk, spoonError = pcall(function()
  assert(helperFunctions.requirePath(hs.configdir .. "/Spoons/TextClipboardHistory.spoon/init.lua"),
    "TextClipboardHistory source is unavailable")
  hs.loadSpoon("TextClipboardHistory")
  spoon.TextClipboardHistory:start()
  spoon.TextClipboardHistory:bindHotkeys({ toggle_clipboard = { { "cmd", "shift" }, "h" } })
end)
if not spoonOk then log.e("TextClipboardHistory could not start: " .. tostring(spoonError)) end

log.i(profileConstants.profileName .. " profile Loaded")
