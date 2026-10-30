-- Test the actual native-app definitions without changing focus.
local calls = {}
local helpers = setmetatable({ runTask = function(path, args)
  calls[#calls + 1] = { path = path, args = args }
end }, { __index = require("helperFunctions") })
local env = setmetatable({ require = function(name)
  if name == "helperFunctions" then return helpers end
  return require(name)
end }, { __index = _G })
local definitions = assert(loadfile(hs.configdir .. "/appBasedHotkeys.lua", "t", env))().definitions
for _, key in ipairs({ "]", "[" }) do
  local count = 0
  for _, def in ipairs(definitions) do
    if def.key == key and #def.mods == 2 and def.mods[1] == "cmd" and def.mods[2] == "shift"
      and def.only and def.only[1] == "dev.herdr.app" then
      count = count + 1
      def.action()
    end
  end
  assert(count == 1, "Native Herdr must have one global navigation binding for " .. key)
end
assert(calls[1].path == "/bin/zsh" and calls[1].args[2] == "herdr-navigate next")
assert(calls[2].args[2] == "herdr-navigate previous")
print("Native Herdr navigation bindings passed")
