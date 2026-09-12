-- Run: hs -c 'print(pcall(dofile, hs.configdir .. "/scripts/test-global-actions.lua"))'
-- Real actions/helpers; only filesystem, clipboard, process and window APIs are fake.
local calls, errors, files, menuWorks, window = {}, {}, {}, false, nil
local configdir = "/fixture config"
local profile = { paths = { desktopFolder = "/desktop", documentsFolder = "/documents", applicationsFolder = "/applications" } }
local fakeHs = {
  configdir = configdir,
  logger = { new = function() return { e = function(message) errors[#errors + 1] = message end } end },
  alert = { show = function() end },
  fs = { attributes = function(path) return files[path] end },
  pasteboard = { getContents = function() calls.clipboard = true; return "-n café" end },
  task = { new = function(path, callback, args)
    calls.task = { path = path, args = args, callback = callback }
    return { setInput = function(_, text) calls.input = text end, start = function(self) return self end }
  end },
  application = { frontmostApplication = function()
    return { selectMenuItem = function(_, path) calls.menu = path; return menuWorks end }
  end },
  window = { focusedWindow = function() return window end },
  eventtap = { keyStroke = function(mods, key) calls.stroke = { mods = mods, key = key } end },
  execute = function() error("blocking shell execution") end,
}
local env = setmetatable({
  hs = fakeHs,
  io = { open = function(path) return files[path] and { close = function() end } or nil end },
}, { __index = _G })
local cache = { activeProfile = { require = function() return profile end } }
env.require = function(name)
  if not cache[name] then
    cache[name] = assert(loadfile(hs.configdir .. "/" .. name .. ".lua", "t", env))()
  end
  return cache[name]
end
local constants = env.require("constants")
local definitions = env.require("globalHotkeys").definitions
local function action(mods, key)
  for _, definition in ipairs(definitions) do
    if table.concat(definition.mods, "+") == mods and definition.key == key then return definition.action end
  end
  error("missing binding")
end
local function executable(path) files[path] = { mode = "file", permissions = "rwxr-xr-x" } end
local function reset() calls, errors = {}, {} end
local failed = 0
local function check(name, fn)
  reset()
  local ok, err = pcall(fn)
  print((ok and "PASS " or "FAIL ") .. name .. (ok and "" or ": " .. tostring(err)))
  if not ok then failed = failed + 1 end
end
check("missing script cannot read clipboard or start a process", function()
  executable(constants.paths.chrome)
  action("alt+shift", "b")()
  assert(not calls.clipboard and not calls.task and #errors > 0)
  files[constants.paths.chrome] = nil
end)
check("Chrome launcher rejects a missing executable", function()
  action("alt", "b")()
  assert(not calls.task and #errors == 1)
end)
check("folder launch rejects missing directories", function()
  executable("/usr/bin/open")
  for _, key in ipairs({ "d", "e", "a" }) do
    reset(); action("alt+shift", key)()
    assert(not calls.task and #errors == 1)
  end
end)
check("existing folder is passed as one argument", function()
  profile.paths.desktopFolder = "/folder with spaces;literal"
  files[profile.paths.desktopFolder] = { mode = "directory" }
  executable("/usr/bin/open")
  action("alt+shift", "d")()
  assert(calls.task.path == "/usr/bin/open" and #calls.task.args == 1 and calls.task.args[1] == profile.paths.desktopFolder)
end)
check("clipboard content goes through stdin with explicit mode and browser", function()
  assert(constants.paths.searchClipboard and constants.paths.chrome and constants.paths.python)
  assert(constants.paths.searchClipboard:sub(1, #configdir) == configdir, "script must follow hs.configdir")
  files[constants.paths.searchClipboard] = { mode = "file", permissions = "rw-r--r--" }
  executable(constants.paths.chrome); executable(constants.paths.python)
  for key, mode in pairs({ b = "window", i = "incognito" }) do
    reset(); action("alt+shift", key)()
    assert(calls.task.path == constants.paths.python and calls.input == "-n café")
    assert(table.concat(calls.task.args, "|") == table.concat({constants.paths.searchClipboard, "--mode", mode, "--browser", constants.paths.chrome}, "|"))
  end
end)
check("missing Python does not start a process", function()
  files[constants.paths.python] = nil
  action("alt+shift", "b")()
  assert(not calls.task and #errors == 1)
end)
check("centering calls the native window operation and tolerates no window", function()
  local centered = false
  window = { centerOnScreen = function() centered = true end }
  action("cmd+shift", "/")()
  assert(centered)
  window = nil
  action("cmd+shift", "/")()
end)
check("native window menu prevents geometry fallback", function()
  window = { moveToUnit = function() error("native menu should handle placement") end }
  menuWorks = true
  action(table.concat(constants.hyperKeyMods, "+"), "left")()
  assert(calls.menu and not calls.task)
end)
check("window and desktop bindings use native APIs without external tools", function()
  menuWorks = false
  window = { moveToUnit = function(_, rect) calls.unit = rect end }
  action(table.concat(constants.hyperKeyMods, "+"), "left")()
  assert(not calls.task and calls.unit.x == 0 and calls.unit.w == 0.5)
  reset(); action("ctrl+alt+shift", "right")()
  assert(not calls.task and table.concat(calls.stroke.mods, "+") == "ctrl+fn" and calls.stroke.key == "right")
end)
assert(failed == 0, failed .. " global action checks failed")
print("global-actions: all checks passed")
