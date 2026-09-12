-- Paste Latest OTP Code from Gmail — sibling of otp.lua (Messages).
--
-- Runs the gog CLI (1Password-backed wrapper, so expect a Touch ID prompt)
-- to search the last hour of mail for a 2FA-looking message, picks the code
-- with otp.pickOtp from the subject (or the body when the subject has none),
-- types it into the focused field and presses Return. One shot, no polling:
-- every retry would be another Touch ID prompt.
local otp = require("profiles.personal.otp")
local helpers = require("helperFunctions")

local M = {}

M.gogPath = "/etc/profiles/per-user/" .. os.getenv("USER") .. "/bin/gog"
M.query   = "newer_than:1h (code OR passcode OR verification OR OTP)"
M.maxThreads = 5

local function gog(args, cb)
  table.insert(args, "--gmail-no-send")
  helpers.runTask(M.gogPath, args, function(rc, out)
    if rc ~= 0 then return cb(nil, "Mail command unavailable") end
    local ok, value = pcall(hs.json.decode, out)
    if not ok or type(value) ~= "table" then
      helpers.reportError("Mail command returned invalid JSON")
      return cb(nil, "Invalid mail response")
    end
    cb(value)
  end)
end

-- Newest thread first: subject, then body. cb(code | nil).
local function scan(threads, i, cb)
  local t = threads[i]
  if not t then return cb(nil) end
  if type(t) ~= "table" or (t.subject ~= nil and type(t.subject) ~= "string") then
    helpers.reportError("Mail command returned invalid thread data")
    return cb(nil, "Invalid mail response")
  end
  local code = otp.pickOtp(t.subject)
  if code then return cb(code) end
  if type(t.id) ~= "string" or t.id == "" then
    helpers.reportError("Mail command returned a thread without an ID")
    return cb(nil, "Invalid mail response")
  end
  -- A thread's id is its first message's id, which is the OTP mail itself.
  gog({ "gmail", "get", t.id, "-j", "--results-only", "--sanitize-content", "--no-input" }, function(msg, err)
    if err then return cb(nil, err) end
    if msg.snippet ~= nil and type(msg.snippet) ~= "string" then
      helpers.reportError("Mail command returned invalid message data")
      return cb(nil, "Invalid mail response")
    end
    code = otp.pickOtp(msg.snippet)
    if code then return cb(code) end
    scan(threads, i + 1, cb)
  end)
end

function M.findRecentCode(cb)
  gog({ "gmail", "search", M.query, "--max", tostring(M.maxThreads), "-j", "--results-only", "--no-input" },
    function(threads, err)
      if err then return cb(nil, err) end
      if next(threads) ~= nil and threads[1] == nil then
        helpers.reportError("Mail command returned an invalid thread list")
        return cb(nil, "Invalid mail response")
      end
      scan(threads, 1, cb)
    end)
end

function M.pasteLatest()
  M.findRecentCode(function(code, err)
    if err then return end
    if code then
      hs.eventtap.keyStrokes(code)
      hs.eventtap.keyStroke({}, "return")
    else
      hs.alert.show("No OTP code found in mail")
    end
  end)
end

return M
