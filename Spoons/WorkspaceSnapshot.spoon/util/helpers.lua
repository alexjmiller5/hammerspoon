-- Generic Hammerspoon helpers used across the Spoon.
local M = {}

-- Attempts to select a menu item on the frontmost application.
-- Returns true on success, false on failure.
-- Caller is responsible for ensuring the target app is frontmost before calling.
function M.tryMenuItem(menuPath)
  local frontApp = hs.application.frontmostApplication()
  if not frontApp then return false end

  return pcall(function()
    if not frontApp:selectMenuItem(menuPath) then
      error("Menu item not found or action failed.")
    end
  end)
end

return M
