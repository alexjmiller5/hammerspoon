-- Plain Lua: real modules and profile init, fake only Hammerspoon effects.
local root = assert(arg[1], "config directory required")
local realLoadfile = loadfile
local function load(path, env)
  if _VERSION == "Lua 5.1" then
    local fn = assert(realLoadfile(path)); setfenv(fn, env); return fn
  end
  return assert(realLoadfile(path, "t", env))
end
local function context(profile)
  local played, menus, errors, starts, definitions = {}, {}, {}, {}, {}
  local callback, menuMode
  local logger = setmetatable({ w = function(message) error(message) end }, { __index = function() return function() end end })
  local fake = {
    configdir = root,
    logger = { new = function() return logger end },
    hotkey = { setLogLevel = function() end },
    alert = { show = function() end },
    spotify = {
      previous = function() played[#played+1] = "previous" end,
      playpause = function() played[#played+1] = "playpause" end,
      next = function() played[#played+1] = "next" end,
    },
    eventtap = { event = { types = { systemDefined = 14 } }, new = function(_, fn)
      callback = fn
      return { start = function(self) starts.media = (starts.media or 0)+1; return self end }
    end },
    application = { frontmostApplication = function() return nil end },
  }
  local inert = { start = function(self) return self end }
  local helpers = {
    bindGlobalHotkeys = function(list) for _, d in ipairs(list) do definitions[#definitions+1]=d end end,
    registerAppBasedHotkeys = function() end,
    updateActiveAppHotkeys = function() end,
    requirePath = function() return false end,
    tryMenuItem = function(path)
      menus[#menus+1] = table.concat(path, "/")
      return menuMode == path[2]
    end,
    reportError = function(message) errors[#errors+1]=message end,
  }
  local env = setmetatable({ hs = fake, require = false }, { __index = _G })
  local cache = { ["profiles.work.transientTabs"] = { start = function() starts.transient = (starts.transient or 0)+1; return inert end }, helperFunctions = helpers, windowManagement = {}, opUnlock = {},
    ["hs.ipc"] = {}, herdrHotkeys = { start = function() return inert end },
    hyperKey = { start = function() return inert end },
    ["profiles.work.browser"] = {},
    ["profiles.personal.screenSharingPlacement"] = { start = function() return inert end },
  }
  cache.activeProfile = { name = profile, require = function(name) return env.require("profiles."..profile.."."..name) end }
  env.require = function(name)
    if not cache[name] then
      local module = load(root.."/"..name:gsub("%.", "/")..".lua", env)()
      if name == "watcherFunctions" then
        for _, factory in ipairs({"createAppBasedHotkeyWatcher", "createSpotifyAutoHideWatcher",
            "createCopyConfirmationWatcher", "createGhosttyCommandClickWatcher", "createWindowlessAppReaper"}) do
          module[factory] = function() return inert end
        end
      elseif name == "profiles.personal.watcherFunctions" then
        module.createAppInputRemapWatcher = function() return inert end
        module.createWatcherOnPowerConnect = function() return nil end
      end
      cache[name] = module
    end
    return cache[name]
  end
  -- Avoid optional personal dependencies without replacing the actual profile init.
  cache["profiles.personal.tailscale"] = { toggle = function() end }
  cache["profiles.personal.otp"] = {}; cache["profiles.personal.otpMail"] = {}
  load(root.."/init.lua", env)()
  assert(starts.media == 1, profile..": shared media watcher must start exactly once")
  assert((starts.transient or 0) == (profile == "work" and 1 or 0), "transient observer must start only in work")
  for _, spec in ipairs({{"f7", "previous"}, {"f8", "playpause"}, {"f9", "next"}}) do
    local count = 0
    for _, def in ipairs(definitions) do
      if def.key == spec[1] and table.concat(def.mods, "+") == "cmd" then
        count = count+1; def.action(); assert(played[#played] == spec[2])
      end
    end
    assert(count == 1, profile..": one binding required for "..spec[1])
  end
  local function event(key, down, flags, repeated)
    return { systemKey = function() return {key=key, down=down, ["repeat"]=repeated} end,
      getFlags = function() return flags or {} end }
  end
  for key, expected in pairs({PLAY="playpause", FAST="next", NEXT="next", REWIND="previous", PREVIOUS="previous"}) do
    local before = #played
    assert(callback(event(key, true, {cmd=true})))
    assert(callback(event(key, true, {cmd=true}, true)))
    assert(callback(event(key, false)))
    assert(#played == before+1 and played[#played] == expected, "media mapping must run once")
  end
  for _, flags in ipairs({{}, {cmd=true, shift=true}, {cmd=true, alt=true}, {cmd=true, ctrl=true}}) do
    assert(not callback(event("PLAY", true, flags)))
  end
  assert(not callback(event("SOUND_UP", true, {cmd=true})))
  assert(not callback(event("PLAY", true, {cmd=true}, true)))
  assert(callback(event("PLAY", true, {cmd=true, fn=true})))
  assert(callback(event("PLAY", false)))
  local notes
  for _, def in ipairs(env.require("profiles.work.appBasedHotkeys").definitions) do
    if def.key == "\\" and table.concat(def.mods, "+") == "cmd"
        and def.only and def.only[1] == "com.apple.Notes" then
      assert(#def.only == 1 and not notes, "Notes binding must be unique and Notes-only")
      notes=def.action
    end
  end
  assert(notes, "work Notes Cmd+backslash is missing")
  menuMode="Show Folders"; notes(); assert(#menus==1 and menus[1]=="View/Show Folders")
  menus={}; menuMode="Hide Folders"; notes()
  assert(table.concat(menus, ",")=="View/Show Folders,View/Hide Folders")
  menus={}; menuMode=nil; notes(); assert(#errors==1 and #menus==2)
end
for _, profile in ipairs({"work", "personal"}) do context(profile) end
print("shared-spotify-notes: both profile inits, unique bindings, media guards and Notes menus passed")
