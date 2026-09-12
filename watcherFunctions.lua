local log = hs.logger.new("Watchers", "debug")

local helperFunctions = require("helperFunctions")
local constants = require("constants")

local M = {}

function M.createAppBasedHotkeyWatcher(registry)
  local previousBundleID = nil

  return hs.application.watcher.new(function(appName, eventType, appObject)
    if eventType == hs.application.watcher.activated then
      previousBundleID = helperFunctions.updateActiveAppHotkeys(appObject, registry, previousBundleID)
    end
  end)
end

function M.createCopyConfirmationWatcher()
  local badge, dismiss
  return hs.pasteboard.watcher.new(function(text)
    local app = hs.application.frontmostApplication()
    if not text or text == "" or not app or app:bundleID() ~= constants.appBundleIds.ghostty then
      return
    end
    if dismiss then dismiss:stop() end
    if badge then badge:delete() end
    local frame = hs.screen.mainScreen():frame()
    badge = hs.canvas.new({ x = frame.x + frame.w - 148, y = frame.y + frame.h - 58, w = 128, h = 38 })
      :appendElements(
        { type = "rectangle", action = "fill", fillColor = { white = 0, alpha = 0.8 }, roundedRectRadii = { xRadius = 8, yRadius = 8 } },
        { type = "text", text = "Text Copied", textSize = 16, textFont = ".AppleSystemUIFont",
          textColor = { white = 1 }, textAlignment = "center", frame = { x = 0, y = 8, w = 128, h = 22 } }
      ):show(0.08)
    dismiss = hs.timer.doAfter(0.5, function()
      badge:delete(0.15)
      badge = nil
    end)
  end)
end

function M.createGhosttyCommandClickWatcher()
  local types = hs.eventtap.event.types
  return hs.eventtap.new({ types.mouseMoved, types.leftMouseDown, types.leftMouseUp }, function(event)
    local flags = event:getFlags()
    if flags.cmd and not flags.alt and not flags.ctrl and not flags.shift then
      local app = hs.application.frontmostApplication()
      if app and app:bundleID() == constants.appBundleIds.ghostty then
        -- Shift lets Ghostty open links even when Herdr captures the mouse.
        flags.shift = true
        event:setFlags(flags)
      end
    end
    return false
  end)
end

-- Apps that show a Dock icon while running (kind == 1) but are not pinned to the
-- Dock linger there with no windows - close the last Preview window and Preview
-- is still sitting in the Dock. Quit them as soon as focus leaves: switching away
-- is both the earliest honest signal that the app is idle and the moment its
-- stale Dock tile starts being in the way. Pinned apps are left alone, and
-- menu-bar-only agents (Codex bar, Synapse) never reach kind == 1, so they are
-- never candidates.
local reaperExempt = {
  [constants.appBundleIds.hammerspoon] = true,
  ["com.apple.finder"] = true, -- windowless by design, and relaunches anyway
}

-- `defaults export` goes through cfprefsd, so a tile pinned seconds ago is
-- already visible here; the on-disk plist can lag by minutes.
local function dockedBundleIDs()
  if not helperFunctions.requirePath("/usr/bin/defaults", "executable") then return nil end
  local ok, plist = pcall(hs.plist.readString, (hs.execute("/usr/bin/defaults export com.apple.dock -")))
  if not ok or not plist then
    log.w("[reaper] could not read the Dock's pinned apps, skipping sweep")
    return nil
  end
  local pinned = {}
  for _, tile in ipairs(plist["persistent-apps"] or {}) do
    local bundleID = tile["tile-data"] and tile["tile-data"]["bundle-identifier"]
    if bundleID then pinned[bundleID] = true end
  end
  return pinned
end

local reapSettleDelay = 1 -- let the switch settle before judging window counts
local reapLaunchGrace = 15 -- an app still opening its first window is not idle

-- Could this app ever be quit? Cheap - no subprocess. Window count is not part
-- of it: LibreOffice still reports phantom windows the instant focus leaves, so
-- counts are only worth trusting after the settle delay.
function M.reapEligible(app)
  local bundleID = app and app:bundleID()
  if not bundleID or reaperExempt[bundleID] or app:kind() ~= 1 then return nil end
  return bundleID
end

-- Seconds until this app can be judged fairly. An app that launched a moment ago
-- may simply not have drawn its first window yet.
function M.launchDeferral(app, launchedAt, now)
  local born = launchedAt[app:pid()]
  if not born then return 0 end
  local remaining = reapLaunchGrace - (now - born)
  return remaining > 0 and remaining or 0
end

-- Which apps to quit right now, plus how long until the soonest app that was too
-- freshly launched to judge. Every running app is examined rather than just the
-- one focus left, because an app can lose its last window while already in the
-- background - no switch away from it will ever follow. `pinnedLookup` is called
-- only once a candidate exists, so an ordinary switch never reads the Dock.
function M.appsToReap(apps, launchedAt, now, pinnedLookup)
  local ready, deferral = {}, nil
  for _, app in ipairs(apps) do
    local bundleID = M.reapEligible(app)
    if bundleID and not app:isFrontmost() and #app:allWindows() == 0 then
      local wait = M.launchDeferral(app, launchedAt, now)
      if wait > 0 then
        deferral = (deferral == nil or wait < deferral) and wait or deferral
      else
        ready[#ready + 1] = { app = app, bundleID = bundleID }
      end
    end
  end
  if #ready == 0 then return {}, deferral end

  local pinned = pinnedLookup()
  if not pinned then return {}, deferral end -- never quit without knowing what is pinned

  local quit = {}
  for _, candidate in ipairs(ready) do
    if not pinned[candidate.bundleID] then quit[#quit + 1] = candidate.app end
  end
  return quit, deferral
end

function M.createWindowlessAppReaper()
  local launchedAt, pending = {}, nil
  local events = hs.application.watcher

  local function reapSoon(delay)
    if pending then return end -- rapid Cmd+Tabbing needs one check, not a queue
    -- Held in `pending` because an unreferenced hs.timer is collected before it
    -- fires.
    pending = hs.timer.doAfter(delay, function()
      pending = nil
      local quit, deferral = M.appsToReap(hs.application.runningApplications(), launchedAt,
        hs.timer.secondsSinceEpoch(), dockedBundleIDs)
      for _, app in ipairs(quit) do
        log.i("[reaper] quit windowless unpinned app: " .. (app:name() or "?"))
        -- Graceful Quit AppleEvent, never kill9: save prompts stay intact.
        app:kill()
      end
      if deferral then reapSoon(deferral) end
    end)
  end

  return hs.application.watcher.new(function(_, event, app)
    if not app then return end
    if event == events.launched then
      launchedAt[app:pid()] = hs.timer.secondsSinceEpoch()
    elseif event == events.terminated then
      launchedAt[app:pid()] = nil
    elseif event == events.deactivated then
      reapSoon(reapSettleDelay)
    end
  end)
end

return M
