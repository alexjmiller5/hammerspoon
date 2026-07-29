local M = {}

M.profileName = "Work"

local home = os.getenv("HOME")

-- Application Bundle IDs
M.appBundleIds = {
  gemini         = "com.google.Chrome.app.caidcmannjgahlnhpmdmihecjcoiigg",
  youtube        = "com.google.Chrome.app.agimnkijcaahngcdmfeangaknmldooml",
  googleTasks    = "com.google.Chrome.app.okhfeehhillipaleckndoboggdkcebmo",
  googleCalendar = "com.google.Chrome.app.kjbdgfilnfhdofibpgamdcdgpehopbep",
  gmail          = "com.google.Chrome.app.fmgjjmmmlfnkbppncabfkddbjimcfncm",
  googleDrive    = "com.google.Chrome.app.aghbiahbpaijignceidepookljebhfak",
}

M.paths = {
  clickMyDrive               = home .. "/.local/bin/click-my-drive-button.applescript",
  openGooglePasswordsManager = home .. "/.local/bin/open-google-passwords-manager.applescript",
  artifactoryRepo            = home ..
  "/Library/CloudStorage/GoogleDrive-<work-email>/My Drive/Desktop/repos/Artifactory-Artifactory",
  driveDesktop               = home ..
  "/Library/CloudStorage/GoogleDrive-<work-email>/My Drive/Desktop",
  driveDownloads             = home ..
  "/Library/CloudStorage/GoogleDrive-<work-email>/My Drive/Downloads",
  driveDocuments             = home ..
  "/Library/CloudStorage/GoogleDrive-<work-email>/My Drive/Documents",
}

return M
