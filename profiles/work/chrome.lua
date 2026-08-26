-- Chrome tab helpers. The work machine consolidates Gmail/Calendar/Tasks/Jira/
-- Slack into one Chrome tab group, so hotkeys target tabs by URL instead of
-- PWA windows.
--
-- Everything runs as ONE in-process AppleScript per keypress (hs.osascript) —
-- no shell, no external binaries. Spawning chrome-cli/osascript per press cost
-- multiple seconds; this takes tens of milliseconds.
--
-- The JS hotkeys additionally require Chrome's View > Developer >
-- "Allow JavaScript from Apple Events".

local M = {}

-- Escape into an AppleScript double-quoted string literal
local function asQuote(s)
  return '"' .. s:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end

-- Run JS in the active tab of the front Chrome window.
function M.js(code)
  local ok, result = hs.osascript.applescript(
    "tell application \"Google Chrome\" to execute active tab of front window javascript "
    .. asQuote(code))
  return ok and result or nil
end

-- Focus the first tab whose URL contains tab.match (plain substring), opening
-- tab.url if no tab matches, then bring Chrome (and the tab's window) forward.
-- One pass, one Apple Events session: fetching "URL of tabs of w" is a single
-- event per window.
--
-- Raising the window is the hard part: "activate" lands on Chrome's most-
-- recently-used window, "set index"/AXRaise cannot cross Mission Control
-- spaces, and AX can't even SEE other-space windows to focus them. So after
-- activating, if the wrong window came up, walk Chrome's windows with real
-- cmd+` presses - macOS's own window cycling, which DOES switch spaces -
-- until the selected tab's title is frontmost.
function M.focusTab(tab)
  if not (tab and tab.match) then return end
  local fallback = ""
  if tab.url and tab.url ~= "" then
    fallback = "  open location " .. asQuote(tab.url) .. "\n"
  end
  local ok, tabTitle = hs.osascript.applescript([[
tell application "Google Chrome"
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
end tell]])
  if not ok or type(tabTitle) ~= "string" or tabTitle == "" then return end

  local function frontMatches()
    return M.frontTitle():find(tabTitle, 1, true) == 1
  end
  local attempts = 0
  local function step()
    if frontMatches() or attempts >= 8 then return end
    attempts = attempts + 1
    hs.eventtap.keyStroke({ "cmd" }, "`", 0, hs.application.get("com.google.Chrome"))
    hs.timer.doAfter(0.25, step)
  end
  hs.timer.doAfter(0.3, step)
end

-- Front Chrome window title ("<tab title> - Google Chrome"). Cheap (no shell),
-- used to dispatch app-based hotkeys on which site the active tab is showing.
function M.frontTitle()
  local chrome = hs.application.get("com.google.Chrome")
  local win = chrome and chrome:focusedWindow()
  return win and win:title() or ""
end

return M
