local log = hs.logger.new("App Based Hotkeys", "debug")

local constants = require("constants")
local profileConstants = require("activeProfile").require("constants")
local helperFunctions = require("helperFunctions")

local M = {}

local actions = {
  pwaDevTools = function() hs.eventtap.keyStroke({ "cmd", "alt" }, "i") end,
  claudeToggleSidebar = function()
    hs.eventtap.keyStroke({ "cmd" }, ".")
  end,
  -- Gemini sidebar toggle (Cmd+\) is now handled natively inside the Gemini
  -- Desktop app via a bundled WKUserScript (see active-projects/gemini-desktop
  -- UserScripts/), so no Hammerspoon hotkey is needed here.
  xcodeToggleSidebar = function()
    if not helperFunctions.tryMenuItem({ "View", "Navigators", "Show Navigator" }) then
      helperFunctions.tryMenuItem({ "View", "Navigators", "Hide Navigator" })
    end
  end,
  zoomToggleMute = function() hs.eventtap.keyStroke({ "cmd", "shift" }, "a") end,
  spotifyToggleSidebars = function()
    hs.eventtap.keyStroke({ "alt", "shift" }, "l")
    hs.eventtap.keyStroke({ "alt", "shift" }, "r")
  end,
  chromeDuplicateTab = function()
    helperFunctions.tryMenuItem({ "Tab", "Duplicate Tab" })
    helperFunctions.tryMenuItem({ "Tab", "Select Previous Tab" })
  end,
  chromeDuplicateAndGoBack = function()
    helperFunctions.tryMenuItem({ "Tab", "Duplicate Tab" })
    helperFunctions.tryMenuItem({ "History", "Back" })
  end,
  chromeToggleDevTools = function()
    helperFunctions.tryMenuItem({ "View", "Developer", "Developer Tools" })
  end,
  chromeToggleSidebar = function()
    local ax = require("hs.axuielement")
    local chrome = hs.application.get(constants.appBundleIds.chrome)
    if not chrome then return end
    local win = chrome:focusedWindow()
    if not win then return end
    local button = helperFunctions.findChromeSidebarButton(ax.windowElement(win), 0)
    if button then button:performAction("AXPress") end
  end,

  previewToggleSidebar = function()
    if PreviewSidebarVisible then
      helperFunctions.tryMenuItem({ "View", "Hide Sidebar" })
      PreviewSidebarVisible = false
    else
      helperFunctions.tryMenuItem({ "View", "Thumbnails" })
      PreviewSidebarVisible = true
    end
  end,

  -- Hammerspoon Native
  hammerspoonReload = function()
    hs.reload()
  end,

  -- Generic
  quit = function()
    hs.eventtap.keyStroke({ "cmd" }, "q")
  end,
}

-- App bundle-ID lists for `only`/`except`, defined once and shared so a repeated
-- app (e.g. Chrome, used 4×) isn't spelled out on every definition. These lists
-- are only read (never mutated), so sharing one table across definitions is safe.
local apps = {
  claude      = { constants.appBundleIds.claude },
  xcode       = { constants.appBundleIds.xcode },
  gemini      = { profileConstants.appBundleIds.gemini },
  zoom        = { constants.appBundleIds.zoom },
  spotify     = { constants.appBundleIds.spotify },
  chrome      = { constants.appBundleIds.chrome },
  hammerspoon = { constants.appBundleIds.hammerspoon },
  notes       = { constants.appBundleIds.notes },
  preview     = { constants.appBundleIds.preview },
}

M.definitions = {
  -- Claude
  { mods = { "cmd" }, key = "\\", action = actions.claudeToggleSidebar,
    only = apps.claude },

  -- Xcode
  { mods = { "cmd" }, key = "\\", action = actions.xcodeToggleSidebar,
    only = apps.xcode },

  -- Gemini (native Gemini Desktop app). Sidebar toggle (Cmd+\) + auto-extended-
  -- thinking are handled by bundled WKUserScripts inside the app, not here.
  { mods = { "cmd", "shift" }, key = "d", action = actions.pwaDevTools,
    only = apps.gemini },

  -- Zoom
  { mods = { "cmd" }, key = "u", action = actions.zoomToggleMute,
    only = apps.zoom },

  -- Spotify
  { mods = { "cmd" }, key = "\\", action = actions.spotifyToggleSidebars,
    only = apps.spotify },

  -- Chrome
  { mods = { "cmd" },                 key = "\\", action = actions.chromeToggleSidebar,
    only = apps.chrome },
  { mods = { "cmd" },                 key = "d", action = actions.chromeDuplicateTab,
    only = apps.chrome },
  { mods = { "cmd", "alt", "shift" }, key = "[", action = actions.chromeDuplicateAndGoBack,
    only = apps.chrome },
  { mods = { "cmd", "shift" },        key = "d", action = actions.chromeToggleDevTools,
    only = apps.chrome },

  -- Hammerspoon
  { mods = { "cmd" }, key = "r", action = actions.hammerspoonReload,
    only = apps.hammerspoon },

  -- Notes
  { mods = { "cmd" }, key = "w", action = actions.quit,
    only = apps.notes },

  -- Preview
  { mods = { "cmd" }, key = "\\", action = actions.previewToggleSidebar,
    only = apps.preview },
}

return M
