local log = hs.logger.new("Profile Watchers", "debug")

local M = {}

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
