-- Browser tab helpers. The work machine consolidates Gmail/Calendar/Tasks/Jira/
-- Slack/Gemini into one tab group in the work browser (appBundleIds.browser:
-- Island by default, any Chromium browser that keeps Chrome's AppleScript
-- dictionary works), so hotkeys target tabs by URL instead of PWA windows.
--
-- Everything runs as ONE in-process AppleScript per keypress (hs.osascript) —
-- no shell, no external binaries. Spawning chrome-cli/osascript per press cost
-- multiple seconds; this takes tens of milliseconds.
--
-- The JS hotkeys additionally require the browser's View > Developer >
-- "Allow JavaScript from Apple Events".

local constants = require("profiles.work.constants")

local M = {}

-- Escape into an AppleScript double-quoted string literal
local function asQuote(s)
  return '"' .. s:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end

local function bundleID()
  return constants.appBundleIds.browser
end

-- "tell application id ..." resolves the browser by bundle ID, not by name.
local function tellBrowser()
  return "tell application id " .. asQuote(bundleID())
end

-- Run JS in the active tab of the front browser window.
function M.js(code)
  local ok, result = hs.osascript.applescript(
    tellBrowser() .. " to execute active tab of front window javascript " .. asQuote(code))
  return ok and result or nil
end

-- Open a URL in a new browser window and bring it forward.
function M.openWindow(url)
  hs.osascript.applescript(tellBrowser() .. [[

  make new window
  set URL of active tab of front window to ]] .. asQuote(url) .. [[

  activate
end tell]])
end

function M.focusTab(tab)
  if not (tab and tab.match) then return end
  local fallback = ""
  if tab.url and tab.url ~= "" then
    fallback = "  open location " .. asQuote(tab.url) .. "\n"
  end
  local script = tellBrowser() .. [[

  repeat with w in windows
    try
      set urlList to URL of tabs of w
      repeat with i from 1 to count of urlList
        if item i of urlList contains ]] .. asQuote(tab.match) .. [[ then
          set active tab index of w to i
          set theTitle to title of tab i of w
          activate
          set index of w to 1
          return theTitle
        end if
      end repeat
    end try
  end repeat
]] .. fallback .. [[
  activate
  return ""
end tell]]
  local ok, result = hs.osascript.applescript(script)
  if not ok or type(result) ~= "string" or result == "" then
    return
  end
  local tabTitle = result

  -- The raise only sticks once the browser is ALREADY the frontmost app: from
  -- the background, "activate" lands on its most-recent window and the
  -- pre-activation raise is ignored (macOS decides the key window, and
  -- nothing scriptable crosses Mission Control spaces from the back).
  -- Empirically a SECOND press always works - so automate the second press:
  -- once activation has landed, re-run the same raise script.
  --
  -- Success = the browser genuinely frontmost AND its focused window carries
  -- the tab's title. (app:focusedWindow() alone lies: it reports the
  -- browser's internal key window even when the browser isn't frontmost.)
  local attempts = 0
  local function step()
    local frontmost = hs.application.frontmostApplication()
    local browserFront = frontmost ~= nil and frontmost:bundleID() == bundleID()
    local front = M.frontTitle()
    if browserFront and front:find(tabTitle, 1, true) == 1 then
      return
    end
    if attempts >= 6 then
      return
    end
    attempts = attempts + 1
    if not browserFront then
      -- hs activation (NSRunningApplication, ignoring-other-apps) is more
      -- forceful than AppleScript "activate".
      local browserApp = hs.application.get(bundleID())
      if browserApp then browserApp:activate() end
    else
      hs.osascript.applescript(script)
    end
    hs.timer.doAfter(0.3, step)
  end
  hs.timer.doAfter(0.3, step)
end

-- Front browser window title (the active tab's title). Cheap (no shell),
-- used to dispatch app-based hotkeys on which site the active tab is showing.
function M.frontTitle()
  local browserApp = hs.application.get(bundleID())
  local win = browserApp and browserApp:focusedWindow()
  return win and win:title() or ""
end

return M
