local log = hs.logger.new("Init", "debug")

-- Activate the hammerspoon cli

require("hs.ipc")

-- hs.hotkey logs every enable/disable at info level. The app-based hotkey
-- watcher toggles dozens per app switch, and each line is mirrored to
-- connected hs CLI clients: one stalled client then blocks the main thread
-- inside the watcher callback and wedges the IPC.
hs.hotkey.setLogLevel("warning")

-- Require modules

local helperFunctions = require("helperFunctions")
local watcherFunctions = require("watcherFunctions")
local herdrHotkeys = require("herdrHotkeys")
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

-- Herdr's macOS-style shortcuts, live only in windows opened by hdr/herdr
HerdrWindowFilter = herdrHotkeys.start()

CopyConfirmationWatcher = watcherFunctions.createCopyConfirmationWatcher()
GhosttyCommandClickWatcher = watcherFunctions.createGhosttyCommandClickWatcher():start()

-- Quits unpinned Dock apps (Preview, Shortcuts, ...) when focus leaves them windowless
WindowlessAppReaper = watcherFunctions.createWindowlessAppReaper():start()

-- Nix opts in alongside its native Caps-to-Right-Control mapping (nil otherwise).
HyperKeyWatcher = require("hyperKey").start()

-- Global Variables

PreviewSidebarVisible = false

hs.alert.show("Hammerspoon Config Loaded")
