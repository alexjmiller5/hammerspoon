-- Run through hs: tests the actual launcher without opening an app.
local calls = {}
local env = setmetatable({ hs = { application = {
  launchOrFocusByBundleID = function(id) calls[#calls + 1] = id end,
} } }, { __index = _G })
local definitions = assert(loadfile(hs.configdir .. "/globalHotkeys.lua", "t", env))().definitions
local matched = 0
for _, def in ipairs(definitions) do
  if def.key == "h" and #def.mods == 1 and def.mods[1] == "alt" then
    matched = matched + 1
    def.action()
  end
end
assert(matched == 1, "Option+H must have exactly one launcher")
assert(calls[1] == "dev.herdr.app", "Option+H must launch Herdr")
print("Herdr launcher passed")
