-- Paste Latest OTP Code from Gmail — sibling of otp.lua (Messages).
--
-- Runs the gog CLI (1Password-backed wrapper, so expect a Touch ID prompt)
-- to search the last hour of mail for a 2FA-looking message, picks the code
-- with otp.pickOtp from the subject (or the body when the subject has none),
-- types it into the focused field and presses Return. One shot, no polling:
-- every retry would be another Touch ID prompt.
local otp = require("profiles.personal.otp")
local log = hs.logger.new("OTPMail", "info")

local M = {}

M.gogPath = "/etc/profiles/per-user/" .. os.getenv("USER") .. "/bin/gog"
M.query   = "newer_than:1h (code OR passcode OR verification OR OTP)"
M.maxThreads = 5

local function gog(args, cb)
  local task = hs.task.new(M.gogPath, function(rc, out, err)
    if rc ~= 0 then log.e("gog exit " .. rc .. ": " .. (err or "")) end
    cb(rc == 0 and hs.json.decode(out) or nil)
  end, args)
  task:start()
end

-- Newest thread first: subject, then body. cb(code | nil).
local function scan(threads, i, cb)
  local t = threads[i]
  if not t then return cb(nil) end
  local code = otp.pickOtp(t.subject)
  if code then return cb(code) end
  -- A thread's id is its first message's id, which is the OTP mail itself.
  gog({ "gmail", "get", t.id, "-j", "--results-only", "--sanitize-content", "--no-input" }, function(msg)
    code = msg and otp.pickOtp(msg.snippet)
    if code then return cb(code) end
    scan(threads, i + 1, cb)
  end)
end

function M.findRecentCode(cb)
  gog({ "gmail", "search", M.query, "--max", tostring(M.maxThreads), "-j", "--results-only", "--no-input" },
    function(threads) scan(threads or {}, 1, cb) end)
end

function M.pasteLatest()
  M.findRecentCode(function(code)
    if code then
      hs.eventtap.keyStrokes(code)
      hs.eventtap.keyStroke({}, "return")
    else
      hs.alert.show("No OTP code found in mail")
    end
  end)
end

return M
