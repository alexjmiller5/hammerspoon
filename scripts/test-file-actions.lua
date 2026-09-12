-- Run: hs -c 'print(pcall(dofile, hs.configdir .. "/scripts/test-file-actions.lua"))'
-- Real temporary files; only sound, process, and UI side effects are replaced.
local root = os.tmpname()
os.remove(root)
assert(hs.fs.mkdir(root))
local sample = root .. "/a file.txt"
local f = assert(io.open(sample, "w")); f:write("sample"); f:close()
local calls, errors, failCreate, failStart = {}, {}, false, false
local sound
local fakeHs = {
  configdir = hs.configdir,
  fs = hs.fs,
  logger = { new = function() return { e = function(s) errors[#errors + 1] = s end } end },
  alert = { show = function() end },
  sound = { getByFile = function(path) calls.sound = path; return sound end },
  task = { new = function(path, callback, args)
    calls.task = { path = path, args = args, callback = callback }
    if failCreate then return nil end
    return {
      setInput = function(_, input) calls.input = input end,
      start = function(self) calls.started = true; return not failStart and self or false end,
    }
  end },
}
local env = setmetatable({ hs = fakeHs }, { __index = _G })
local helpers = assert(loadfile(hs.configdir .. "/helperFunctions.lua", "t", env))()
local ok, err = pcall(function()
  assert(pcall(helpers.playAudioFileByPath, nil), "invalid sound path must not crash the watcher")
  assert(#errors == 1 and not calls.sound, "invalid paths must be reported before loading audio")
  errors, calls = {}, {}
  assert(not helpers.requirePath(root .. "/missing"), "missing file must be rejected")
  assert(not helpers.requirePath(root), "a directory is not a readable file")
  assert(helpers.requirePath(root, "directory"), "existing folders must remain usable")
  assert(helpers.requirePath(sample), "a readable file with spaces must work")
  assert(not helpers.requirePath(sample, "executable"), "non-executable files must be rejected")

  calls, errors = {}, {}
  local failure
  assert(not helpers.runTask(root .. "/missing", {}, function(rc) failure = rc end))
  assert(not calls.task and failure ~= 0 and #errors == 1, "missing executable must fail without spawning")
  calls, errors = {}, {}
  assert(helpers.runTask("/bin/cat", { sample }, nil, "input"))
  assert(calls.started and calls.task.args[1] == sample and calls.input == "input")
  calls.task.callback(1, "private output", "private stderr")
  assert(#errors == 1 and not errors[1]:find("private"), "process failure must not leak output")
  calls, errors = {}, {}
  helpers.runTask("/bin/cat", {}, function() return true end)
  calls.task.callback(15, "", "")
  assert(#errors == 0, "a handled failure must not produce a duplicate alert")
  for _, kind in ipairs({ "create", "start" }) do
    calls, errors, failure = {}, {}, nil
    failCreate, failStart = kind == "create", kind == "start"
    assert(not helpers.runTask("/bin/cat", {}, function(rc) failure = rc end))
    assert(failure ~= 0 and #errors == 1, "process startup failure must be handled")
  end
  failCreate, failStart = false, false

  calls, errors = {}, {}
  helpers.playAudioFileByPath(sample)
  assert(#errors == 1, "an existing but unplayable audio file must be reported")
  calls, errors = {}, {}
  sound = {
    device = function() error("default playback must not hard-code an output device") end,
    play = function() calls.played = true; return true end,
  }
  assert(helpers.playAudioFileByPath(sample))
  assert(calls.played and #errors == 0)
  sound.play = function() return false end
  assert(not helpers.playAudioFileByPath(sample) and #errors == 1, "playback failure must be reported")
end)
os.remove(sample)
hs.fs.rmdir(root)
assert(ok, err)
print("file-actions: all checks passed")
