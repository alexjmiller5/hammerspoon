-- Chrome regular handler. Snapshot reads URLs via JXA (faster + more reliable
-- than chrome-cli for our purposes since JXA also sees PWAs). Restore uses
-- chrome-cli for speed.
local log = require("util.log").new("chrome")
local M = {}

-- Match a Hammerspoon window title (e.g. "Namecheap - Google Chrome") to its
-- Chrome JXA window by stripping the " - Google Chrome" suffix.
function M.normalize_hs_title(title)
  if type(title) ~= "string" then return "" end
  return title:gsub(" %- Google Chrome$", "")
end

-- Query all Chrome windows + tabs via JXA. Returns:
--   { { windowId, title, activeTabUrl, tabs = { url, url, ... } } }
function M.query_chrome_via_jxa()
  if not hs or not hs.osascript then
    return nil, "hs.osascript not available"
  end
  local script = [[
    const c = Application("Google Chrome");
    if (!c.running()) { JSON.stringify({error: "Chrome not running"}); }
    else {
      JSON.stringify(c.windows().map(w => ({
        windowId: w.id(),
        title: w.title(),
        activeTabUrl: w.activeTab().url(),
        tabs: w.tabs().map(t => t.url())
      })));
    }
  ]]
  local ok, result = hs.osascript.javascript(script)
  if not ok then return nil, "JXA failed: " .. tostring(result) end
  local parsed = hs.json.decode(result)
  if parsed and parsed.error then return nil, parsed.error end
  return parsed
end

-- Capture snapshot entries for regular Chrome windows (NOT PWAs).
-- `mac_windows`: list of { id = macOSWinId, title = string, bundleId = string }
-- Returns: list of { tabs = { url, url, ... } }
function M.capture(mac_windows)
  local entries = {}
  local jxa_windows = nil

  for _, w in ipairs(mac_windows) do
    if w.bundleId == "com.google.Chrome" then
      if jxa_windows == nil then
        local result = M.query_chrome_via_jxa()
        jxa_windows = result or {}
      end
      local target = M.normalize_hs_title(w.title)
      for _, jw in ipairs(jxa_windows) do
        if jw.title == target then
          if jw.tabs and #jw.tabs > 0 then
            table.insert(entries, { tabs = jw.tabs })
          end
          break
        end
      end
    end
  end

  return entries
end

-- Spawn a new Chrome window with the given tabs.
-- Returns true on success, false + error on failure.
function M.launch(tabs)
  if not tabs or #tabs == 0 then
    return false, "no tabs to launch"
  end
  -- Open first tab in a new window.
  local first_cmd = ("chrome-cli open %q -n"):format(tabs[1])
  local _ = hs.execute(first_cmd, true)
  -- chrome-cli prints "Id: <num>" for the new tab; the window ID is the parent
  -- of that tab. Easier: query the most recent window via chrome-cli list windows.
  -- For the MVP, just open subsequent tabs in the (new) frontmost window with no -w.
  -- chrome-cli's `open <url>` defaults to the frontmost window's new tab, which
  -- is what we just created.
  for i = 2, #tabs do
    local cmd = ("chrome-cli open %q"):format(tabs[i])
    hs.execute(cmd, true)
  end
  log.i("launched Chrome window with " .. #tabs .. " tabs")
  return true
end

return M
