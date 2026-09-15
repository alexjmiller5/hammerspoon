-- Native unposted events only; never touches the real keyboard or Caps Lock.
local now, capsToggles, callback, entered, binds = 10, 0, nil, 0, {}
local modal = {
  bind = function(_, mods, key, fn) binds[#binds + 1] = { mods = mods, key = key, fn = fn } end,
  enter = function() entered = entered + 1 end,
  exit = function() entered = entered - 1 end,
}
local eventAPI = hs.eventtap.event
local fakeHs = {
  keycodes = hs.keycodes,
  fs = { attributes = function() return "file" end },
  timer = { secondsSinceEpoch = function() return now end },
  hid = { capslock = { toggle = function() capsToggles = capsToggles + 1 end } },
  hotkey = { modal = { new = function() return modal end } },
  eventtap = { event = eventAPI, new = function(_, handler)
    callback = handler
    return { start = function(self) return self end }
  end },
}
local env = setmetatable({ hs = fakeHs }, { __index = _G })
local module = assert(loadfile(hs.configdir .. "/hyperKey.lua", "t", env))()
assert(module.enabled, "the Nix marker enables Hyper")

local fired = 0
module.bind("b", function() fired = fired + 1 end)
assert(#binds == 1 and binds[1].key == "b" and #binds[1].mods == 1 and binds[1].mods[1] == "ctrl",
  "Hyper bindings are Control+key inside the modal")
assert(module.start(), "start returns the running tap")

local mask, types = eventAPI.rawFlagMasks, eventAPI.types
local function flags(code, raw)
  return eventAPI.newEvent():setType(types.flagsChanged):setKeyCode(code):rawFlags(raw)
end
local function press() callback(flags(hs.keycodes.map.rightctrl, mask.control | mask.deviceRightControl)) end
local function release() callback(flags(hs.keycodes.map.rightctrl, 0)) end

press(); assert(entered == 1, "Right Control down enters the modal")
now = now + 0.1; release(); assert(entered == 0, "Right Control up exits the modal")
assert(capsToggles == 1, "a quick unused tap toggles Caps Lock")
press(); binds[1].fn(); now = now + 0.1; release()
assert(fired == 1 and capsToggles == 1, "a chord fires its action and must not toggle Caps Lock")
press(); now = now + 1; release()
assert(capsToggles == 1, "a long hold must not toggle Caps Lock")
callback(flags(hs.keycodes.map.shift, mask.shift | mask.deviceLeftShift))
assert(entered == 0 and capsToggles == 1, "other modifiers are ignored")
print("hyper-key: modal enter/exit, Control-bound keys, tap and hold checks passed")
