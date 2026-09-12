local constants = require("constants")
local profileConstants = require("activeProfile").require("constants")
local helpers = require("helperFunctions")

local M = {}

local function searchClipboard(mode)
  local script = helpers.requirePath(constants.paths.searchClipboard)
  if not script then return end
  local browser = helpers.requirePath(constants.paths.chrome, "executable")
  if not browser then return end
  local text = hs.pasteboard.getContents()
  if not text or text == "" then return end
  helpers.runTask(constants.paths.python, { script, "--mode", mode, "--browser", browser }, nil, text)
end

local function openFolder(path)
  if helpers.requirePath(path, "directory") then
    helpers.runTask("/usr/bin/open", { path })
  end
end

local actions = {
  -- App Launchers
  launchGhostty = function()
    hs.application.launchOrFocusByBundleID(constants.appBundleIds.ghostty)
  end,
  launchVSCode = function()
    hs.application.launchOrFocusByBundleID(constants.appBundleIds.vscode)
  end,
  launchNotes = function()
    hs.application.launchOrFocusByBundleID(constants.appBundleIds.notes)
  end,
  launchChromeNewWindow = function()
    helpers.runTask(constants.paths.chrome, { "--new-window" })
  end,
  launchZoom = function()
    hs.application.launchOrFocusByBundleID(constants.appBundleIds.zoom)
  end,
  launchSpotify = function()
    hs.application.launchOrFocusByBundleID(constants.appBundleIds.spotify)
  end,
  launchYouTube = function()
    hs.application.launchOrFocusByBundleID(profileConstants.appBundleIds.youtube)
  end,
  launchHammerspoon = function()
    hs.application.launchOrFocusByBundleID(constants.appBundleIds.hammerspoon)
  end,
  launchSystemSettings = function()
    hs.application.launchOrFocusByBundleID(constants.appBundleIds.systemSettings)
  end,
  launchXcode = function()
    hs.application.launchOrFocusByBundleID(constants.appBundleIds.xcode)
  end,
  launchFinder = function()
    hs.osascript.applescript(
      'tell application "Finder" \n if not (exists window 1) then make new Finder window \n activate \n end tell'
    )
  end,

  -- Scripts
  searchClipWindow = function()
    searchClipboard("window")
  end,
  searchClipIncognito = function()
    searchClipboard("incognito")
  end,
  openDesktopFolder = function()
    openFolder(profileConstants.paths.desktopFolder)
  end,
  openDocumentsFolder = function()
    openFolder(profileConstants.paths.documentsFolder)
  end,
  openApplicationsFolder = function()
    openFolder(profileConstants.paths.applicationsFolder)
  end,
  newIncognitoWindow = function()
    hs.osascript.applescript(
      'tell application "Google Chrome" to make new window with properties {mode:"incognito"} \n activate'
    )
    hs.application.launchOrFocusByBundleID(constants.appBundleIds.chrome)
  end,
  forceQuitApp = function()
    -- Native force-quit: SIGKILL (signal 9) the frontmost app directly via
    -- Hammerspoon — no shell/osascript needed. kill9() == `kill -9` (immediate,
    -- no cleanup), targeting exactly the app receiving input events.
    local app = hs.application.frontmostApplication()
    if app then app:kill9() end
  end,

  -- Window Management
  windowCenter = function()
    local window = hs.window.focusedWindow()
    if window then window:centerOnScreen() end
  end,

  windowLeft = function()
    if not helpers.tryMenuItem({ "Window", "Move & Resize", "Left" }) then
      -- Grid 1:2, start at 0, span 1 (Left Half)
      helpers.runTask(constants.paths.yabai, { "-m", "window", "--grid", "1:2:0:0:1:1" })
    end
  end,

  windowRight = function()
    if not helpers.tryMenuItem({ "Window", "Move & Resize", "Right" }) then
      -- Grid 1:2, start at 1, span 1 (Right Half)
      helpers.runTask(constants.paths.yabai, { "-m", "window", "--grid", "1:2:1:0:1:1" })
    end
  end,

  windowMaximize = function()
    if not helpers.tryMenuItem({ "Window", "Fill" }) then
      -- Grid 1:1, full span (Maximize)
      helpers.runTask(constants.paths.yabai, { "-m", "window", "--grid", "1:1:0:0:1:1" })
    end
  end,

  windowBottomHalf = function()
    if not helpers.tryMenuItem({ "Window", "Move & Resize", "Bottom" }) then
      -- Grid 2:1 (2 rows, 1 col), start at x:0 y:1, span 1x1
      helpers.runTask(constants.paths.yabai, { "-m", "window", "--grid", "2:1:0:1:1:1" })
    end
  end,

  windowTopLeft = function()
    if not helpers.tryMenuItem({ "Window", "Move & Resize", "Top Left" }) then
      -- Grid 2:2, start 0,0 (Top Left Quarter)
      helpers.runTask(constants.paths.yabai, { "-m", "window", "--grid", "2:2:0:0:1:1" })
    end
  end,

  windowBottomLeft = function()
    if not helpers.tryMenuItem({ "Window", "Move & Resize", "Bottom Left" }) then
      -- Grid 2:2, start 0,1 (Bottom Left Quarter)
      helpers.runTask(constants.paths.yabai, { "-m", "window", "--grid", "2:2:0:1:1:1" })
    end
  end,

  windowTopRight = function()
    if not helpers.tryMenuItem({ "Window", "Move & Resize", "Top Right" }) then
      -- Grid 2:2, start 1,0 (Top Right Quarter)
      helpers.runTask(constants.paths.yabai, { "-m", "window", "--grid", "2:2:1:0:1:1" })
    end
  end,

  windowBottomRight = function()
    if not helpers.tryMenuItem({ "Window", "Move & Resize", "Bottom Right" }) then
      -- Grid 2:2, start 1,1 (Bottom Right Quarter)
      helpers.runTask(constants.paths.yabai, { "-m", "window", "--grid", "2:2:1:1:1:1" })
    end
  end,

  windowMakeLarger = function()
    -- Increase window size ratio by 5%
    helpers.runTask(constants.paths.yabai, { "-m", "window", "--ratio", "rel:0.05" })
  end,

  windowMakeSmaller = function()
    -- Decrease window size ratio by 5%
    helpers.runTask(constants.paths.yabai, { "-m", "window", "--ratio", "rel:-0.05" })
  end,

  nextDesktop = function()
    helpers.runTask(constants.paths.yabai, { "-m", "space", "--focus", "next" })
  end,

  prevDesktop = function()
    helpers.runTask(constants.paths.yabai, { "-m", "space", "--focus", "prev" })
  end,

  -- Native Hammerspoon
  reloadConfig = function()
    hs.reload()
  end,

}

-- Hotkey Definitions Table
M.definitions = {
  -- App Launchers
  {
    mods = { "alt" },
    key = "t",
    action = actions.launchGhostty
  },
  { mods = { "alt" }, key = "a", action = actions.launchNotes },
  { mods = { "alt" }, key = "b", action = actions.launchChromeNewWindow },
  -- NOTE: alt+n / alt+shift+m / alt+shift+t deliberately have NO base
  -- bindings: the profiles own them. Profile bindings load after base ones and silently
  -- win any same-combo conflict, so a base binding here would be dead code.
  {
    mods = { "alt" },
    key = "v",
    action = actions.launchVSCode
  },
  {
    mods = { "alt" },
    key = "z",
    action = actions.launchZoom
  },
  {
    mods = { "alt" },
    key = "s",
    action = actions.launchSpotify
  },
  {
    mods = { "alt" },
    key = "y",
    action = actions.launchYouTube
  },
  {
    mods = { "alt", "shift" },
    key = "h",
    action = actions.launchHammerspoon
  },
  {
    mods = { "alt" },
    key = "x",
    action = actions.launchXcode
  },
  {
    mods = { "alt", "shift" },
    key = "s",
    action = actions.launchSystemSettings
  },
  {
    mods = { "alt" },
    key = "f",
    action = actions.launchFinder
  },
  -- Scripts
  {
    mods = { "alt", "shift" },
    key = "d",
    action = actions.openDesktopFolder
  },
  {
    mods = { "alt", "shift" },
    key = "e",
    action = actions.openDocumentsFolder
  },
  {
    mods = { "alt", "shift" },
    key = "a",
    action = actions.openApplicationsFolder
  },
  {
    mods = { "alt", "shift" },
    key = "b",
    action = actions.searchClipWindow
  },
  {
    mods = { "alt", "shift" },
    key = "i",
    action = actions.searchClipIncognito
  },
  {
    mods = { "alt" },
    key = "i",
    action = actions.newIncognitoWindow
  },
  {
    mods = { "cmd", "shift" },
    key = "q",
    action = actions.forceQuitApp
  },

  -- Window Management
  {
    mods = constants.hyperKeyMods,
    key = "/",
    action = actions.windowCenter
  },
  {
    mods = constants.hyperKeyMods,
    key = "left",
    action = actions.windowLeft
  },
  {
    mods = constants.hyperKeyMods,
    key = "right",
    action = actions.windowRight
  },
  {
    mods = constants.hyperKeyMods,
    key = "up",
    action = actions.windowMaximize
  },
  {
    mods = constants.hyperKeyMods,
    key = "down",
    action = actions.windowBottomHalf
  },
  {
    mods = constants.hyperKeyMods,
    key = "p",
    action = actions.windowTopLeft
  },
  {
    mods = constants.hyperKeyMods,
    key = ";",
    action = actions.windowBottomLeft
  },
  {
    mods = constants.hyperKeyMods,
    key = "[",
    action = actions.windowTopRight
  },
  {
    mods = constants.hyperKeyMods,
    key = "\'",
    action = actions.windowBottomRight
  },
  {
    mods = { "cmd", "shift" },
    key = "/",
    action = actions.windowCenter
  },
  {
    mods = { "cmd", "shift" },
    key = "=",
    action = actions.windowMakeLarger
  },
  {
    mods = { "cmd", "shift" },
    key = "-",
    action = actions.windowMakeSmaller
  },
  {
    mods = { "ctrl", "alt", "shift" },
    key = "right",
    action = actions.nextDesktop
  },
  {
    mods = { "ctrl", "alt", "shift" },
    key = "left",
    action = actions.prevDesktop
  },

  -- Hammerspoon Native
  {
    mods = constants.hyperKeyMods,
    key = "h",
    action = actions.reloadConfig
  },

}

return M
