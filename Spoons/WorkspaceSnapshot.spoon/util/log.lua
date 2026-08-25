-- Wraps hs.logger so the rest of the code uses a single import.
-- Also tees logs to a file under ~/Library/Logs/WorkspaceSnapshot/
-- for post-hoc inspection.
local paths = require("util.paths")

local M = {}

local function ensure_log_dir()
  os.execute("mkdir -p " .. ("%q"):format(paths.logs_root))
end

function M.new(name)
  if not hs or not hs.logger then
    -- Standalone Lua: no-op logger so tests don't blow up.
    return setmetatable({}, { __index = function() return function() end end })
  end
  ensure_log_dir()
  local logger = hs.logger.new(name, "info")

  -- Also append to file. Cheap implementation: re-open per write.
  local function file_log(level, ...)
    local f = io.open(paths.log_file, "a")
    if not f then return end
    local args = {...}
    local parts = {}
    for i = 1, #args do parts[i] = tostring(args[i]) end
    f:write(string.format("[%s] %s [%s] %s\n",
      os.date("%Y-%m-%dT%H:%M:%S"), level:upper(), name, table.concat(parts, " ")))
    f:close()
  end

  -- hs.logger's methods are dot-defined (not colon-defined): they take a
  -- variadic message list, NOT self. Calling logger[level](logger, ...) would
  -- print the logger table as the first arg ("table: 0x...") before the
  -- actual message. So just forward args directly without prepending self.
  local wrapped = {}
  for _, level in ipairs({"d", "i", "w", "e", "f"}) do
    wrapped[level] = function(...)
      logger[level](...)
      file_log(level, ...)
    end
  end
  return wrapped
end

return M
