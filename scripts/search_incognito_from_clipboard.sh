# Pure bash URL encoding function
urlencode() {
  local string="$1"
  local length="${#string}"
  local encoded=""
  local i c
  for ((i = 0; i < length; i++)); do
    c="${string:$i:1}"
    case "$c" in
      [a-zA-Z0-9.~_-])
        encoded+="$c"
        ;;
      ' ')
        encoded+="+"
        ;;
      *)
        encoded+=$(printf '%%%02X' "'$c")
        ;;
    esac
  done
  echo "$encoded"
}

# Get the clipboard content
CLIPBOARD_CONTENT=$(pbpaste)

# Array for valid URLs
VALID_URLS=()

# Process each line from the clipboard
while read -r line; do
  URL=$(echo "$line" | tr -d '[:space:]')
  if [[ "$URL" =~ ^(https?://)?([a-zA-Z0-9.-]+\.[a-zA-Z]{2,})(/.*)?$ ]]; then
    if [[ ! "$URL" =~ ^https?:// ]]; then
      URL="https://$URL"
    fi
    VALID_URLS+=("$URL")
  fi
done <<<"$CLIPBOARD_CONTENT"

if [ ${#VALID_URLS[@]} -gt 0 ]; then
  # 1. Open the first URL in a new incognito window and activate Chrome
  osascript \
    -e 'tell application "Google Chrome"' \
    -e '  set new_window to make new window with properties {mode:"incognito"}' \
    -e '  set URL of active tab of new_window to "'"${VALID_URLS[0]}"'"' \
    -e '  activate' \
    -e 'end tell'

  # 2. If there are more URLs, open them in new tabs in the frontmost window
  if [ ${#VALID_URLS[@]} -gt 1 ]; then
    # A brief pause to ensure the window is ready for new tabs
    sleep 0.2
    for i in $(seq 1 $((${#VALID_URLS[@]} - 1))); do
      osascript \
        -e 'tell application "Google Chrome"' \
        -e '  tell front window to make new tab with properties {URL:"'"${VALID_URLS[$i]}"'"}' \
        -e 'end tell'
    done
  fi
elif [ -n "$CLIPBOARD_CONTENT" ]; then
  # Use bash function to encode the clipboard text
  ENCODED_QUERY=$(urlencode "$CLIPBOARD_CONTENT")
  SEARCH_URL="https://www.google.com/search?q=${ENCODED_QUERY}"

  # Open the search URL in a new incognito window
  osascript \
    -e 'tell application "Google Chrome"' \
    -e '  set new_window to make new window with properties {mode:"incognito"}' \
    -e '  set URL of active tab of new_window to "'"$SEARCH_URL"'"' \
    -e '  activate' \
    -e 'end tell'
else
  echo "Clipboard is empty."
  exit 1
fi