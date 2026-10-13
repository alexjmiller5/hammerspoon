-- Unlock 1Password on the mini from this laptop. The mini asks over ssh by
-- dropping the reason into ~/.local/state/op-unlock/request (`op-unlock
-- request`; an `hs -c` call from an ssh session wedges Hammerspoon's IPC
-- port, so a watched file is the transport); this shows a secure prompt,
-- then runs `op-unlock --stdin <hours>` on the mini with the password on
-- stdin. The password lives in this process, the ssh channel and the mini's
-- `op signin`; it is never written anywhere.
local M = {}
local log = hs.logger.new("opUnlock", "info")
M.host = "mac-mini-tailscale"
M.hours = 24

local function trim(s) return (tostring(s or ""):gsub("%s+$", "")) end

-- Run ssh with one line on stdin. For a non-streaming hs.task the input must
-- be set BEFORE start (set afterwards, ssh receives nothing); stdin closes by
-- itself once the data is written.
function M.sshWithInput(args, input, callback)
  local task = hs.task.new("/usr/bin/ssh", callback,
    { "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", M.host, table.unpack(args) })
  task:setInput(input)
  task:start()
  return task
end

-- One prompt at a time: requests that arrive while it is open, or while the
-- mini signs in, are covered by that unlock. A mini that never answers stops
-- blocking after `signinTimeout` seconds (its own sign-in gives up at 60).
M.signinTimeout = 90
local function now() return hs.timer.secondsSinceEpoch() end

local function unlock(password)
  M.busyUntil = now() + M.signinTimeout
  M.sshWithInput({ "op-unlock", "--stdin", tostring(M.hours) }, password .. "\n", function(code, out, err)
    M.busyUntil = nil
    if code == 0 then
      hs.alert.show("mini " .. trim(out))
    else
      hs.alert.show("mini unlock failed: " .. trim(err ~= "" and err or out), 4)
      log.e(trim(err))
    end
  end)
end

function M.request(reason)
  if M.busyUntil and now() < M.busyUntil then
    log.i("unlock already in progress; dropped request: " .. tostring(reason))
    return "busy"
  end
  M.busyUntil = math.huge -- until the prompt is answered
  -- Deferred so the watcher callback returns before the dialog blocks.
  hs.timer.doAfter(0, function()
    hs.application.launchOrFocus("Hammerspoon")
    local button, password = hs.dialog.textPrompt(
      "Unlock 1Password on the mini",
      (reason or "an agent asked") .. "\n\nAccount password; memory only, " .. M.hours .. "h window.",
      "", "Unlock", "Cancel", true)
    if button == "Unlock" and password ~= "" then unlock(password) else M.busyUntil = nil end
  end)
  return "queued"
end

-- Transport: the mini writes the reason here over ssh; the file is consumed.
local requestDir = os.getenv("HOME") .. "/.local/state/op-unlock"
local requestFile = requestDir .. "/request"
hs.fs.mkdir(requestDir)
M.watcher = hs.pathwatcher.new(requestDir, function()
  local f = io.open(requestFile, "r")
  if not f then return end
  local reason = f:read("*a")
  f:close()
  os.remove(requestFile)
  if reason and reason ~= "" then M.request(reason) end
end):start()

return M
