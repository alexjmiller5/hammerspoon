local log              = hs.logger.new("Profile App Based Hotkeys", "debug")

local profileConstants = require("profiles.personal.constants")
local helperFunctions  = require("helperFunctions")
local constants        = require("constants")

local M                = {}

local actions          = {
  -- PWA
  pwaDevTools = function()
    hs.eventtap.keyStroke({ "cmd", "alt" }, "i")
  end,

  -- Notion
  copyNotionId = function()
    if helperFunctions.tryMenuItem({ "Edit", "Copy Link to Current Page" }) then
      hs.timer.doAfter(0.1, function()
        local url = hs.pasteboard.getContents()
        if not url then return end
        local clean_path = url:gsub("?.*", "")
        local id = clean_path:sub(-32)
        if id:match("^[a-fA-F0-9]+$") then
          hs.pasteboard.setContents(id)
          hs.alert.show("Notion ID Copied:\n" .. id)
        else
          hs.alert.show("No valid Notion ID found")
        end
      end)
    else
      hs.alert.show("Could not find 'Copy Link' menu item")
    end
  end,
  notionNewShifted = function() helperFunctions.tryMenuItem({ "File", "New Window" }) end,

  sendUrlToReceptor = function()
    local ok, url = hs.osascript.applescript(
      'tell application id "com.google.Chrome" to get URL of active tab of front window')
    if not ok or type(url) ~= "string" or url == "" then
      helperFunctions.reportError("Could not read the current Chrome tab URL")
      return
    end
    helperFunctions.runTask("/usr/bin/shortcuts", { "run", profileConstants.shortcutIds.receptor_outbox },
      function(code) if code == 0 then hs.alert.show("Queued in Receptor") end end, url)
  end,

  -- iMessage
  markReadUnread = function()
    if not helperFunctions.tryMenuItem({ "Conversation", "Mark as Read" }) then
      helperFunctions.tryMenuItem({ "Conversation", "Mark as Unread" })
    end
  end,

  -- Texts
  textsPrevChat = function() hs.eventtap.keyStroke({ "cmd", "shift" }, "[") end,
  textsNextChat = function() hs.eventtap.keyStroke({ "cmd", "shift" }, "]") end,

  -- T3 Chat
  t3ToggleSidebar = function() hs.eventtap.keyStroke({ "cmd" }, "b") end,

  -- 1Password
  hitCommandF = function()
    hs.eventtap.keyStroke({ "cmd" }, "f")
  end,

  -- 1Password + Photos share the same View-menu sidebar toggle
  toggleSidebarViaMenu = function()
    if not helperFunctions.tryMenuItem({ "View", "Show Sidebar" }) then
      helperFunctions.tryMenuItem({ "View", "Hide Sidebar" })
    end
  end,
}

-- App bundle-ID lists for `only`/`except`, defined once and shared so a repeated
-- app (Notion, Messages, Texts, 1Password each appear multiple times) isn't
-- spelled out on every definition. These lists are only read, never mutated.
local apps = {
  googleMaps  = { profileConstants.appBundleIds.googleMaps },
  notion      = { profileConstants.appBundleIds.notion },
  chrome      = { constants.appBundleIds.chrome },
  t3Chat      = { profileConstants.appBundleIds.t3Chat },
  messages    = { profileConstants.appBundleIds.messages },
  texts       = { profileConstants.appBundleIds.texts },
  onePassword = { profileConstants.appBundleIds.onePassword },
  photos      = { profileConstants.appBundleIds.photos },
}

M.definitions          = {
  -- Google Maps PWA
  {
    mods = { "cmd", "shift" },
    key = "d",
    action = actions.pwaDevTools,
    only = apps.googleMaps
  },

  -- Notion
  {
    mods = { "cmd", "shift" },
    key = "i",
    action = actions.copyNotionId,
    only = apps.notion
  },
  {
    mods = { "cmd" },
    key = "n",
    action = actions.notionNewShifted,
    only = apps.notion
  },
  -- Chrome
  {
    mods = { "cmd", "shift" },
    key = "s",
    action = actions.sendUrlToReceptor,
    only = apps.chrome
  },

  -- T3 Chat
  {
    mods = { "cmd" },
    key = "\\",
    action = actions.t3ToggleSidebar,
    only = apps.t3Chat
  },

  -- Messages
  {
    mods = { "cmd" },
    key = "u",
    action = actions.markReadUnread,
    only = apps.messages
  },

  -- Texts
  {
    mods = {},
    key = "up",
    action = actions.textsPrevChat,
    only = apps.texts
  },
  {
    mods = {},
    key = "down",
    action = actions.textsNextChat,
    only = apps.texts
  },

  -- 1Password
  {
    mods = { "cmd" },
    key = "k",
    action = actions.hitCommandF,
    only = apps.onePassword
  },
  {
    mods = { "cmd" },
    key = "\\",
    action = actions.toggleSidebarViaMenu,
    only = apps.onePassword
  },

  -- Photos
  {
    mods = { "cmd" },
    key = "\\",
    action = actions.toggleSidebarViaMenu,
    only = apps.photos
  },
}

return M
