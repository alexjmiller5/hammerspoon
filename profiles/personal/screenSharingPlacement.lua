local M = {}
local setting = "screenSharingPlacement.title"
local bundleID = "com.apple.ScreenSharing"

function M.start()
  local title = hs.settings.get(setting)
  if type(title) ~= "string" or title == "" then return end
  local wf, ax = hs.window.filter, hs.uielement.watcher
  local log = hs.logger.new("Sharing Placement", "warning")
  local watched, pending = {}, {}
  local controller = {}
  local release, queue

  local function matches(win)
    if not win or not win:isStandard() or not win:isVisible() or win:isFullScreen() then return false end
    local app, current = win:application(), win:title() or ""
    return app and app:bundleID() == bundleID
      and (current == title or current:sub(1, #title + #" – ") == title .. " – ")
  end

  local function remove(id)
    local entry = watched[id]
    if entry then
      if entry.timer then entry.timer:stop() end
      entry.watcher:stop()
    end
    watched[id], pending[id] = nil, nil
    if not next(pending) and release then release:stop() end
  end

  local function signature(frame, top)
    return table.concat({frame.x, frame.y, frame.w, frame.h, top}, ":")
  end

  local function correct(entry)
    entry.timer = nil
    local ok, err = pcall(function()
      if not matches(entry.win) then remove(entry.id); return end
      if hs.eventtap.checkMouseButtons().left then release:start(); return end
      pending[entry.id] = nil
      local frame = entry.win:frame()
      local top = entry.win:screen():frame().y + 8
      if math.abs(frame.y - top) <= 1 or entry.settled == signature(frame, top) then return end
      entry.win:setTopLeft({x = frame.x, y = top})
      -- Remember the actual result so an app refusing the position cannot loop.
      entry.settled = signature(entry.win:frame(), top)
    end)
    if not ok then
      remove(entry.id)
      log.w("Could not position Screen Sharing: " .. tostring(err))
    end
  end

  queue = function(entry)
    if entry.timer then entry.timer:stop() end
    pending[entry.id] = entry
    entry.timer = hs.timer.doAfter(0.1, function() correct(entry) end)
  end

  -- Only listen for release while a pending correction encountered a held mouse.
  release = hs.eventtap.new({hs.eventtap.event.types.leftMouseUp}, function()
    release:stop()
    for _, entry in pairs(pending) do queue(entry) end
    return false
  end)

  local function track(win)
    local ok, id = pcall(function() return win and win:id() end)
    if not ok or not id then return end
    if not matches(win) then remove(id); return end
    local entry = watched[id]
    if not entry then
      entry = {id = id, win = win}
      entry.watcher = win:newWatcher(function(_, event)
        if event == ax.elementDestroyed then remove(id) else queue(entry) end
      end)
      entry.watcher:start({ax.windowMoved, ax.windowResized, ax.elementDestroyed})
      watched[id] = entry
    end
    queue(entry)
  end

  controller.filter = wf.new(false):setAppFilter(
    hs.application.nameForBundleID(bundleID) or "Screen Sharing",
    {currentSpace = true, fullscreen = false, allowRoles = "AXStandardWindow"})
  controller.filter:subscribe(
    {wf.windowAllowed, wf.windowFocused, wf.windowTitleChanged, wf.windowOnScreen}, track)
  controller.filter:subscribe({wf.windowRejected, wf.windowDestroyed}, function(win)
    -- A destroyed Accessibility element may no longer return its window ID.
    for id, entry in pairs(watched) do
      if entry.win == win then remove(id) end
    end
  end)

  local function refresh()
    for _, win in ipairs(controller.filter:getWindows()) do track(win) end
  end
  controller.screen = hs.screen.watcher.new(refresh):start()

  function controller:stop()
    self.filter:unsubscribeAll()
    self.filter:pause()
    self.screen:stop()
    release:stop()
    for id in pairs(watched) do remove(id) end
  end

  refresh()
  return controller
end

return M
