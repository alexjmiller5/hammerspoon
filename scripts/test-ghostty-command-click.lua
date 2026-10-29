-- Run: hs -c 'print(pcall(dofile, hs.configdir .. "/scripts/test-ghostty-command-click.lua"))'
local callback, types, frontmost, herdrWindow
local fakeHs = {
  logger = hs.logger,
  application = { frontmostApplication = function() return frontmost end },
  window = { focusedWindow = function() return herdrWindow end },
  eventtap = {
    event = hs.eventtap.event,
    new = function(events, fn) types, callback = events, fn; return {} end,
  },
}
local env = setmetatable({ hs = fakeHs, require = function(name)
  if name == "herdrHotkeys" then return { _isHerdrWindow = function(win) return win == true end } end
  return require(name)
end }, { __index = _G })
local watchers = assert(loadfile(hs.configdir .. "/watcherFunctions.lua", "t", env))()
assert(watchers.createGhosttyCommandClickWatcher, "Command-click watcher is missing")
watchers.createGhosttyCommandClickWatcher()
local t = hs.eventtap.event.types
assert(#types == 3 and types[1] == t.mouseMoved and types[2] == t.leftMouseDown and types[3] == t.leftMouseUp)
for _, marked in ipairs({ false, true }) do
herdrWindow = marked
for _, bundle in ipairs({ "", "com.apple.finder", "com.mitchellh.ghostty" }) do
  frontmost = bundle ~= "" and { bundleID = function() return bundle end } or nil
  for _, kind in ipairs(types) do
    for _, flags in ipairs({ {}, {cmd=true}, {ctrl=true}, {cmd=true,alt=true}, {cmd=true,ctrl=true}, {cmd=true,shift=true} }) do
      local event = hs.eventtap.event.newMouseEvent(kind, {x=0,y=0}):setFlags(flags)
      assert(not callback(event), "mouse events must pass through")
      local actual = event:getFlags()
      local remap = bundle == "com.mitchellh.ghostty" and flags.cmd and not flags.alt and not flags.ctrl and not flags.shift
      local expected = { cmd = flags.cmd, ctrl = flags.ctrl, alt = flags.alt, shift = flags.shift }
      if remap and marked then expected.cmd, expected.ctrl = nil, true
      elseif remap then expected.shift = true end
      for _, modifier in ipairs({ "cmd", "ctrl", "alt", "shift" }) do
        assert(not not actual[modifier] == not not expected[modifier],
          "Command-click must use Herdr's link handler in marked windows and native bypass elsewhere")
      end
    end
  end
end
end
print("ghostty-command-click: all checks passed")
