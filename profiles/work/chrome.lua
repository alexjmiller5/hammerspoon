-- Chrome tab helpers built on chrome-cli (https://github.com/prasmussen/chrome-cli).
-- The work machine consolidates Gmail/Calendar/Tasks/Jira/Slack into one Chrome
-- tab group, so hotkeys target tabs by URL instead of PWA windows.
--
-- Requires in Chrome: View > Developer > "Allow JavaScript from Apple Events"
-- (chrome-cli execute is built on it).

local constants = require("constants")

local M = {}

-- Resolve chrome-cli ONCE via the user's login shell (finds mise/brew PATH with
-- no hardcoded path), then run every call through plain /bin/sh with the
-- absolute path — the interactive shell is slow and its startup output pollutes
-- captured stdout, so it must not run per keypress.
local chromeCliPath
local function chromeCli()
  if chromeCliPath == nil then
    local out = hs.execute("command -v chrome-cli", true) or ""
    chromeCliPath = out:match("(%S+)%s*$") or false -- last token skips shell-startup noise
    if not chromeCliPath then hs.alert.show("chrome-cli not found on PATH") end
  end
  return chromeCliPath or nil
end

local function shellQuote(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

-- Run JS in the active tab of the front Chrome window.
function M.js(code)
  local cli = chromeCli()
  if not cli then return "" end
  return hs.execute(shellQuote(cli) .. " execute " .. shellQuote(code)) or ""
end

-- Focus the first tab whose URL contains tab.match (plain substring), opening
-- tab.url if no tab matches, then bring Chrome (and the tab's window) forward.
-- `chrome-cli activate` selects the tab inside its window but does NOT raise
-- that window over other Chrome windows, so we raise it by id ourselves.
function M.focusTab(tab)
  if not (tab and tab.match) then return end
  local cli = chromeCli()
  if not cli then return end
  local winId, tabId
  local links = hs.execute(shellQuote(cli) .. " list links") or ""
  for line in links:gmatch("[^\n]+") do
    if line:find(tab.match, 1, true) then
      winId, tabId = line:match("^%[(%d+):(%d+)%]")
      tabId = tabId or line:match("^%[(%d+)%]") -- single-window output has no window id
      break
    end
  end
  if tabId then
    hs.execute(shellQuote(cli) .. " activate -t " .. tabId)
    if winId then
      hs.osascript.applescript(
        'tell application "Google Chrome" to set index of window id ' .. winId .. " to 1")
    end
  elseif tab.url and tab.url ~= "" then
    hs.execute(shellQuote(cli) .. " open " .. shellQuote(tab.url))
  end
  hs.application.launchOrFocusByBundleID(constants.appBundleIds.chrome)
end

-- Front Chrome window title ("<tab title> - Google Chrome"). Cheap (no shell),
-- used to dispatch app-based hotkeys on which site the active tab is showing.
function M.frontTitle()
  local chrome = hs.application.get(constants.appBundleIds.chrome)
  local win = chrome and chrome:focusedWindow()
  return win and win:title() or ""
end

return M
