-- Behavior check for the windowless-app reaper. Run through the hs CLI:
--   hs -c 'print(pcall(dofile, hs.configdir .. "/scripts/test-windowless-app-reaper.lua"))'
-- Uses fake application objects, so nothing on the machine is quit.

local watcherFunctions = dofile(hs.configdir .. "/watcherFunctions.lua")

local function fakeApp(bundleID, windows, kind)
  local app = { killed = false }
  function app:bundleID() return bundleID end
  function app:name() return bundleID end
  function app:kind() return kind or 1 end
  function app:allWindows() local w = {} for i = 1, windows do w[i] = i end return w end
  function app:kill() self.killed = true end
  return app
end

local pinned = { ["com.spotify.client"] = true }

-- An unpinned, windowless, Dock-kind app survives one sweep, dies on the next.
local preview = fakeApp("com.apple.Preview", 0)
local state = watcherFunctions.reapWindowlessApps({}, { preview }, pinned)
assert(not preview.killed, "quit on the first sweep - no grace period")
assert(state["com.apple.Preview"] == "windowless")
state = watcherFunctions.reapWindowlessApps(state, { preview }, pinned)
assert(preview.killed, "never quit a windowless unpinned app")
assert(state["com.apple.Preview"] == "quit")

-- A quit it refused (unsaved-work dialog) is not retried every sweep.
preview.killed = false
state = watcherFunctions.reapWindowlessApps(state, { preview }, pinned)
assert(not preview.killed, "re-quit an app that already declined")

-- Everything else is untouchable, twice over.
local spared = {
  pinnedApp = fakeApp("com.spotify.client", 0),        -- pinned to the Dock
  menuBarApp = fakeApp("com.alexmiller.synapse", 0, 0), -- kind 0, no Dock icon
  finder = fakeApp("com.apple.finder", 0),              -- exempt
  hammerspoon = fakeApp("org.hammerspoon.Hammerspoon", 0),
  hasWindow = fakeApp("com.apple.Shortcuts", 1),        -- unpinned but in use
}
local apps = {}
for _, app in pairs(spared) do apps[#apps + 1] = app end
local s = {}
for _ = 1, 3 do s = watcherFunctions.reapWindowlessApps(s, apps, pinned) end
for label, app in pairs(spared) do assert(not app.killed, "quit " .. label) end

-- A window reappearing clears the countdown.
local shortcuts = fakeApp("com.apple.Shortcuts", 0)
s = watcherFunctions.reapWindowlessApps({}, { shortcuts }, pinned)
local reopened = fakeApp("com.apple.Shortcuts", 1)
s = watcherFunctions.reapWindowlessApps(s, { reopened }, pinned)
assert(s["com.apple.Shortcuts"] == nil, "kept a stale countdown after a window reopened")
s = watcherFunctions.reapWindowlessApps(s, { shortcuts }, pinned)
assert(not shortcuts.killed, "countdown did not restart from scratch")

print("windowless-app reaper: all checks passed")
return true
