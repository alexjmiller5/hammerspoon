-- Chrome-scoped hotkeys dispatched on the active tab (by window title, which is
-- "<tab title> - Google Chrome") — the tab-group replacement for the old
-- per-PWA bindings. JS runs in the page via chrome-cli (see chrome.lua).
--
-- NOTE: Google Docs' menu bar ignores synthetic (untrusted) JS clicks, so
-- deleteCurrentGoogleDoc drives the real "Search the menus" UI (Option+/) with
-- genuine keystrokes instead.

local baseConstants = require("constants")
local chrome = require("profiles.work.chrome")
local helpers = require("helperFunctions")

local M = {}

local chromeBundleId = baseConstants.appBundleIds.chrome

-- Re-send the hotkey's own keystroke without re-triggering it (see the
-- pass-through pattern in AGENTS.md).
local function passThrough(mods, key)
  helpers.disableHotkeysForApp(AppBasedHotkeyRegistry, chromeBundleId)
  hs.eventtap.keyStroke(mods, key, 0)
  hs.timer.doAfter(0.2, function()
    helpers.enableHotkeysForApp(AppBasedHotkeyRegistry, chromeBundleId)
  end)
end

-- Synthetic-click helper prefixed onto JS payloads (mousedown+mouseup+click —
-- plain .click() is ignored by Gmail's side-panel tabs).
local jsClick = [[var clk=function(e){if(!e)return;
["mousedown","mouseup","click"].forEach(function(t){e.dispatchEvent(new MouseEvent(t,{bubbles:true}))});};
]]

local actions = {
  -- cmd+shift+\ — site-specific panel toggle (cmd+\ stays the general Chrome
  -- tab-strip sidebar everywhere)
  toggleSitePanel = function()
    local title = chrome.frontTitle()
    if title:find("Google Docs", 1, true) then
      -- Prefix match + getClientRects: in multi-tab docs the closed-state
      -- button is labeled "Show tabs & outlines, N tabs", and offsetParent
      -- is null for elements in fixed-position containers.
      chrome.js(jsClick .. [[clk([...document.querySelectorAll(
        '[aria-label^="Hide tabs & outlines"],[aria-label^="Show tabs & outlines"]')]
        .find(function(e){return e.getClientRects().length}));]])
    elseif title:find("Confluence", 1, true) then
      -- Confluence's own sidebar shortcut. Caveat: like the native shortcut,
      -- it only toggles when focus is outside a text field - mid-edit it
      -- types a literal "[".
      hs.eventtap.keyStroke({}, "[", 0, hs.application.get(chromeBundleId))
    else
      passThrough({ "cmd", "shift" }, "\\")
    end
  end,

  -- cmd+\ — context-aware sidebar toggle
  toggleContextSidebar = function()
    local title = chrome.frontTitle()
    if title:find("Gmail", 1, true) or title:find("Google Calendar", 1, true) then
      -- Google Tasks side panel (clicking its rail tab toggles open/closed)
      chrome.js(jsClick .. [[clk(document.querySelector('[aria-label="Tasks"]'));]])
    else
      -- Fall back to the base-config behavior: Chrome's tab-strip sidebar
      local ax = require("hs.axuielement")
      local app = hs.application.get(chromeBundleId)
      local win = app and app:focusedWindow()
      if not win then return end
      local button = helpers.findChromeSidebarButton(ax.windowElement(win), 0)
      if button then button:performAction("AXPress") end
    end
  end,

  -- cmd+K — Gmail: focus search; elsewhere pass through (Slack web uses it natively)
  searchCurrentSite = function()
    local title = chrome.frontTitle()
    if title:find("Gmail", 1, true) then
      chrome.js([[var i=document.querySelector('input[aria-label="Search mail"]');
        if(i){i.focus();i.select();}]])
    else
      passThrough({ "cmd" }, "k")
    end
  end,

  -- esc — Gmail search results: clear the search; everywhere else pass through
  escapeOrClearGmailSearch = function()
    local title = chrome.frontTitle()
    if title:find("Gmail", 1, true) and title:find("Search results", 1, true) then
      chrome.js(jsClick .. [[var c=document.querySelector('button[aria-label="Clear search"]');
        if(c){clk(c);}else{location.hash="#inbox";}]])
    else
      passThrough({}, "escape")
    end
  end,

  -- Slack DESKTOP app (kept alongside Slack web: Alex uses both)
  slackToggleSidebar = function()
    hs.eventtap.keyStroke({ "cmd", "shift" }, "d")
  end,
  slackSearch = function()
    hs.eventtap.keyStroke({ "cmd" }, "g")
  end,

  -- cmd+shift+backspace — Google Docs: move the current doc to trash.
  -- Docs menus reject untrusted clicks, so this types into the real
  -- "Search the menus" box (Option+/) with genuine keystrokes. Outside Docs
  -- the combo passes through (it's Chrome's Clear Browsing Data shortcut).
  deleteCurrentGoogleDoc = function()
    local title = chrome.frontTitle()
    if not title:find("Google Docs", 1, true) then
      passThrough({ "cmd", "shift" }, "delete")
      return
    end
    local app = hs.application.get(chromeBundleId)
    hs.eventtap.keyStroke({ "alt" }, "/", 0, app)
    hs.timer.doAfter(0.6, function()
      hs.eventtap.keyStrokes("move to trash")
      hs.timer.doAfter(0.8, function()
        hs.eventtap.keyStroke({}, "return", 0, app)
      end)
    end)
  end,
}

local chromeOnly = { chromeBundleId }
local slackOnly = { baseConstants.appBundleIds.slack }

M.definitions = {
  { mods = { "cmd" },          key = "\\",     action = actions.toggleContextSidebar,    only = chromeOnly },
  { mods = { "cmd", "shift" }, key = "\\",     action = actions.toggleSitePanel,         only = chromeOnly },
  { mods = { "cmd" },        key = "k",      action = actions.searchCurrentSite,       only = chromeOnly },
  { mods = {},               key = "escape", action = actions.escapeOrClearGmailSearch, only = chromeOnly },
  { mods = { "cmd", "shift" }, key = "delete", action = actions.deleteCurrentGoogleDoc, only = chromeOnly },
  { mods = { "cmd" },          key = "\\",     action = actions.slackToggleSidebar,      only = slackOnly },
  { mods = { "cmd" },          key = "k",      action = actions.slackSearch,             only = slackOnly },
}

return M
