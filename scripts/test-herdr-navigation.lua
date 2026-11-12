-- Test the actual native-app definitions without changing focus.
local calls = {}
local failNext = false
local helpers = setmetatable({ runTask = function(path, args, callback)
  calls[#calls + 1] = { path = path, args = args }
  if failNext then failNext=false; callback(1,"","mod unavailable") end
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
assert(calls[1].path == "/etc/profiles/per-user/" .. os.getenv("USER") .. "/bin/herdr-app" and calls[1].args[2] == "compact-terminals-bar.next")
assert(calls[2].args[2] == "compact-terminals-bar.previous")
print("Native Herdr navigation bindings passed")

for _, expected in ipairs({ { "w", { "cmd" }, "compact-terminals-bar.close" }, { "t", { "cmd", "shift" }, "reopen" }, { "]", { "cmd" }, "pane-next" }, { "[", { "cmd" }, "pane-previous" }, { "r", { "cmd", "shift" }, "reconnect" } }) do
  local matched = 0
  for _, def in ipairs(definitions) do
    if def.key == expected[1] and table.concat(def.mods,"+") == table.concat(expected[2],"+")
      and def.only and def.only[1] == "dev.herdr.app" then
      matched = matched + 1
      def.action()
      assert((calls[#calls].args[2] or calls[#calls].args[1]) == expected[3])
    end
  end
  assert(matched == 1, "Native close/restore binding missing")
end
print("Native close/restore bindings passed")

for _, def in ipairs(definitions) do
  if def.key == "]" and table.concat(def.mods,"+") == "cmd+shift" and def.only and def.only[1] == "dev.herdr.app" then
    failNext=true
    def.action()
    assert(calls[#calls].path:match("/bin/herdr%-navigate$"))
    assert(calls[#calls].args[1] == "next")
  end
end
for _, call in ipairs(calls) do assert(call.path ~= "/bin/zsh", "Hotkeys must not launch login shells") end
print("Native fast dispatch and other-layout fallback passed")
