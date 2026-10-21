-- Run through hs -c. Application events are isolated from the running watcher.
local callback, hidden = nil, 0
local events = { deactivated = 1, activated = 2, hidden = 3, terminated = 4 }
function events.new(fn) callback = fn; return {} end
local fakeHs = { logger = hs.logger, application = { watcher = events } }
local env = setmetatable({ hs = fakeHs }, { __index = _G })
local watchers = assert(loadfile(hs.configdir .. "/watcherFunctions.lua", "t", env))()
assert(watchers.createSpotifyAutoHideWatcher, "Spotify auto-hide watcher is missing")
watchers.createSpotifyAutoHideWatcher()
local spotify = {
  bundleID = function() return "com.spotify.client" end,
  hide = function() hidden = hidden + 1 end,
}
callback("Spotify", events.deactivated, spotify)
assert(hidden == 1, "Spotify must hide when focus leaves")
callback("Spotify", events.activated, spotify)
callback("Spotify", events.hidden, spotify)
callback(nil, events.terminated, { bundleID = function() error("terminated app is invalid") end })
callback("Spotify", events.deactivated, nil)
callback("Other", events.deactivated, { bundleID = function() return "com.apple.finder" end })
assert(hidden == 1, "other events and apps must remain untouched")
print("spotify-auto-hide: focus loss and unrelated events passed")
