local log = hs.logger.new("Herdr Hotkeys", "debug")

local constants = require("constants")

-- macOS-style shortcuts for Herdr, active only in the Ghostty windows that
-- `hdr`/`herdr` opened. Ghostty's key table did this before, but an active key
-- table paints a permanent indicator pill; Ghostty has no option to hide it.
-- Each hotkey types Herdr's ctrl+b prefix followed by its key, so Ghostty's own
-- Cmd shortcuts keep working in every ordinary window.
--
-- herdr-window drops a sentinel file just before it opens a window; the first
-- Ghostty window created after that is the herdr one. A file rather than an
-- `hs -c` call so opening a window never depends on the IPC port being
-- responsive. Marked ids persist in hs.settings, so a reload keeps them.

local M = {}

local SETTINGS_KEY = "herdrWindowIds"
local PENDING = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state"))
  .. "/herdr-window/pending"
local PENDING_MAX_AGE = 30 -- seconds; older means herdr-window failed, ignore it

-- key = literal text to type after the prefix, or { mods, key } for a keystroke
local bindings = {
  { { "cmd" }, "t", "c" },                             -- new tab
  { { "cmd", "shift" }, "t", "t" },                    -- reopen closed tab
  { { "cmd", "shift" }, "[", "p" },                    -- previous tab
  { { "cmd", "shift" }, "]", "n" },                    -- next tab
  { { "cmd" }, "w", "X" },                             -- close tab (keeps agents)
  { { "cmd" }, "d", "v" },                             -- split right
  { { "cmd", "shift" }, "d", "-" },                    -- split down
  { { "cmd" }, "[", { { "shift" }, "tab" } },          -- previous pane
  { { "cmd" }, "]", { {}, "tab" } },                   -- next pane
  { { "cmd", "shift" }, "return", "z" },               -- toggle pane zoom
  { { "cmd", "shift" }, "n", "N" },                    -- new workspace
  { { "cmd" }, "p", "g" },                             -- workspace + tab picker
  { { "cmd" }, "\\", "b" },                            -- toggle sidebar
  { { "cmd", "alt" }, "[", { { "ctrl" }, "p" } },      -- previous agent
  { { "cmd", "alt" }, "]", { { "ctrl" }, "n" } },      -- next agent
  { { "cmd", "shift" }, "w", "q" },                    -- detach, agents keep running
  { { "cmd" }, ",", "s" },                             -- settings
}

for n = 1, 9 do
  table.insert(bindings, { { "cmd" }, tostring(n), tostring(n) })
end

local function sendPrefixed(key)
  return function()
    hs.eventtap.keyStroke({ "ctrl" }, "b", 0)
    if type(key) == "string" then
      hs.eventtap.keyStrokes(key)
    else
      hs.eventtap.keyStroke(key[1], key[2], 0)
    end
  end
end

local hotkeys = {}
for _, def in ipairs(bindings) do
  table.insert(hotkeys, hs.hotkey.new(def[1], def[2], sendPrefixed(def[3])))
end

-- Marked window ids, loaded from settings and pruned of windows that are gone.
local marked = {}
for _, id in ipairs(hs.settings.get(SETTINGS_KEY) or {}) do
  if hs.window.get(id) then marked[id] = true end
end

local function save()
  local ids = {}
  for id in pairs(marked) do table.insert(ids, id) end
  hs.settings.set(SETTINGS_KEY, ids)
end

local active = false

local function setActive(shouldBeActive)
  if shouldBeActive == active then return end
  active = shouldBeActive
  for _, hk in ipairs(hotkeys) do
    if active then hk:enable() else hk:disable() end
  end
end

local function isHerdrWindow(win)
  return win ~= nil and marked[win:id()] == true
end

local function markWindow(win)
  marked[win:id()] = true
  save()
  log.i("marked herdr window " .. win:id())
end

local function isGhostty(win)
  local app = win and win:application()
  return app ~= nil and app:bundleID() == constants.appBundleIds.ghostty
end

-- A window created while herdr-window's sentinel is fresh is a herdr window.
local function claimPendingWindow(win)
  if not isGhostty(win) then return false end
  local attributes = hs.fs.attributes(PENDING)
  if not attributes then return false end
  if attributes.mode ~= "file" then
    log.w("ignoring an invalid herdr-window sentinel")
    return false
  end
  if not os.remove(PENDING) then
    log.w("cannot consume the herdr-window sentinel")
    return false
  end
  if os.time() - attributes.modification > PENDING_MAX_AGE then
    log.w("ignoring a stale herdr-window sentinel")
    return false
  end
  markWindow(win)
  return true
end

function M.markFocusedWindow()
  -- herdr-window activates the window just before calling this, but give the
  -- window server a moment to catch up before giving up on it.
  for _ = 1, 15 do
    local win = hs.window.focusedWindow()
    if isGhostty(win) then
      markWindow(win)
      setActive(true)
      return true
    end
    hs.timer.usleep(100000)
  end
  log.w("no focused Ghostty window to mark")
  return false
end

function M.start()
  local filter = hs.window.filter.new(true)
  filter:subscribe(hs.window.filter.windowCreated, function(win)
    if claimPendingWindow(win) then setActive(true) end
  end)
  filter:subscribe(hs.window.filter.windowFocused, function(win)
    setActive(isHerdrWindow(win))
  end)
  filter:subscribe(hs.window.filter.windowDestroyed, function(win)
    -- A destroyed window may no longer answer :id(), in which case its mark
    -- lingers until the next config reload prunes it. Harmless: the id has to
    -- be handed to a *new* Ghostty window before it means anything.
    local ok, id = pcall(function() return win and win:id() end)
    if ok and id and marked[id] then
      marked[id] = nil
      save()
    end
  end)
  setActive(isHerdrWindow(hs.window.focusedWindow()))
  return filter
end

-- Exposed for the test script
M._bindings = bindings
M._isHerdrWindow = isHerdrWindow
M._marked = marked
M._pendingPath = PENDING

return M
