local M = {}
local spec = require("spec")
local gemini = require("apps.gemini")
local log = require("util.log").new("restore")

local KNOWN_BUNDLES_SET = {
  ["com.google.Chrome"]     = true,
  ["com.microsoft.VSCode"]  = true,
  ["com.mitchellh.ghostty"] = true,
  [gemini.BUNDLE_ID]        = true,
}

-- True if the focused space has zero "capturable" windows (= safe to use as target).
local function focused_space_is_blank()
  local sp = require("hs.spaces")
  local ids = sp.windowsForSpace(sp.focusedSpace()) or {}
  for _, id in ipairs(ids) do
    local w = hs.window.get(id)
    if w and w:subrole() == "AXStandardWindow" then
      local bid = w:application() and w:application():bundleID() or nil
      if KNOWN_BUNDLES_SET[bid] then
        return false
      end
    end
  end
  return true
end

-- Return target space id; create new if focused is non-blank.
-- POC-verified on macOS 26.1 (Tahoe): hs.spaces.addSpaceToScreen works but the
-- FIRST invocation in a session sometimes fails with "unable to get Mission
-- Control data from the Dock". Retry once after a brief Dock-warmup delay,
-- and always pass closeMC=true (second arg) so the API picks up MC state.
function M.pick_or_create_target_space()
  local sp = require("hs.spaces")
  if focused_space_is_blank() then
    log.i("focused space is blank - using it as target")
    return sp.focusedSpace()
  end
  log.i("focused space has windows - creating new space")
  local screen_id = hs.screen.primaryScreen():getUUID()

  local function try_add()
    local ok, ret, err = pcall(sp.addSpaceToScreen, screen_id, true)
    if not ok then return false, tostring(ret) end
    if not ret then return false, tostring(err) end
    return true
  end

  local ok1, err1 = try_add()
  if not ok1 then
    log.w("addSpaceToScreen first attempt failed: " .. tostring(err1) .. " - retrying")
    hs.timer.usleep(300000) -- 300ms Dock warmup
    local ok2, err2 = try_add()
    if not ok2 then
      log.e("addSpaceToScreen failed twice: " .. tostring(err2) .. " - falling back to focused space")
      return sp.focusedSpace()
    end
  end

  -- API returns success but not the new space id; query again.
  hs.timer.usleep(500000)
  local all = sp.spacesForScreen(screen_id) or {}
  local target = all[#all]
  sp.gotoSpace(target)

  -- gotoSpace kicks off macOS's Mission Control animation and returns
  -- immediately. If we return NOW, the launch loop fires while the animation
  -- is mid-flight, so the first few windows get created in the source Space
  -- and briefly flash there before the window-watcher moves them.
  --
  -- Poll focusedSpace() until it stabilises on the target (or we time out).
  -- This is blocking-wait on the Lua thread; the switch animation itself
  -- runs in the WindowServer/Dock, so blocking Lua doesn't stall it.
  local poll_interval_us = 50000    -- 50ms
  local max_iterations = 60          -- 3s total budget
  for _ = 1, max_iterations do
    if sp.focusedSpace() == target then break end
    hs.timer.usleep(poll_interval_us)
  end
  if sp.focusedSpace() ~= target then
    log.w(("timed out waiting for space switch to target=%s (focused=%s)"):format(
      tostring(target), tostring(sp.focusedSpace())))
  end
  return target
end

-- Watch for new windows for the next N seconds and move them to target_space.
function M.watch_and_move_new_windows(target_space, duration_seconds)
  local filter = hs.window.filter.new(nil):setOverrideFilter({
    visible = true,
    allowRoles = "AXStandardWindow",
  })
  local sp = require("hs.spaces")
  filter:subscribe(hs.window.filter.windowCreated, function(w)
    local bid = w:application() and w:application():bundleID() or nil
    if KNOWN_BUNDLES_SET[bid] then
      local current = sp.windowSpaces(w) or {}
      local in_target = false
      for _, s in ipairs(current) do if s == target_space then in_target = true; break end end
      if not in_target then
        sp.moveWindowToSpace(w:id(), target_space)
        log.i("moved new window " .. w:id() .. " to target space")
      end
    end
  end)
  hs.timer.doAfter(duration_seconds, function()
    filter:unsubscribeAll()
  end)
end

-- Launch every entry in the snapshot via the appropriate app handler.
-- Returns count of windows we attempted to launch.
function M.restore_to_current_space(snap)
  log.i(("restore_to_current_space: ghostty=%d chrome=%d vscode=%d gemini=%d"):format(
    #snap.ghostty, #snap.chrome, #snap.vscode, #snap.gemini))

  local ok, err = spec.validate(snap)
  if not ok then
    log.e("snapshot failed validation: " .. err)
    return 0, "invalid snapshot: " .. err
  end
  log.i("snapshot validates ok")

  log.i("picking or creating target space")
  local target = M.pick_or_create_target_space()
  log.i(("target space = %s"):format(tostring(target)))

  log.i("starting 30s window watcher to move newly-created windows to target")
  M.watch_and_move_new_windows(target, 30)

  local count = 0
  local ghostty_mod = require("apps.ghostty")
  local chrome_mod  = require("apps.chrome")
  local vscode_mod  = require("apps.vscode")
  local gemini_mod  = require("apps.gemini")

  for i, e in ipairs(snap.ghostty) do
    log.i(("ghostty.launch #%d cwd=%s session=%s"):format(i, e.cwd, tostring(e.sessionId)))
    local _, err_g = ghostty_mod.launch(e.cwd, e.sessionId)
    if err_g then log.w("ghostty.launch failed: " .. err_g) else count = count + 1 end
  end
  for i, e in ipairs(snap.chrome) do
    log.i(("chrome.launch #%d with %d tabs"):format(i, #e.tabs))
    local _, err_c = chrome_mod.launch(e.tabs)
    if err_c then log.w("chrome.launch failed: " .. tostring(err_c)) else count = count + 1 end
  end
  for i, e in ipairs(snap.vscode) do
    log.i(("vscode.launch #%d workspace=%s terminals=%d"):format(
      i, e.workspace, #(e.terminals or {})))
    vscode_mod.launch(e.workspace, e.terminals)
    count = count + 1
  end
  for i, e in ipairs(snap.gemini) do
    log.i(("gemini.launch #%d url=%s"):format(i, tostring(e.url)))
    local _, err_g = gemini_mod.launch(e.url)
    if err_g then log.w("gemini.launch failed: " .. tostring(err_g)) else count = count + 1 end
  end

  log.i(("restore_to_current_space complete: %d launches dispatched"):format(count))
  return count
end

return M
