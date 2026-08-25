local M = {}

local spec = require("spec")

-- Match the count header line: "ghostty=2 vscode=1 chrome=1 gemini=1"
-- Accept any number of categories; ignore unknown names.
local HEADER_PATTERN = "^[%w_]+=%d+([ %w_=%d]*)$"

local function is_header(line)
  return line:match(HEADER_PATTERN) ~= nil
end

local function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- Parse "ghostty:/Users/x" or "ghostty:/Users/x#session=abc"
local function parse_ghostty_line(line)
  local body = line:sub(#"ghostty:" + 1)
  local cwd, frag = body:match("^([^#]+)(.*)$")
  if not cwd then return nil end
  local entry = { cwd = trim(cwd) }
  if frag and #frag > 0 then
    local sid = frag:match("#session=([%w%-]+)")
    if sid then entry.sessionId = sid end
  end
  return entry
end

-- Parse "vscode:/path#term=cwd=/p,session=abc;term=cwd=/q"
local function parse_vscode_line(line)
  local body = line:sub(#"vscode:" + 1)
  local ws, frag = body:match("^([^#]+)(.*)$")
  if not ws then return nil end
  local entry = { workspace = trim(ws), terminals = {} }
  if frag and #frag > 0 then
    for term_spec in (frag .. ";"):gmatch("#?term=([^;]+);") do
      local cwd = term_spec:match("cwd=([^,]+)")
      local sid = term_spec:match("session=([%w%-]+)")
      if cwd then
        table.insert(entry.terminals, { cwd = trim(cwd), sessionId = sid })
      end
    end
  end
  return entry
end

-- Parse "chrome: https://a | https://b | https://c"
local function parse_chrome_line(line)
  local body = line:sub(#"chrome:" + 1)
  local entry = { tabs = {} }
  for tab in (body .. "|"):gmatch("([^|]+)|") do
    local t = trim(tab)
    if #t > 0 then table.insert(entry.tabs, t) end
  end
  if #entry.tabs == 0 then return nil end
  return entry
end

-- Parse "gemini:https://gemini.google.com/app/xxx"
local function parse_gemini_line(line)
  local url = trim(line:sub(#"gemini:" + 1))
  if url == "" then return nil end
  return { url = url }
end

function M.parse_text(text)
  if type(text) ~= "string" or trim(text) == "" then
    return nil, "snapshot text is empty"
  end
  local snap = spec.empty_snapshot()
  local lines = {}
  for line in text:gmatch("([^\n]*)\n?") do
    table.insert(lines, line)
  end
  -- Trailing empty line from trailing newline; ignore.
  while #lines > 0 and lines[#lines] == "" do table.remove(lines) end
  if #lines == 0 then return nil, "snapshot text is empty" end

  -- First non-blank, non-comment line must be a header.
  local first
  for _, l in ipairs(lines) do
    if l ~= "" and not l:match("^%s*#") then first = l; break end
  end
  if not first or not is_header(first) then
    return nil, "missing count header on first line"
  end

  for i, line in ipairs(lines) do
    if line == "" or line:match("^%s*#") then
      local _ = nil  -- skip blank/comment line
    elseif i == 1 or is_header(line) then
      local _ = nil  -- skip header (only first occurrence expected; tolerate extras)
    elseif line:sub(1, 8) == "ghostty:" then
      local e = parse_ghostty_line(line)
      if e then table.insert(snap.ghostty, e) end
    elseif line:sub(1, 7) == "vscode:" then
      local e = parse_vscode_line(line)
      if e then table.insert(snap.vscode, e) end
    elseif line:sub(1, 7) == "chrome:" then
      local e = parse_chrome_line(line)
      if e then table.insert(snap.chrome, e) end
    elseif line:sub(1, 7) == "gemini:" then
      local e = parse_gemini_line(line)
      if e then table.insert(snap.gemini, e) end
    end
  end

  return snap
end

-- Snapshot text format reserved characters:
-- `|` separates Chrome tab URLs (a tab URL containing `|` would corrupt the format;
--      callers must ensure URLs are pre-encoded, e.g., `%7C` for any literal `|`)
-- `,` and `;` separate VSCode terminal spec fields (cwd / session)
-- `#` separates a path/identifier from a fragment annotation
-- Snapshot producers (capture.lua and friends) must avoid emitting these characters
-- in unescaped form within fields. Currently relies on:
--   - Chrome URLs being well-formed (browser-controlled)
--   - Filesystem paths not containing `,`, `;`, or `#` (extremely rare on macOS)
--   - Session IDs being UUIDs (matching `[%w%-]+`)

local function format_ghostty(entry)
  local s = "ghostty:" .. entry.cwd
  if entry.sessionId then s = s .. "#session=" .. entry.sessionId end
  return s
end

local function format_vscode(entry)
  local s = "vscode:" .. entry.workspace
  if entry.terminals and #entry.terminals > 0 then
    local parts = {}
    for _, t in ipairs(entry.terminals) do
      local p = "cwd=" .. t.cwd
      if t.sessionId then p = p .. ",session=" .. t.sessionId end
      table.insert(parts, p)
    end
    s = s .. "#term=" .. table.concat(parts, ";term=")
  end
  return s
end

local function format_chrome(entry)
  return "chrome: " .. table.concat(entry.tabs, " | ")
end

local function format_gemini(entry)
  return "gemini:" .. entry.url
end

function M.validate_clipboard_text(text)
  if type(text) ~= "string" or trim(text) == "" then
    return false, "clipboard is empty"
  end
  if #text > 10240 then
    return false, "clipboard text too large (>10KB)"
  end
  local first
  for line in text:gmatch("[^\n]+") do
    if not line:match("^%s*#") and trim(line) ~= "" then first = line; break end
  end
  if not first or not is_header(first) then
    return false, "missing count header on first non-comment line"
  end
  return true
end

function M.format_text(snap)
  local header = string.format(
    "ghostty=%d vscode=%d chrome=%d gemini=%d",
    #snap.ghostty, #snap.vscode, #snap.chrome, #snap.gemini
  )
  local lines = { header }
  for _, e in ipairs(snap.ghostty) do table.insert(lines, format_ghostty(e)) end
  for _, e in ipairs(snap.vscode)  do table.insert(lines, format_vscode(e))  end
  for _, e in ipairs(snap.chrome)  do table.insert(lines, format_chrome(e))  end
  for _, e in ipairs(snap.gemini)  do table.insert(lines, format_gemini(e))  end
  return table.concat(lines, "\n")
end

return M
