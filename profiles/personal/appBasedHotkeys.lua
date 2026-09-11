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
    -- Active tab URL via chrome-cli (replaces the "get URL of active tab" osascript)
    local url = hs.execute("/opt/homebrew/bin/chrome-cli info | awk '/^Url: /{print substr($0,6)}'")
        :gsub("%s+$", "")
    if url ~= "" then
      local task = hs.task.new("/usr/bin/shortcuts", nil,
        { "run", profileConstants.shortcutIds.receptor_outbox })
      task:setInput(url)
      task:start()
      hs.alert.show("Sent to Receptor")
    else
      log.i("sendUrlToReceptor: could not read active tab URL from chrome-cli")
    end
  end,

  focusChrome = function()
    hs.application.launchOrFocusByBundleID(constants.appBundleIds.chrome)
  end,

  -- iMessage
  markReadUnread = function()
    if not helperFunctions.tryMenuItem({ "Conversation", "Mark as Read" }) then
      helperFunctions.tryMenuItem({ "Conversation", "Mark as Unread" })
    end
  end,
  toggleMessagesSidebar = function()
    -- Rebuild the script: swiftc -O -framework AppKit -framework ApplicationServices ~/.hammerspoon/profiles/personal/scripts/toggle_messages_sidebar.swift -o ~/.hammerspoon/profiles/personal/scripts/toggle_messages_sidebar
    hs.task.new(profileConstants.paths.toggleMessagesSidebar, nil):start()
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
  whatsapp    = { profileConstants.appBundleIds.whatsapp },
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
  {
    mods = constants.hyperKeyMods,
    key = "b",
    action = actions.focusChrome,
    except = apps.chrome
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
  {
    mods = { "cmd" },
    key = "\\",
    action = actions.toggleMessagesSidebar,
    only = apps.messages
  },

  -- WhatsApp
  {
    mods = { "cmd" },
    key = "u",
    action = actions.markReadUnread,
    only = apps.whatsapp
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
