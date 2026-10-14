-- Isolated Accessibility/events: no live windows or input.
local timers, subscriptions, filterWindows, mouse, tap, display = {}, {}, {}, false
local screen = {x=0,y=34,w=1470,h=922}
local target = "<session>"
local function window(title, bundle)
  local w = {titleValue=title, bundle=bundle or "com.apple.ScreenSharing",
    rect={x=20,y=77,w=1200,h=879}, visible=true, standard=true, fullscreen=false, moves=0, ident=1}
  function w:id() return self.ident end
  function w:title() return self.titleValue end
  function w:application() return {bundleID=function() return self.bundle end} end
  function w:isStandard() return self.standard end
  function w:isVisible() return self.visible end
  function w:isFullScreen() return self.fullscreen end
  function w:screen() return {frame=function() return screen end} end
  function w:frame() return {x=self.rect.x,y=self.rect.y,w=self.rect.w,h=self.rect.h} end
  function w:setTopLeft(p)
    self.moves=self.moves+1
    if not self.refuse then self.rect.x,self.rect.y=p.x,p.y end
    if self.raw then self.raw.callback(self,"moved") end
  end
  function w:newWatcher(callback)
    self.raw={callback=callback,start=function(s) s.active=true; return s end,
      stop=function(s) s.active=false; return s end}
    return self.raw
  end
  return w
end
local wf={windowAllowed="allowed",windowFocused="focused",windowTitleChanged="title",
  windowOnScreen="onScreen",windowRejected="rejected",windowDestroyed="destroyed"}
function wf.new()
  return {setAppFilter=function(s) return s end,
    subscribe=function(s,events,callback)
      if type(events)=="string" then events={events} end
      for _,e in ipairs(events) do subscriptions[e]=callback end
      return s
    end,
    getWindows=function() return filterWindows end,
    unsubscribeAll=function() subscriptions={} end,
    pause=function(s) s.paused=true end}
end
local fakeHs={
  settings={get=function() return target end},
  application={nameForBundleID=function() return "Screen Sharing" end},
  window={filter=wf},
  uielement={watcher={windowMoved="moved",windowResized="resized",elementDestroyed="destroyed"}},
  timer={doAfter=function(delay,callback)
    assert(delay==0.1,"corrections must use a short one-shot debounce")
    local t={callback=callback,active=true,stop=function(s) s.active=false end}
    timers[#timers+1]=t; return t
  end},
  screen={watcher={new=function(callback)
    display={callback=callback,start=function(s) s.active=true; return s end,
      stop=function(s) s.active=false end}; return display
  end}},
  eventtap={checkMouseButtons=function() return {left=mouse} end,
    event={types={leftMouseUp=2}},
    new=function(_,callback)
      tap={callback=callback,start=function(s) s.active=true; return s end,
        stop=function(s) s.active=false; return s end}; return tap
    end},
  logger={new=function() return {w=function() end} end},
}
local env=setmetatable({hs=fakeHs},{__index=_G})
local chunk=assert(loadfile(hs.configdir.."/profiles/personal/screenSharingPlacement.lua","t",env),
  "Screen Sharing placement module must exist")
local placement=chunk()
local function flush()
  local batch=timers; timers={}
  for _,t in ipairs(batch) do if t.active then t.active=false; t.callback() end end
end
local w=window("<session> – Locked")
filterWindows={w}
local controller=placement.start()
flush()
assert(w.rect.y==42 and w.rect.x==20 and w.rect.w==1200 and w.rect.h==879,
  "initial placement must pin only the vertical coordinate")
local moves=w.moves; flush(); assert(w.moves==moves,"self-generated move must settle")
w.rect.x=70; w.rect.y=70
w.raw.callback(w,"moved"); w.raw.callback(w,"resized"); flush()
assert(w.rect.y==42 and w.rect.x==70 and w.moves==moves+1,"coalesce raw move and resize events")
mouse=true; w.rect.y=77; w.raw.callback(w,"moved"); flush()
assert(w.rect.y==77 and tap.active,"never reposition while dragging")
mouse=false; assert(tap.callback()==false,"release must pass through"); flush()
assert(w.rect.y==42 and not tap.active,"pin after release and stop the temporary tap")
w.fullscreen=true; w.rect.y=0; w.raw.callback(w,"resized"); flush()
assert(w.rect.y==0,"fullscreen must remain untouched")
w.fullscreen=false; w.rect.y=77; subscriptions.focused(w); flush()
assert(w.rect.y==42,"restore placement after fullscreen")
for _,other in ipairs({window("<another-session>"),window("<session>","other.app")}) do
  subscriptions.allowed(other); flush()
  assert(other.moves==0 and not other.raw,"other sessions and apps must stay untouched")
end
w.titleValue="<session> extra"; w.rect.y=77; w.raw.callback(w,"moved"); flush()
assert(w.rect.y==77,"session title matching needs a boundary")
w.titleValue="<session>"; w.standard=false; subscriptions.focused(w); flush()
assert(w.rect.y==77,"dialogs must stay untouched")
w.standard=true; w.visible=false; subscriptions.focused(w); flush()
assert(w.rect.y==77,"hidden windows must stay untouched")
w.visible=true; screen={x=-1600,y=80,w=1600,h=1000}; display.callback(); flush()
assert(w.rect.y==88 and w.rect.x==70,"display changes must use the current display origin")
w.refuse=true; w.rect.y=120; w.raw.callback(w,"moved"); flush()
moves=w.moves; flush(); flush()
assert(w.moves==moves,"a refused position must not create a retry loop")
w.refuse=false; w.rect.y=130; w.raw.callback(w,"moved"); flush()
assert(w.rect.y==88,"later user movement must recover after a refused placement")
mouse=true; w.rect.y=140; w.raw.callback(w,"moved"); flush()
assert(tap.active)
subscriptions.destroyed(w)
assert(not w.raw.active and not tap.active,"destroy must release observers and drag tap")
mouse=false; flush(); assert(w.rect.y==140,"destroyed window must not be moved")
w.ident=2; filterWindows={w}; subscriptions.allowed(w); w.rect.y=150
controller:stop(); flush()
assert(not w.raw.active and not display.active and controller.filter.paused,"stop must release all watchers")
assert(w.rect.y==150,"stop must cancel pending corrections")
target=nil; filterWindows={window("<session>")}; placement.start(); flush()
assert(filterWindows[1].moves==0,"no target configured must be a no-op")
print("screen-sharing-placement: geometry, events, drag, exclusions, refusal and cleanup passed")
