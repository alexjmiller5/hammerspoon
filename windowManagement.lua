local helpers = require("helperFunctions")
local M = {}

local layouts = {
  left = { "Left", 0, 0, 0.5, 1 },
  right = { "Right", 0.5, 0, 0.5, 1 },
  maximize = { "Fill", 0, 0, 1, 1 },
  bottom = { "Bottom", 0, 0.5, 1, 0.5 },
  topLeft = { "Top Left", 0, 0, 0.5, 0.5 },
  bottomLeft = { "Bottom Left", 0, 0.5, 0.5, 0.5 },
  topRight = { "Top Right", 0.5, 0, 0.5, 0.5 },
  bottomRight = { "Bottom Right", 0.5, 0.5, 0.5, 0.5 },
}

function M.place(name)
  local layout = assert(layouts[name], "Unknown window layout: " .. tostring(name))
  local win = hs.window.focusedWindow()
  if not win then return end
  local menu = name == "maximize" and { "Window", "Fill" }
    or { "Window", "Move & Resize", layout[1] }
  if not helpers.tryMenuItem(menu) then
    win:moveToUnit({ x = layout[2], y = layout[3], w = layout[4], h = layout[5] }, 0)
  end
end

function M.center()
  local win = hs.window.focusedWindow()
  if win then win:centerOnScreen() end
end

-- Grow or shrink both dimensions by a fraction of the usable screen,
-- keeping the window's center where possible and respecting screen edges.
function M.resize(delta)
  local win = hs.window.focusedWindow()
  if not win then return end
  local frame, screen = win:frame(), win:screen():frame()
  local width = math.max(1, math.min(screen.w, frame.w + screen.w * delta))
  local height = math.max(1, math.min(screen.h, frame.h + screen.h * delta))
  frame.x = math.max(screen.x, math.min(frame.x + (frame.w - width) / 2, screen.x + screen.w - width))
  frame.y = math.max(screen.y, math.min(frame.y + (frame.h - height) / 2, screen.y + screen.h - height))
  frame.w, frame.h = width, height
  win:setFrame(frame, 0)
end

function M.desktop(direction)
  assert(direction == "left" or direction == "right", "Expected left or right desktop")
  -- macOS's physical arrow events carry the Function flag. Match the native
  -- Control-arrow Spaces shortcuts without opening Mission Control.
  hs.eventtap.keyStroke({ "ctrl", "fn" }, direction, 0)
end

return M
