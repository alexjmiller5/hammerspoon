use AppleScript version "2.4"
use scripting additions

on run argv
    -- 1. Input validation
    if (count of argv) is 0 then
        return "Error: No JavaScript code provided."
    end if
    
    set payloadJs to item 1 of argv
    
    tell application "Google Chrome"
        -- OPTIMIZATION 1: Check the frontmost window (Standard Chrome Tabs)
        try
            if (execute active tab of window 1 javascript "document.hasFocus()") is true then
                execute active tab of window 1 javascript payloadJs
                return "Success: Window 1"
            end if
        end try
        
        -- OPTIMIZATION 2: Check the LAST window (PWA Shim usually sits at the end of the list)
        try
            set lastIndex to count of windows
            if lastIndex > 1 then
                if (execute active tab of window lastIndex javascript "document.hasFocus()") is true then
                    execute active tab of window lastIndex javascript payloadJs
                    return "Success: Last Window"
                end if
            end if
        end try
        
        -- OPTIMIZATION 3: If those fail, get ALL windows in memory and loop
        -- This prevents doing O(N) IPC calls if we don't have to
        set allWindows to every window
        
        repeat with w in allWindows
            try
                -- We already checked 1 and last, but checking again is negligible speed cost
                -- compared to missing a window in the middle.
                if (execute active tab of w javascript "document.hasFocus()") is true then
                    execute active tab of w javascript payloadJs
                    return "Success: Window ID " & (id of w)
                end if
            end try
        end repeat
    end tell
    
    return "Error: No focused Chrome window found."
end run