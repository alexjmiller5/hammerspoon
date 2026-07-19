local log = hs.logger.new("Global Hotkeys", "debug")

local constants = require("constants")
local profileConstants = require("profile.constants")
local helpers = require("helperFunctions")

local M = {}

local actions = {
  -- App Launchers
  launchGhostty = function()
    hs.application.launchOrFocusByBundleID(constants.appBundleIds.ghostty)
  end,
  launchNotes = function()
    hs.application.launchOrFocusByBundleID(constants.appBundleIds.notes)
  end,
  launchVSCode = function()
    hs.application.launchOrFocusByBundleID(constants.appBundleIds.vscode)
  end,
  launchClaude = function()
    hs.application.launchOrFocusByBundleID(constants.appBundleIds.claude)
  end,
  launchGemini = function()
    -- The Gemini Desktop app runs windowless-resident (launched at login via
    -- its LaunchAgent), so launchOrFocus alone would activate an app with no
    -- window to show. Focus it if it already has a window; otherwise ask it to
    -- create one via its URL scheme (instant, since the process is warm).
    local app = hs.application.get(profileConstants.appBundleIds.gemini)
    if app and #app:allWindows() > 0 then
      app:activate()
    else
      hs.urlevent.openURL("geminiapp://open")
    end
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
  launchSlack = function()
    hs.application.launchOrFocusByBundleID(constants.appBundleIds.slack)
  end,
  launchSystemSettings = function()
    hs.application.launchOrFocusByBundleID(constants.appBundleIds.systemSettings)
  end,
  launchXcode = function()
    hs.application.launchOrFocusByBundleID(constants.appBundleIds.xcode)
  end,
  launchFinder = function()
    -- hs.application.launchOrFocusByBundleID(constants.appBundleIds.finder)
    hs.osascript.applescript(
      'tell application "Finder" \n if not (exists window 1) then make new Finder window \n activate \n end tell'
    )
  end,
  launchOrFocusChrome = function()
    hs.application.launchOrFocusByBundleID(constants.appBundleIds.chrome)
  end,
  launchChromeNewWindow = function()
    hs.task.new("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", nil, { "--new-window" }):start()
  end,

  -- Scripts
  searchClipTab = function()
    hs.task.new("/bin/sh", nil, { constants.paths.searchClipTab }):start()
  end,
  searchClipWindow = function()
    hs.task.new("/bin/sh", nil, { constants.paths.searchClipWindow }):start()
  end,
  searchClipIncognito = function()
    hs.task.new("/bin/sh", nil, { constants.paths.searchClipIncognito }):start()
  end,
  -- openHsConfigInVscode = function()
  --   hs.task.new("/usr/bin/open", nil, { "vscode://file/" .. constants.paths.hsConfig .. "?windowId=_blank" }):start()
  -- end,
  openDesktopFolder = function()
    hs.task.new("/usr/bin/open", nil, { profileConstants.paths.desktopFolder }):start()
  end,
  openDocumentsFolder = function()
    hs.task.new("/usr/bin/open", nil, { profileConstants.paths.documentsFolder }):start()
  end,
  openApplicationsFolder = function()
    hs.task.new("/usr/bin/open", nil, { profileConstants.paths.applicationsFolder }):start()
  end,
  newIncognitoWindow = function()
    hs.osascript.applescript(
      'tell application "Google Chrome" to make new window with properties {mode:"incognito"} \n activate'
    )
    hs.application.launchOrFocusByBundleID(constants.appBundleIds.chrome)
  end,
  newChromeWindow = function()
    hs.osascript.applescript('tell application "Google Chrome" to make new window \n activate')
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
    hs.execute([[
    export PATH=/opt/homebrew/bin:$PATH
    YABAI=$(which yabai)
    JQ=$(which jq)

    WIN_JSON=$($YABAI -m query --windows --window)
    DISP_JSON=$($YABAI -m query --displays --display)

    read -r W H IS_FLOAT <<< $(echo "$WIN_JSON" | $JQ -r '.frame.w, .frame.h, ."is-floating" | tonumber | floor')
    read -r DW DH DX DY <<< $(echo "$DISP_JSON" | $JQ -r '.frame.w, .frame.h, .frame.x, .frame.y | tonumber | floor')

    if [ "$IS_FLOAT" = "0" ]; then
      $YABAI -m window --toggle float
      sleep 0.1
    fi

    TARGET_X=$(( DX + (DW - W) / 2 ))
    TARGET_Y=$(( DY + (DH - H) / 2 ))

    $YABAI -m window --move abs:$TARGET_X:$TARGET_Y
  ]])
  end,

  windowLeft = function()
    if not helpers.tryMenuItem({ "Window", "Move & Resize", "Left" }) then
      -- Grid 1:2, start at 0, span 1 (Left Half)
      hs.execute("/opt/homebrew/bin/yabai -m window --grid 1:2:0:0:1:1")
    end
  end,

  windowRight = function()
    if not helpers.tryMenuItem({ "Window", "Move & Resize", "Right" }) then
      -- Grid 1:2, start at 1, span 1 (Right Half)
      hs.execute("/opt/homebrew/bin/yabai -m window --grid 1:2:1:0:1:1")
    end
  end,

  windowMaximize = function()
    if not helpers.tryMenuItem({ "Window", "Fill" }) then
      -- Grid 1:1, full span (Maximize)
      hs.execute("/opt/homebrew/bin/yabai -m window --grid 1:1:0:0:1:1")
    end
  end,

  windowBottomHalf = function()
    if not helpers.tryMenuItem({ "Window", "Move & Resize", "Bottom" }) then
      -- Grid 2:1 (2 rows, 1 col), start at x:0 y:1, span 1x1
      hs.execute("/opt/homebrew/bin/yabai -m window --grid 2:1:0:1:1:1")
    end
  end,

  windowTopLeft = function()
    if not helpers.tryMenuItem({ "Window", "Move & Resize", "Top Left" }) then
      -- Grid 2:2, start 0,0 (Top Left Quarter)
      hs.execute("/opt/homebrew/bin/yabai -m window --grid 2:2:0:0:1:1")
    end
  end,

  windowBottomLeft = function()
    if not helpers.tryMenuItem({ "Window", "Move & Resize", "Bottom Left" }) then
      -- Grid 2:2, start 0,1 (Bottom Left Quarter)
      hs.execute("/opt/homebrew/bin/yabai -m window --grid 2:2:0:1:1:1")
    end
  end,

  windowTopRight = function()
    if not helpers.tryMenuItem({ "Window", "Move & Resize", "Top Right" }) then
      -- Grid 2:2, start 1,0 (Top Right Quarter)
      hs.execute("/opt/homebrew/bin/yabai -m window --grid 2:2:1:0:1:1")
    end
  end,

  windowBottomRight = function()
    if not helpers.tryMenuItem({ "Window", "Move & Resize", "Bottom Right" }) then
      -- Grid 2:2, start 1,1 (Bottom Right Quarter)
      hs.execute("/opt/homebrew/bin/yabai -m window --grid 2:2:1:1:1:1")
    end
  end,

  windowMakeLarger = function()
    -- Increase window size ratio by 5%
    hs.execute("/opt/homebrew/bin/yabai -m window --ratio rel:0.05")
  end,

  windowMakeSmaller = function()
    -- Decrease window size ratio by 5%
    hs.execute("/opt/homebrew/bin/yabai -m window --ratio rel:-0.05")
  end,

  nextDesktop = function()
    hs.execute("/opt/homebrew/bin/yabai -m space --focus next")
  end,

  prevDesktop = function()
    hs.execute("/opt/homebrew/bin/yabai -m space --focus prev")
  end,

  -- Native Hammerspoon
  reloadConfig = function()
    hs.reload()
  end,

  -- Workspace Snapshot Spoon (closures resolve spoon.* at trigger time,
  -- after init.lua has called hs.loadSpoon)
  workspaceSnapshot = function()
    if spoon.WorkspaceSnapshot then spoon.WorkspaceSnapshot.snapshot() end
  end,
  workspaceSnapshotClose = function()
    if spoon.WorkspaceSnapshot then spoon.WorkspaceSnapshot.snapshotAndClose() end
  end,
  workspaceRestore = function()
    if spoon.WorkspaceSnapshot then spoon.WorkspaceSnapshot.restore() end
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
  {
    mods = { "alt" },
    key = "n",
    action = actions.launchNotes
  },
  {
    mods = { "alt" },
    key = "v",
    action = actions.launchVSCode
  },
  {
    mods = { "alt" },
    key = "g",
    action = actions.launchGemini
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
    key = "m",
    action = actions.launchSlack
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
  -- {
  --   mods = constants.hyperKeyMods,
  --   key = "b",
  --   action = actions.launchOrFocusChrome
  -- },

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
    key = "t",
    action = actions.searchClipTab
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
    mods = { "alt" },
    key = "b",
    action = actions.newChromeWindow
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

  -- Workspace Snapshot Spoon
  {
    mods = { "cmd", "shift", "alt" },
    key = "s",
    action = actions.workspaceSnapshot
  },
  {
    mods = { "cmd", "shift", "alt" },
    key = "x",
    action = actions.workspaceSnapshotClose
  },
  {
    mods = { "cmd", "shift", "alt" },
    key = "r",
    action = actions.workspaceRestore
  }
}

return M