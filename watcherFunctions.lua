local log = hs.logger.new("Watchers", "debug")

local helperFunctions = require("helperFunctions")

local M = {}

function M.createAppBasedHotkeyWatcher(registry)
  local previousBundleID = nil

  return hs.application.watcher.new(function(appName, eventType, appObject)
    if eventType == hs.application.watcher.activated then
      previousBundleID = helperFunctions.updateActiveAppHotkeys(appObject, registry, previousBundleID)
    end
  end)
end

function M.createMouseWatcher()
  return hs.eventtap.new({ hs.eventtap.event.types.otherMouseDown }, function(e)
    local button = e:getProperty(hs.eventtap.event.properties.mouseEventButtonNumber)

    if button == 4 then
      -- Button 4 -> Ctrl + Left Arrow (Back)
      hs.eventtap.keyStroke({ "ctrl" }, "left")
      return true -- Consume event
    elseif button == 5 then
      -- Button 5 -> Ctrl + Right Arrow (Forward)
      hs.eventtap.keyStroke({ "ctrl" }, "right")
      return true -- Consume event
    elseif button == 2 then
      -- Button 3 (Middle Click is usually index 2) -> Mission Control
      -- Uses the standard macOS shortcut Ctrl+Up
      hs.eventtap.keyStroke({ "ctrl" }, "up")
      return true -- Consume event
    end

    return false -- Let other buttons pass through
  end)
end

return M