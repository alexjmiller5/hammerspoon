-- Paste Latest OTP Code — Hammerspoon port of the Raycast Messages
-- extension command (the only one Alex used from that extension).
--
-- Reads ~/Library/Messages/chat.db directly with hs.sqlite3 (Hammerspoon
-- needs Full Disk Access), polls for up to pollSeconds for an incoming
-- message from the last lookbackSeconds that contains a code, types the code
-- into the focused field and presses Return.
local log = hs.logger.new("OTP", "info")

local M = {}

M.pollSeconds     = 8
M.pollInterval    = 0.25
M.lookbackSeconds = 60
M.dbPath          = os.getenv("HOME") .. "/Library/Messages/chat.db"

-- Modern messages keep their text in attributedBody (a typedstream blob),
-- not the text column. The string sits right after a 0x01 0x2B marker,
-- prefixed by its byte length: one byte, or 0x81 followed by a LE uint16.
function M.decodeAttributedBody(blob)
  if not blob then return "" end
  local i = blob:find("\1+", 1, true)
  if not i then return "" end
  local j = i + 2
  local n = blob:byte(j)
  if not n then return "" end
  if n == 0x81 then
    local lo, hi = blob:byte(j + 1, j + 2)
    if not hi then return "" end
    n, j = lo + hi * 256, j + 3
  else
    j = j + 1
  end
  return blob:sub(j, j + n - 1)
end

local function isWordChar(c) return c ~= "" and c:match("[%w_]") ~= nil end

-- All matches of `pattern` (a digit-ish run) with JS-style \b on both ends:
-- returns { {code=, s=, e=}, ... } where s/e are 1-based start and end+1.
local function boundedMatches(text, pattern)
  local out = {}
  for s, code, e in text:gmatch("()(" .. pattern .. ")()") do
    if not isWordChar(text:sub(s - 1, s - 1)) and not isWordChar(text:sub(e, e)) then
      out[#out + 1] = { code = code, s = s, e = e }
    end
  end
  return out
end

-- Same heuristic as the Raycast command: candidate digit runs (plain, or
-- 123-456 style) that aren't hugging phone-number punctuation, 4-10 digits,
-- longest wins (ties → last); fall back to the first 4+ digit run.
function M.pickOtp(text)
  if not text or text == "" then return nil end
  local candidates = boundedMatches(text, "%d%d%d%d+")
  for _, m in ipairs(boundedMatches(text, "%d%d%d+%-%d%d%d+")) do candidates[#candidates + 1] = m end

  local best
  for _, m in ipairs(candidates) do
    local preceding = text:sub(math.max(1, m.s - 2), m.s - 1)
    local following = text:sub(m.e, m.e + 1)
    if not preceding:match("[()%-+./]") and not following:match("[()%-+./]") then
      local code = m.code:gsub("%-", "")
      if #code >= 4 and #code <= 10 and (not best or #code >= #best) then best = code end
    end
  end
  if best then return best end

  local fallback = boundedMatches(text, "%d%d%d%d+")[1]
  return fallback and fallback.code or nil
end

-- Newest-first scan of incoming messages from the lookback window.
function M.findRecentCode()
  local db = hs.sqlite3.open(M.dbPath, hs.sqlite3.OPEN_READONLY)
  if not db then
    log.e("cannot open " .. M.dbPath .. " (Hammerspoon needs Full Disk Access)")
    return nil
  end
  local since = (os.time() - M.lookbackSeconds - 978307200) * 1000000000
  local rows = {}
  for row in db:nrows(string.format(
    "SELECT text, attributedBody FROM message WHERE is_from_me = 0 AND date > %d ORDER BY date DESC LIMIT 50",
    since)) do
    rows[#rows + 1] = row
  end
  db:close()
  for _, row in ipairs(rows) do
    local body = (row.text and row.text ~= "") and row.text or M.decodeAttributedBody(row.attributedBody)
    local code = M.pickOtp(body)
    if code then return code end
  end
  return nil
end

local poller

function M.pasteLatest()
  if poller then poller:stop() end
  local deadline = hs.timer.secondsSinceEpoch() + M.pollSeconds
  local function attempt()
    local code = M.findRecentCode()
    if code then
      poller:stop(); poller = nil
      hs.eventtap.keyStrokes(code)
      hs.eventtap.keyStroke({}, "return")
    elseif hs.timer.secondsSinceEpoch() >= deadline then
      poller:stop(); poller = nil
      hs.alert.show("No OTP code found in " .. M.pollSeconds .. "s")
    end
  end
  poller = hs.timer.doEvery(M.pollInterval, attempt)
  attempt()
end

-- Run with: hs -c 'require("profiles.personal.otp").selfCheck()'
function M.selfCheck()
  local function blob(s) return "junk\1+" .. string.char(#s) .. s .. "\134\132tail" end
  assert(M.decodeAttributedBody(blob("Your code is 123456")) == "Your code is 123456")
  local long = string.rep("a", 300)
  assert(M.decodeAttributedBody("\1+\129" .. string.char(300 % 256, 300 // 256) .. long) == long)
  assert(M.decodeAttributedBody(nil) == "" and M.decodeAttributedBody("no marker") == "")

  assert(M.pickOtp("Your verification code is 482913") == "482913")
  assert(M.pickOtp("Code: 4829") == "4829")
  assert(M.pickOtp("Use 123-456 to sign in") == "123456")
  assert(M.pickOtp("G-728311 is your Google code") == "728311")           -- via fallback
  assert(M.pickOtp("Call (555) 123-4567 or use code 91827") == "91827")   -- phone skipped
  assert(M.pickOtp("Your code is 7391 (expires in 10 minutes)") == "7391") -- "10" too short
  assert(M.pickOtp("order 12345678901 shipped") == "12345678901")         -- >10 digits: fallback only
  assert(M.pickOtp("no digits here") == nil and M.pickOtp("") == nil)
  assert(M.pickOtp("abc1234def") == nil)                                  -- no word boundary
  print("otp selfCheck ok")
end

return M
