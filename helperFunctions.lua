local log = hs.logger.new("HelperFunctions", "debug")

local constants = require("constants")

local M = {}

function M.reportError(message)
  log.e(message)
  hs.alert.show(message)
end

-- Check at the point of use: symlinks, removable files and permissions can change.
function M.requirePath(path, kind)
  kind = kind or "file"
  local attr = type(path) == "string" and path ~= "" and hs.fs.attributes(path)
  local valid = attr and attr.mode == (kind == "directory" and "directory" or "file")
  if valid and kind == "executable" then
    valid = attr.permissions:find("x", 1, true) ~= nil
  elseif valid and kind == "file" then
    local file = io.open(path, "rb")
    valid = file ~= nil
    if file then file:close() end
  end
  if valid then return path end
  M.reportError("Missing or inaccessible " .. kind .. ": " .. tostring(path))
end

function M.runTask(path, args, callback, input)
  if not M.requirePath(path, "executable") then
    if callback then callback(-1, "", "Executable unavailable") end
    return
  end
  local function finished(code, out, err)
    -- A callback can acknowledge an intentional failure (such as a timeout).
    local handled = callback and callback(code, out, err)
    if code ~= 0 and handled ~= true then M.reportError(path .. " failed (exit " .. tostring(code) .. ")") end
  end
  local task = hs.task.new(path, finished, args or {})
  if task and input then task:setInput(input) end
  if not task or not task:start() then
    finished(-1, "", "Could not start process")
    return
  end
  return task
end

-- Use the system output unless the caller explicitly chooses another device.
function M.playAudioFileByPath(soundPath, device)
  if not M.requirePath(soundPath) then return false end
  local sound = hs.sound.getByFile(soundPath)
  if not sound then
    M.reportError("Cannot decode audio: " .. soundPath)
    return false
  end
  if device and not sound:device(device) then
    M.reportError("Audio output unavailable: " .. device)
    return false
  end
  if not sound:play() then
    M.reportError("Cannot play audio: " .. soundPath)
    return false
  end
  return true
end

-- Attempts to select a menu item on the frontmost application.
-- Returns true on success, false on failure.
function M.tryMenuItem(menuPath)
    local frontApp = hs.application.frontmostApplication()
    if not frontApp then return false end

    return pcall(function()
        if not frontApp:selectMenuItem(menuPath) then
            error("Menu item not found or action failed.")
        end
    end)
end

-- Bind a list of global hotkeys immediately
function M.bindGlobalHotkeys(definitions)
    if not definitions then return end
    for _, hk in ipairs(definitions) do
        hs.hotkey.bind(hk.mods, hk.key, hk.action)
    end
end

-- Logic for the AppWatcher to swap active keys
function M.updateActiveAppHotkeys(app, registry, previousBundleID)
    local newBundleID = app and app:bundleID() or nil

    if newBundleID == previousBundleID then return previousBundleID end

    -- Undo previous app
    if previousBundleID and registry[previousBundleID] then
        local prev = registry[previousBundleID]
        for _, hk in ipairs(prev.only) do hk:disable() end
        for _, hk in ipairs(prev.except) do hk:enable() end
    end

    -- Apply new app
    if newBundleID and registry[newBundleID] then
        local new = registry[newBundleID]
        for _, hk in ipairs(new.only) do hk:enable() end
        for _, hk in ipairs(new.except) do hk:disable() end
    end

    return newBundleID
end

-- Temporarily disable all hotkeys for a bundle ID (for pass-through scenarios)
function M.disableHotkeysForApp(registry, bundleID)
    if not (bundleID and registry[bundleID]) then return end
    local entry = registry[bundleID]
    for _, hk in ipairs(entry.only) do hk:disable() end
    for _, hk in ipairs(entry.except) do hk:disable() end
end

-- Restore hotkeys for a bundle ID to "app is active" state after pass-through.
-- only-mode hotkeys get re-enabled; except-mode hotkeys stay disabled.
function M.enableHotkeysForApp(registry, bundleID)
    if not (bundleID and registry[bundleID]) then return end
    local entry = registry[bundleID]
    for _, hk in ipairs(entry.only) do hk:enable() end
end

-- Adds definitions to the registry (state) for the App Watcher to use later.
-- sourceDefinitions is a flat list where each entry has `only` or `except` bundle ID lists.
function M.registerAppBasedHotkeys(targetRegistry, sourceDefinitions)
    if not sourceDefinitions then return end

    for _, def in ipairs(sourceDefinitions) do
        if type(def.action) ~= "function" then
            print(string.format("⚠️ ERROR: Action is nil for key: %s", tostring(def.key)))
            goto continue
        end

        local hk = hs.hotkey.new(def.mods, def.key, def.action)

        if def.only then
            for _, bundleID in ipairs(def.only) do
                if not targetRegistry[bundleID] then
                    targetRegistry[bundleID] = { only = {}, except = {} }
                end
                table.insert(targetRegistry[bundleID].only, hk)
            end
        elseif def.except then
            hk:enable()
            for _, bundleID in ipairs(def.except) do
                if not targetRegistry[bundleID] then
                    targetRegistry[bundleID] = { only = {}, except = {} }
                end
                table.insert(targetRegistry[bundleID].except, hk)
            end
        else
            print(string.format("⚠️ ERROR: Definition missing 'only' or 'except' for key: %s", tostring(def.key)))
        end

        ::continue::
    end
end

function M.findChromeSidebarButton(element, depth)
  if depth > 10 then return nil end
  local targetTitles = { ["expand tabs"] = true, ["collapse tabs"] = true }
  local role = element:attributeValue("AXRole")
  if role == "AXButton" then
    local title = (element:attributeValue("AXTitle") or ""):lower()
    local desc = (element:attributeValue("AXDescription") or ""):lower()
    if targetTitles[title] or targetTitles[desc] then
      return element
    end
  end
  for _, child in ipairs(element:attributeValue("AXChildren") or {}) do
    local found = M.findChromeSidebarButton(child, depth + 1)
    if found then return found end
  end
  return nil
end

return M
