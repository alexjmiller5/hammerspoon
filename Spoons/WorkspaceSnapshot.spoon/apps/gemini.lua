-- Gemini handler: snapshot + restore for the native Gemini Desktop app
-- (separate repo: active-projects/gemini-desktop).
--
-- Unlike the old Chrome-PWA path, Gemini Desktop is a REAL macOS app:
--   * hs.window sees its windows directly (bundleId == BUNDLE_ID)
--   * window ids match hs.window:id() exactly
--   * hs.spaces.moveWindowToSpace works on them
-- So capture just joins the app's own window-state file (windowId -> url) to
-- the live windows, and restore spawns a window via the app's URL scheme and
-- lets restore.lua's window-watcher move it to the target Space — no browser
-- extension, native-messaging host, or nav-queue required.
local M = {}
local paths = require("util.paths")
local log = require("util.log").new("gemini")

M.BUNDLE_ID  = "com.alexmiller.geminidesktop"
M.HOME_URL   = "https://gemini.google.com/app"
M.URL_SCHEME = "geminiapp"

-- Read the Gemini Desktop app's window-state file. Returns the parsed table,
-- or nil on any failure (missing file, malformed JSON).
function M.read_state_file(path)
  path = path or paths.gemini_windows_json
  local f = io.open(path, "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  if hs and hs.json then
    local ok, parsed = pcall(hs.json.decode, content)
    if not ok then return nil end
    return parsed
  end
  -- Standalone (tests): tiny pure-Lua JSON reader.
  local ok, parsed = pcall(require("tests.minijson").decode, content)
  if not ok then return nil end
  return parsed
end

-- Build a { [windowId] = url } map from the state-file data.
function M.url_by_window_id(data)
  local map = {}
  if data and type(data.windows) == "table" then
    for _, w in ipairs(data.windows) do
      if w.windowId and w.url then map[w.windowId] = w.url end
    end
  end
  return map
end

-- Capture snapshot entries for the given Gemini Desktop windows.
-- `mac_windows`: list of { id = macOSWinId, title, bundleId } (from hs.window)
-- `opts` (optional, for tests): { state_data = <parsed>, state_path = <path> }
-- Returns: list of { url = string }
function M.capture(mac_windows, opts)
  opts = opts or {}
  local data = opts.state_data or M.read_state_file(opts.state_path)
  local url_map = M.url_by_window_id(data)
  local entries = {}
  for _, w in ipairs(mac_windows) do
    if w.bundleId == M.BUNDLE_ID then
      -- Join by exact window id. Fall back to the home url if the state file
      -- is momentarily stale (window exists but hasn't been recorded yet) so
      -- we still round-trip a window rather than silently dropping it.
      local url = url_map[w.id] or M.HOME_URL
      table.insert(entries, { url = url })
    end
  end
  return entries
end

-- Percent-encode a URL and wrap it in the app's open-a-window scheme URL.
-- Everything except RFC-3986 unreserved chars is encoded so the `url` query
-- value survives shell + LaunchServices + URLComponents parsing intact.
function M.scheme_url_for(url)
  url = url or M.HOME_URL
  local encoded = url:gsub("[^%w%-%._~]", function(c)
    return string.format("%%%02X", string.byte(c))
  end)
  return M.URL_SCHEME .. "://open?url=" .. encoded
end

-- Spawn a new Gemini window at `url` via the app's URL scheme. LaunchServices
-- routes the geminiapp:// URL to the app (launching it if needed); the app
-- creates the window on the current Space, and restore.lua's window-watcher
-- moves it to the target Space.
--
-- Uses hs.urlevent.openURL rather than shelling out to `open`: `hs.execute`
-- with a login shell returned rc=1 for the scheme URL (the login-shell env
-- broke LaunchServices resolution), and openURL avoids the shell + quoting
-- entirely.
-- Returns true on success, or false + error.
function M.launch(url)
  if not hs or not hs.urlevent then return false, "hs.urlevent not available" end
  local scheme_url = M.scheme_url_for(url)
  local ok = hs.urlevent.openURL(scheme_url)
  if not ok then return false, "openURL failed for " .. scheme_url end
  log.i("launched gemini window -> " .. (url or M.HOME_URL))
  return true
end

return M
