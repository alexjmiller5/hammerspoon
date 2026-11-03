-- Isolated Lua dispatch, AppleScript envelope and collision checks; no browser actions.
local root = hs.configdir
local function loadProfile(profile, workBrowser)
  local calls, frontID, reply = {}, 'com.google.Chrome', true
  local fake = {
    configdir=root,logger=hs.logger,
    application={frontmostApplication=function() return {bundleID=function() return frontID end} end},
    osascript={applescript=function(script) calls.script=script;return true,reply end},
    eventtap={keyStroke=function() calls.keys=true end},timer={doAfter=function() end},
  }
  local cache = {activeProfile={name=profile,require=function() return {appBundleIds={browser=workBrowser}} end}}
  local env=setmetatable({hs=fake},{__index=_G})
  env.require=function(name)
    if not cache[name] then cache[name]=assert(loadfile(root..'/'..name:gsub('%.','/')..'.lua','t',env))() end
    return cache[name]
  end
  local helpers=env.require('helperFunctions')
  local defs=env.require('appBasedHotkeys').definitions
  cache['profiles.personal.constants']={appBundleIds={}}
  cache['profiles.work.constants']={appBundleIds={browser=workBrowser}}
  cache['profiles.work.browser']={frontTitle=function() return '' end,js=function() return nil end}
  local extra=env.require('profiles.'..profile..'.appBasedHotkeys').definitions
  for _,def in ipairs(extra) do defs[#defs+1]=def end
  local function find(id)
    local found={}
    for _,d in ipairs(defs) do
      if d.key=='\\' and table.concat(d.mods,'+')=='cmd+shift' then
        for _,bundle in ipairs(d.only or {}) do if bundle==id then found[#found+1]=d.action end end
      end
    end
    return found
  end
  return helpers,find,calls,function(id) frontID=id end,function(value) reply=value end
end
local helpers,find,calls,setFront,setReply=loadProfile('personal','io.island.Island')
assert(#find('com.google.Chrome')==1,'one Chrome Cmd+Shift+backslash binding required')
assert(#find('io.island.Island')==1,'one Island Cmd+Shift+backslash binding required')
assert(#find('com.apple.finder')==0,'do not claim non-browser shortcuts')
assert(helpers.browserJS and helpers.toggleVerdictSidebar,'reuse shared in-process JavaScript helpers')
find('com.google.Chrome')[1]()
assert(calls.script and calls.script:find('tell application id "com.google.Chrome"',1,true),'target active browser by bundle ID')
assert(not calls.keys,'must click the DOM button, never type the shortcut recursively')
setFront('io.island.Island');calls.script=nil
find('io.island.Island')[1]()
assert(calls.script:find('tell application id "io.island.Island"',1,true),'Island uses the same JS path')
setFront('com.apple.finder');calls.script=nil
assert(helpers.toggleVerdictSidebar('com.google.Chrome')==false and not calls.script,'focus race must not target another app')
setFront('com.google.Chrome');setReply(false)
assert(helpers.toggleVerdictSidebar('com.google.Chrome')==false,'non-Verdict/missing-control false stays false')
setReply(nil)
assert(helpers.toggleVerdictSidebar('com.google.Chrome')==false,'AppleScript failure is a safe no-op')
local _,workFind,workCalls,workFront=loadProfile('work','io.island.Island')
assert(#workFind('io.island.Island')==1 and #workFind('com.google.Chrome')==0,'work dispatcher alone owns its existing chord')
workFront('io.island.Island'); workFind('io.island.Island')[1](); assert(workCalls.script and not workCalls.keys,'Verdict must consume work dispatch without fallback keystrokes')
local _,customFind=loadProfile('work','com.google.Chrome')
assert(#customFind('com.google.Chrome')==1 and #customFind('io.island.Island')==0,'configured Chrome work browser has no duplicate binding')
local captured
helpers.browserJS=function(_,code) captured=code;return true end
assert(helpers.toggleVerdictSidebar('com.google.Chrome')==true)
assert(captured,'DOM test payload must come from the real helper')
print('verdict-sidebar: dispatch, focus guard, false/error and browser collision checks passed')
return captured
