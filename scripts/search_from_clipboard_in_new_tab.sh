#!/bin/bash

CHROME_EXEC="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
CLIPBOARD_CONTENT=$(pbpaste)
if [ -z "$CLIPBOARD_CONTENT" ]; then exit 0; fi

# Function to URL-encode a string safely
urlencode() {
  echo -n "$1" | python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read()));'
}

# Find all valid URLs in the clipboard content
VALID_URLS=()
while read -r line; do
  URL=$(echo "$line" | tr -d '[:space:]')
  if [[ "$URL" =~ ^(https?://)?([a-zA-Z0-9.-]+\.[a-zA-Z]{2,})(/.*)?$ ]]; then
    [[ "$URL" =~ ^https?:// ]] || URL="https://$URL"
    VALID_URLS+=("$URL")
  fi
done <<<"$CLIPBOARD_CONTENT"

# If URLs are found, open them; otherwise, perform a Google search
if [ ${#VALID_URLS[@]} -gt 0 ]; then
  "$CHROME_EXEC" "${VALID_URLS[0]}" >/dev/null 2>&1 &
else
  ENCODED_QUERY=$(urlencode "$CLIPBOARD_CONTENT")
  "$CHROME_EXEC" "https://www.google.com/search?q=${ENCODED_QUERY}" >/dev/null 2>&1 &
fi