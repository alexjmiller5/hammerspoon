local helpers = require("helperFunctions")
local M = {}
local binary = "/etc/profiles/per-user/" .. os.getenv("USER") .. "/bin/herdr-native"

function M.run(action, continuation)
  if M.pending then
    helpers.reportError("Checking the connection. No additional action queued.")
    return
  end
  local request = {}
  M.pending = request
  local function finish(ok, message)
    if M.pending ~= request then return end
    M.pending = nil
    if request.timer then request.timer:stop() end
    if ok then continuation() else helpers.reportError(message) end
  end
  request.timer = hs.timer.doAfter(1.5, function()
    finish(false, "Herdr connection check timed out. Action cancelled; try Cmd+Shift+R.")
    -- Only the read-only probe is terminated, never a create/close operation.
    if request.task then request.task:terminate() end
  end)
  request.task = helpers.runTask(binary, { "check-connection", "--action", action }, function(code, _, err)
    finish(code == 0, err ~= "" and err:gsub("%s+$", "") or "Connection unavailable. Action cancelled.")
    return true
  end)
end

return M
