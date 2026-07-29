-- Part 0: Configuration
set pwaUrlStart to "https://drive.google.com"
set pwaBundleID to "com.google.Chrome.app.aghbiahbpaijignceidepookljebhfak"
set foundWindowID to missing value
set findTimeoutSeconds to 60 -- Wait up to 60 seconds for the window to appear
set findLoopCounter to 0

-- Part 1: FIND the PWA window (with a waiting loop and timeout)
log "PHASE 1: Waiting for the PWA window..."
repeat until foundWindowID is not missing value
    tell application "Google Chrome"
        repeat with theWindow in every window
            try
                set currentTitle to title of theWindow
                set currentUrl to URL of tab 1 of theWindow
                
                if (currentTitle is "") and (currentUrl starts with pwaUrlStart) then
                    set foundWindowID to id of theWindow
                    exit repeat
                end if
            on error
                -- Ignore windows that might not have a tab 1, etc.
            end try
        end repeat
    end tell
    
    -- Timeout logic
    if foundWindowID is not missing value then
        log "   Window found! ID: " & foundWindowID
        exit repeat
    else
        set findLoopCounter to findLoopCounter + 1
        if findLoopCounter > findTimeoutSeconds then
            log "   TIMEOUT: Window not found after " & findTimeoutSeconds & " seconds."
            exit repeat
        end if
        delay 1 -- Wait 1 second before trying again
    end if
end repeat

-- (All the AppleScript code before this stays the same)

-- Part 2: ACT on the window ID if it was found
if foundWindowID is not missing value then
    log linefeed & "PHASE 2: ACTING on window ID " & foundWindowID
    
    tell application "Google Chrome"
        set targetWindow to window id foundWindowID
        set targetTab to tab 1 of targetWindow
        
        -- NEW: Use AppleScript to wait for the tab to finish loading
        set loadTimeoutSeconds to 30
        log "   Waiting for tab to finish loading (checking 'loading' property)..."
        repeat with i from 1 to loadTimeoutSeconds
            if loading of targetTab is false then
                log "   Tab has finished loading."
                exit repeat
            end if
            if i is loadTimeoutSeconds then
                log "   TIMEOUT: Tab was still loading after " & loadTimeoutSeconds & " seconds. Continuing anyway..."
            end if
            delay 1
        end repeat
        
        set targetWindow to window id foundWindowID
        
        execute tab 1 of targetWindow javascript "document.querySelector('[aria-label=\"My Drive\"]').click();"
    end tell
end if