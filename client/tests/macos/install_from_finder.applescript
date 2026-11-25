on pressButton(processName, namesToPress)
  tell application "System Events"
    if not (exists process processName) then return ""
    tell process processName
      repeat with currentWindow in windows
        repeat with control in entire contents of currentWindow
          if role of control is "AXButton" then
            set label to name of control
            if label is in namesToPress and enabled of control then
              click control
              return label
            end if
          end if
        end repeat
      end repeat
    end tell
  end tell
  return ""
end pressButton

on authenticate(installPassword)
  tell application "System Events"
    repeat with processName in {"SecurityAgent", "authorizationhost", "CoreServicesUIAgent", "System Settings", "Installer"}
      if exists process (contents of processName) then
        tell process (contents of processName)
          repeat with currentWindow in windows
            repeat with control in entire contents of currentWindow
              if (subrole of control) is "AXSecureTextField" then
                set frontmost to true
                repeat with userField in entire contents of currentWindow
                  if role of userField is "AXTextField" and subrole of userField is not "AXSecureTextField" then
                    if value of userField is "runner" or name of userField is "User Name" then
                      set value of userField to "coldwireqa"
                      exit repeat
                    end if
                  end if
                end repeat
                set focused of control to true
                keystroke installPassword
                key code 36
                return true
              end if
            end repeat
          end repeat
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
    tell application "Finder" to open (POSIX file packagePath as alias)
    delay 3
    if my pressButton("CoreServicesUIAgent", {"Done", "OK"}) is not "" then
      do shell script "/usr/bin/open 'x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension'"
    end if

    repeat 65 times
      set chosen to my pressButton("Installer", {"Close"})
      if chosen is not "" then return "Installer completed"
      if my authenticate(installPassword) then
        log "Submitted the temporary runner credentials"
        delay 3
      else
        set chosen to my pressButton("CoreServicesUIAgent", {"Open Anyway", "Open Anyway…", "Open"})
        if chosen is "" then set chosen to my pressButton("System Settings", {"Open Anyway", "Open Anyway…"})
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
