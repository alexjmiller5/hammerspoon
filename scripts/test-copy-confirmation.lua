-- Run: hs -c 'print(pcall(dofile, hs.configdir .. "/scripts/test-copy-confirmation.lua"))'
local callback, frontmost, shown, closed = nil, nil, {}, {}
local fakeHs = {
  logger = hs.logger,
  application = { frontmostApplication = function() return frontmost end },
  pasteboard = { watcher = { new = function(fn) callback = fn; return {} end } },
  alert = {
    show = function(text, style, duration)
      shown[#shown + 1] = { text = text, duration = duration }
      return tostring(#shown)
    end,
    closeSpecific = function(id) closed[#closed + 1] = id end,
  },
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
assert(#shown == 1 and shown[1].text == "Copied", "confirm without exposing clipboard contents")
assert(shown[1].duration == 0.5, "confirmation must be brief")
callback("another copy")
assert(#shown == 2 and closed[1] == "1", "rapid copies must replace the previous badge")
print("copy-confirmation: all checks passed")
