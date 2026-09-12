-- Run: hs -c 'print(pcall(dofile, hs.configdir .. "/scripts/test-personal-controls.lua"))'
-- Real modules and JSON parsing; subprocesses, playback and alerts stay isolated.
local processes, errors, alerts, playback, timers = {}, {}, {}, {}, {}
local failStart = false
local fakeHs = {
  configdir = hs.configdir,
  fs = hs.fs,
  json = { decode = function(value)
    -- Match the decoder's malformed-input result without its expected console error.
    if value == "not JSON" then return nil end
    return hs.json.decode(value)
  end },
  logger = { new = function() return { e = function(s) errors[#errors + 1] = s end } end },
  alert = { show = function(s) alerts[#alerts + 1] = s end },
  eventtap = { keyStroke = function() error("controls must not synthesize foreground keystrokes") end },
  spotify = {
    next = function() playback[#playback + 1] = "next" end,
    playpause = function() playback[#playback + 1] = "playpause" end,
    previous = function() playback[#playback + 1] = "previous" end,
  },
  timer = { doAfter = function(seconds, callback)
    local timer = { seconds = seconds, callback = callback, stop = function(self) self.stopped = true end }
    timers[#timers + 1] = timer
    return timer
  end },
  task = { new = function(path, callback, args)
    local process = { path = path, callback = callback, args = args,
      start = function(self) return not failStart and self or false end,
      terminate = function(self) self.terminated = true end,
    }
    processes[#processes + 1] = process
    return process
  end },
}
local cache = {
  constants = { hyperKeyMods = { "cmd", "alt", "ctrl", "shift" } },
  ["profiles.personal.constants"] = { appBundleIds = {} },
  ["profiles.personal.otp"] = {},
  ["profiles.personal.otpMail"] = {},
}
local env = setmetatable({ hs = fakeHs, os = setmetatable({
  getenv = function(name)
    if name == "HAMMERSPOON_TAILSCALE_BIN" then return "/bin/cat" end
  end,
}, { __index = os }) }, { __index = _G })
env.require = function(name)
  if not cache[name] then
    cache[name] = assert(loadfile(hs.configdir .. "/" .. name:gsub("%.", "/") .. ".lua", "t", env))()
  end
  return cache[name]
end
local definitions = env.require("profiles.personal.globalHotkeys").definitions
local function action(mods, key)
  for _, def in ipairs(definitions) do
    if table.concat(def.mods, "+") == mods and def.key == key then return def.action end
  end
  error("missing binding " .. mods .. "+" .. key)
end
local toggle = action("cmd+alt+ctrl+shift", "t")
local function complete(code, output)
  processes[#processes].callback(code, output or "", "private process error")
end
local function status(state)
  complete(0, hs.json.encode({ BackendState = state, Self = {}, Peer = {}, Health = {} }))
end
toggle()
assert(#processes == 1 and processes[1].path == "/bin/cat", "configured CLI path must be honored")
assert(table.concat(processes[1].args, " ") == "status --json", "toggle must inspect state before acting")
assert(#timers == 1 and timers[1].seconds == 30, "status queries must have a bounded watchdog")
toggle()
assert(#processes == 1, "repeated keypress must not race an outstanding status query")
status("Running")
assert(#processes == 2 and table.concat(processes[2].args, " ") == "down", "running connection must disconnect")
toggle()
assert(#processes == 2, "repeated keypress must not race a state change")
complete(0)
assert(#alerts == 1 and alerts[1]:lower():find("disconnected"), "successful disconnect needs feedback")
toggle(); status("Stopped")
assert(table.concat(processes[#processes].args, " ") == "up", "reconnect must preserve preferences with plain up")
assert(timers[#timers].seconds == 30, "a stalled reconnect needs a bounded watchdog")
complete(0)
assert(timers[#timers].stopped, "successful reconnect must cancel its watchdog")
assert(#alerts == 2 and alerts[2]:lower():find("connected"), "successful reconnect needs feedback")
toggle(); status("Stopped")
local stalled, watchdog = processes[#processes], timers[#timers]
local priorAlerts, priorErrors = #alerts, #errors
watchdog.callback()
assert(stalled.terminated and #errors == priorErrors + 1, "watchdog must terminate only the retained reconnect process")
assert(errors[#errors]:lower():find("timed out"), "timeout feedback must describe an unconfirmed connection")
toggle()
local afterRetry = #processes
stalled.callback(0, "", "")
assert(#alerts == priorAlerts + 1 and #processes == afterRetry, "late success must not claim a timed-out operation connected")
stalled.callback(15, "", "")
assert(#errors == priorErrors + 1, "terminated reconnect must not report a second error")
status("Running"); complete(0)
for _, phase in ipairs({ "status", "down" }) do
  toggle()
  if phase == "down" then status("Running") end
  local stalledPhase, deadline = processes[#processes], timers[#timers]
  assert(not deadline.stopped, "hung " .. phase .. " must retain an active deadline")
  deadline.callback()
  assert(stalledPhase.terminated, "timeout must stop the hung " .. phase .. " process")
  local timeoutErrors = #errors
  local beforeRetry = #processes
  toggle()
  assert(#processes == beforeRetry + 1, "hung " .. phase .. " must release the repeat guard")
  stalledPhase.callback(0, hs.json.encode({ BackendState = "Running" }), "")
  assert(#processes == beforeRetry + 1, "late " .. phase .. " callback must not affect the next toggle")
  stalledPhase.callback(15, "", "")
  assert(#errors == timeoutErrors, "terminated " .. phase .. " must not report a second error")
  complete(1)
end
for _, state in ipairs({ "NeedsLogin", "NeedsMachineAuth", "Starting", "NoState", "Unexpected" }) do
  local before, priorErrors = #processes, #errors
  toggle(); status(state)
  assert(#processes == before + 1 and #errors == priorErrors + 1,
    "unready state must report a problem without changing connectivity: " .. state)
end
for _, output in ipairs({ "not JSON", "null", "{}", '"Running"' }) do
  local before, priorErrors = #processes, #errors
  toggle(); complete(0, output)
  assert(#processes == before + 1 and #errors == priorErrors + 1,
    "malformed status must fail safely and release the repeat guard")
end
local before = #processes
toggle(); complete(1)
toggle()
assert(#processes == before + 2, "status failure must release the repeat guard")
status("Running"); complete(1)
before = #processes
toggle(); complete(1)
assert(#processes == before + 1, "state-change failure must release the repeat guard")
failStart = true
before = #processes
toggle(); toggle()
assert(#processes == before + 2, "process start failure must release the repeat guard")
failStart = false
for _, s in ipairs(errors) do assert(not s:find("private"), "process errors must not leak private output") end
action("cmd+shift", "f9")()
action("cmd+shift", "f8")()
action("cmd+shift", "f7")()
assert(table.concat(playback, " ") == "next playpause previous", "media keys must target Spotify directly")
action("cmd+alt+ctrl+shift", "s")()
local shortcut = processes[#processes]
assert(shortcut.path == "/usr/bin/shortcuts" and shortcut.args[1] == "run", "Shortcut launch must remain asynchronous")
local priorErrors = #errors
complete(1)
assert(#errors == priorErrors + 1, "Shortcut failures must use the shared error-reporting runner")
print("personal-controls: all checks passed")
