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
