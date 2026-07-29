-- Machine profile selector. Reads ~/.config/hammerspoon-profile (written per
-- machine by nix-config); defaults to "personal" so the repo works standalone.
-- Usage:  require("activeProfile").require("constants")  → profiles/<name>/constants.lua
local f = io.open(os.getenv("HOME") .. "/.config/hammerspoon-profile")
local name = f and f:read("*l") or "personal"
if f then f:close() end

return {
    name = name,
    require = function(mod)
        return require("profiles." .. name .. "." .. mod)
    end,
}
