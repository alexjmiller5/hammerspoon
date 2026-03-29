#!/bin/bash
kill -9 "$(osascript -e 'tell application "System Events" to get unix id of first process whose frontmost is true and background only is false')"