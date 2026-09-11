-- Behavior check for the windowless-app reaper. Run through the hs CLI:
--   hs -c 'print(pcall(dofile, hs.configdir .. "/scripts/test-windowless-app-reaper.lua"))'
-- Uses fake application objects, so nothing on the machine is quit.

local watcherFunctions = dofile(hs.configdir .. "/watcherFunctions.lua")

local nextPid = 100
local function fakeApp(bundleID, windows, kind, frontmost)
  nextPid = nextPid + 1
  local app = { killed = false, fakePid = nextPid }
  function app:bundleID() return bundleID end
  function app:name() return bundleID end
  function app:kind() return kind or 1 end
  function app:pid() return self.fakePid end
  function app:isFrontmost() return frontmost or false end
  function app:allWindows() local w = {} for i = 1, windows do w[i] = i end return w end
  function app:kill() self.killed = true end
  return app
end

local function pinning(...)
  local pinned, calls = {}, 0
  for _, bundleID in ipairs({ ... }) do pinned[bundleID] = true end
  return function() calls = calls + 1 return pinned end, function() return calls end
end

local function bundleIDs(apps)
  local names = {}
  for _, app in ipairs(apps) do names[#names + 1] = app:bundleID() end
  table.sort(names)
  return table.concat(names, ",")
end

local now = 10000

-- Which apps are even considerable. Window count is deliberately not part of it:
-- LibreOffice reports phantom windows at the instant focus leaves, and judging
-- it then is what used to let it linger.
assert(watcherFunctions.reapEligible(fakeApp("org.libreoffice.script", 2)) == "org.libreoffice.script",
  "an app with windows at switch time must still be considered once it settles")
assert(watcherFunctions.reapEligible(fakeApp("com.apple.finder", 0)) == nil, "Finder")
assert(watcherFunctions.reapEligible(fakeApp("org.hammerspoon.Hammerspoon", 0)) == nil, "Hammerspoon")
assert(watcherFunctions.reapEligible(fakeApp("com.alexmiller.synapse", 0, 0)) == nil, "menu-bar app")

-- An app that just launched is deferred, never dropped.
local fresh = fakeApp("com.apple.Preview", 0)
assert(watcherFunctions.launchDeferral(fresh, {}, now) == 0, "unknown launch time should not defer")
local wait = watcherFunctions.launchDeferral(fresh, { [fresh:pid()] = now - 3 }, now)
assert(wait > 0 and wait <= 15, "an app launched 3s ago must be re-checked later, got " .. tostring(wait))
assert(watcherFunctions.launchDeferral(fresh, { [fresh:pid()] = now - 60 }, now) == 0, "launch grace never expires")

-- The whole estate is judged, not just the app focus left - an app can lose its
-- last window while already in the background.
local spared = {
  fakeApp("com.spotify.client", 0), -- pinned
  fakeApp("com.google.Chrome", 2), -- has windows
  fakeApp("com.apple.Shortcuts", 0, 1, true), -- frontmost
  fakeApp("com.apple.finder", 0), -- exempt
  fakeApp("org.hammerspoon.Hammerspoon", 0), -- exempt
  fakeApp("com.alexmiller.synapse", 0, 0), -- menu-bar only
}
local doomed = { fakeApp("com.apple.Preview", 0), fakeApp("org.libreoffice.script", 0) }
local apps = {}
for _, app in ipairs(spared) do apps[#apps + 1] = app end
for _, app in ipairs(doomed) do apps[#apps + 1] = app end

local quit = watcherFunctions.appsToReap(apps, {}, now, pinning("com.spotify.client"))
assert(bundleIDs(quit) == "com.apple.Preview,org.libreoffice.script", "quit set was " .. bundleIDs(quit))

-- A freshly launched app is held back, and reported so it gets a second look.
local launching = fakeApp("com.apple.Preview", 0)
local held, deferral = watcherFunctions.appsToReap({ launching }, { [launching:pid()] = now - 5 }, now, pinning())
assert(#held == 0, "quit an app mid-launch")
assert(deferral and deferral > 0, "no follow-up scheduled for the launching app")

-- A Dock read that failed must never be read as "nothing is pinned".
local blind = watcherFunctions.appsToReap({ fakeApp("com.apple.Preview", 0) }, {}, now, function() return nil end)
assert(#blind == 0, "quit an app without knowing what is pinned")

-- Reading the Dock costs a subprocess, so a check with nothing windowless must
-- skip it - that is the ordinary app switch. (A windowless PINNED app is not in
-- this set: it is a genuine candidate until the Dock says otherwise.)
local lookup, calls = pinning()
watcherFunctions.appsToReap({
  fakeApp("com.google.Chrome", 2),
  fakeApp("com.apple.Shortcuts", 0, 1, true),
  fakeApp("com.apple.finder", 0),
  fakeApp("com.alexmiller.synapse", 0, 0),
}, {}, now, lookup)
assert(calls() == 0, "read the Dock with nothing windowless to quit")

print("windowless-app reaper: all checks passed")
return true
