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

-- TextClipboardHistory spoon: machine-local, copied into Spoons/ by the work
-- machine's bootstrap (gitignored here, like WorkspaceSnapshot). Load + bind
-- only when present so a machine without it still gets the rest of the profile.
local spoonOk = pcall(function()
  hs.loadSpoon("TextClipboardHistory")
  spoon.TextClipboardHistory:start()
  spoon.TextClipboardHistory:bindHotkeys({ toggle_clipboard = { { "cmd", "shift" }, "h" } })
end)
if not spoonOk then log.i("TextClipboardHistory spoon not installed; skipping") end

log.i(profileConstants.profileName .. " profile Loaded")
