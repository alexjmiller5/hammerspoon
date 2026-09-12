-- Machine profile selector. Reads ~/.config/hammerspoon-profile (written per
-- machine by nix-config); defaults to "personal" so the repo works standalone.
-- Usage:  require("activeProfile").require("constants")  → profiles/<name>/constants.lua
local helpers = require("helperFunctions")
local path = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hammerspoon-profile"
local name = "personal"
local f, _, errno = io.open(path, "r")
if f then
    local value = f:read("*l")
    f:close()
    if value and value:match("^[%w_-]+$") then
        local profileDir = hs.configdir .. "/profiles/" .. value
        if helpers.requirePath(profileDir .. "/constants.lua")
            and helpers.requirePath(profileDir .. "/init.lua") then
            name = value
        end
    else
        helpers.reportError("Invalid or unreadable profile file: " .. path)
    end
elseif errno ~= 2 then
    helpers.reportError("Cannot read profile file: " .. path)
end

return {
    name = name,
    require = function(mod)
        return require("profiles." .. name .. "." .. mod)
    end,
}
