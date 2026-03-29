#!/bin/bash

CHROME_EXEC="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
CLIPBOARD_CONTENT=$(pbpaste)
if [ -z "$CLIPBOARD_CONTENT" ]; then exit 0; fi

# Extract URLs using grep to handle mixed text/markdown
# This creates an array of all matches found
IFS=$'\n' VALID_URLS=($(echo "$CLIPBOARD_CONTENT" | grep -Eo 'https?://[a-zA-Z0-9./?=_%:-]+'))

if [ ${#VALID_URLS[@]} -gt 0 ]; then
  # Use "${VALID_URLS[@]}" to pass ALL found URLs to Chrome
  "$CHROME_EXEC" --new-window "${VALID_URLS[@]}" >/dev/null 2>&1 &
else
  # Fallback to search
  ENCODED_QUERY=$(echo -n "$CLIPBOARD_CONTENT" | python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read()));')
  "$CHROME_EXEC" --new-window "https://www.google.com/search?q=${ENCODED_QUERY}" >/dev/null 2>&1 &
fi