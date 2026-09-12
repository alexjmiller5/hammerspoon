-- Run: hs -c 'print(pcall(dofile, hs.configdir .. "/scripts/test-herdr-hotkeys.lua"))'
local ghostty = "com.mitchellh.ghostty"

local function fakeWindow(id, bundle)
  return {
    id = function() return id end,
    application = function() return { bundleID = function() return bundle or ghostty end } end,
  }
end

local strokes, hotkeys, subscriptions, stored = {}, {}, {}, { 4242 }
local focused, existing = nil, { [4242] = true }
local pendingMtime, removed, pendingMode, removalFails = nil, nil, "file", false
local errors = {}

local fakeHs = {
  logger = { new = function() return { i = function() end, w = function(message) errors[#errors + 1] = message end } end },
  timer = { usleep = function() end },
  settings = {
    get = function() return stored end,
    set = function(_, ids) stored = ids end,
  },
  hotkey = {
    new = function(mods, key)
      local hk = { mods = mods, key = key, enabled = false }
      hk.enable = function(self) self.enabled = true; return self end
      hk.disable = function(self) self.enabled = false; return self end
      table.insert(hotkeys, hk)
      return hk
    end,
  },
  eventtap = {
    keyStroke = function(mods, key) table.insert(strokes, { mods = mods, key = key }) end,
    keyStrokes = function(text) table.insert(strokes, { text = text }) end,
  },
  fs = { attributes = function(_, field)
    if not pendingMtime then return nil end
    local attributes = { mode = pendingMode, modification = pendingMtime }
    return field and attributes[field] or attributes
  end },
  window = {
    get = function(id) return existing[id] and fakeWindow(id) or nil end,
    focusedWindow = function() return focused end,
    filter = {
      windowCreated = "created",
      windowFocused = "focused",
      windowDestroyed = "destroyed",
      new = function()
        return { subscribe = function(self, event, fn) subscriptions[event] = fn; return self end }
      end,
    },
  },
}

local fakeOs = setmetatable({
  time = function() return 1000 end,
  remove = function(path)
    removed = path
    if removalFails then return nil, "permission denied" end
    pendingMtime = nil; return true
  end,
}, { __index = os })
local env = setmetatable({ hs = fakeHs, os = fakeOs }, { __index = _G })
local M = assert(loadfile(hs.configdir .. "/herdrHotkeys.lua", "t", env))()

-- One hotkey per binding, and nothing is live before a herdr window is focused
assert(#hotkeys == #M._bindings, "every binding must produce a hotkey")
local mine = {}                      -- later module loads append to `hotkeys`
for i, hk in ipairs(hotkeys) do mine[i] = hk end
assert(#M._bindings == 26, "expected 17 shortcuts plus cmd+1..9, got " .. #M._bindings)
for _, hk in ipairs(mine) do assert(not hk.enabled, "hotkeys must start disabled") end

-- The id restored from settings survives; an id whose window is gone is pruned
existing[99] = nil
stored = { 4242, 99 }
local M2 = assert(loadfile(hs.configdir .. "/herdrHotkeys.lua", "t", env))()
assert(M2._marked[4242] and not M2._marked[99], "only live window ids are restored")

M.start()
assert(subscriptions.focused and subscriptions.destroyed and subscriptions.created,
  "must watch creation, focus and destruction")

-- Focus gating: only a marked window turns the shortcuts on
subscriptions.focused(fakeWindow(4242))
for _, hk in ipairs(mine) do assert(hk.enabled, "marked window must enable hotkeys") end
subscriptions.focused(fakeWindow(777))
for _, hk in ipairs(mine) do assert(not hk.enabled, "plain Ghostty window must not steal Cmd keys") end

-- Marking: the focused Ghostty window is remembered and persisted
focused = fakeWindow(555)
assert(M.markFocusedWindow(), "a focused Ghostty window must be markable")
assert(M._isHerdrWindow(fakeWindow(555)), "marked window must be recognised")
local sawIt = false
for _, id in ipairs(stored) do if id == 555 then sawIt = true end end
assert(sawIt, "marked ids must persist to settings")

focused = fakeWindow(556, "com.apple.finder")
assert(not M.markFocusedWindow(), "a non-Ghostty window must not be marked")

-- Destroying a marked window forgets it, and a window that can no longer
-- answer :id() must not blow up the subscription
subscriptions.destroyed(fakeWindow(555))
assert(not M._isHerdrWindow(fakeWindow(555)), "destroyed window must be unmarked")
subscriptions.destroyed({ id = function() error("window is gone") end })
subscriptions.destroyed(nil)

-- The sentinel file herdr-window drops claims the next new Ghostty window
pendingMtime, removed = 995, nil
subscriptions.created(fakeWindow(1111))
assert(M._isHerdrWindow(fakeWindow(1111)), "a fresh sentinel must claim the new window")
assert(removed == M._pendingPath, "the sentinel must be consumed exactly once")

pendingMtime, removed = 995, nil
subscriptions.created(fakeWindow(1112, "com.apple.finder"))
assert(not M._isHerdrWindow(fakeWindow(1112)), "a non-Ghostty window must not be claimed")
assert(removed == nil, "a non-Ghostty window must leave the sentinel for Ghostty")

pendingMtime, removed = 900, nil   -- 100s old, past PENDING_MAX_AGE
subscriptions.created(fakeWindow(1113))
assert(not M._isHerdrWindow(fakeWindow(1113)), "a stale sentinel must not claim a window")
assert(removed == M._pendingPath, "a stale sentinel must still be cleared")

pendingMtime, removed = nil, nil
subscriptions.created(fakeWindow(1114))
assert(not M._isHerdrWindow(fakeWindow(1114)), "no sentinel means an ordinary Ghostty window")

pendingMtime, removed, pendingMode = 995, nil, "directory"
subscriptions.created(fakeWindow(1115))
assert(not M._isHerdrWindow(fakeWindow(1115)) and not removed, "a directory must not be consumed as a sentinel")
pendingMtime, pendingMode, removalFails = 995, "file", true
subscriptions.created(fakeWindow(1116))
assert(not M._isHerdrWindow(fakeWindow(1116)), "failed sentinel consumption must not mark a window")
subscriptions.created(fakeWindow(1117))
assert(not M._isHerdrWindow(fakeWindow(1117)), "failed consumption must not claim later unrelated windows")
removalFails = false

-- Every shortcut sends Herdr's prefix first, then its own key. hs.hotkey.new's
-- third argument is the action, so re-load with a stub that records it.
local actions = {}
fakeHs.hotkey.new = function(mods, key, fn)
  local hk = { mods = mods, key = key, enabled = false }
  hk.enable = function(self) self.enabled = true; return self end
  hk.disable = function(self) self.enabled = false; return self end
  table.insert(actions, { mods = mods, key = key, fn = fn })
  return hk
end
local M3 = assert(loadfile(hs.configdir .. "/herdrHotkeys.lua", "t", env))()
assert(#actions == #M3._bindings, "every binding must bind an action")

local function findAction(mods, key)
  for _, a in ipairs(actions) do
    if a.key == key and #a.mods == #mods then
      local match = true
      for i, mod in ipairs(mods) do if a.mods[i] ~= mod then match = false end end
      if match then return a end
    end
  end
  error("no action bound for " .. key)
end

strokes = {}
findAction({ "cmd", "shift" }, "]").fn()
assert(#strokes == 2, "next tab must be two events, got " .. #strokes)
assert(strokes[1].mods[1] == "ctrl" and strokes[1].key == "b", "prefix must be ctrl+b")
assert(strokes[2].text == "n", "next tab must type n after the prefix")

strokes = {}
findAction({ "cmd" }, "]").fn()
assert(strokes[1].key == "b" and strokes[2].key == "tab" and #strokes[2].mods == 0,
  "next pane must be prefix then a bare tab")

strokes = {}
findAction({ "cmd", "alt" }, "[").fn()
assert(strokes[2].key == "p" and strokes[2].mods[1] == "ctrl",
  "previous agent must be prefix then ctrl+p")

strokes = {}
findAction({ "cmd" }, "w").fn()
assert(strokes[2].text == "X", "close tab must type X so agent sessions are saved")

print("herdr-hotkeys: all checks passed")
