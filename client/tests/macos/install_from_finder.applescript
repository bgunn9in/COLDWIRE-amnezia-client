on pressButton(processName, namesToPress)
  tell application "System Events"
    if not (exists process processName) then return ""
    tell process processName
      if (count of windows) is 0 then return ""
      set widgets to entire contents of window 1
      repeat with widgetItem in widgets
        set widget to contents of widgetItem
        if role of widget is "AXButton" then
          set buttonName to name of widget
          if buttonName is missing value then set buttonName to description of widget
          if buttonName is in namesToPress and enabled of widget then
            click widget
            return buttonName
          end if
        end if
      end repeat
    end tell
  end tell
  return ""
end pressButton

on clickVisibleButton(buttonName)
  set workPath to system attribute "RUNNER_TEMP"
  set picturePath to workPath & "/finder-button.png"
  do shell script "/usr/sbin/screencapture -x " & quoted form of picturePath
  set positions to paragraphs of (do shell script quoted form of (workPath & "/find-button") & " " & quoted form of picturePath & " " & quoted form of buttonName)
  set xPosition to item 1 of positions as integer
  set yPosition to item 2 of positions as integer
  tell application "System Events" to click at {xPosition, yPosition}
end clickVisibleButton

on authenticate(installPassword)
  tell application "System Events"
    repeat with processName in {"SecurityAgent", "authorizationhost", "CoreServicesUIAgent", "System Settings", "Installer"}
      if exists process (contents of processName) then
        tell process (contents of processName)
          if (count of windows) > 0 then
            set widgets to entire contents of window 1
            repeat with widgetItem in widgets
              set widget to contents of widgetItem
              if role of widget is "AXTextField" and subrole of widget is "AXSecureTextField" then
                set frontmost to true
                repeat with fieldItem in widgets
                  set userField to contents of fieldItem
                  if role of userField is "AXTextField" and subrole of userField is not "AXSecureTextField" then
                    if value of userField is "runner" or name of userField is "User Name" then
                      set value of userField to "coldwireqa"
                      exit repeat
                    end if
                  end if
                end repeat
                set focused of widget to true
                keystroke installPassword
                key code 36
                return true
              end if
            end repeat
          end if
        end tell
      end if
    end repeat
  end tell
  return false
end authenticate

on run argv
  set packagePath to item 1 of argv
  set installPassword to system attribute "COLDWIRE_TEST_PASSWORD"
  if installPassword is "" then error "Missing temporary runner password"
  with timeout of 15 seconds
    do shell script "/usr/bin/open -R " & quoted form of packagePath
    delay 2
    tell application "System Events"
      tell process "Finder" to set frontmost to true
      keystroke "o" using {command down}
    end tell
    delay 3
    tell application "System Events" to tell process "CoreServicesUIAgent" to click button "Done" of window 1
    do shell script "/usr/bin/open 'x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Security'"
    delay 4
    if my pressButton("System Settings", {"Open Anyway", "Open Anyway…"}) is "" then my clickVisibleButton("Open Anyway")
    log "Requested approval for the candidate package"

    repeat 28 times
      set chosen to my pressButton("Installer", {"Close"})
      if chosen is not "" then return "Installer completed"
      if my authenticate(installPassword) then
        log "Submitted the temporary runner credentials"
        delay 3
      else
        set chosen to my pressButton("CoreServicesUIAgent", {"Open Anyway", "Open Anyway…", "Open"})
        if chosen is "" then set chosen to my pressButton("Installer", {"Use Password…", "Use Password...", "Continue", "Agree", "Install"})
        if chosen is not "" then log chosen
        delay 1
      end if
    end repeat

    tell application "System Events"
      repeat with processName in {"Installer", "CoreServicesUIAgent", "SecurityAgent", "System Settings"}
        if exists process (contents of processName) then
          tell process (contents of processName)
            log {name, name of windows, name of buttons of windows}
          end tell
        end if
      end repeat
    end tell
  end timeout
  error "The Finder installer did not finish"
end run
