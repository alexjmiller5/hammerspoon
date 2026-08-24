-- Chrome tab helpers built on chrome-cli (https://github.com/prasmussen/chrome-cli).
-- The work machine consolidates Gmail/Calendar/Tasks/Jira/Slack into one Chrome
-- tab group, so hotkeys target tabs by URL instead of PWA windows.
--
-- Requires in Chrome: View > Developer > "Allow JavaScript from Apple Events"
-- (chrome-cli execute is built on it).

local constants = require("constants")

local M = {}

-- ponytail: hs.execute(cmd, true) runs a login shell so chrome-cli is found via
-- PATH (mise/brew) with no hardcoded path. Costs ~100-300ms per invocation; if
-- that ever grates, replace "chrome-cli" below with an absolute path.
local function sh(cmd)
  local out = hs.execute(cmd, true)
  return out or ""
end

local function shellQuote(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

-- Run JS in the active tab of the front Chrome window.
function M.js(code)
  return sh("chrome-cli execute " .. shellQuote(code))
end

-- Focus the first tab whose URL matches tab.pattern (grep -E), opening
-- tab.url if no tab matches, then bring Chrome forward.
function M.focusTab(tab)
  if not (tab and tab.pattern) then return end
  local cmd = "id=$(chrome-cli list links | grep -E -m1 " .. shellQuote(tab.pattern)
      .. " | sed -E " .. shellQuote([[s/^\[([0-9]+:)?([0-9]+)\].*/\2/]]) .. "); "
      .. 'if [ -n "$id" ]; then chrome-cli activate -t "$id"; '
  if tab.url and tab.url ~= "" then
    cmd = cmd .. "else chrome-cli open " .. shellQuote(tab.url) .. "; "
  end
  cmd = cmd .. "fi"
  sh(cmd)
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
