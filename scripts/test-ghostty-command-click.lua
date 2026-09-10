-- Run: hs -c 'print(pcall(dofile, hs.configdir .. "/scripts/test-ghostty-command-click.lua"))'
local callback, types, frontmost
local fakeHs = {
  logger = hs.logger,
  application = { frontmostApplication = function() return frontmost end },
  eventtap = {
    event = hs.eventtap.event,
    new = function(events, fn) types, callback = events, fn; return {} end,
  },
}
local env = setmetatable({ hs = fakeHs }, { __index = _G })
local watchers = assert(loadfile(hs.configdir .. "/watcherFunctions.lua", "t", env))()
assert(watchers.createGhosttyCommandClickWatcher, "Command-click watcher is missing")
watchers.createGhosttyCommandClickWatcher()
local t = hs.eventtap.event.types
assert(#types == 3 and types[1] == t.mouseMoved and types[2] == t.leftMouseDown and types[3] == t.leftMouseUp)
for _, bundle in ipairs({ "", "com.apple.finder", "com.mitchellh.ghostty" }) do
  frontmost = bundle ~= "" and { bundleID = function() return bundle end } or nil
  for _, kind in ipairs(types) do
    for _, flags in ipairs({ {}, {cmd=true}, {ctrl=true}, {cmd=true,alt=true}, {cmd=true,ctrl=true}, {cmd=true,shift=true} }) do
      local event = hs.eventtap.event.newMouseEvent(kind, {x=0,y=0}):setFlags(flags)
      assert(not callback(event), "mouse events must pass through")
      local actual = event:getFlags()
      local expectedShift = flags.shift or (bundle == "com.mitchellh.ghostty" and flags.cmd and not flags.alt and not flags.ctrl)
      assert(not not actual.shift == not not expectedShift, "Command-click must bypass mouse capture only in Ghostty")
      for _, modifier in ipairs({ "cmd", "ctrl", "alt" }) do
        assert(not not actual[modifier] == not not flags[modifier], "other modifiers must stay unchanged")
      end
    end
  end
end
print("ghostty-command-click: all checks passed")
