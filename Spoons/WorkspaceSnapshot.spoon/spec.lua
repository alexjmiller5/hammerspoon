-- The snapshot data model. The intermediate representation between parse.lua
-- (text I/O) and capture/restore (live system I/O).
local M = {}

function M.empty_snapshot()
  return {
    ghostty = {},  -- list of { cwd = string, sessionId = string|nil }
    chrome  = {},  -- list of { tabs = list of string URLs }
    gemini  = {},  -- list of { url = string } (native Gemini Desktop app windows)
    vscode  = {},  -- list of { workspace = string, terminals = list of { cwd = string, sessionId = string|nil } }
  }
end

local function validate_ghostty_entry(entry, i)
  if type(entry.cwd) ~= "string" or entry.cwd == "" then
    return false, ("ghostty[%d]: missing or empty cwd"):format(i)
  end
  if entry.sessionId ~= nil and type(entry.sessionId) ~= "string" then
    return false, ("ghostty[%d]: sessionId must be string or nil"):format(i)
  end
  return true
end

local function validate_chrome_entry(entry, i)
  if type(entry.tabs) ~= "table" or #entry.tabs == 0 then
    return false, ("chrome[%d]: tabs must be non-empty list"):format(i)
  end
  for j, tab in ipairs(entry.tabs) do
    if type(tab) ~= "string" then
      return false, ("chrome[%d].tabs[%d] must be string URL"):format(i, j)
    end
  end
  return true
end

local function validate_gemini_entry(entry, i)
  if type(entry.url) ~= "string" or entry.url == "" then
    return false, ("gemini[%d]: missing or empty url"):format(i)
  end
  return true
end

local function validate_vscode_entry(entry, i)
  if type(entry.workspace) ~= "string" or entry.workspace == "" then
    return false, ("vscode[%d]: missing or empty workspace"):format(i)
  end
  if entry.terminals ~= nil and type(entry.terminals) ~= "table" then
    return false, ("vscode[%d]: terminals must be list or nil"):format(i)
  end
  return true
end

function M.validate(s)
  if type(s) ~= "table" then
    return false, "snapshot must be a table"
  end
  for _, cat in ipairs({"ghostty", "chrome", "gemini", "vscode"}) do
    if type(s[cat]) ~= "table" then
      return false, ("missing or non-table category: %s"):format(cat)
    end
  end
  for i, e in ipairs(s.ghostty) do
    local ok, err = validate_ghostty_entry(e, i)
    if not ok then return false, err end
  end
  for i, e in ipairs(s.chrome) do
    local ok, err = validate_chrome_entry(e, i)
    if not ok then return false, err end
  end
  for i, e in ipairs(s.gemini) do
    local ok, err = validate_gemini_entry(e, i)
    if not ok then return false, err end
  end
  for i, e in ipairs(s.vscode) do
    local ok, err = validate_vscode_entry(e, i)
    if not ok then return false, err end
  end
  return true
end

return M
