local M = {}
local paths = require("util.paths")
local log = require("util.log").new("vscode")

-- Extract the workspace identifier from a VSCode title.
-- VSCode title patterns:
--   "<filename> — <workspace-folder>"                   (em dash U+2014; single-folder workspace)
--   "<filename> — <workspace-folder> (Workspace)"      (multi-root .code-workspace file)
-- Returns the workspace identifier with the "(Workspace)" suffix STRIPPED, so
-- matchers compare against the base name regardless of single/multi-root.
function M.workspace_from_title(title)
  if type(title) ~= "string" then return "" end
  local _, _, ws = title:find("— (.+)$")
  ws = ws or title
  -- Strip the multi-root suffix " (Workspace)" if present.
  ws = ws:gsub(" %(Workspace%)%s*$", "")
  return ws
end

-- Read the state file for a specific workspace (or one passed by path for tests).
function M.read_state_file(path)
  local f = io.open(path, "r")
  if not f then return nil, "vscode state file not found at " .. path end
  local content = f:read("*a")
  f:close()
  if hs and hs.json then
    local ok, parsed = pcall(hs.json.decode, content)
    if not ok then return nil, "JSON parse error" end
    return parsed
  else
    local json = require("tests.minijson")
    return json.decode(content)
  end
end

-- Compare a state-file's workspacePath against the title-derived workspace name.
-- Matches if either:
--   - workspacePath ends with "/<name>"               (single-folder workspace)
--   - workspacePath ends with "/<name>.code-workspace" (multi-root .code-workspace file)
--   - basename(workspacePath without .code-workspace) == name
local function workspace_matches(workspace_path, name)
  if type(workspace_path) ~= "string" or type(name) ~= "string" then return false end
  if workspace_path:match("/" .. name .. "$") then return true end
  if workspace_path:match("/" .. name .. "%.code%-workspace$") then return true end
  -- Last-resort basename match for either .code-workspace or folder.
  local base = workspace_path:match("([^/]+)$") or ""
  base = base:gsub("%.code%-workspace$", "")
  return base == name
end

-- Search vscode-state/ for a file matching the given workspace name.
-- Workspaces are hashed by absolute path on disk; we scan and pick whichever
-- state file's workspacePath matches the title-derived name.
function M.find_state_file_for_workspace(workspace_name, state_dir)
  state_dir = state_dir or paths.vscode_state_dir
  local p = io.popen('ls "' .. state_dir .. '"/*.json 2>/dev/null')
  if not p then return nil end
  for file in p:lines() do
    local data = M.read_state_file(file)
    if data and workspace_matches(data.workspacePath, workspace_name) then
      p:close()
      return file
    end
  end
  p:close()
  return nil
end

-- Capture snapshot entries for VSCode windows.
-- `mac_windows`: list of { id, title, bundleId }
-- Returns: list of { workspace = string, terminals = { {cwd, sessionId}, ... } }
function M.capture(mac_windows)
  local entries = {}
  for _, w in ipairs(mac_windows) do
    if w.bundleId == "com.microsoft.VSCode" then
      local ws_name = M.workspace_from_title(w.title)
      if ws_name == "" then
        log.i("skipping VSCode no-folder window id=" .. w.id)
      else
        local state_file = M.find_state_file_for_workspace(ws_name)
        if state_file then
          local data = M.read_state_file(state_file)
          if data and data.workspacePath then
            local terminals = {}
            for _, t in ipairs(data.terminals or {}) do
              table.insert(terminals, { cwd = t.cwd, sessionId = t.claudeSessionId })
            end
            table.insert(entries, { workspace = data.workspacePath, terminals = terminals })
          end
        else
          log.w("no vscode-state file found for workspace " .. ws_name)
          -- Still capture the workspace name as a best-effort.
          -- Title-derived workspace path isn't absolute; we'd need user help to resolve.
          -- Skip for now; the extension's state file is authoritative.
        end
      end
    end
  end
  return entries
end

-- Write the pending restore spec then trigger VSCode to open the workspace.
-- Plan C's extension picks up the pending file and spawns terminals.
function M.launch(workspace_path, terminals)
  -- Ensure pending dir exists.
  os.execute('mkdir -p "' .. paths.pending_vscode_dir .. '"')

  local pending_file = paths.pending_vscode_file_for(workspace_path)
  local terminal_specs = {}
  for _, t in ipairs(terminals or {}) do
    local cmd = ""
    if t.sessionId then cmd = "claude --resume " .. t.sessionId end
    table.insert(terminal_specs, { cwd = t.cwd, initialCommand = cmd })
  end

  local payload = {
    schemaVersion = 1,
    createdAt = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
    workspacePath = workspace_path,
    terminals = terminal_specs,
  }
  local f = assert(io.open(pending_file, "w"))
  f:write(hs.json.encode(payload))
  f:close()
  log.i("wrote pending spec: " .. pending_file)

  -- Trigger VSCode to open the workspace via deeplink. Use hs.urlevent.openURL
  -- rather than shelling out to `open`: hs.execute with a login shell returns
  -- rc=1 for scheme URLs (the login-shell env breaks LaunchServices
  -- resolution), so the open silently failed and VSCode never launched.
  local url = "vscode://file/" .. workspace_path .. "?windowId=_blank"
  local ok = hs.urlevent.openURL(url)
  if not ok then
    log.w("openURL failed for " .. url)
    return false, "openURL failed"
  end
  return true
end

return M
