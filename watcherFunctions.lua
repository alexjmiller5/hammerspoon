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
-- is still sitting in the Dock. Quit those once they have been windowless for a
-- full sweep. Pinned apps are left alone, and menu-bar-only agents (Codex bar,
-- Synapse) never reach kind == 1, so they are never candidates.
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

-- One sweep. `state` maps bundle ID -> "windowless" (seen empty once, still in
-- its grace period) or "quit" (already asked to quit - don't nag an unsaved-work
-- dialog every 20 seconds). Apps that exited or regained a window drop out of
-- the returned state. Returns the next state and the names it quit.
function M.reapWindowlessApps(state, apps, pinned)
  local nextState, quit = {}, {}
  for _, app in ipairs(apps) do
    local bundleID = app:bundleID()
    if bundleID and app:kind() == 1 and not pinned[bundleID] and not reaperExempt[bundleID] then
      if #app:allWindows() > 0 then
        nextState[bundleID] = nil -- has windows again: forget it
      elseif state[bundleID] == "quit" then
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

function M.createWindowlessAppReaper(interval)
  local state = {}
  return hs.timer.new(interval or 20, function()
    local pinned = dockedBundleIDs()
    if not pinned then return end
    local quit
    state, quit = M.reapWindowlessApps(state, hs.application.runningApplications(), pinned)
    for _, name in ipairs(quit) do log.i("[reaper] quit windowless unpinned app: " .. name) end
  end)
end

return M
