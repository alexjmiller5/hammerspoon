local M = {}
local paths = require("util.paths")
local log = require("util.log").new("history")

-- Save the snapshot text to ~/Library/Application Support/WorkspaceSnapshot/history/
-- so an accidentally-overwritten clipboard can be recovered.
function M.save(text)
  os.execute('mkdir -p "' .. paths.history_dir .. '"')
  local timestamp = os.date("!%Y-%m-%dT%H-%M-%SZ")
  local path = paths.history_dir .. "/" .. timestamp .. ".txt"
  local f, err = io.open(path, "w")
  if not f then log.w("history save failed: " .. tostring(err)); return nil end
  f:write(text)
  f:close()
  return path
end

return M
