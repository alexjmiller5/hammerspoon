local log              = hs.logger.new("Profile App Based Hotkeys", "debug")

local profileConstants = require("profile.constants")
local helperFunctions  = require("helperFunctions")
local constants        = require("constants")

local M                = {}

local actions          = {
  -- PWA
  pwaCloseWindow = function()
    hs.eventtap.keyStroke({ "cmd" }, "h")
  end,
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
  notionNewShifted = function() hs.eventtap.keyStroke({ "cmd", "shift" }, "n") end,
  notionCmdK = function() hs.eventtap.keyStroke({ "cmd" }, "k") end,
  notionSearch = function() hs.eventtap.keyStroke({ "cmd" }, "f") end,

  sendUrlToReceptor = function()
    local script = 'tell application "Google Chrome" to get URL of active tab of window 1'
    local ok, url = hs.osascript.applescript(script)
    if ok and url then
      local task = hs.task.new("/usr/bin/shortcuts", nil,
        { "run", profileConstants.shortcutIds.receptor_outbox })
      task:setInput(url)
      task:start()
      hs.alert.show("Sent to Receptor")
    else
      log.i("sendUrlToReceptor: Failed to create hs.task object.")
    end
  end,

  focusChrome = function()
    hs.application.launchOrFocusByBundleID(constants.appBundleIds.chrome)
  end,

  -- Mail
  mailClearSearch = function()
    hs.eventtap.keyStroke({ "cmd" }, "k")
    hs.timer.doAfter(0.05, function() hs.eventtap.keyStroke({}, "escape") end)
  end,

  -- iMessage
  markReadUnread = function()
    if not helperFunctions.tryMenuItem({ "Conversation", "Mark as Read" }) then
      helperFunctions.tryMenuItem({ "Conversation", "Mark as Unread" })
    end
  end,
  toggleMessagesSidebar = function()
    -- Reload the script: swiftc -O -framework AppKit -framework ApplicationServices ~/.hammerspoon/profile/scripts/toggle_messages_sidebar.swift -o ~/.hammerspoon/profile/scripts/toggle_messages_sidebar
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
  onePasswordToggleSidebar = function()
    if not helperFunctions.tryMenuItem({ "View", "Show Sidebar" }) then
      helperFunctions.tryMenuItem({ "View", "Hide Sidebar" })
    end
  end,

  -- Photos
  togglePhotosSidebar = function()
    if not helperFunctions.tryMenuItem({ "View", "Show Sidebar" }) then
      helperFunctions.tryMenuItem({ "View", "Hide Sidebar" })
    end
  end,

  -- LibreOffice
  quitFromLastWindow = function()
    log.i("--- [quitFromLastWindow] Triggered ---")

    local app = hs.application.frontmostApplication()
    if not app then
      log.e("[quitFromLastWindow] No frontmost application found. Exiting.")
      return
    end

    local bundleID = app:bundleID()

    -- FIX: Use #app:allWindows() instead of app:countWindows()
    local windowCount = #app:allWindows()

    log.i(string.format("[quitFromLastWindow] App: %s | BundleID: %s | Window Count: %d", app:name(), bundleID,
      windowCount))

    if windowCount <= 1 then
      log.i("[quitFromLastWindow] Condition Met: Window count <= 1. Sending Cmd+Q to quit app.")
      -- app:kill()
      hs.eventtap.keyStroke({ "cmd", "shift" }, "q")
    else
      log.i("[quitFromLastWindow] Condition Met: Window count > 1. Proceeding to pass-through Cmd+W.")

      helperFunctions.disableHotkeysForApp(AppBasedHotkeyRegistry, bundleID)

      hs.eventtap.keyStroke({ "cmd" }, "w")

      hs.timer.doAfter(0.1, function()
        helperFunctions.enableHotkeysForApp(AppBasedHotkeyRegistry, bundleID)
        log.i("--- [quitFromLastWindow] Sequence Complete ---")
      end)
    end
  end,
}

M.definitions          = {
  -- Google Maps PWA
  -- { mods = { "cmd" },          key = "w", action = actions.pwaCloseWindow,
  --   only = { profileConstants.appBundleIds.googleMaps } },
  {
    mods = { "cmd", "shift" },
    key = "d",
    action = actions.pwaDevTools,
    only = { profileConstants.appBundleIds.googleMaps }
  },

  -- Notion
  {
    mods = { "cmd", "shift" },
    key = "i",
    action = actions.copyNotionId,
    only = { profileConstants.appBundleIds.notion }
  },
  {
    mods = { "cmd" },
    key = "n",
    action = actions.notionNewShifted,
    only = { profileConstants.appBundleIds.notion }
  },
  -- { mods = { "cmd", "shift" }, key = "k", action = actions.notionCmdK,
  --   only = { profileConstants.appBundleIds.notion } },
  {
    mods = { "cmd" },
    key = "k",
    action = actions.notionSearch,
    only = { profileConstants.appBundleIds.notion }
  },

  -- Chrome
  {
    mods = { "cmd", "shift" },
    key = "s",
    action = actions.sendUrlToReceptor,
    only = { constants.appBundleIds.chrome }
  },
  -- { mods = constants.hyperKeyMods, key = "b", action = actions.sendUrlToReceptor,
  --   only = { constants.appBundleIds.chrome } },
  {
    mods = constants.hyperKeyMods,
    key = "b",
    action = actions.focusChrome,
    except = { constants.appBundleIds.chrome }
  },

  -- T3 Chat
  {
    mods = { "cmd" },
    key = "\\",
    action = actions.t3ToggleSidebar,
    only = { profileConstants.appBundleIds.t3Chat }
  },

  -- Mail
  -- { mods = {}, key = "escape", action = actions.mailClearSearch,
  --   only = { profileConstants.appBundleIds.mail } },

  -- Messages
  {
    mods = { "cmd" },
    key = "u",
    action = actions.markReadUnread,
    only = { profileConstants.appBundleIds.messages }
  },
  {
    mods = { "cmd" },
    key = "\\",
    action = actions.toggleMessagesSidebar,
    only = { profileConstants.appBundleIds.messages }
  },

  -- WhatsApp
  {
    mods = { "cmd" },
    key = "u",
    action = actions.markReadUnread,
    only = { profileConstants.appBundleIds.whatsapp }
  },

  -- Texts
  {
    mods = {},
    key = "up",
    action = actions.textsPrevChat,
    only = { profileConstants.appBundleIds.texts }
  },
  {
    mods = {},
    key = "down",
    action = actions.textsNextChat,
    only = { profileConstants.appBundleIds.texts }
  },

  -- 1Password
  {
    mods = { "cmd" },
    key = "k",
    action = actions.hitCommandF,
    only = { profileConstants.appBundleIds.onePassword }
  },
  {
    mods = { "cmd" },
    key = "\\",
    action = actions.onePasswordToggleSidebar,
    only = { profileConstants.appBundleIds.onePassword }
  },

  -- LibreOffice
  {
    mods = { "cmd" },
    key = "w",
    action = actions.quitFromLastWindow,
    only = { profileConstants.appBundleIds.libreoffice }
  },

  -- Photos
  {
    mods = { "cmd" },
    key = "\\",
    action = actions.togglePhotosSidebar,
    only = { profileConstants.appBundleIds.photos }
  },
}

return M
