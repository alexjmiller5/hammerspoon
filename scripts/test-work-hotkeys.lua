-- Run: hs -c 'print(pcall(dofile, hs.configdir .. "/scripts/test-work-hotkeys.lua"))'
-- Load the real definitions in isolation; fake only macOS side effects.
local calls, bindings, title, jsResult, undoCode, slackCode = {}, {}, "", nil, nil, nil
local chromeApp = {}
local frontmost = chromeApp
local fakeHs = {
  configdir = hs.configdir,
  logger = hs.logger,
  application = {
    get = function() return chromeApp end,
    frontmostApplication = function() return frontmost end,
    launchOrFocusByBundleID = function(id) calls.launch = id end,
  },
  urlevent = { openURL = function(url) calls.url = url end },
  task = { new = function(path, _, args)
    return { start = function() calls.task = { path = path, args = args } end }
  end },
  osascript = { applescript = function(script) calls.script = script; return true, "" end },
  eventtap = { keyStroke = function(mods, key, _, app) calls.stroke = { mods = mods, key = key, app = app } end },
  timer = { doAfter = function(_, fn) fn() end },
  hotkey = { bind = function(mods, key, action)
    local sorted = { table.unpack(mods) }; table.sort(sorted)
    bindings[table.concat(sorted, "+") .. ":" .. key] = action
  end },
}
function chromeApp:allWindows() return {} end
function chromeApp:bundleID() return "com.google.Chrome" end
local cache = {
  ["activeProfile"] = { require = function()
    return { appBundleIds = { gemini = "com.example.gemini-pwa" }, paths = {} }
  end },
  ["profiles.work.chrome"] = {
    frontTitle = function() return title end,
    js = function(code) calls.js = code; return jsResult end,
  },
}
local env = setmetatable({ hs = fakeHs, AppBasedHotkeyRegistry = {} }, { __index = _G })
env.require = function(name)
  if not cache[name] then
    cache[name] = assert(loadfile(hs.configdir .. "/" .. name:gsub("%.", "/") .. ".lua", "t", env))()
  end
  return cache[name]
end
local helpers = env.require("helperFunctions")
helpers.bindGlobalHotkeys(env.require("globalHotkeys").definitions)
helpers.bindGlobalHotkeys(env.require("profiles.work.globalHotkeys").definitions)
local failed = 0
local function check(name, fn)
  calls = {}
  local ok, err = pcall(fn)
  print((ok and "PASS " or "FAIL ") .. name .. (ok and "" or ": " .. tostring(err)))
  if not ok then failed = failed + 1 end
end
check("Option+A opens Apple Notes on work", function()
  assert(bindings["alt:a"], "missing Option+A")()
  assert(calls.launch == "com.apple.Notes")
end)
check("Option+B requests a new Chrome window on work", function()
  assert(bindings["alt:b"], "missing Option+B")()
  assert(calls.task and calls.task.args[1] == "--new-window")
end)
check("Option+G launches the configured work PWA even with no windows", function()
  bindings["alt:g"]()
  assert(calls.launch == "com.example.gemini-pwa" and not calls.url,
    "work Gemini must not use the personal desktop app's URL scheme")
end)

local appDefs = env.require("profiles.work.appBasedHotkeys").definitions
local function action(mods, key)
  for _, def in ipairs(appDefs) do
    if table.concat(def.mods, "+") == mods and def.key == key
      and def.only[1] == "com.google.Chrome" then return def.action end
  end
  error("missing Chrome binding " .. mods .. "+" .. key)
end
check("Slack sidebar clicks its page control without triggering Chrome hotkeys", function()
  title = "general - Example - Slack"
  action("cmd+shift", "\\")()
  assert(calls.js and not calls.stroke)
  slackCode = calls.js
end)
check("Confluence sidebar keeps its existing shortcut", function()
  title = "Page - Confluence"
  action("cmd+shift", "\\")()
  assert(calls.stroke and calls.stroke.key == "[")
end)
check("Gmail U consumes only a successful Undo click", function()
  title, jsResult = "Inbox - Gmail", true
  action("", "u")()
  assert(calls.js and not calls.stroke)
  undoCode = calls.js
end)
check("Gmail U types normally when Undo is unavailable or editing", function()
  for _, result in ipairs({ false, "" }) do
    calls, jsResult = {}, result
    action("", "u")()
    assert(calls.stroke and calls.stroke.key == "u")
  end
  calls, jsResult = {}, nil
  action("", "u")()
  assert(calls.stroke and calls.stroke.key == "u")
end)
check("U on other websites passes through without injecting JS", function()
  title = "Example"
  action("", "u")()
  assert(not calls.js and calls.stroke and calls.stroke.key == "u")
end)
check("pass-through does not enable Chrome bindings after focus leaves Chrome", function()
  local enabled = false
  env.AppBasedHotkeyRegistry["com.google.Chrome"] = {
    only = {{ disable = function() end, enable = function() enabled = true end }}, except = {},
  }
  frontmost = { bundleID = function() return "com.apple.Notes" end }
  action("", "u")()
  assert(not enabled, "Chrome bindings leaked into another app")
end)

-- Loading the personal profile must keep its windowless Gemini behavior.
cache["profiles.personal.otp"], cache["profiles.personal.otpMail"] = {}, {}
helpers.bindGlobalHotkeys(env.require("profiles.personal.globalHotkeys").definitions)
check("personal Gemini still opens its resident desktop app window", function()
  bindings["alt:g"]()
  assert(calls.url == "geminiapp://open" and not calls.launch)
end)
assert(failed == 0, failed .. " work hotkey checks failed")
print("work-hotkeys: all checks passed")
return undoCode, slackCode
