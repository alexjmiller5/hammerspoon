-- Synthetic mail only; no account access, clipboard writes or keystrokes.
local root = hs.configdir
local function run(copyExpected)
  local requests, events, response = {}, {}, {}
  local fake = {
    json = { decode = function() return response end },
    pasteboard = { setContents = function(code) events[#events+1] = "copy:"..code; return true end },
    eventtap = {
      keyStrokes = function(code) events[#events+1] = "type:"..code end,
      keyStroke = function() events[#events+1] = "return" end,
    },
    alert = { show = function() end }, timer = { doAfter = function() end },
  }
  local helpers = {
    runTask = function(_, args, cb) requests[#requests+1] = args; cb(0, "{}") end,
    reportError = function() end,
  }
  local otp = { lookbackSeconds = 60, pickOtp = function(s) return s and s:match("%d%d%d%d%d%d") end }
  local env = setmetatable({hs=fake, os={getenv=os.getenv,time=function() return 2000000000 end},
    require=function(name)
      if name=="helperFunctions" then return helpers end
      if name=="profiles.personal.otp" then return otp end
      error(name)
    end}, {__index=_G})
  local mail = assert(loadfile(root.."/profiles/personal/otpMail.lua","t",env))()
  response = {{id="synthetic",subject="Verification code 654321"}}
  mail.pasteLatest()
  assert(requests[1][2] == "messages" and requests[1][3] == "search", "search messages, not stale thread heads")
  if copyExpected then
    assert(table.concat(events,",")=="copy:654321,type:654321,return", "copy OTP before typing and Return")
  else
    assert(requests[1][4]:find("after:1999999940",1,true), "search must use Messages 60-second window")
  end
end
run(false)
run(true)
print("otp-mail: requested behavior passed")
