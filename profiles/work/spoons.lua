local log = hs.logger.new("Spoons", "debug")

hs.loadSpoon("TextClipboardHistory")
spoon.TextClipboardHistory:start()
spoon.TextClipboardHistory:bindHotkeys({
  toggle_clipboard = {{"cmd", "shift"}, "h"}
})

log.i("TextClipboardHistory Spoon loaded!")