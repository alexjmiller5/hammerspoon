-- Isolated callbacks: never activate apps, read live tabs, or send to Receptor.
local calls, windows, space, appleOK, appleResult = {}, {}, 42, true, "https://example.com/?a=1&b=2"
local app = { allWindows = function() return windows end, bundleID = function() return "com.google.Chrome" end }
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
  if name == "profiles.personal.otp" or name == "profiles.personal.otpMail"
      or name == "profiles.personal.tailscale" then return {} end
  return assert(loadfile(hs.configdir .. "/" .. name:gsub("%.", "/") .. ".lua", "t", env))()
end
local defs = env.require("profiles.personal.appBasedHotkeys").definitions
local bound = {}
fakeHs.hotkey = {
  new = function(mods, key, action)
    local binding = { mods = mods, key = key, action = action,
      enable = function(self) self.enabled = true; return self end,
      disable = function(self) self.enabled = false; return self end }
    bound[#bound + 1] = binding
    return binding
  end,
}
fakeHs.hotkey.bind = function(...) return fakeHs.hotkey.new(...):enable() end
local registration = assert(loadfile(hs.configdir .. "/helperFunctions.lua", "t", env))()
local registry = {}
registration.registerAppBasedHotkeys(registry, defs)
registration.bindGlobalHotkeys(env.require("profiles.personal.globalHotkeys").definitions)
-- Reproduce Chrome being focused with no windows using the real scope logic.
registration.updateActiveAppHotkeys(app, registry, nil)
local function focus()
  for _, binding in ipairs(bound) do
    if binding.enabled and binding.key == "b"
        and table.concat(binding.mods, "+") == "cmd+alt+ctrl+shift" then
      return binding.action()
    end
  end
  error("Hyper+B is disabled while Chrome is focused")
end
local function action(key, scope)
  for _, def in ipairs(defs) do
    if def.key == key and def[scope] and def[scope][1] == "com.google.Chrome" then return def.action end
  end
  error("missing action: " .. key)
end
local send = action("s", "only")
local function window(id)
  return { id = function() return id end, isStandard = function() return true end,
    isMinimized = function() return false end, focus = function() calls.focus = id end }
end
createdWindow = window(3)
focus()
assert(calls.script and calls.focus == 3, "focused Chrome with no windows must create and focus one")
calls, windows = {}, { window(1), window(2) }
focus()
assert(calls.focus == 2 and not calls.script, "must focus only a Chrome window on the current Space")
calls, windows, createdSpace = {}, { window(1) }, 99
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
