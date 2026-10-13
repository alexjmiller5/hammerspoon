-- Fake hs only; never shows a dialog or contacts the mini. Runs through the hs
-- CLI or plain `lua scripts/test-op-unlock.lua` from the repo root.
local now, prompts, answers, timers, tasks = 0, 0, {}, {}, {}
local fakeHs = {
  logger = { new = function() return { i = function() end, e = function() end } end },
  fs = { mkdir = function() end },
  pathwatcher = { new = function() return { start = function(self) return self end } end },
  timer = {
    doAfter = function(_, fn) timers[#timers + 1] = fn end,
    secondsSinceEpoch = function() return now end,
  },
  application = { launchOrFocus = function() end },
  dialog = {
    textPrompt = function()
      prompts = prompts + 1
      local a = table.remove(answers, 1)
      return a[1], a[2]
    end,
  },
  task = {
    new = function(_, callback)
      local t = { callback = callback, setInput = function() end, start = function() end }
      tasks[#tasks + 1] = t
      return t
    end,
  },
  alert = { show = function() end },
}
local env = setmetatable({ hs = fakeHs }, { __index = _G })
local dir = (rawget(_G, "hs") and hs.configdir) or "."
local opUnlock = assert(loadfile(dir .. "/opUnlock.lua", "t", env))()

local function runTimers()
  local pending = timers
  timers = {}
  for _, fn in ipairs(pending) do fn() end
end
local function ask(answer)
  if answer then answers[#answers + 1] = answer end
  opUnlock.request("an agent needs Personal")
  runTimers()
end

-- Two agents ask before the first prompt is up: one prompt.
answers[#answers + 1] = { "Unlock", "pw" }
opUnlock.request("agent one")
opUnlock.request("agent two")
runTimers()
assert(prompts == 1, "concurrent requests show one prompt, got " .. prompts)
assert(#tasks == 1, "Unlock sends the password to the mini once")

ask()
assert(prompts == 1, "a request while the mini is signing in is covered by that unlock")

tasks[1].callback(0, "unlocked for 24h", "")
ask({ "Cancel", "" })
assert(prompts == 2, "after the mini answers, a new request prompts again")

ask({ "Unlock", "pw" })
assert(prompts == 3, "a cancelled prompt does not block the next request")

now = now + 120
ask({ "Cancel", "" })
assert(prompts == 4, "a mini that never answers stops blocking prompts after its timeout")

print("op-unlock: one prompt per unlock, cancel and timeout checks passed")
