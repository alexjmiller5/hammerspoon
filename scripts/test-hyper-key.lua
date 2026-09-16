-- Fake hs.hotkey only; never touches the real keyboard or Caps Lock.
local now, capsToggles, entered, binds, f19 = 10, 0, 0, {}, nil
local modal = {
  bind = function(_, mods, key, fn) binds[#binds + 1] = { mods = mods, key = key, fn = fn } end,
  enter = function() entered = entered + 1 end,
  exit = function() entered = entered - 1 end,
}
local fakeHs = {
  fs = { attributes = function() return "file" end },
  timer = { secondsSinceEpoch = function() return now end },
  hid = { capslock = { toggle = function() capsToggles = capsToggles + 1 end } },
  hotkey = {
    modal = { new = function() return modal end },
    bind = function(mods, key, pressed, released)
      f19 = { mods = mods, key = key, pressed = pressed, released = released }
      return f19
    end,
  },
}
local env = setmetatable({ hs = fakeHs }, { __index = _G })
local module = assert(loadfile(hs.configdir .. "/hyperKey.lua", "t", env))()
assert(module.enabled(), "the Nix marker enables Hyper")

local fired = 0
module.bind("b", function() fired = fired + 1 end)
assert(#binds == 1 and binds[1].key == "b" and #binds[1].mods == 0,
  "Hyper bindings are bare keys inside the modal, never modifier chords")
assert(module.start() == f19, "start returns the F19 hotkey")
assert(f19.key == "f19" and #f19.mods == 0, "the carrier is a bare F19 press")

f19.pressed(); assert(entered == 1, "F19 down enters the modal")
now = now + 0.1; f19.released(); assert(entered == 0, "F19 up exits the modal")
assert(capsToggles == 1, "a quick unused tap toggles Caps Lock")
f19.pressed(); binds[1].fn(); now = now + 0.1; f19.released()
assert(fired == 1 and capsToggles == 1, "a chord fires its action and must not toggle Caps Lock")
f19.pressed(); now = now + 1; f19.released()
assert(capsToggles == 1, "a long hold must not toggle Caps Lock")
print("hyper-key: F19 modal enter/exit, bare-key bindings, tap and hold checks passed")
