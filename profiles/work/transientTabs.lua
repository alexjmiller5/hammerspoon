-- Observation only: this module has no tab-closing operation.
local M = { observations = {}, unavailableTabs = 0 }
local log = hs.logger.new("TransientTabs", "info")
local timer, lastSummary

local function quote(text)
  return '"' .. text:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r") .. '"'
end

local function validate(rules)
  assert(type(rules) == "table" and #rules <= 20, "Expected at most 20 rules")
  local ids = {}
  for _, rule in ipairs(rules) do
    assert(type(rule) == "table" and type(rule.id) == "string" and
      rule.id:match("^[%w_-]+$") and #rule.id <= 40 and not ids[rule.id], "Invalid rule id")
    ids[rule.id] = true
    assert(type(rule.host) == "string" and rule.host:match("^[%w.-]+$") and
      rule.host == rule.host:lower(), "Expected an exact lowercase host")
    assert(type(rule.pathPrefix) == "string" and rule.pathPrefix:sub(1, 1) == "/" and
      not rule.pathPrefix:find("[?#]"), "Expected a path prefix without query or fragment")
    assert(type(rule.contains) == "table" and #rule.contains <= 8, "Expected success phrases")
    for _, phrase in ipairs(rule.contains) do
      assert(type(phrase) == "string" and #phrase > 0 and #phrase <= 300 and
        not phrase:find("[\r\n]"), "Invalid success phrase")
    end
  end
  return rules
end

function M.scan()
  M.observations = {}
  M.unavailableTabs = 0
  local rules = hs.settings.get("transientTabs.rules") or {}
  local ok = pcall(validate, rules)
  if not ok then log.w("Invalid transient tab rules; observation skipped"); return end
  if #rules == 0 then return end
  local browser = require("profiles.work.constants").appBundleIds.browser
  if not hs.application.get(browser) then return end -- never launch a browser
  local file = io.open(hs.configdir .. "/profiles/work/transientTabs.js", "r")
  if not file then log.w("Transient tab classifier unavailable"); return end
  local source = file:read("*a"); file:close()
  local js = "(() => { const rules = " .. hs.json.encode(rules) .. "; return " .. source .. "; })()"
  local script = [[
with timeout of 2 seconds
  tell application id ]] .. quote(browser) .. "\n" .. [[
    set results to {}
    set unavailableCount to 0
    repeat with w in windows
      repeat with t in tabs of w
        try
          set verdict to execute t javascript ]] .. quote(js) .. "\n" .. [[
          set end of results to {id of w, id of t, verdict}
        on error
          set unavailableCount to unavailableCount + 1
        end try
      end repeat
    end repeat
    return {results, unavailableCount}
  end tell
end timeout]]
  local ran, success, rows = pcall(hs.osascript.applescript, script)
  if not ran or not success or type(rows) ~= "table" then
    log.w("Transient tab scan unavailable")
    lastSummary = nil
    return
  end
  M.unavailableTabs = rows[2] or 0
  rows = rows[1] or {}
  local summary = {}
  if M.unavailableTabs > 0 then summary[1] = tostring(M.unavailableTabs) .. " tabs unavailable" end
  for _, row in ipairs(rows) do
    local decoded, matches = pcall(hs.json.decode, row[3])
    if decoded and type(matches) == "table" then
      for _, match in ipairs(matches) do
        local known = false
        for _, rule in ipairs(rules) do if rule.id == match.rule then known = true end end
        if known and (match.status == "success" or match.status == "candidate") then
          M.observations[#M.observations + 1] = {
            window = row[1], tab = row[2], rule = match.rule, status = match.status,
          }
          summary[#summary + 1] = tostring(row[1]) .. ":" .. tostring(row[2]) .. " " .. match.rule .. " " .. match.status
        end
      end
    end
  end
  table.sort(summary)
  local current = table.concat(summary, "; ")
  if current ~= lastSummary then
    if current ~= "" then log.i(current) end
    lastSummary = current
  end
end

function M.stop()
  if timer then timer:stop(); timer = nil end
  M.observations = {}
  M.unavailableTabs = 0
  lastSummary = nil
end

function M.start()
  M.stop()
  if require("activeProfile").name ~= "work" then return M end
  local rules = hs.settings.get("transientTabs.rules") or {}
  local ok = pcall(validate, rules)
  if not ok then log.w("Invalid transient tab rules; observation skipped"); return M end
  if #rules > 0 then
    timer = hs.timer.doEvery(10, M.scan)
    M.scan()
  end
  return M
end

function M.configure(rules)
  validate(rules)
  hs.settings.set("transientTabs.rules", rules)
  return M.start()
end

return M
