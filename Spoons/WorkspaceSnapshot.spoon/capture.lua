-- Snapshot orchestrator: walks the focused macOS Space, buckets every
-- capturable window by its app category, and dispatches each bucket to the
-- matching app handler (ghostty/chrome/vscode/gemini) to produce a snapshot
-- table.
local M = {}
local spec = require("spec")
local log = require("util.log").new("capture")

local gemini = require("apps.gemini")

local KNOWN_BUNDLES = {
  ["com.google.Chrome"]     = "chrome",
  ["com.microsoft.VSCode"]  = "vscode",
  ["com.mitchellh.ghostty"] = "ghostty",
  [gemini.BUNDLE_ID]        = "gemini",
}

local function bundle_to_category(bundle_id)
  return KNOWN_BUNDLES[bundle_id]
end

local function list_capturable_windows_in_focused_space()
  local sp = require("hs.spaces")
  local focused = sp.focusedSpace()
  local space_ids = sp.windowsForSpace(focused) or {}

  -- Index of window IDs in the focused space, for fast lookup.
  local in_space = {}
  for _, id in ipairs(space_ids) do in_space[id] = true end

  -- Iterate hs.window.allWindows() (windows HS has confirmed AX access to)
  -- and filter to those in the focused space. Do NOT call hs.window.get(id)
  -- on raw CGS space IDs — some of those are ghost IDs that hang macOS's AX
  -- subsystem indefinitely when accessed. allWindows() pre-filters those out.
  local windows = {}
  for _, w in ipairs(hs.window.allWindows()) do
    local id = w:id()
    if id and in_space[id] and w:subrole() == "AXStandardWindow" then
      local app = w:application()
      local bid = app and app:bundleID() or nil
      if bundle_to_category(bid) then
        table.insert(windows, {
          id = id,
          title = w:title() or "",
          bundleId = bid,
        })
      end
    end
  end
  return windows
end

function M.capture_current_space()
  local snap = spec.empty_snapshot()

  local windows = list_capturable_windows_in_focused_space()
  log.i(("capturing %d windows from focused space"):format(#windows))

  -- Bucket by category.
  local by_cat = { ghostty = {}, chrome = {}, vscode = {}, gemini = {} }
  for _, w in ipairs(windows) do
    local cat = bundle_to_category(w.bundleId)
    if cat then table.insert(by_cat[cat], w) end
  end
  log.i(("bucketed: ghostty=%d chrome=%d vscode=%d gemini=%d"):format(
    #by_cat.ghostty, #by_cat.chrome, #by_cat.vscode, #by_cat.gemini))

  -- Dispatch each category.
  local ghostty_mod = require("apps.ghostty")
  local chrome_mod  = require("apps.chrome")
  local vscode_mod  = require("apps.vscode")
  local gemini_mod  = require("apps.gemini")

  log.i(("dispatching ghostty.capture for %d mac windows"):format(#by_cat.ghostty))
  snap.ghostty = ghostty_mod.capture(by_cat.ghostty)
  log.i(("ghostty.capture returned %d entries"):format(#snap.ghostty))

  log.i(("dispatching chrome.capture for %d mac windows"):format(#by_cat.chrome))
  snap.chrome  = chrome_mod.capture(by_cat.chrome)
  log.i(("chrome.capture returned %d entries"):format(#snap.chrome))

  log.i(("dispatching vscode.capture for %d mac windows"):format(#by_cat.vscode))
  snap.vscode  = vscode_mod.capture(by_cat.vscode)
  log.i(("vscode.capture returned %d entries"):format(#snap.vscode))

  log.i(("dispatching gemini.capture for %d mac windows"):format(#by_cat.gemini))
  snap.gemini  = gemini_mod.capture(by_cat.gemini)
  log.i(("gemini.capture returned %d entries"):format(#snap.gemini))

  return snap
end

return M
