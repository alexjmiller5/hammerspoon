local log = hs.logger.new("KeyLogger", "debug")

local M = {}

local keyLoggerTap

function M.start()
  if keyLoggerTap then
    M.stop()
  end
  log.i("Starting diagnostic key logger.")
  keyLoggerTap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(e)
    local flags = e:getFlags()
    local key = e:getCharacters(true)
    log.i(string.format("Key Pressed -> Key: %s | Flags: %s", tostring(key), hs.inspect(flags)))
  end)
  keyLoggerTap:start()
end

function M.stop()
  if keyLoggerTap then
    log.i("Stopping diagnostic key logger.")
    keyLoggerTap:stop()
    keyLoggerTap = nil
  end
end

return M