-- Picks Team → “(Personal Team)” in the visible Signing & Capabilities editor.
-- Then Command-S so the Team ID is written into the project (both targets stamped by the shell).

on uiKids(e)
	try
		return UI elements of e
	on error
		return {}
	end try
end uiKids

on walkName(e, theName, d)
	if d > 14 then return missing value
	try
		if name of e is theName then return e
	end try
	repeat with c in uiKids(e)
		set r to walkName(c, theName, d + 1)
		if r is not missing value then return r
	end repeat
	return missing value
end walkName

on walkPopups(e, d)
	set acc to {}
	if d > 14 then return acc
	try
		if role of e is "AXPopUpButton" then set end of acc to e
	end try
	repeat with c in uiKids(e)
		set acc to acc & my walkPopups(c, d + 1)
	end repeat
	return acc
end walkPopups

on walkCheck(e, theName, d)
	if d > 14 then return missing value
	try
		if (role of e is "AXCheckBox") and (name of e is theName) then return e
	end try
	repeat with c in uiKids(e)
		set r to walkCheck(c, theName, d + 1)
		if r is not missing value then return r
	end repeat
	return missing value
end walkCheck

tell application "Xcode" to activate
delay 1.0

tell application "System Events"
	if not UI elements enabled then return "NO_AX"
	tell process "Xcode"
		set frontmost to true
		delay 0.4
		if (count of windows) is 0 then return "NO_WIN"
		set win to window 1
		
		set tabBtn to my walkName(win, "Signing & Capabilities", 0)
		if tabBtn is not missing value then
			try
				click tabBtn
				delay 0.6
			end try
		end if
		
		set autoBox to my walkCheck(win, "Automatically manage signing", 0)
		if autoBox is not missing value then
			try
				if value of autoBox is 0 then
					click autoBox
					delay 0.4
				end if
			end try
		end if
		
		set pops to my walkPopups(win, 0)
		set teamPop to missing value
		repeat with p in pops
			set blob to ""
			try
				set blob to (value of p as string) & " " & (name of p as string) & " " & (description of p as string)
			end try
			set blobL to blob as string
			considering case
			end considering
			if blobL contains "Personal Team" and blobL does not contain "Unknown" then
				return "ALREADY"
			end if
			if blobL contains "Unknown" or blobL contains "None" or blobL contains "Team" or blobL contains "Add an Account" then
				set teamPop to p
				if blobL contains "Unknown" or blobL contains "None" then exit repeat
			end if
		end repeat
		if teamPop is missing value then return "NO_POPUP:" & (count of pops as string)
		
		click teamPop
		delay 0.5
		set picked to false
		try
			repeat with mi in menu items of menu 1 of teamPop
				set n to name of mi as string
				if n contains "Personal Team" then
					click mi
					set picked to true
					exit repeat
				end if
			end repeat
		end try
		if picked is false then return "NO_PERSONAL"
		delay 0.8
	end tell
end tell

tell application "System Events"
	keystroke "s" using command down
end tell
delay 0.5
return "OK"
