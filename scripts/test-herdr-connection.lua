local callbacks, timers, alerts = {}, {}, {}
local terminated = false
local helpers = { runTask = function(path,args,callback)
  assert(path:match("/bin/herdr%-native$"))
  assert(args[1]=="check-connection")
  callbacks[#callbacks+1]=callback
  return {terminate=function() terminated=true end}
end,reportError=function(message) alerts[#alerts+1]=message end }
local fakeHs={timer={doAfter=function(seconds,callback)
  assert(seconds==1.5)
  local timer={callback=callback,stop=function() end}
  timers[#timers+1]=timer
  return timer
end}}
local env=setmetatable({hs=fakeHs,require=function(name) if name=="helperFunctions" then return helpers end return require(name) end},{__index=_G})
local guard=assert(loadfile(hs.configdir .. "/herdrConnection.lua","t",env))()
local acted=0
local function action() acted=acted+1 end
guard.run("new",action)
assert(acted==0,"Do not mutate before the read-only check")
callbacks[1](1,"","mini is disconnected")
assert(acted==0 and alerts[#alerts]:match("disconnected"))
guard.run("close",action)
callbacks[2](0,"","")
assert(acted==1)
guard.run("new",action)
guard.run("new",action)
assert(#callbacks==3,"Repeated keys must not queue mutations")
timers[3].callback()
assert(terminated and acted==1)
callbacks[3](0,"","")
assert(acted==1,"A late successful response must not fire a cancelled key")
guard.run("reopen",action)
callbacks[4](0,"","")
assert(acted==2,"A new key works after timeout")
print("Connection guard: offline, healthy, timeout, repeated and late keys passed")
