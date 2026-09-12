-- Isolated registration and menu dispatch; no app launch, keys, or contact edits.
local calls, available, selected = {}, true, true
local app = { selectMenuItem = function(_, path)
  calls[#calls + 1] = table.concat(path, "/")
  return selected
end }
local fakeHs = {
  configdir = hs.configdir,
  logger = hs.logger,
  application = {
    get = function(id)
      assert(id == "com.apple.AddressBook", "edit must target Contacts by bundle ID")
      return available and app or nil
    end,
    frontmostApplication = function() error("must not depend on the live frontmost app") end,
  },
  eventtap = { keyStroke = function() error("must use Contacts' native menu action") end },
}
local reported
local helpers = { reportError = function(message) reported = message end }
local env = setmetatable({ hs = fakeHs }, { __index = _G })
env.require = function(name)
  if name == "helperFunctions" then return helpers end
  return assert(loadfile(hs.configdir .. "/" .. name .. ".lua", "t", env))()
end
local definitions = env.require("appBasedHotkeys").definitions
local edit
for _, def in ipairs(definitions) do
  if def.key == "e" and table.concat(def.mods, "+") == "cmd"
      and def.only and def.only[1] == "com.apple.AddressBook" then edit = def.action end
  assert(not (def.key == "s" and def.only and def.only[1] == "com.apple.AddressBook"),
    "Contacts must retain its native save shortcut")
end
assert(edit, "Contacts Cmd+E must be registered only for Contacts")
edit()
assert(#calls == 1 and calls[1] == "Edit/Edit Card", "edit must select the native Edit Card menu item")
available = false
edit()
assert(#calls == 1, "missing Contacts must not launch an app or act elsewhere")
available, selected = true, false
edit()
assert(reported, "unavailable menu action must report failure")
print("contacts-hotkey: all checks passed")
