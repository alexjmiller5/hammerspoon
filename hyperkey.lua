-- local M = {}

-- local log = hs.logger.new(M.name, "debug")

-- local constants = require("constants")

-- local isHyperActive = false
-- local istap = true
-- local hyperListener

-- -- TODO: Review hyperkey implementation idea -- hammerspoon is unable to watch the caps lock keypresses, so you gotta map it to F19 with HDutil and then can use it as a hyper key.
-- -- At least that is the current idea I was running with, let's see if it works when I come back to this code. Using the keylogger was really helpful so I could see what hammerspoon's seeing
-- function M.start()
--   if hyperListener then
--     M.stop()
--   end
--   log.i("Starting F19 Hyper Key.")

--   hyperListener = hs.eventtap.new({hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp}, function(e)
--     local keycode = e:getKeyCode()
--     local isTriggerKey = (keycode == hs.keycodes.map.f19)

--     if isTriggerKey then
--       if e:getType() == hs.eventtap.event.types.keyDown then
--         isHyperActive = true
--         istap = true
--         return true -- Consume the event
--       elseif e:getType() == hs.eventtap.event.types.keyUp then
--         isHyperActive = false
--         if istap then
--           hs.eventtap.keyStroke({}, "f19") -- It was a tap, so fire F19
--         end
--         return true -- Consume the event
--       end
--     elseif isHyperActive then
--       istap = false -- Another key was pressed, so not a tap
--     end

--     if e:getType() == hs.eventtap.event.types.keyDown then
--       local flags = hs.fnutils.copy(e:getFlags())
--       hs.fnutils.each(constants.hyperKeyMods, function(mod)
--         flags[mod] = true
--       end)
--       e:setFlags(flags)
--     end
--     -- Let the modified event pass through
--     return false
--   end)

--   return false -- Let all other events pass through
--   -- end) (this line seems commented out or vestigial in source)

--   hyperListener:start()
-- end

-- function M.stop()
--   if hyperListener then
--     log.i("Stopping F19 Hyper Key.")
--     hyperListener:stop()
--     hyperListener = nil
--   end
-- end

-- return M