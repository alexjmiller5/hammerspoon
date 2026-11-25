-- Plain Lua or Hammerspoon, with effects replaced at the system boundary.
local root = assert(arg and arg[1] or hs.configdir)
local profile = "work"
local capturedScript
local settings, messages, callback, scans = {}, {}, nil, 0
local responseOK, response = true, {{{12, 34, '[{"rule":"cli","status":"success"}]'}}, 0}
local fake = {
 settings = { get = function(k) return settings[k] end, set = function(k,v) settings[k]=v end },
 logger = { new = function() return { i=function(s) messages[#messages+1]=s end, w=function(s) messages[#messages+1]=s end } end },
 configdir = root,
 application = { get = function() return {} end },
 json = { encode = function() return "[]" end, decode = function(s)
   if s == '[{"rule":"cli","status":"success"}]' then return {{rule="cli",status="success"}} end
   error("bad JSON")
 end },
 timer = { doEvery = function(_, fn) callback=fn; return {stop=function() callback=nil end} end },
 osascript = { applescript = function(script) capturedScript=script; scans=scans+1; return responseOK, response end },
}
local env = setmetatable({hs=fake, require=function(name)
 if name=="profiles.work.constants" then return {appBundleIds={browser="com.google.Chrome"}} end
 if name=="activeProfile" then return {name=profile} end
 error(name)
end}, {__index=_G})
local fn
if _VERSION=="Lua 5.1" then fn=assert(loadfile(root.."/profiles/work/transientTabs.lua"));setfenv(fn,env)
else fn=assert(loadfile(root.."/profiles/work/transientTabs.lua","t",env)) end
local observer=fn()
observer.start()
assert(scans==0 and callback==nil, "unconfigured observer must not inspect tabs")
local rules={{id="cli",host="localhost",pathPrefix="/",contains={"Signed in"}}}
observer.configure(rules)
assert(callback and scans==1, "configured work observer must start")
assert(observer.observations[1].rule=="cli" and observer.observations[1].tab==34)
callback()
assert(#messages==1, "unchanged observations should not flood logs")
response={ {}, 3 }; callback(); assert(observer.unavailableTabs==3 and #observer.observations==0, "unavailable tabs must not be successes")
responseOK=false;response="PRIVATE callback URL"
callback()
assert(#observer.observations==0, "failed scans must clear stale results")
for _,line in ipairs(messages) do assert(not line:find("PRIVATE",1,true),"errors must not expose data") end
for _,bad in ipairs({
 {{id="bad",host="*.example.com",pathPrefix="/",contains={}}},
 {{id="bad",host="example.com",pathPrefix="login",contains={}}},
 {{id="bad",host="example.com",pathPrefix="/",contains={""}}},
 {{id="bad",host="example.com",pathPrefix="/",contains="Success"}},
 {{id="bad\nlog",host="example.com",pathPrefix="/",contains={}}},
}) do assert(not pcall(observer.configure,bad), "invalid rule accepted") end
observer.configure({})
assert(callback==nil and #observer.observations==0, "clearing rules must stop observation")
profile="personal"
observer.configure(rules)
assert(callback==nil, "personal profile must never start observation")
print("Transient tab observer: lifecycle, redaction, validation passed")

-- Optional native syntax check; compiles the real emitted envelope without running it.
if arg and arg[2] == "--compile" then
  local path = os.tmpname()
  local file = assert(io.open(path, "w")); file:write(capturedScript); file:close()
  local function shellQuote(value) return "'" .. value:gsub("'", "'\\''") .. "'" end
  local ok = os.execute("/usr/bin/osacompile -o " .. shellQuote(path .. ".scpt") .. " " .. shellQuote(path))
  os.remove(path); os.remove(path .. ".scpt")
  assert(ok == true or ok == 0, "emitted AppleScript must compile")
  print("Transient tab AppleScript syntax passed")
end
