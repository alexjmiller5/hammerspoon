local log = hs.logger.new("Profile Watchers", "debug")

local M = {}

function M.createAppInputRemapWatcher()
  local apps = require("profiles.personal.constants").appBundleIds
  local eventAPI = hs.eventtap.event
  local sourceTag = 0x4853524d
  return hs.eventtap.new({ eventAPI.types.keyDown, eventAPI.types.keyUp }, function(event)
    if event:getProperty(eventAPI.properties.eventSourceUserData) == sourceTag then return false end
    local key, flags = event:getKeyCode(), event:getFlags()
    if key ~= hs.keycodes.map.u and key ~= hs.keycodes.map.escape then return false end
    local app = hs.application.frontmostApplication()
    local bundle = app and app:bundleID()
    if bundle == apps.whatsapp and key == hs.keycodes.map.u and flags.cmd then
      flags.shift = true
      event:setFlags(flags)
    elseif bundle == apps.mail and key == hs.keycodes.map.escape
        and event:getType() == eventAPI.types.keyDown
        and event:getProperty(eventAPI.properties.keyboardEventAutorepeat) == 0 then
      local escape = event:copy():setProperty(eventAPI.properties.eventSourceUserData, sourceTag)
      flags.cmd = true
      local function commandK(down)
        return eventAPI.newKeyEvent({}, "k", down):setFlags(flags)
          :setProperty(eventAPI.properties.eventSourceUserData, sourceTag)
      end
      return true, { commandK(true), commandK(false), escape }
    end
    return false
  end)
end

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
    -- Swallow repeats and the matching release, including when Cmd
    -- were released first, so macOS cannot also handle this press.
    if held[media.key] then
      if not media.down then held[media.key] = nil end
      return true
    end
    local flags = event:getFlags()
    if media.down and not media["repeat"] and flags.cmd
        and not flags.shift and not flags.alt and not flags.ctrl then
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
