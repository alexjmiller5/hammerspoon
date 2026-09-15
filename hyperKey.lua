-- Hyper = Caps Lock, which Nix's hidutil mapping turns into F19. Carbon hotkeys
-- (hs.hotkey) match in the window server before Hammerspoon's event taps see an
-- event, so injecting modifier flags cannot drive them; and carrying a real
-- modifier (Control) collides with system shortcuts such as Ctrl+Up. Instead an
-- hs.hotkey.modal holds every Hyper binding as a bare key while F19 is down.
local M = {}

M.enabled = hs.fs.attributes(os.getenv("HOME") .. "/.config/hammerspoon/native-hyper", "mode") == "file"

local modal, pressedAt, used

function M.bind(key, action)
  modal = modal or hs.hotkey.modal.new()
  modal:bind({}, key, function()
    used = true
    action()
  end)
end

function M.start()
  if not M.enabled then return nil end
  modal = modal or hs.hotkey.modal.new()
  M.hotkey = hs.hotkey.bind({}, "f19", function()
    pressedAt, used = hs.timer.secondsSinceEpoch(), false
    modal:enter()
  end, function()
    modal:exit()
    -- A quick unused tap keeps working as Caps Lock.
    if pressedAt and not used and hs.timer.secondsSinceEpoch() - pressedAt < 0.3 then
      hs.hid.capslock.toggle()
    end
    pressedAt = nil
  end)
  return M.hotkey
end

return M
