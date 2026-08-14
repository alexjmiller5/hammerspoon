local M = {}

M.profileName = "Personal"

local home = os.getenv("HOME")

-- Application Bundle IDs
M.appBundleIds = {
  googleMaps     = "com.google.Chrome.app.mnhkaebcjjhencmpkapnbdaogjamfbcj",
  gemini         = "com.alexmiller.geminidesktop",
  t3Chat         = "com.google.Chrome.app.dbocekhhejgjkfgihlgonbpbikbcbdbd",
  youtube        = "com.google.Chrome.app.agimnkijcaahngcdmfeangaknmldooml",
  karabiner      = "org.pqrs.Karabiner-Elements.Settings",
  legcord        = "app.legcord.Legcord",
  mail           = "com.apple.mail",
  messages       = "com.apple.MobileSMS",
  notion         = "notion.id",
  notionCalendar = "com.cron.electron",
  photos         = "com.apple.Photos",
  whatsapp       = "net.whatsapp.WhatsApp",
  onePassword    = "com.1password.1password",
  texts          = "com.kishanbagaria.jack",
  libreoffice    = "org.libreoffice.script",
  telegram       = "ru.keepcoder.Telegram"

}

M.paths = {
  desktopFolder          = home .. "/Desktop",
  documentsFolder        = home .. "/Documents",
  applicationsFolder     = "/Applications",
  toggleMessagesSidebar  = home .. "/.hammerspoon/profiles/personal/scripts/toggle_messages_sidebar",
  marioWaowAudioFilePath = home .. "/Documents/sound-bites/Mario Waow.mp3"
}

M.shortcutIds = {
  receptor_outbox = "F260718B-F555-4052-8432-F6098375AB56",
}

return M
