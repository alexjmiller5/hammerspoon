-- Isolated callbacks: never activate apps, read live tabs, or send to Receptor.
local calls, windows, space, appleOK, appleResult = {}, {}, 42, true, "https://example.com/?a=1&b=2"
local app = { allWindows = function() return windows end }
local createdWindow, createdSpace, moveOK = nil, 99, true
local helpers = {
  reportError = function(message) calls.error = message end,
  runTask = function(path, args, callback, input)
    calls.task = { path = path, args = args, callback = callback, input = input }
  end,
}
local fakeHs = {
  configdir = hs.configdir, logger = hs.logger,
  application = {
    get = function(id) assert(id == "com.google.Chrome"); return app end,
    frontmostApplication = function() error("test must not depend on the frontmost app") end,
    launchOrFocusByBundleID = function() error("must not jump to another Space") end,
  },
  spaces = {
    focusedSpace = function() return space end,
    windowSpaces = function(id) return { id == 1 and 99 or id == 3 and createdSpace or 42 } end,
    moveWindowToSpace = function(win, target)
      calls.moved = win:id()
      if moveOK then createdSpace = target; return true end
      return nil, "cannot move"
    end,
  },
  osascript = { applescript = function(script)
    calls.script = script
    if script:find("make new window", 1, true) then windows[#windows + 1] = createdWindow end
    return appleOK, appleResult
  end },
  timer = { doAfter = function(_, callback) callback() end },
  alert = { show = function(message) calls.alert = message end },
}
local env = setmetatable({ hs = fakeHs }, { __index = _G })
env.require = function(name)
  if name == "helperFunctions" then return helpers end
  return assert(loadfile(hs.configdir .. "/" .. name:gsub("%.", "/") .. ".lua", "t", env))()
end
local defs = env.require("profiles.personal.appBasedHotkeys").definitions
local function action(key, scope)
  for _, def in ipairs(defs) do
    if def.key == key and def[scope] and def[scope][1] == "com.google.Chrome" then return def.action end
  end
  error("missing action: " .. key)
end
local focus, send = action("b", "except"), action("s", "only")
local function window(id)
  return { id = function() return id end, isStandard = function() return true end,
    isMinimized = function() return false end, focus = function() calls.focus = id end }
end
windows = { window(1), window(2) }
createdWindow = window(3)
focus()
assert(calls.focus == 2 and not calls.script, "must focus only a Chrome window on the current Space")
calls, windows = {}, { window(1) }
focus()
assert(calls.script and calls.script:find("make new window", 1, true))
assert(calls.moved == 3 and createdSpace == 42 and calls.focus == 3,
  "a window created on an assigned desktop must move before focus")
calls, windows, createdSpace, moveOK = {}, { window(1) }, 99, false
focus()
assert(calls.error and not calls.focus, "failed Space move must not focus a window on another desktop")
calls, space = {}, nil
focus()
assert(calls.error and not calls.script, "unknown Space must not jump to an arbitrary window")
calls, appleOK, appleResult = {}, true, "https://example.com/?a=1&b=2"
send()
assert(calls.task and calls.task.path == "/usr/bin/shortcuts" and calls.task.input == appleResult)
assert(not calls.alert, "success must wait for the Shortcut to finish")
calls.task.callback(0)
assert(calls.alert == "Queued in Receptor")
calls, appleOK = {}, false
send()
assert(calls.error and not calls.task, "failed URL lookup must not send stale input")
calls, appleOK, appleResult = {}, true, ""
send()
assert(calls.error and not calls.task, "empty URL must not run the Shortcut")
print("personal-app-actions: all checks passed")
