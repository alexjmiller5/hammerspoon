-- Native input events remain unposted; application identity is a fixture.
local callback, appID = nil, nil
local fakeHs = {
  logger = hs.logger,
  keycodes = hs.keycodes,
  application = { frontmostApplication = function()
    return appID and { bundleID = function() return appID end } or nil
  end },
  eventtap = {
    event = hs.eventtap.event,
    new = function(_, handler) callback = handler; return {} end,
  },
}
local env = setmetatable({ hs = fakeHs, require = function(name)
  assert(name == "profiles.personal.constants")
  return { appBundleIds = { mail = "com.apple.mail", whatsapp = "net.whatsapp.WhatsApp" } }
end }, { __index = _G })
local watchers = assert(loadfile(hs.configdir .. "/profiles/personal/watcherFunctions.lua", "t", env))()
assert(watchers.createAppInputRemapWatcher, "app input remaps are missing")()
local function key(name, down, flags)
  return hs.eventtap.event.newKeyEvent({}, name, down):setFlags(flags or {})
end
appID = "net.whatsapp.WhatsApp"
local event = key("u", true, {cmd=true, alt=true})
assert(not callback(event))
assert(event:getFlags().cmd and event:getFlags().alt and event:getFlags().shift,
  "WhatsApp Cmd+U must add Shift while preserving optional modifiers")
event = key("u", true)
assert(not callback(event) and not event:getFlags().shift, "plain typing must pass through")
appID = "com.apple.mail"
local consumed, emitted = callback(key("escape", true, {alt=true}))
assert(consumed and #emitted == 3, "Mail Escape must prepend a complete Cmd+K press")
assert(emitted[1]:getKeyCode() == hs.keycodes.map.k and emitted[1]:getType() == hs.eventtap.event.types.keyDown)
assert(emitted[2]:getKeyCode() == hs.keycodes.map.k and emitted[2]:getType() == hs.eventtap.event.types.keyUp)
assert(emitted[1]:getFlags().cmd and emitted[1]:getFlags().alt)
assert(emitted[3]:getKeyCode() == hs.keycodes.map.escape and emitted[3]:getFlags().alt)
assert(not emitted[3]:getFlags().cmd, "Escape must retain the original modifiers")
assert(not callback(emitted[3]), "the generated Escape must not recurse")
assert(not callback(key("escape", false)), "physical key release must pass through")
local repeated = key("escape", true):setProperty(hs.eventtap.event.properties.keyboardEventAutorepeat, 1)
assert(not callback(repeated), "holding Escape must not repeatedly invoke Cmd+K")
for _, id in ipairs({"com.apple.finder", "com.google.Chrome"}) do
  appID = id
  event = key("u", true, {cmd=true})
  assert(not callback(event) and not event:getFlags().shift)
  assert(not callback(key("escape", true)), "unrelated apps must pass through")
end
appID = nil
assert(not callback(key("escape", true)))
print("app-input-remaps: native events, scope, modifiers, repeat and recursion checks passed")
