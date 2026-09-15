-- Hyper = Caps Lock, natively remapped to Right Control by Nix. Carbon hotkeys
-- (hs.hotkey) match in the window server before Hammerspoon's event taps see an
-- event, so injecting flags cannot drive them; instead a modal holds every Hyper
-- binding while physical Right Control is down. Right Control is reserved for Hyper.
local M = {}

M.enabled = hs.fs.attributes(os.getenv("HOME") .. "/.config/hammerspoon/native-hyper", "mode") == "file"

local modal, pressedAt, used

-- Held Right Control already contributes Control to every key event.
function M.bind(key, action)
  modal = modal or hs.hotkey.modal.new()
  modal:bind({ "ctrl" }, key, function()
    used = true
    action()
  end)
end

function M.start()
  if not M.enabled then return nil end
  modal = modal or hs.hotkey.modal.new()
  local types, mask = hs.eventtap.event.types, hs.eventtap.event.rawFlagMasks
  M.tap = hs.eventtap.new({ types.flagsChanged }, function(event)
    if event:getKeyCode() ~= hs.keycodes.map.rightctrl then return false end
    if event:rawFlags() & mask.deviceRightControl ~= 0 then
      pressedAt, used = hs.timer.secondsSinceEpoch(), false
      modal:enter()
    else
      modal:exit()
      -- A quick unused tap keeps working as Caps Lock.
      if pressedAt and not used and hs.timer.secondsSinceEpoch() - pressedAt < 0.3 then
        hs.hid.capslock.toggle()
      end
      pressedAt = nil
    end
    return false
  end)
  return M.tap:start()
end

return M
