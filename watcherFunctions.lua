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
  local alertID
  return hs.pasteboard.watcher.new(function(text)
    local app = hs.application.frontmostApplication()
    if not text or text == "" or not app or app:bundleID() ~= constants.appBundleIds.ghostty then
      return
    end
    if alertID then hs.alert.closeSpecific(alertID, 0) end
    alertID = hs.alert.show("Copied", {
      textSize = 16, radius = 8, padding = 10, strokeWidth = 0,
      atScreenEdge = 2, fadeInDuration = 0.08, fadeOutDuration = 0.15,
    }, 0.5)
  end)
end

return M
