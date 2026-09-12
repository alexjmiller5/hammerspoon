local log = hs.logger.new("Profile Watchers", "debug")

local M = {}

-- The top row emits system media events when standard F-key mode is off.
function M.createSpotifyMediaKeyWatcher()
  local actions = {
    PLAY = hs.spotify.playpause,
    FAST = hs.spotify.next,
    NEXT = hs.spotify.next,
    REWIND = hs.spotify.previous,
    PREVIOUS = hs.spotify.previous,
  }
  local held = {}
  return hs.eventtap.new({ hs.eventtap.event.types.systemDefined }, function(event)
    local media = event:systemKey()
    local action = actions[media.key]
    if not action then return false end
    -- Swallow repeats and the matching release, including when Cmd/Shift
    -- were released first, so macOS cannot also handle this press.
    if held[media.key] then
      if not media.down then held[media.key] = nil end
      return true
    end
    local flags = event:getFlags()
    if media.down and not media["repeat"] and flags.cmd and flags.shift
        and not flags.alt and not flags.ctrl then
      held[media.key] = true
      action()
      return true
    end
    return false
  end)
end

function M.createWatcherOnPowerConnect(onConnectCallback)
  local previousSource = hs.battery.powerSource()

  return hs.battery.watcher.new(function()
    local currentSource = hs.battery.powerSource()

    if currentSource == "AC Power" and previousSource == "Battery Power" then
      if onConnectCallback then
        onConnectCallback()
      end
    end

    previousSource = currentSource
  end)
end

return M
