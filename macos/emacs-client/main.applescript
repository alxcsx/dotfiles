-- Emacs Client AppleScript application.
--
-- Thin front-end for emacsclient: opens files/dirs in the Emacs server
-- (daemon), starting one if needed, so Finder/Spotlight users get a client
-- frame instead of a second standalone Emacs.
--
-- `open -a Emacs` is only a fallback: running it unconditionally opened a
-- second GUI Emacs window on every launch.

property emacsclientPath : "/opt/homebrew/bin/emacsclient"
property shellPath : "PATH='/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin'"

on open theDropped
	repeat with oneDrop in theDropped
		set dropPath to quoted form of POSIX path of oneDrop
		try
			do shell script shellPath & " " & emacsclientPath & " -c -a '' -n " & dropPath
		on error
			do shell script "open -a Emacs"
		end try
	end repeat
end open

-- Handle launch without files (from Spotlight, Dock, or Finder)
on run
	try
		do shell script shellPath & " " & emacsclientPath & " -c -a '' -n"
	on error
		do shell script "open -a Emacs"
	end try
end run

-- Handle org-protocol:// URLs (for org-capture, org-roam, etc.)
on open location this_URL
	try
		do shell script shellPath & " " & emacsclientPath & " -n " & quoted form of this_URL
	on error
		do shell script "open -a Emacs"
	end try
end open location
