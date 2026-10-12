-- Run: hs -c 'print(pcall(dofile, hs.configdir .. "/scripts/test-chrome-sidebar-button.lua"))'
-- findChromeSidebarButton against fake AX trees. Chrome 155 appends the
-- shortcut to the tab-strip button's title: "Collapse Tabs (⇧⌘L)".
local helpers = require("helperFunctions")

local function element(attributes, children)
  attributes.AXChildren = children
  return { attributeValue = function(_, name) return attributes[name] end }
end

local function find(node)
  local window = element({ AXRole = "AXWindow" }, { element({ AXRole = "AXGroup" }, { node }) })
  return helpers.findChromeSidebarButton(window, 0)
end

for _, title in ipairs({ "Collapse Tabs (⇧⌘L)", "Expand Tabs (⇧⌘L)", "Collapse tabs", "Expand tabs" }) do
  local button = element({ AXRole = "AXButton", AXTitle = title })
  assert(find(button) == button, title)
end
local described = element({ AXRole = "AXButton", AXDescription = "Expand Tabs (⇧⌘L)" })
assert(find(described) == described, "description only")
assert(find(element({ AXRole = "AXButton", AXTitle = "New tab" })) == nil, "other button")
assert(find(element({ AXRole = "AXStaticText", AXTitle = "Collapse Tabs" })) == nil, "not a button")
return "ok"
