-- Real definitions and app-scope registration; no posted keys or live windows.
local bound, calls = {}, {}
local fakeHs = {
  configdir = hs.configdir,
  logger = hs.logger,
  application = { frontmostApplication = function() error("must use fixture app focus") end },
  eventtap = { keyStroke = function() error("must not post keyboard events") end },
  hotkey = { new = function(mods, key, action)
    local hotkey = { mods = mods, key = key, action = action,
      enable = function(self) self.enabled = true; return self end,
      disable = function(self) self.enabled = false; return self end }
    bound[#bound + 1] = hotkey
    return hotkey
  end },
}
fakeHs.hotkey.bind = function(...) return fakeHs.hotkey.new(...):enable() end
local env = setmetatable({ hs = fakeHs }, { __index = _G })
local cache = {
  activeProfile = { require = function() return {} end },
  ["profiles.work.constants"] = { appBundleIds = { gemini = "fixture.gemini" }, tabs = {} },
  ["profiles.work.chrome"] = {},
  ["profiles.personal.otp"] = {},
  ["profiles.personal.otpMail"] = {},
  ["profiles.personal.tailscale"] = {},
  windowManagement = {
    resize = function(delta) calls.resize = delta end,
    place = function(position) calls.place = position end,
  },
}
env.require = function(name)
  if not cache[name] then
    cache[name] = assert(loadfile(hs.configdir .. "/" .. name:gsub("%.", "/") .. ".lua", "t", env))()
  end
  return cache[name]
end
local helpers = env.require("helperFunctions")
local function matching(key)
  local result = {}
  for _, hotkey in ipairs(bound) do
    if hotkey.enabled and table.concat(hotkey.mods, "+") == "cmd+shift" and hotkey.key == key then
      result[#result + 1] = hotkey
    end
  end
  return result
end
local failures = 0
for _, profile in ipairs({ "personal", "work" }) do
  bound = {}
  local registry, previous = {}, nil
  helpers.bindGlobalHotkeys(env.require("globalHotkeys").definitions)
  helpers.registerAppBasedHotkeys(registry, env.require("appBasedHotkeys").definitions)
  helpers.bindGlobalHotkeys(env.require("profiles." .. profile .. ".globalHotkeys").definitions)
  helpers.registerAppBasedHotkeys(registry, env.require("profiles." .. profile .. ".appBasedHotkeys").definitions)
  local function focus(id)
    previous = helpers.updateActiveAppHotkeys({ bundleID = function() return id end }, registry, previous)
  end
  for _, otherApp in ipairs({ "com.google.Chrome", "fixture.other" }) do
    focus("com.apple.finder")
    for _, key in ipairs({ "=", "-", "." }) do
      if #matching(key) ~= 0 then
        print("FAIL " .. profile .. " intercepts Finder Cmd+Shift+" .. key)
        failures = failures + 1
      end
    end
    focus(otherApp)
    for key, delta in pairs({ ["="] = 0.05, ["-"] = -0.05 }) do
      local hotkeys = matching(key)
      assert(#hotkeys == 1, "window sizing must stay enabled outside Finder")
      hotkeys[1].action()
      assert(calls.resize == delta, "window sizing must preserve its direction and step")
    end
    if profile == "work" then
      local hotkeys = matching(".")
      assert(#hotkeys == 1, "work right-half shortcut must stay enabled outside Finder")
      hotkeys[1].action()
      assert(calls.place == "right", "work shortcut must still place the window on the right")
    end
  end
end
assert(failures == 0, failures .. " Finder shortcut scope checks failed")
print("finder-shortcuts: all checks passed")
