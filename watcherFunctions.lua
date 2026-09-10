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

return M
