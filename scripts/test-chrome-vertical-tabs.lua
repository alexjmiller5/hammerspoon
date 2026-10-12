-- Run: hs -c 'print(pcall(dofile, hs.configdir .. "/scripts/test-chrome-vertical-tabs.lua"))'
-- toggleVerticalTabs picks whichever View menu item the browser shows, and
-- reports when it shows neither (vertical tabs off, or a renamed item).
local helpers = require("helperFunctions")

local realFront, realAlert = hs.application.frontmostApplication, hs.alert.show
local items, selected, alerted
local app = { selectMenuItem = function(_, path)
  if path[1] == "View" and items[path[2]] then selected = path[2]; return true end
end }
hs.application.frontmostApplication = function() return app end
hs.alert.show = function(message) alerted = message end

local ok, err = pcall(function()
  for _, case in ipairs({
    { menu = { ["Collapse Vertical Tabs"] = true }, want = "Collapse Vertical Tabs" },
    { menu = { ["Expand Vertical Tabs"] = true }, want = "Expand Vertical Tabs" },
    { menu = {} },
  }) do
    items, selected, alerted = case.menu, nil, nil
    helpers.toggleVerticalTabs()
    assert(selected == case.want, tostring(case.want))
    assert((alerted ~= nil) == (case.want == nil), "alert only when neither item exists")
  end
end)
hs.application.frontmostApplication, hs.alert.show = realFront, realAlert
assert(ok, err)
return "ok"
