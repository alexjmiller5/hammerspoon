-- Unlock 1Password on the mini from this laptop. The mini asks over ssh
-- (`hs -c 'opUnlock.request("<reason>")'`, from `op-unlock request`); this
-- shows a secure prompt, then runs `op-unlock --stdin <hours>` on the mini
-- with the password on stdin. The password lives in this process, the ssh
-- channel and the mini's `op signin`; it is never written anywhere.
local M = {}
local log = hs.logger.new("opUnlock", "info")
M.host = "mac-mini-tailscale"
M.hours = 6

local function trim(s) return (tostring(s or ""):gsub("%s+$", "")) end

local function unlock(password)
  local task = hs.task.new("/usr/bin/ssh", function(code, out, err)
    if code == 0 then
      hs.alert.show("mini " .. trim(out))
    else
      hs.alert.show("mini unlock failed: " .. trim(err ~= "" and err or out), 4)
      log.e(trim(err))
    end
  end, { "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", M.host, "op-unlock", "--stdin", tostring(M.hours) })
  task:start()
  task:setInput(password .. "\n")
  task:closeInput()
end

function M.request(reason)
  -- Deferred so the `hs -c` caller returns before the dialog blocks.
  hs.timer.doAfter(0, function()
    hs.application.launchOrFocus("Hammerspoon")
    local button, password = hs.dialog.textPrompt(
      "Unlock 1Password on the mini",
      (reason or "an agent asked") .. "\n\nAccount password; memory only, " .. M.hours .. "h window.",
      "", "Unlock", "Cancel", true)
    if button == "Unlock" and password ~= "" then unlock(password) end
  end)
  return "queued"
end

return M
