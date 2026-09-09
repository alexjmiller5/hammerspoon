-- Run: hs -c 'print(pcall(dofile, hs.configdir .. "/scripts/test-copy-confirmation.lua"))'
local callback, frontmost, shown, timers = nil, nil, {}, {}
local fakeHs = {
  logger = hs.logger,
  application = { frontmostApplication = function() return frontmost end },
  pasteboard = { watcher = { new = function(fn) callback = fn; return {} end } },
  screen = { mainScreen = function() return { frame = function() return { x = -1200, y = 50, w = 1200, h = 800 } end } end },
  canvas = { new = function(frame)
    local badge = { frame = frame }
    function badge:appendElements(...) self.elements = {...}; return self end
    function badge:show() shown[#shown + 1] = self; return self end
    function badge:delete() self.deleted = true end
    return badge
  end },
  timer = { doAfter = function(duration, fn)
    local timer = { duration = duration, fire = fn, stop = function(self) self.stopped = true end }
    timers[#timers + 1] = timer
    return timer
  end },
}
local env = setmetatable({ hs = fakeHs }, { __index = _G })
local watchers = assert(loadfile(hs.configdir .. "/watcherFunctions.lua", "t", env))()
assert(watchers.createCopyConfirmationWatcher, "copy confirmation watcher is missing")
watchers.createCopyConfirmationWatcher()

callback("text without a focused app")
frontmost = { bundleID = function() return "com.apple.finder" end }
callback("text copied outside Ghostty")
assert(#shown == 0, "copies outside Ghostty must stay silent")

frontmost = { bundleID = function() return "com.mitchellh.ghostty" end }
callback(nil)
callback("")
assert(#shown == 0, "empty and non-text clipboard updates must stay silent")
callback("private clipboard contents")
assert(#shown == 1 and shown[1].elements[2].text == "Text Copied", "confirm without exposing clipboard contents")
local f = shown[1].frame
assert(f.x + f.w == -20 and f.y + f.h == 830, "badge must sit 20 points from the focused screen's bottom-right corner")
assert(timers[1].duration == 0.5, "confirmation must be brief")
callback("another copy")
assert(#shown == 2 and shown[1].deleted and timers[1].stopped, "rapid copies must replace the previous badge")
timers[2].fire()
assert(shown[2].deleted, "badge must disappear after the timeout")
print("copy-confirmation: all checks passed")
