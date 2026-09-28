-- Run: hs -c 'print(pcall(dofile, hs.configdir .. "/scripts/test-work-hotkeys.lua"))'
-- Load the real definitions in isolation; fake only macOS side effects.
local calls, bindings, title, jsResult, undoCode, slackCode = {}, {}, "", nil, nil, nil
local island = "io.island.Island"
local browserApp = {}
local frontmost = browserApp
local fakeHs = {
  configdir = hs.configdir,
  logger = hs.logger,
  fs = { attributes = function(path)
    local folder = path == os.getenv("HOME") .. "/Downloads"
    return { mode = folder and "directory" or "file", permissions = "rwxr-xr-x" }
  end },
  alert = { show = function() end },
  application = {
    get = function() return browserApp end,
    frontmostApplication = function() return frontmost end,
    launchOrFocusByBundleID = function(id) calls.launch = id end,
    pathForBundleID = function(id) return "/Apps/" .. id .. ".app" end,
    infoForBundleID = function(id) return { CFBundleExecutable = "exe-" .. id } end,
  },
  urlevent = { openURL = function(url) calls.url = url end },
  task = { new = function(path, _, args)
    return { start = function(self) calls.task = { path = path, args = args }; return self end }
  end },
  osascript = { applescript = function(script) calls.script = script; return true, "" end },
  eventtap = { keyStroke = function(mods, key, _, app) calls.stroke = { mods = mods, key = key, app = app } end },
  timer = { doAfter = function(_, fn) fn() end },
  hotkey = { bind = function(mods, key, action)
    local sorted = { table.unpack(mods) }; table.sort(sorted)
    bindings[table.concat(sorted, "+") .. ":" .. key] = action
  end },
}
function browserApp:allWindows() return {} end
function browserApp:bundleID() return island end
local constants -- the real work constants, loaded below
local cache = {
  ["activeProfile"] = { require = function() return constants end },
  ["profiles.work.browser"] = {
    frontTitle = function() return title end,
    js = function(code) calls.js = code; return jsResult end,
    focusTab = function(tab) calls.tab = tab end,
    openWindow = function(url) calls.window = url end,
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
constants = env.require("profiles.work.constants")
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
check("the work browser is Island", function()
  assert(constants.appBundleIds.browser == island)
end)
check("Option+B opens a new Island window on work", function()
  assert(bindings["alt:b"], "missing Option+B")()
  assert(calls.task and calls.task.path == "/Apps/" .. island .. ".app/Contents/MacOS/exe-" .. island)
  assert(table.concat(calls.task.args, " ") == "--new-window")
end)
check("Option+I opens an Island incognito window on work", function()
  bindings["alt:i"]()
  assert(calls.task and calls.task.path:find(island, 1, true) and not calls.script)
  assert(table.concat(calls.task.args, " ") == "--incognito --new-window")
end)
check("Option+G and Option+Y focus Island tabs, not PWAs", function()
  for key, tab in pairs({ g = "gemini", y = "youtube" }) do
    calls = {}
    bindings["alt:" .. key]()
    assert(calls.tab == constants.tabs[tab] and not calls.launch, "Option+" .. key)
  end
end)
check("Option+Shift+W opens the Downloads folder in Finder on work", function()
  assert(bindings["alt+shift:w"], "missing Option+Shift+W")()
  assert(calls.task and calls.task.path == "/usr/bin/open")
  assert(#calls.task.args == 1 and calls.task.args[1] == constants.paths.downloadsFolder)
  assert(constants.paths.downloadsFolder == os.getenv("HOME") .. "/Downloads")
end)
check("Option+L opens the password manager in an Island window", function()
  bindings["alt:l"]()
  assert(calls.window == "chrome://password-manager/passwords")
end)

local appDefs = env.require("profiles.work.appBasedHotkeys").definitions
local function action(mods, key)
  for _, def in ipairs(appDefs) do
    if table.concat(def.mods, "+") == mods and def.key == key
      and def.only[1] == island then return def.action end
  end
  error("missing Island binding " .. mods .. "+" .. key)
end
check("no work or shared browser hotkey is Chrome-only", function()
  local defs = { table.unpack(appDefs) }
  for _, def in ipairs(env.require("appBasedHotkeys").definitions) do defs[#defs + 1] = def end
  for _, def in ipairs(defs) do
    local only = table.concat(def.only or {}, ",")
    assert(only ~= "com.google.Chrome", "Chrome-only binding " .. table.concat(def.mods, "+") .. "+" .. def.key)
  end
end)
check("Slack sidebar clicks its page control without triggering browser hotkeys", function()
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
check("pass-through does not enable browser bindings after focus leaves Island", function()
  local enabled = false
  env.AppBasedHotkeyRegistry[island] = {
    only = {{ disable = function() end, enable = function() enabled = true end }}, except = {},
  }
  frontmost = { bundleID = function() return "com.apple.Notes" end }
  action("", "u")()
  assert(not enabled, "Island bindings leaked into another app")
end)

-- Each profile loads independently, including the shared definitions.
bindings = {}
cache["profiles.personal.otp"], cache["profiles.personal.otpMail"] = {}, {}
cache["activeProfile"] = { require = function() return env.require("profiles.personal.constants") end }
cache["globalHotkeys"] = nil
helpers.bindGlobalHotkeys(env.require("globalHotkeys").definitions)
helpers.bindGlobalHotkeys(env.require("profiles.personal.globalHotkeys").definitions)
check("personal Option+B still opens Chrome", function()
  calls = {}
  bindings["alt:b"]()
  assert(calls.task and calls.task.path:find("com.google.Chrome", 1, true))
end)
check("personal Option+G is unbound", function()
  assert(not bindings["alt:g"], "personal Option+G still launches Gemini")
end)
check("personal app hotkeys have no Gemini target or empty app scope", function()
  for _, def in ipairs(env.require("appBasedHotkeys").definitions) do
    assert(not def.only or #def.only > 0, "empty app scope")
    for _, id in ipairs(def.only or {}) do
      assert(id ~= "com.alexmiller.geminidesktop", "desktop Gemini still has app hotkeys")
    end
  end
end)
assert(failed == 0, failed .. " work hotkey checks failed")
print("work-hotkeys: all checks passed")
return undoCode, slackCode
