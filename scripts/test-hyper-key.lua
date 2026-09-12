-- Use native, unposted events; never change the real keyboard or Caps Lock.
local callback, now, capsToggles = nil, 10, 0
local eventAPI = hs.eventtap.event
local mask = eventAPI.rawFlagMasks
local hyper = mask.command | mask.alternate | mask.control | mask.shift
local fakeHs = {
  keycodes = hs.keycodes,
  timer = { secondsSinceEpoch = function() return now end },
  hid = { capslock = { toggle = function() capsToggles = capsToggles + 1 end } },
  eventtap = { event = eventAPI, new = function(_, handler) callback = handler; return {} end },
}
local env = setmetatable({hs=fakeHs}, {__index=_G})
local source = HYPER_KEY_TEST_SOURCE
local module = source and assert(load(source, "hyper-key", "t", env))()
  or assert(loadfile(hs.configdir .. "/hyperKey.lua", "t", env))()
module.new()
local function event(kind, code, flags)
  return eventAPI.newEvent():setType(kind):setKeyCode(code):rawFlags(flags or 0)
end
for _, kind in ipairs({eventAPI.types.keyDown, eventAPI.types.keyUp, eventAPI.types.flagsChanged,
    eventAPI.types.leftMouseDown, eventAPI.types.scrollWheel, eventAPI.types.systemDefined}) do
  local e = event(kind, hs.keycodes.map.b, mask.control | mask.deviceRightControl | mask.secondaryFn)
  assert(not callback(e), "Hyper must modify and forward the original event")
  assert(e:rawFlags() & hyper == hyper, "held Right Control must add every Hyper modifier")
  assert(e:rawFlags() & mask.secondaryFn ~= 0, "Fn must survive")
  local plain = event(kind, hs.keycodes.map.b, mask.shift | mask.deviceLeftShift)
  callback(plain)
  assert(plain:rawFlags() == mask.shift | mask.deviceLeftShift, "release must preserve only physical modifiers")
end
local function press()
  callback(event(eventAPI.types.flagsChanged, hs.keycodes.map.rightctrl, mask.control | mask.deviceRightControl))
end
local function release()
  callback(event(eventAPI.types.flagsChanged, hs.keycodes.map.rightctrl, 0))
end
press(); now = now + 0.1; release()
assert(capsToggles == 1, "a quick unused tap toggles Caps Lock")
press(); callback(event(eventAPI.types.keyDown, hs.keycodes.map.b, mask.control | mask.deviceRightControl))
now = now + 0.1; release()
assert(capsToggles == 1, "a chord must not toggle Caps Lock")
press(); now = now + 1; release()
assert(capsToggles == 1, "a long hold or delayed release must not toggle Caps Lock")
press() -- Simulate a release hidden by Secure Input, then ordinary input.
callback(event(eventAPI.types.keyDown, hs.keycodes.map.a, 0))
release()
assert(capsToggles == 1, "missed releases must not leave tap state behind")
print("hyper-key: native flags, releases, Fn, tap and missed-event checks passed")
