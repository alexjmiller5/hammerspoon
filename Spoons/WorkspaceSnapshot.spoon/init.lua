--- === WorkspaceSnapshot ===
---
--- Snapshot a macOS Space's window state to clipboard text and restore it later
--- into a fresh space. Covers Chrome, Chrome PWAs, VSCode (with integrated
--- terminals), and Ghostty (with Claude Code sessions).
---
--- Public action methods (call directly OR bind via `:bindHotkeys({...})`):
---  - `obj.snapshot()`         - copy current space's window state to clipboard
---  - `obj.snapshotAndClose()` - snapshot AND close all captured windows
---  - `obj.restore()`          - read clipboard, restore into a blank/new space
---
--- Two integration styles:
---   STANDARD (for distributed install) - bind via the Spoon convention:
---     hs.loadSpoon("WorkspaceSnapshot"):bindHotkeys({
---       snapshot      = { mods, "s" },
---       snapshotClose = { mods, "x" },
---       restore       = { mods, "r" },
---     }):start()
---
---   INLINE (for users with their own hotkey registry) - load the Spoon
---   without bindHotkeys, then reference obj.snapshot / .snapshotAndClose /
---   .restore from your registry's action table.

local obj = {}
obj.__index = obj

-- Metadata
obj.name     = "WorkspaceSnapshot"
obj.version  = "0.1"
obj.author   = "Alex Miller <98389659+alexjmiller5@users.noreply.github.com>"
obj.homepage = "https://github.com/alexjmiller5/workspace-snapshot"
obj.license  = "MIT"

-- Spoons use the script's directory for require resolution.
local spoonPath = hs.spoons.scriptPath()
package.path = spoonPath .. "?.lua;" .. spoonPath .. "?/init.lua;" .. package.path

-- Force-clear our own submodules from the require cache so `hs.reload()`
-- picks up edits without a full Hammerspoon quit/relaunch. Required because
-- `hs.reload()` re-runs ~/.hammerspoon/init.lua (and thus this Spoon's
-- init.lua) but does NOT clear `package.loaded` — so any nested `require()`
-- still returns the stale cached chunk.
for _, m in ipairs({
  "capture", "restore", "parse",
  "apps.ghostty", "apps.chrome", "apps.vscode", "apps.gemini",
  "util.helpers", "util.history",
  "util.log", "util.paths", "util.claude_registry",
}) do
  package.loaded[m] = nil
end

local capture         = require("capture")
local restore         = require("restore")
local parse           = require("parse")
local history         = require("util.history")
local claude_registry = require("util.claude_registry")
local paths           = require("util.paths")
local log             = require("util.log").new("Spoon")

local function show_alert(msg)
  hs.alert.show(msg, { textSize = 16 }, 2)
end

-- Build a multi-line summary of a snapshot for the user-facing alert.
-- Lists per-category counts + a brief detail (cwd basenames, tab counts, etc.)
-- so the user can confirm at a glance what was captured.
local function summarize_snapshot(snap)
  local lines = {}
  local function basename(path) return path:match("([^/]+)$") or path end

  if #snap.ghostty > 0 then
    local details = {}
    for _, e in ipairs(snap.ghostty) do
      local b = basename(e.cwd)
      if e.sessionId then b = b .. "*" end -- mark claude sessions
      table.insert(details, b)
    end
    table.insert(lines, ("Ghostty (%d): %s"):format(#snap.ghostty, table.concat(details, ", ")))
  end
  if #snap.chrome > 0 then
    local tab_total = 0
    for _, e in ipairs(snap.chrome) do tab_total = tab_total + #e.tabs end
    table.insert(lines, ("Chrome (%d): %d tab%s"):format(
      #snap.chrome, tab_total, tab_total == 1 and "" or "s"))
  end
  if #snap.vscode > 0 then
    local details = {}
    for _, e in ipairs(snap.vscode) do
      local b = basename(e.workspace):gsub("%.code%-workspace$", "")
      local tcount = #(e.terminals or {})
      if tcount > 0 then b = b .. " (" .. tcount .. "t)" end
      table.insert(details, b)
    end
    table.insert(lines, ("VSCode (%d): %s"):format(#snap.vscode, table.concat(details, ", ")))
  end
  if #snap.gemini > 0 then
    local details = {}
    for _, e in ipairs(snap.gemini) do
      -- Show the chat id (last path segment) or "app" for the home url.
      local chat = e.url:match("/app/([%w%-]+)") or "app"
      table.insert(details, chat)
    end
    table.insert(lines, ("Gemini (%d): %s"):format(#snap.gemini, table.concat(details, ", ")))
  end

  return table.concat(lines, "\n")
end

-- Forward declarations so the public methods below can reference them.
local do_snapshot, do_restore

do_snapshot = function(close_after)
  local sp = require("hs.spaces")
  log.i(("=== do_snapshot triggered (close_after=%s) ==="):format(tostring(close_after)))

  log.i("step 1/5: capture.capture_current_space()")
  local snap = capture.capture_current_space()
  local total = #snap.ghostty + #snap.chrome + #snap.vscode + #snap.gemini
  log.i(("step 1 done: ghostty=%d chrome=%d vscode=%d gemini=%d (total=%d)"):format(
    #snap.ghostty, #snap.chrome, #snap.vscode, #snap.gemini, total))
  if total == 0 then
    log.i("no capturable windows; bailing out")
    show_alert("WorkspaceSnapshot: nothing to capture")
    return
  end

  log.i("step 2/5: parse.format_text")
  local text = parse.format_text(snap)
  log.i(("step 2 done: formatted text is %d bytes"):format(#text))

  log.i("step 3/5: hs.pasteboard.setContents")
  hs.pasteboard.setContents(text)
  log.i("step 3 done: clipboard set")

  log.i("step 4/5: history.save")
  local saved = history.save(text)
  log.i(("step 4 done: history saved to %s"):format(tostring(saved)))

  log.i("step 5/5: alert")
  local header = close_after
    and ("Snapshotted + closing %d windows"):format(total)
    or ("Snapshotted %d windows"):format(total)
  local body = summarize_snapshot(snap)
  show_alert(header .. "\n" .. body)
  log.i(("=== do_snapshot complete (%d windows) ==="):format(total))

  if close_after then
    log.i("close_after=true; enumerating windows to close")
    -- Same defensive enumeration as capture.lua: iterate hs.window.allWindows()
    -- (windows with confirmed AX access) intersected with the focused space's
    -- window-id set, never calling hs.window.get on raw CGS IDs (some hang).
    local space_id_set = {}
    for _, id in ipairs(sp.windowsForSpace(sp.focusedSpace()) or {}) do
      space_id_set[id] = true
    end
    local to_close = {}
    for _, w in ipairs(hs.window.allWindows()) do
      local id = w:id()
      if id and space_id_set[id] and w:subrole() == "AXStandardWindow" then
        local app = w:application()
        local bid = app and app:bundleID() or ""
        if bid == "com.google.Chrome" or bid == "com.microsoft.VSCode"
           or bid == "com.mitchellh.ghostty"
           or bid == "com.alexmiller.geminidesktop" then
          table.insert(to_close, w)
        end
      end
    end
    log.i(("found %d windows to close"):format(#to_close))
    local count_closed = 0
    for _, w in ipairs(to_close) do
      local ok = pcall(function() w:close() end)
      if ok then
        count_closed = count_closed + 1
        log.i(("  closed id=%d"):format(w:id() or -1))
      else
        log.w(("  close failed for id=%d"):format(w:id() or -1))
      end
    end
    log.i(("close_after complete: %d of %d closed"):format(count_closed, #to_close))
    show_alert(("Closed %d windows"):format(count_closed))
  end
end

do_restore = function()
  log.i("=== do_restore triggered ===")

  log.i("step 1/4: read + validate clipboard")
  local text = hs.pasteboard.getContents()
  if not text then
    log.w("clipboard is nil")
    show_alert("Clipboard is empty")
    return
  end
  log.i(("clipboard has %d bytes"):format(#text))
  local ok, err = parse.validate_clipboard_text(text)
  if not ok then
    log.w("validate_clipboard_text rejected: " .. tostring(err))
    show_alert("Not a snapshot - " .. err)
    return
  end
  log.i("step 1 done: clipboard validates as a snapshot")

  log.i("step 2/4: parse.parse_text")
  local snap, perr = parse.parse_text(text)
  if not snap then
    log.w("parse error: " .. tostring(perr))
    show_alert("Parse error: " .. perr)
    return
  end
  log.i(("step 2 done: parsed ghostty=%d chrome=%d vscode=%d gemini=%d"):format(
    #snap.ghostty, #snap.chrome, #snap.vscode, #snap.gemini))

  log.i("step 3/4: restore.restore_to_current_space (will pick target + launch)")
  local count = restore.restore_to_current_space(snap)
  log.i(("step 3 done: dispatched %d launch calls"):format(count))

  log.i("step 4/4: alert")
  show_alert(("Restored %d windows (launching async)"):format(count))
  log.i(("=== do_restore complete (%d launches dispatched) ==="):format(count))
end

-- Public action methods. Users can reference these directly from their own
-- hotkey registries (e.g. globalHotkeys.lua) without going through bindHotkeys.
function obj.snapshot()         do_snapshot(false) end
function obj.snapshotAndClose() do_snapshot(true)  end
function obj.restore()          do_restore()       end

-- Called by scripts/claude-hooks/session-start.sh via `hs -c` whenever a
-- claude session starts in a Ghostty terminal. Captures the focused window's
-- macOS CGS id and records {macWindowId, sessionId, cwd} in the registry so
-- M.capture can attribute the session deterministically to the right terminal
-- (Ghostty's AppleScript doesn't expose per-terminal shell PIDs, so without
-- this hook M.capture has to guess when multiple terminals share a cwd).
--
-- Sanity-gated: silently no-ops unless the focused window is Ghostty AND the
-- session's cwd matches the focused window's title (path-shaped) or is at
-- least plausibly the cwd of the Ghostty terminal that just ran claude.
function obj.registerClaudeSession(sessionId, cwd, pid)
  if type(sessionId) ~= "string" or sessionId == "" then
    log.w("registerClaudeSession: missing sessionId")
    return
  end
  if type(cwd) ~= "string" or cwd == "" then
    log.w("registerClaudeSession: missing cwd")
    return
  end
  -- pid may arrive as string via `hs -c`; coerce.
  pid = tonumber(pid)
  if not pid or pid <= 0 then
    log.w("registerClaudeSession: missing/invalid pid; skipping")
    return
  end
  local fw = hs.window.focusedWindow()
  if not fw then
    log.w("registerClaudeSession: no focused window; skipping")
    return
  end
  local app = fw:application()
  local bid = app and app:bundleID() or ""
  if bid ~= "com.mitchellh.ghostty" then
    log.w("registerClaudeSession: focused app is not Ghostty (" .. bid .. "); skipping")
    return
  end
  local mac_window_id = fw:id()
  if type(mac_window_id) ~= "number" then
    log.w("registerClaudeSession: focused window has no id; skipping")
    return
  end
  claude_registry.upsert(paths.ghostty_claude_registry_file, {
    macWindowId = mac_window_id,
    sessionId   = sessionId,
    cwd         = cwd,
    pid         = pid,
  })
  log.i(("registered claude session %s -> macWindowId=%d cwd=%s pid=%d"):format(
    sessionId, mac_window_id, cwd, pid))
end


function obj:init()
  return self
end

function obj:start()
  log.i("WorkspaceSnapshot started")
  return self
end

function obj:stop()
  if self._hotkeys then
    for _, hk in pairs(self._hotkeys) do hk:delete() end
    self._hotkeys = nil
  end
  return self
end

-- Standard Spoon hotkey binding. Maps action names to the public methods above.
function obj:bindHotkeys(mapping)
  self._hotkeys = self._hotkeys or {}
  local action_for = {
    snapshot      = obj.snapshot,
    snapshotClose = obj.snapshotAndClose,
    restore       = obj.restore,
  }
  for name, spec_ in pairs(mapping) do
    if self._hotkeys[name] then self._hotkeys[name]:delete() end
    local fn = action_for[name]
    if fn then
      self._hotkeys[name] = hs.hotkey.bind(spec_[1], spec_[2], fn)
    else
      log.w("unknown bindHotkeys action: " .. tostring(name))
    end
  end
  return self
end

return obj
