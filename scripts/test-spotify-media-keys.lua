-- Run through hs -c. Native events stay unposted; Spotify calls are recorded.
-- Catches missing media-event handling, double toggles, and stolen plain keys.
local callback, played = nil, {}
local fakeHs = {
  logger = hs.logger,
  eventtap = {
    event = hs.eventtap.event,
    new = function(types, handler)
      assert(#types == 1 and types[1] == hs.eventtap.event.types.systemDefined)
      callback = handler
      return {}
    end,
  },
  spotify = {
    playpause = function() played[#played + 1] = "playpause" end,
    next = function() played[#played + 1] = "next" end,
    previous = function() played[#played + 1] = "previous" end,
  },
}
local env = setmetatable({ hs = fakeHs }, { __index = _G })
local watchers = assert(loadfile(hs.configdir .. "/profiles/personal/watcherFunctions.lua", "t", env))()
assert(type(watchers.createSpotifyMediaKeyWatcher) == "function",
  "Cmd+Shift media events have no Spotify handler")
watchers.createSpotifyMediaKeyWatcher()
local function event(key, down, flags, repeated)
  local native = hs.eventtap.event.newSystemKeyEvent(key, down):setFlags(flags or {})
  if not repeated then return native end
  return {
    getFlags = function() return native:getFlags() end,
    systemKey = function()
      local value = native:systemKey()
      value["repeat"] = true
      return value
    end,
  }
end
local mods = { cmd = true, shift = true }
for _, key in ipairs({ "PLAY", "FAST", "REWIND", "NEXT", "PREVIOUS" }) do
  local before = #played
  assert(callback(event(key, true, mods)), "media press must be consumed: " .. key)
  assert(callback(event(key, true, mods, true)), "held media repeats must be consumed")
  assert(#played == before + 1, "holding a media key must not repeat the action")
  assert(callback(event(key, false)), "release must be consumed even after modifiers are released")
  assert(#played == before + 1, "release must not run the action again")
end
assert(table.concat(played, " ") == "playpause next previous next previous")
local before = #played
for _, flags in ipairs({ {}, { cmd = true }, { shift = true },
  { cmd = true, shift = true, alt = true }, { cmd = true, shift = true, ctrl = true } }) do
  assert(not callback(event("PLAY", true, flags)), "unrelated shortcuts must pass through")
  assert(not callback(event("PLAY", false, flags)), "unhandled releases must pass through")
end
assert(not callback(event("SOUND_UP", true, mods)), "volume controls must pass through")
assert(not callback(event("PLAY", true, mods, true)), "do not claim a key held before the modifiers")
assert(not callback(hs.eventtap.event.newKeyEvent(mods, "f8", true)),
  "ordinary F8 stays with its existing hotkey")
assert(#played == before, "unrelated events must not control Spotify")
assert(callback(event("PLAY", true, { cmd = true, shift = true, fn = true })))
assert(callback(event("PLAY", false)))
assert(#played == before + 1, "Fn mode must not prevent a media event from working")
print("spotify-media-keys: native media events, repeat/release handling and pass-through passed")
