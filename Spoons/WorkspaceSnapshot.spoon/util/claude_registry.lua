-- Per-Ghostty-terminal claude session registry.
--
-- The hook script `scripts/claude-hooks/session-start.sh` invokes
-- `spoon.WorkspaceSnapshot.registerClaudeSession(sessionId, cwd)` via `hs -c`
-- whenever claude starts (gated to Ghostty terminals). The Spoon then captures
-- the focused window's macOS CGS id and writes a tuple
--   { macWindowId, sessionId, cwd }
-- to this registry.
--
-- At snapshot time, ghostty.lua's M.capture indexes the registry by
-- macWindowId to look up the correct sessionId per visible terminal —
-- deterministic where the queue-based fallback can only guess when multiple
-- terminals share a cwd across Spaces.
--
-- Schema (Application Support/WorkspaceSnapshot/ghostty-claude-registry.json):
--   { "schemaVersion": 1, "entries": [ { macWindowId, sessionId, cwd }, ... ] }
local M = {}

local SCHEMA_VERSION = 1

-- JSON encode/decode shim: prefer hs.json when in Hammerspoon, fall back to
-- the minimal test-fixture decoder for standalone Lua test contexts.
local function decode(s)
  if hs and hs.json and hs.json.decode then return hs.json.decode(s) end
  local minijson = require("minijson")
  return minijson.decode(s)
end

local function encode(t)
  if hs and hs.json and hs.json.encode then
    return hs.json.encode(t, true)  -- prettyprint
  end
  -- Standalone Lua fallback: hand-roll a minimal pretty encoder. Only used in
  -- test contexts where hs.json isn't available.
  local function quote(s) return '"' .. tostring(s):gsub('"', '\\"') .. '"' end
  local function enc(v)
    local tv = type(v)
    if tv == "string" then return quote(v) end
    if tv == "number" or tv == "boolean" then return tostring(v) end
    if tv == "nil" then return "null" end
    if tv == "table" then
      -- Array if integer-keyed starting at 1.
      if #v > 0 or next(v) == nil then
        local parts = {}
        for i = 1, #v do parts[i] = enc(v[i]) end
        return "[" .. table.concat(parts, ",") .. "]"
      end
      local parts = {}
      for k, val in pairs(v) do
        table.insert(parts, quote(k) .. ":" .. enc(val))
      end
      return "{" .. table.concat(parts, ",") .. "}"
    end
    return "null"
  end
  return enc(t)
end

-- Read the registry file. Returns a flat list of entry tables; returns {} on
-- any failure (missing file, empty, malformed JSON, schema mismatch). Callers
-- never need to handle errors.
function M.read(path)
  local f = io.open(path, "r")
  if not f then return {} end
  local raw = f:read("*a")
  f:close()
  if not raw or raw == "" then return {} end
  local ok, data = pcall(decode, raw)
  if not ok or type(data) ~= "table" then return {} end
  local entries = data.entries
  if type(entries) ~= "table" then return {} end
  return entries
end

-- Atomically write entries to the registry. Creates parent dir if missing.
local function write(path, entries)
  local dir = path:match("^(.*)/[^/]+$")
  if dir then os.execute("mkdir -p " .. ("%q"):format(dir)) end
  local payload = { schemaVersion = SCHEMA_VERSION, entries = entries }
  local tmp = path .. ".tmp"
  local f, err = io.open(tmp, "w")
  if not f then return nil, err end
  f:write(encode(payload))
  f:close()
  os.rename(tmp, path)
  return true
end

-- Insert or replace an entry keyed by macWindowId. If an entry with the same
-- macWindowId exists, it's overwritten in-place; otherwise the new entry is
-- appended.
function M.upsert(path, entry)
  assert(type(entry.macWindowId) == "number", "macWindowId must be a number")
  assert(type(entry.sessionId) == "string", "sessionId must be a string")
  assert(type(entry.cwd) == "string", "cwd must be a string")
  -- pid is optional in the type, but live_entries treats entries without one
  -- as stale, so production writers should always set it.
  local entries = M.read(path)
  for i, e in ipairs(entries) do
    if e.macWindowId == entry.macWindowId then
      entries[i] = entry
      return write(path, entries)
    end
  end
  table.insert(entries, entry)
  return write(path, entries)
end

-- Return the set of currently-running user-facing claude CLI PIDs as a
-- {[pid] = true} table. Uses `pgrep -x claude` (exact argv[0] basename match)
-- so the Electron Claude.app desktop binary ("Claude" with capital C) and
-- bg-pty-host/bg-spare/--agent subprocess workers are filtered out. Empty
-- table on any failure.
function M.live_claude_pids()
  local pids = {}
  local p = io.popen("pgrep -x claude 2>/dev/null")
  if not p then return pids end
  for line in p:lines() do
    local pid = tonumber(line)
    if pid then pids[pid] = true end
  end
  p:close()
  return pids
end

-- Filter a list of entries down to those backed by a currently-running claude
-- process. `live_pids` is the {[pid] = true} table; falls back to a live
-- pgrep call when omitted.
--
-- Entries without a `pid` field are treated as stale (registered by pre-pid
-- versions of the hook; user needs to /exit + re-launch to refresh).
--
-- The pgrep set check is strictly stronger than `kill -0 <pid>`: it defends
-- against PID recycling (a non-claude process that inherits a recycled PID
-- won't be in the live-claude set).
function M.live_entries(entries, live_pids)
  if live_pids == nil then live_pids = M.live_claude_pids() end
  local kept = {}
  for _, e in ipairs(entries) do
    if type(e.pid) == "number" and live_pids[e.pid] then
      table.insert(kept, e)
    end
  end
  return kept
end

-- Index a list of entries by macWindowId for O(1) lookup. Last entry wins
-- on duplicate keys.
function M.by_mac_window_id(entries)
  local idx = {}
  for _, e in ipairs(entries) do
    idx[e.macWindowId] = e
  end
  return idx
end

return M
