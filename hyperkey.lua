-- F19 → Hyperkey (Cmd+Ctrl+Opt+Shift) modifier emitter.
--
-- This module exists because macOS Sequoia/Tahoe changed how Caps Lock
-- interacts with input timing, and Karabiner's Caps Lock → modifier rule
-- stopped working reliably. As a workaround:
--   1. hidutil remaps Caps Lock (HID 0x700000039) → F19 (HID 0x70000006E)
--      (run by a LaunchAgent at login so it survives reboot).
--   2. This module listens for F19 key events and posts the four
--      Hyper modifier keys (left_command, left_shift, left_option, left_control)
--      as if held down for the duration of the F19 press.
--
-- Effect: any hs.hotkey.bind({"cmd","alt","ctrl","shift"}, "X", ...) fires
-- when the user holds Caps Lock + X. Same for app-based hotkey registries
-- that use the same modifier list (constants.hyperKeyMods).
--
-- Edge cases handled:
--   - If Hammerspoon reloads while Caps Lock (F19) is held, on next start()
--     we explicitly post mod-up events to clear any stuck modifier state.
--   - On stop(), modifiers are released defensively.
--   - F19 key events themselves are consumed (returned `true` from the
--     eventtap callback) so they don't reach any other app as a real F19.

local log = hs.logger.new("Hyperkey", "info")

local M = {}

-- macOS virtual keycodes (same numbers hs.keycodes.map returns).
local F19_KEYCODE = 80
-- Left-side modifier keys. We emit the LEFT variants of each modifier; macOS
-- treats left and right as equivalent for modifier-flag purposes, but using
-- a consistent side avoids any "stuck right shift" surprises.
local LEFT_CMD = 55
local LEFT_SHIFT = 56
local LEFT_OPT = 58
local LEFT_CTRL = 59

local HYPER_MOD_KEYCODES = { LEFT_CMD, LEFT_SHIFT, LEFT_OPT, LEFT_CTRL }

local state = {
  held = false,
  tap = nil,
}

-- ATOMIC: post a single flagsChanged event with all 4 modifier bits set/unset.
-- Faster than posting 4 separate keyDown events because each :post() has
-- macOS-event-pipeline overhead. With one event instead of four, latency
-- between Caps Lock press and the modifier state being visible to apps drops
-- ~4x.
local function post_mods(is_down)
  local flags = is_down and { cmd = true, shift = true, alt = true, ctrl = true } or {}
  local e = hs.eventtap.event.newEvent()
  e:setType(hs.eventtap.event.types.flagsChanged)
  e:setFlags(flags)
  e:post()
end

-- FALLBACK: if the atomic flagsChanged approach doesn't get picked up by
-- hs.hotkey (some macOS event-routing paths only respect real keyDown events
-- for modifier state), revert to posting 4 separate keyDown events. Kept as
-- a switchable function for the user to flip back via M.use_keydown_emit().
local function post_mods_keydown_form(is_down)
  for _, kc in ipairs(HYPER_MOD_KEYCODES) do
    hs.eventtap.event.newKeyEvent(kc, is_down):post()
  end
end

-- Switch emit strategy at runtime.
function M.use_atomic_emit()
  post_mods = function(is_down)
    local flags = is_down and { cmd = true, shift = true, alt = true, ctrl = true } or {}
    local e = hs.eventtap.event.newEvent()
    e:setType(hs.eventtap.event.types.flagsChanged)
    e:setFlags(flags)
    e:post()
  end
  log.i("emit strategy: atomic flagsChanged")
end

function M.use_keydown_emit()
  post_mods = post_mods_keydown_form
  log.i("emit strategy: 4 separate keyDown events")
end

function M.start()
  if state.tap then
    log.i("start() called but tap already running; no-op")
    return
  end

  -- Clear any stuck modifier state from a previous bad shutdown.
  post_mods(false)
  state.held = false
  log.i("posted mods=up to clear any stuck state")

  log.i("Starting F19 → Hyper watcher")
  state.tap = hs.eventtap.new(
    { hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp },
    function(e)
      local kc = e:getKeyCode()
      if kc ~= F19_KEYCODE then
        return false
      end
      local is_down = e:getType() == hs.eventtap.event.types.keyDown
      log.i(string.format("F19 event: %s (held was %s)", is_down and "DOWN" or "UP", tostring(state.held)))
      if is_down then
        if not state.held then
          state.held = true
          post_mods(true)
          log.i("posted mods=DOWN (cmd+shift+opt+ctrl)")
        end
      else
        if state.held then
          state.held = false
          post_mods(false)
          log.i("posted mods=UP")
        end
      end
      return true -- consume the F19 event so it doesn't leak to apps
    end
  )
  state.tap:start()
  log.i("F19 eventtap started")
end

function M.stop()
  if state.tap then
    state.tap:stop()
    state.tap = nil
  end
  if state.held then
    post_mods(false)
    state.held = false
  end
  log.i("Stopped F19 → Hyper watcher")
end

return M
