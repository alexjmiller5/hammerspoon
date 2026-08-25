-- Centralized macOS data-dir paths. All other modules reference these
-- instead of hard-coding paths.
local M = {}

local function home()
  return os.getenv("HOME") or error("HOME env not set")
end

M.app_support_root  = home() .. "/Library/Application Support/WorkspaceSnapshot"
M.caches_root       = home() .. "/Library/Caches/WorkspaceSnapshot"
M.logs_root         = home() .. "/Library/Logs/WorkspaceSnapshot"

M.ghostty_claude_registry_file  = M.app_support_root .. "/ghostty-claude-registry.json"
M.vscode_state_dir              = M.app_support_root .. "/vscode-state"
M.history_dir                   = M.app_support_root .. "/history"
M.pending_vscode_dir  = M.caches_root .. "/pending-vscode"

-- Written continuously by the Gemini Desktop app (separate repo:
-- active-projects/gemini-desktop). Maps its open windows to URLs so we can
-- capture which Gemini windows are open and at what URL.
M.gemini_windows_json = home() .. "/Library/Application Support/GeminiDesktop/windows.json"

M.log_file            = M.logs_root .. "/spoon.log"

M.claude_projects_root = home() .. "/.claude/projects"
M.claude_sessions_root = home() .. "/.claude/sessions"

-- SHA-256 of `workspace_path` (lowercase hex), used as VSCode workspace key.
-- Uses `hs.hash.SHA256` when running in Hammerspoon; falls back to `shasum`
-- for standalone test contexts.
function M.workspace_hash(workspace_path)
  if hs and hs.hash and hs.hash.SHA256 then
    return hs.hash.SHA256(workspace_path):lower()
  end
  -- Standalone fallback (tests). Use a temp file to avoid any shell quoting
  -- pitfalls — `%q` doesn't escape $ or backticks, so naively interpolating
  -- workspace_path into a shell command can execute arbitrary substitutions.
  local tmp = os.tmpname()
  local fout = assert(io.open(tmp, "w"))
  fout:write(workspace_path)
  fout:close()
  local p = io.popen("shasum -a 256 < " .. tmp .. " | cut -d' ' -f1")
  local h = p:read("*a"):gsub("%s+$", "")
  p:close()
  os.remove(tmp)
  return h
end

function M.vscode_state_file_for(workspace_path)
  return M.vscode_state_dir .. "/" .. M.workspace_hash(workspace_path) .. ".json"
end

function M.pending_vscode_file_for(workspace_path)
  return M.pending_vscode_dir .. "/" .. M.workspace_hash(workspace_path) .. ".json"
end

return M
