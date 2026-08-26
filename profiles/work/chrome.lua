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
-- event per window, and raising the window is "set index to 1".
function M.focusTab(tab)
  if not (tab and tab.match) then return end
  local fallback = ""
  if tab.url and tab.url ~= "" then
    fallback = "  open location " .. asQuote(tab.url) .. "\n"
  end
  hs.osascript.applescript([[
tell application "Google Chrome"
  repeat with w in windows
    try
      set urlList to URL of tabs of w
      repeat with i from 1 to count of urlList
        if item i of urlList contains ]] .. asQuote(tab.match) .. [[ then
          set active tab index of w to i
          -- activate BEFORE raising: raising an inactive app's window with
          -- "set index" doesn't decide which window becomes key on activation
          -- (the previously-key one sometimes wins) - raise after instead.
          activate
          set index of w to 1
          return
        end if
      end repeat
    end try
  end repeat
]] .. fallback .. [[
  activate
end tell]])
end

-- Front Chrome window title ("<tab title> - Google Chrome"). Cheap (no shell),
-- used to dispatch app-based hotkeys on which site the active tab is showing.
function M.frontTitle()
  local chrome = hs.application.get("com.google.Chrome")
  local win = chrome and chrome:focusedWindow()
  return win and win:title() or ""
end

return M
