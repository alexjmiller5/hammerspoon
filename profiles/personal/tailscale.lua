local helpers = require("helperFunctions")
local M = {}
-- Retain tasks and the operation watchdog until completion.
local pending
local executable = os.getenv("HAMMERSPOON_TAILSCALE_BIN") or "/Applications/Tailscale.app/Contents/MacOS/Tailscale"

local function finish(operation)
  if pending ~= operation then return false end
  if operation.timer then operation.timer:stop() end
  pending = nil
  return true
end

function M.toggle()
  if pending then return end
  local operation = {}
  pending = operation
  operation.timer = hs.timer.doAfter(30, function()
    if not finish(operation) then return end
    if operation.task then operation.task:terminate() end
    helpers.reportError("Tailscale toggle timed out. Check the Tailscale app.")
  end)
  operation.task = helpers.runTask(executable, { "status", "--json" }, function(code, output)
    if pending ~= operation then return true end
    if code ~= 0 then finish(operation); return end
    local ok, status = pcall(hs.json.decode, output)
    local state = ok and type(status) == "table" and status.BackendState
    local command = state == "Running" and "down" or state == "Stopped" and "up"
    if not command then
      finish(operation)
      helpers.reportError(state == "NeedsLogin" and "Sign in through the Tailscale app before toggling."
        or "Tailscale is not ready to toggle. Check its app status.")
      return
    end
    -- Plain up preserves the enrolled client's preferences; no reset or new login.
    operation.task = helpers.runTask(executable, { command }, function(result)
      if not finish(operation) then return true end
      if result == 0 then
        hs.alert.show(command == "up" and "Tailscale connected" or "Tailscale disconnected")
      end
    end)
  end)
end

return M
