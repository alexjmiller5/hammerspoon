-- Ghostty app handler: snapshot (read terminals via AppleScript dictionary)
-- and restore (spawn new windows via JXA new-window-with-configuration).
local M = {}

-- True if `title` looks like a filesystem path (a plain-shell Ghostty title,
-- set by Ghostty's shell-integration when no claude is running).
function M.is_path_title(title)
  if type(title) ~= "string" or #title == 0 then return false end
  return title:sub(1, 1) == "/" or title:sub(1, 2) == "~/"
end

-- Strip leading spinner glyph + space from a Claude ai-title.
-- Spinners observed: braille range (U+2800..U+28FF), sparkle (✳ U+2733), star (✨ U+2728).
function M.strip_spinner(title)
  if type(title) ~= "string" then return "" end
  -- Defensive: strip variation selector U+FE0F (UTF-8: EF B8 8F) that may
  -- follow an emoji in emoji-presentation form (e.g. ✳️ vs ✳).
  local t = title:gsub("\xEF\xB8\x8F", "")
  -- Lua patterns don't handle multi-byte Unicode classes. Use literal escapes
  -- for the known glyphs and a generic "first UTF-8 char of 3 bytes + space"
  -- fallback that matches the braille block (E2 A0 80..E2 A3 BF).
  -- Strip explicit sparkles/stars first.
  local s = t:gsub("^✳%s+", ""):gsub("^✨%s+", "")
  if s ~= t then return s end
  -- Strip braille: E2 A0..A3 80..BF, followed by space.
  s = t:gsub("^\xE2[\xA0-\xA3][\x80-\xBF]%s+", "")
  return s
end

-- Query the live Ghostty app via JXA, returning a list of:
--   { windowId = string, name = string, terminals = { {id, name, workingDirectory}, ... } }
-- Returns nil + error on failure (Ghostty not running, AppleScript permission denied, etc.).
function M.query_ghostty_via_jxa()
  if not hs or not hs.osascript then
    return nil, "hs.osascript not available (running outside Hammerspoon?)"
  end
  local script = [[
    const g = Application("Ghostty");
    if (!g.running()) { JSON.stringify({error: "Ghostty not running"}); }
    else {
      JSON.stringify(g.windows().map(w => ({
        windowId: w.id(),
        name: w.name(),
        terminals: w.terminals().map(t => ({
          id: t.id(),
          name: t.name(),
          workingDirectory: t.workingDirectory()
        }))
      })));
    }
  ]]
  local ok, result, _ = hs.osascript.javascript(script)
  if not ok then return nil, "JXA call failed: " .. tostring(result) end
  local parsed = hs.json.decode(result)
  if parsed and parsed.error then return nil, parsed.error end
  return parsed
end

-- Capture snapshot entries for the given macOS Ghostty windows.
-- `mac_windows`: list of { id = macOSWinId, title = string } (from hs.window)
-- `opts` (optional, for tests):
--   registry = list of { macWindowId, sessionId, cwd, pid } — skip live read
-- Returns: list of { cwd = string, sessionId = string|nil }
--
-- Attribution is REGISTRY-ONLY: a window's sessionId comes from a registry
-- entry matching its macWindowId, or is nil. The registry is populated by
-- the SessionStart hook (scripts/claude-hooks/session-start.sh) on each
-- claude launch in a Ghostty terminal. Stale entries (claude exited without
-- notice) are pruned at read time via `live_entries` (pgrep -x claude).
--
-- No queue or mtime fallback: prior versions tried to infer sids by mtime-
-- ordering jsonls under the cwd, which over-attributed when other claudes
-- ran at the same cwd in different Spaces. The hook + registry close that
-- gap deterministically. Claudes started before the hook was installed are
-- invisible to capture; user can `/exit` and re-launch to refresh.
function M.capture(mac_windows, opts)
  opts = opts or {}
  local entries = {}
  local applescript_windows = nil  -- lazy; only needed for ai-titled windows

  local registry_entries = opts.registry
  if registry_entries == nil then
    local ok, claude_registry = pcall(require, "util.claude_registry")
    local ok2, paths_mod = pcall(require, "util.paths")
    if ok and ok2 then
      registry_entries = claude_registry.live_entries(
        claude_registry.read(paths_mod.ghostty_claude_registry_file))
    else
      registry_entries = {}
    end
  end
  local registry_by_id = {}
  for _, e in ipairs(registry_entries) do
    registry_by_id[e.macWindowId] = e
  end

  for _, w in ipairs(mac_windows) do
    local title = w.title or ""
    local reg = registry_by_id[w.id]
    if M.is_path_title(title) then
      local cwd = title
      if cwd:sub(1, 2) == "~/" then
        cwd = (os.getenv("HOME") or "") .. cwd:sub(2)
      end
      table.insert(entries, { cwd = cwd, sessionId = reg and reg.sessionId or nil })
    else
      -- Claude-titled: AppleScript lookup is still the only way to get the cwd
      -- (the title isn't path-shaped). sessionId comes from the registry, or
      -- nil if this window isn't registered.
      if applescript_windows == nil then
        local result, _ = M.query_ghostty_via_jxa()
        applescript_windows = result or {}
      end
      local normalized_title = M.strip_spinner(title)
      local matched_cwd = nil
      for _, aw in ipairs(applescript_windows) do
        if M.strip_spinner(aw.name) == normalized_title and #aw.terminals > 0 then
          matched_cwd = aw.terminals[1].workingDirectory
          break
        end
      end
      if matched_cwd then
        table.insert(entries, { cwd = matched_cwd, sessionId = reg and reg.sessionId or nil })
      end
    end
  end

  return entries
end

-- Spawn a new Ghostty window at `cwd`, optionally running `claude --resume <id>`.
-- Returns the new Ghostty window's stable id (a string) or nil + error.
function M.launch(cwd, sessionId)
  if not hs or not hs.osascript then
    return nil, "hs.osascript not available"
  end
  -- Build initialInput JS-side. Pass cwd and sessionId via string format, then
  -- concatenate a real newline character in the JS string.
  local script
  if sessionId then
    script = ([[
      const g = Application("Ghostty");
      const cfg = g.newSurfaceConfiguration();
      cfg.initialWorkingDirectory = %q;
      cfg.initialInput = "claude --resume " + %q + "\n";
      const w = g.newWindow({withConfiguration: cfg});
      JSON.stringify({id: w.id()});
    ]]):format(cwd, sessionId)
  else
    script = ([[
      const g = Application("Ghostty");
      const cfg = g.newSurfaceConfiguration();
      cfg.initialWorkingDirectory = %q;
      const w = g.newWindow({withConfiguration: cfg});
      JSON.stringify({id: w.id()});
    ]]):format(cwd)
  end
  local ok, result = hs.osascript.javascript(script)
  if not ok then return nil, "JXA newWindow failed: " .. tostring(result) end
  local parsed = hs.json.decode(result)
  return parsed and parsed.id or nil
end

return M
