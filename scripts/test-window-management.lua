-- Isolated window and input fixtures: never move a live window or change Spaces.
local calls, focused, menuWorks = {}, nil, false
local screen = { x = 100, y = 50, w = 1200, h = 800 }
local frame = { x = 400, y = 250, w = 600, h = 400 }
local window = {
  centerOnScreen = function() calls.center = true end,
  moveToUnit = function(_, rect) calls.unit = rect end,
  screen = function() return { frame = function() return screen end } end,
  frame = function() return { x = frame.x, y = frame.y, w = frame.w, h = frame.h } end,
  setFrame = function(_, rect) calls.frame = rect end,
}
local env = setmetatable({
  hs = {
    window = { focusedWindow = function() return focused end },
    eventtap = { keyStroke = function(mods, key, delay) calls.stroke = {mods, key, delay} end },
  },
  require = function(name)
    assert(name == "helperFunctions")
    return { tryMenuItem = function(path) calls.menu = path; return menuWorks end }
  end,
}, { __index = _G })
local wm = assert(loadfile(hs.configdir .. "/windowManagement.lua", "t", env))()
for _, name in ipairs({"left", "right", "maximize", "bottom", "topLeft", "bottomLeft", "topRight", "bottomRight"}) do
  wm.place(name)
end
wm.center(); wm.resize(0.05)
assert(next(calls) == nil, "no focused window must be a no-op")
focused = window
for name, expected in pairs({
  left = {0,0,0.5,1}, right = {0.5,0,0.5,1}, maximize = {0,0,1,1}, bottom = {0,0.5,1,0.5},
  topLeft = {0,0,0.5,0.5}, bottomLeft = {0,0.5,0.5,0.5},
  topRight = {0.5,0,0.5,0.5}, bottomRight = {0.5,0.5,0.5,0.5},
}) do
  calls = {}; wm.place(name)
  local rect = assert(calls.unit, "missing geometry fallback for " .. name)
  assert(rect.x == expected[1] and rect.y == expected[2] and rect.w == expected[3] and rect.h == expected[4], name)
  menuWorks = true; calls = {}; wm.place(name)
  assert(calls.menu and not calls.unit, "native menu must take priority")
  menuWorks = false
end
calls = {}; wm.center(); assert(calls.center)
calls = {}; wm.resize(0.05)
assert(calls.frame.x == 370 and calls.frame.y == 230 and calls.frame.w == 660 and calls.frame.h == 440,
  "grow around the center by five percent of usable screen size")
calls = {}; wm.resize(-0.05)
assert(calls.frame.x == 430 and calls.frame.y == 270 and calls.frame.w == 540 and calls.frame.h == 360)
frame = { x = 100, y = 50, w = 1200, h = 800 }
calls = {}; wm.resize(0.05)
assert(calls.frame.x == 100 and calls.frame.y == 50 and calls.frame.w == 1200 and calls.frame.h == 800)
frame = { x = 100, y = 50, w = 1, h = 1 }
calls = {}; wm.resize(-0.05)
assert(calls.frame.w >= 1 and calls.frame.h >= 1, "shrinking must keep positive dimensions")
for _, direction in ipairs({"left", "right"}) do
  calls = {}; wm.desktop(direction)
  assert(table.concat(calls.stroke[1], "+") == "ctrl+fn" and calls.stroke[2] == direction and calls.stroke[3] == 0,
    "desktop navigation must use native Control-arrow with the physical arrow Function flag")
end
print("window-management: placement, resizing, empty-window and native desktop checks passed")
