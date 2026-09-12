local M = {}

function M.new()
  local events = hs.eventtap.event
  local mask = events.rawFlagMasks
  local hyper = mask.command | mask.alternate | mask.control | mask.shift
  local pressedAt
  return hs.eventtap.new({ "all" }, function(event)
    local raw, kind = event:rawFlags(), event:getType()
    local held = raw & mask.deviceRightControl ~= 0
    local modifier = kind == events.types.flagsChanged
      and event:getKeyCode() == hs.keycodes.map.rightctrl
    if modifier then
      if held then
        pressedAt = hs.timer.secondsSinceEpoch()
      else
        if pressedAt and hs.timer.secondsSinceEpoch() - pressedAt < 0.3 then
          hs.hid.capslock.toggle()
        end
        pressedAt = nil
      end
    elseif not held or kind == events.types.keyDown
        or kind == events.types.leftMouseDown or kind == events.types.rightMouseDown
        or kind == events.types.otherMouseDown or kind == events.types.scrollWheel then
      pressedAt = nil
    end
    -- Physical flags are authoritative, so a missed release cannot latch Hyper.
    if held then event:rawFlags(raw | hyper) end
    return false
  end)
end

return M
