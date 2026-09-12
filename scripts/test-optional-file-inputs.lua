-- Isolated fixtures only: never opens the real Messages database or runs gog.
-- Run: hs -c 'print(pcall(dofile, hs.configdir .. "/scripts/test-optional-file-inputs.lua"))'
local root = hs.configdir
local errors, stopped, opened, closed, timerCallback, tasks = {}, 0, 0, 0, nil, {}
local readMode, body, databaseMode, response = "missing", nil, "missing", nil
local helpers = {
  reportError = function(message) errors[#errors + 1] = message end,
  requirePath = function(path)
    if path:find("/profiles/", 1, true) then
      if path:find("/unknown/", 1, true) or path:find("/unreadable/", 1, true)
          or path:find("/partial/init.lua", 1, true) then
        errors[#errors + 1] = "Unavailable profile file"; return nil
      end
      return path
    end
    if databaseMode == "missing" then errors[#errors + 1] = "Unavailable path"; return nil end
    return path
  end,
  runTask = function(path, args, callback)
    tasks[#tasks + 1] = { path = path, args = args }
    callback(response.rc or 0, response.out or "", "PRIVATE STDERR")
  end,
}
local fakeHs = {
  configdir = root,
  logger = { new = function() return { e = function(message) errors[#errors + 1] = message end } end },
  alert = { show = function(message) errors[#errors + 1] = message end },
  timer = {
    secondsSinceEpoch = function() return 1000 end,
    doEvery = function(_, callback)
      timerCallback = callback
      return { stop = function() stopped = stopped + 1 end }
    end,
  },
  eventtap = {
    keyStrokes = function() error("a failure must never type into an app") end,
    keyStroke = function() error("a failure must never type into an app") end,
  },
  sqlite3 = {
    OPEN_READONLY = 1,
    OK = 0,
    open = function(_, flags)
      opened = opened + 1
      assert(flags == 1, "the database must be opened read-only")
      if databaseMode == "missing" then error("missing database must not be opened") end
      if databaseMode == "throw" then error("PRIVATE SQLITE ERROR") end
      if databaseMode == "open" then return nil end
      return {
        nrows = function()
          if databaseMode == "query" then error("PRIVATE SQLITE ERROR") end
          return function() return nil end
        end,
        close = function()
          closed = closed + 1
          return databaseMode == "close" and 5 or 0
        end,
      }
    end,
  },
  json = { decode = function()
    if response.decodeError then error("PRIVATE JSON CONTENT") end
    return response.decoded
  end },
}
local fakeIo = {
  open = function()
    if readMode == "missing" then return nil, "absent", 2 end
    if readMode == "denied" then return nil, "unreadable", 13 end
    return {
      read = function()
        if readMode == "read-error" then return nil, "cannot read", 21 end
        return body
      end,
      close = function() end,
    }
  end,
}
local modules = { helperFunctions = helpers }
local env = setmetatable({ hs = fakeHs, io = fakeIo,
  require = function(name) return assert(modules[name], "unexpected require: " .. name) end,
  dofile = function() error("optional config must be read through the fixture") end,
}, { __index = _G })
local function readModule(path)
  return assert(loadfile(root .. "/" .. path .. ".lua", "t", env))()
end
local function reset() errors = {}; stopped = 0; opened = 0; closed = 0 end

for _, path in ipairs({ "activeProfile", "profiles/work/constants" }) do
  readMode = "missing"; reset()
  local value = readModule(path)
  assert(#errors == 0, "absent optional config must be quiet: " .. path)
  if path == "activeProfile" then assert(value.name == "personal") end
  for _, mode in ipairs({ "denied", "read-error", "invalid" }) do
    reset(); readMode = mode; body = path == "activeProfile" and "../wrong" or "this is not lua"
    value = readModule(path)
    assert(#errors == 1, "bad optional config must report once: " .. path .. " " .. mode)
    if path == "activeProfile" then assert(value.name == "personal") end
  end
end
readMode = "valid"; body = "work"; reset()
assert(readModule("activeProfile").name == "work", "valid profile must load")
body = "custom_profile-1"
assert(readModule("activeProfile").name == body, "readable custom profiles remain supported")
for _, profile in ipairs({ "unknown", "unreadable", "partial" }) do
  body = profile; reset()
  assert(readModule("activeProfile").name == "personal" and #errors == 1,
    "unavailable selected profile must fall back and report once: " .. profile)
end
body = "return { tabs = { jira = { match = 'example.invalid', url = '' } } }"
assert(readModule("profiles/work/constants").tabs.jira.match == "example.invalid", "valid overrides must merge")
for _, contents in ipairs({ "return 42", "error('PRIVATE CONFIG CONTENT')" }) do
  body = contents; reset(); readModule("profiles/work/constants")
  assert(#errors == 1 and not errors[1]:find("PRIVATE", 1, true), "invalid config must fail safely")
end

local otp = readModule("profiles/personal/otp")
modules["profiles.personal.otp"] = otp
otp.selfCheck()
for _, mode in ipairs({ "missing", "throw", "open", "query", "close" }) do
  reset(); databaseMode = mode
  otp.pasteLatest()
  assert(stopped >= 1 and #errors == 1, "database failure must stop polling and report once: " .. mode)
  if mode == "missing" then assert(opened == 0, "missing path must fail before SQLite") end
  if mode == "query" then assert(closed == 1, "query failure must close database") end
  assert(not errors[1]:find("PRIVATE", 1, true), "database diagnostics must not expose message content")
end
databaseMode = "empty"; reset()
local code, err = otp.findRecentCode()
assert(not code and not err and closed == 1 and #errors == 0, "empty results are not an error")

-- Real SQLite fixture checks the native iterator and read-only database API.
local path = os.tmpname()
local db = assert(hs.sqlite3.open(path))
assert(db:exec("CREATE TABLE message (text, attributedBody, is_from_me, date)") == hs.sqlite3.OK)
local date = (os.time() - 978307200) * 1000000000
assert(db:exec(string.format("INSERT INTO message VALUES ('Code: 482913', NULL, 0, %d)", date)) == hs.sqlite3.OK)
assert(db:close() == hs.sqlite3.OK)
local sqliteStub = fakeHs.sqlite3
fakeHs.sqlite3 = hs.sqlite3
otp.dbPath = path
local fixtureOk, fixtureError = pcall(function()
  reset(); local found, reason = otp.findRecentCode()
  assert(found == "482913" and not reason and #errors == 0, "native SQLite must return the fixture OTP")
  local writer = assert(hs.sqlite3.open(path))
  assert(writer:exec("DROP TABLE message") == hs.sqlite3.OK)
  assert(writer:close() == hs.sqlite3.OK)
  reset(); found, reason = otp.findRecentCode()
  assert(not found and reason and #errors == 1, "native schema failure must return cleanly")
end)
fakeHs.sqlite3 = sqliteStub
assert(os.remove(path))
assert(fixtureOk, fixtureError)

local mail = readModule("profiles/personal/otpMail")
for _, fixture in ipairs({ { rc = -1 }, { decodeError = true }, { decoded = 42 }, { decoded = { 42 } } }) do
  reset(); response = fixture
  local called, failure = 0, nil
  mail.findRecentCode(function(found, reason) called = called + 1; assert(not found); failure = reason end)
  assert(called == 1 and failure, "unavailable gog or malformed response must fail cleanly")
  for _, message in ipairs(errors) do assert(not message:find("PRIVATE", 1, true), "mail errors must not expose response content") end
end
response = { decoded = { { subject = "Your code is 123456" } } }; reset()
mail.findRecentCode(function(found, reason) assert(found == "123456" and not reason) end)
response = { decoded = {} }; reset()
mail.findRecentCode(function(found, reason) assert(not found and not reason) end)
for _, task in ipairs(tasks) do
  assert(table.concat(task.args, " "):find("%-%-gmail%-no%-send"), "gog must be read-only")
end
print("optional-file-inputs: all checks passed")
