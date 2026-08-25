local M = {}

M.profileName = "Work"

local home = os.getenv("HOME")

-- Application Bundle IDs. gemini/youtube are required by the base config's
-- alt+G / alt+Y launchers; PWA ids are machine-specific, so override them in
-- work-local.lua (below) if those PWAs exist on the work machine.
M.appBundleIds = {
  gemini  = "com.google.Chrome.app.caidcmannjgahlnhpmdmihecjcoiigg",
  youtube = "com.google.Chrome.app.agimnkijcaahngcdmfeangaknmldooml",
}

-- Required by the base config's folder-opening hotkeys (alt+shift+D/E/A).
M.paths = {
  desktopFolder      = home .. "/Desktop",
  documentsFolder    = home .. "/Documents",
  applicationsFolder = "/Applications",
}

-- The always-alive Chrome tab group. match = plain substring of the tab URL;
-- url = what to open when no tab matches (empty = never auto-open).
M.tabs = {
  gmail    = { match = "mail.google.com", url = "https://mail.google.com" },
  calendar = { match = "calendar.google.com", url = "https://calendar.google.com" },
  tasks    = { match = "tasks.google.com", url = "https://tasks.google.com" },
  drive    = { match = "drive.google.com", url = "https://drive.google.com" },
  slack    = { match = "app.slack.com", url = "https://app.slack.com/client" },
  -- jira: set the real board match/url in work-local.lua
  jira     = { match = "atlassian.net", url = "" },
}

-- Machine-local overrides: company-specific URLs, paths, and bundle ids live
-- OUTSIDE this public repo in ~/.config/hammerspoon/work-local.lua, a file
-- returning a table merged over M one level deep, e.g.
--   return { tabs = { jira = { match = "myco.atlassian.net", url = "https://..." } } }
local ok, localConf = pcall(dofile, home .. "/.config/hammerspoon/work-local.lua")
if ok and type(localConf) == "table" then
  for key, value in pairs(localConf) do
    if type(value) == "table" and type(M[key]) == "table" then
      for k, v in pairs(value) do M[key][k] = v end
    else
      M[key] = value
    end
  end
end

return M
