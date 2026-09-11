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
-- is still sitting in the Dock. Quit those as soon as focus leaves them, with a
-- periodic sweep as the backstop. Pinned apps are left alone, and menu-bar-only
-- agents (Codex bar, Synapse) never reach kind == 1, so they are never
-- candidates.
local reaperExempt = {
  [constants.appBundleIds.hammerspoon] = true,
  ["com.apple.finder"] = true, -- windowless by design, and relaunches anyway
}

-- `defaults export` goes through cfprefsd, so a tile pinned seconds ago is
-- already visible here; the on-disk plist can lag by minutes.
local function dockedBundleIDs()
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

-- Cheap eligibility test - no subprocess, so it is safe on a focus switch.
-- Returns the bundle ID of an app we are allowed to quit, or nil. Pinned-ness is
-- deliberately NOT checked here: reading the Dock costs a subprocess, and almost
-- every app we are asked about turns out to still have windows.
local function reapCandidate(app)
  local bundleID = app and app:bundleID()
  if not bundleID or reaperExempt[bundleID] then return nil end
  if app:kind() ~= 1 or #app:allWindows() > 0 then return nil end
  return bundleID
end

-- One sweep - the backstop for apps that go windowless without a focus switch
-- (last window closed while the app stays frontmost). `state` maps bundle ID ->
-- "windowless" (seen empty once, still in its grace period) or "quit" (already
-- asked to quit - don't nag an unsaved-work dialog every sweep). Apps that
-- exited, regained a window, or got pinned just fall out of the returned state.
-- Returns the next state and the names it quit.
function M.reapWindowlessApps(state, apps, pinned)
  local nextState, quit = {}, {}
  for _, app in ipairs(apps) do
    local bundleID = reapCandidate(app)
    if bundleID and not pinned[bundleID] then
      if state[bundleID] == "quit" then
        nextState[bundleID] = "quit"
      elseif state[bundleID] == "windowless" then
        nextState[bundleID] = "quit"
        quit[#quit + 1] = app:name() or bundleID
        -- Graceful Quit AppleEvent, never kill9: save prompts stay intact.
        app:kill()
      else
        nextState[bundleID] = "windowless"
      end
    end
  end
  return nextState, quit
end

-- Switching away from a windowless app is the earliest honest signal that it is
-- idle, so that is the fast path; the timer only catches what no focus switch
-- ever reports.
local reapSettleDelay = 1 -- re-check after the switch, in case a window follows
local reapLaunchGrace = 15 -- an app still opening its first window is not idle

-- Should focus leaving `app` start a quit check? Returns its bundle ID, or nil.
-- Deliberately does not read the Dock - that costs a subprocess and this runs on
-- every app switch, so pinned-ness is checked later, once a candidate survives
-- the settle delay.
function M.shouldCheckOnSwitch(app, state, launchedAt, now)
  local bundleID = reapCandidate(app)
  if not bundleID or state[bundleID] == "quit" then return nil end
  local born = launchedAt[app:pid()]
  -- An app that just launched may simply not have drawn its window yet; leave
  -- it to the sweep rather than killing it mid-open.
  if born and now - born < reapLaunchGrace then return nil end
  return bundleID
end

function M.createWindowlessAppReaper(interval)
  local state, launchedAt, pendingChecks = {}, {}, {}

  local timer = hs.timer.new(interval or 20, function()
    local pinned = dockedBundleIDs()
    if not pinned then return end
    local quit
    state, quit = M.reapWindowlessApps(state, hs.application.runningApplications(), pinned)
    for _, name in ipairs(quit) do log.i("[reaper] swept windowless unpinned app: " .. name) end
  end)

  local events = hs.application.watcher
  local watcher = hs.application.watcher.new(function(_, event, app)
    if not app then return end

    if event == events.launched then
      launchedAt[app:pid()] = hs.timer.secondsSinceEpoch()
      return
    elseif event == events.terminated then
      launchedAt[app:pid()] = nil
      return
    elseif event ~= events.deactivated then
      return
    end

    local bundleID = M.shouldCheckOnSwitch(app, state, launchedAt, hs.timer.secondsSinceEpoch())
    if not bundleID or pendingChecks[bundleID] then return end

    -- Held in `pendingChecks` because an unreferenced hs.timer is collected
    -- before it fires.
    pendingChecks[bundleID] = hs.timer.doAfter(reapSettleDelay, function()
      pendingChecks[bundleID] = nil
      -- Opened a window, came back to the front, or is pinned after all.
      if not reapCandidate(app) or app:isFrontmost() then return end
      local pinned = dockedBundleIDs()
      if not pinned or pinned[bundleID] then return end
      state[bundleID] = "quit"
      log.i("[reaper] quit windowless unpinned app on focus switch: " .. (app:name() or bundleID))
      app:kill()
    end)
  end)

  return {
    start = function(self) timer:start(); watcher:start(); return self end,
    stop = function(self) timer:stop(); watcher:stop(); return self end,
  }
end

return M
