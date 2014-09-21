#NoEnv
#SingleInstance Off
SendMode Input
SetMouseDelay, 2000
SetWorkingDir %A_ScriptDir%
SetBatchLines, -1
SetTitleMatchMode, 2

CoordMode, ToolTip, Screen
CoordMode, Mouse, Screen
DetectHiddenWindows, On

;==========================================================================================
;=========COMMAND LINE PARAMETERS==========================================================
;==========================================================================================

If %0% != 0
{
	Command = CMD_%1%
	PARAMETER = %2%
	If IsLabel(Command) {
		commandLine := True
		Gosub %Command%
		ExitApp, 1
	}
	
	xpath_load(configXML, "config.xml")
	LoadConfig()
	commandName = %1%
	
	If (learnasArray[commandName] != "")
	{
		runPath := learnasArray[commandName]
		Run % runPath, % GetDirectory(runPath)
		ExitApp, 1
	}
	Else
		ExitApp, 0
}

;==========================================================================================
;=========USER CONFIGURATION===============================================================
;==========================================================================================

global commandFont = "Trebuchet MS"
global commandTextSize = 40
global commandBackground = "Black"
global commandForeground = "White"

global messageFont = "Trebuchet MS"
global messageTextSize = 40
global messageBackground = "Black"
global messageForeground = "White"

global notesFont = "Trebuchet MS"
global notesBackground = "Black"
global notesForeground = "White"

global tipTextSize = 20 ; Command tip box text size (px)
global tipLineHeight = 0.75 ; Spacing between the lines in the command tip box (percentage of tip box font size)
global tipLineOffset = 10 ; Pixels to add to the bottom margin of the tip bar

global fadeSteps = 1000 ; Number of steps in the fade animation (messages, command box)
global slideSteps = 10 ; Number of steps in the slide animation (command tips)
global borderFixEnable := True ; Gets rid of the white border around the command box
global redrawFixEnable := False ; LAGGY. Fixes command box redraw problems on some machines (Win XP?)

global autocompleteStyle = "New" ; "New" for a slide-out menu of options; "Old" for in-line autocompletion of the most popular command
global threshold = 2 ; Minimum number of characters to start matching commands (there are some problems with value 1)
global tipMaxLines = 10 ; Maximum number of lines in a tip

global persistent := False ; Enter to execute commands

;==========================================================================================
;=========SETUP============================================================================
;==========================================================================================

startTime := A_TickCount

Menu, Tray, Icon, Shell32.dll, 134 
xpath_load(configXML, "config.xml")
RefreshCommandsList()
LoadConfig()

Message("automate 1.0.0`nLoaded in " . A_TickCount - startTime . " ms" (newCommands ? "`nNew commands: " newCommands : "") (oldCommands ? "`nDeleted commands: " oldCommands : ""),,20,, (newCommands or oldCommands ? 4000 : 1000))

;==========================================================================================
;=========GLOBAL VARIABLES=================================================================
;==========================================================================================

CommandHistory := []
HISTORYLENGTH = 20
HISTORYCOUNTER = 0
tipSelectedLine = 1
tipScrollMode := True

;==========================================================================================
;=========MESSAGE HANDLERS=================================================================
;==========================================================================================

OnMessage(0x4a, "Receive_WM_COPYDATA")  ; 0x4a is WM_COPYDATA
OnExit, ExitSub

;==========================================================================================
;=========HOTKEYS==========================================================================
;==========================================================================================

WheelUp::
	Volume("Up")
	Return

WheelDown::
	Volume("Down")
	Return

; <^>!ä::SendInput {^} ; Finally this works properly... not going to write French anyway, but works only if default language is Estonian :D
<^>!a::SendInput å
<^>!+a::SendInput Å
<^>!o::SendInput °
<^>!.::SendInput ·

ScrollLock::SendInput {Home} ; Some ergonomical remapping here :)
Pause::SendInput {End}
+ScrollLock::SendInput +{Home}
+Pause::SendInput +{End}
^ScrollLock::SendInput ^{Home}
^Pause::SendInput ^{End}
NumpadDot::SendInput .

AppsKey::Gosub CMD_notes

CapsLock::
	Suspend, Off
	If suspended
	{
		Message("Hotkeys on",,,,500)
		suspended := False
		Return
	}
		
	IfWinExist, msgWindow
	{
		WinGetPos,, msgWindowY,, msgWindowH, msgWindow
		newY := Floor((A_ScreenHeight-commandBoxH)/2 - msgWindowH - 30)
		If (newY != msgWindowY)
			Gui, 3:Show, % "y" (newY > 0 ? newY : commandBoxH ? 0 : "Center")
	}
		
	WinGetActiveTitle, activeTitleTemp
	If activeTitleTemp != commandWindow
		activeTitle := activeTitleTemp
	
	IfWinNotExist, commandWindow
	{
		Gui 2:+AlwaysOnTop -Caption +ToolWindow
		Gui, 2:Color, %commandBackground%, %commandBackground%
		Gui, 2:Font, s%commandTextSize%, %commandFont%
		Gui, 2:Margin,0,0
		Gui, 2:Add, Edit, r1 c%commandForeground% vcommandBox gCommandBoxChanged HwndcommandBoxHwnd
			
		GuiControlGet, commandBox, 2:Pos
		Gui, 2:Font, s%tipTextSize%
		Gui, 2:Add, Text, % "x20 y+-5 w" commandBoxW-24 " r" tipMaxLines "  -Wrap c" commandForeground " BackgroundTrans vcommandTip"
		Gui, 2:Add, Text, x3 yp-1 w15 r%tipMaxLines% c%commandForeground% BackgroundTrans vtipSelector, >
		
		If borderFixEnable
			Gui, 2:Add, Picture, x0 y0 w%commandBoxW% h%commandBoxH% vborderFix, img\frame.bmp
	}
	
	IfWinNotActive, commandWindow
	{
		Gui, 2:Show,Center h%commandBoxH%,commandWindow
		WinSet, Transparent, 150, commandWindow
	}
		
	Goto CommandBoxChanged 
	Return

CapsLock Up::
	If persistent
		Return
		
CommandExecute:
	GuiControlGet,COMMANDINPUT,2:,commandBox
		
	If StrLen(tempCmd) >= threshold and autocompleteStyle = "New" and !literalMode
	{
		commandName := TopMatches(tempCmd, commandArray, tipSelectedLine)
		PARAMETER := tempParam
	}
	Else
	{
		commandInputArray := DecomposeCommand(COMMANDINPUT)
		commandName := commandInputArray[1]
		PARAMETER := commandInputArray[2]
	}
	
	GuiControl, 2:, commandBox,
	autoClear := True ; Used to disable the resize animation
	FadeGUI(2, "commandWindow")
	commandLabel := "CMD_" commandName 
	
	If IsLabel(commandLabel)
	{
		Gosub, %commandLabel%
		UpdateCommandUsage(commandName)
		UpdateCommandHistory(Trim(commandName " " PARAMETER))
	}
	Else If COMMANDINPUT
	{
		If runPath := learnasArray[commandName]
		{
			If PARAMETER = target
				Run % "explorer /select, " runPath
			Else
			{
				Run % runPath, % GetDirectory(runPath)
				UpdateCommandUsage(commandName)
			}
			UpdateCommandHistory(Trim(commandName " " PARAMETER))
		}
		Else
		{	
			If fileMode
				COMMANDINPUT := GetFilePath(COMMANDINPUT, tipSelectedLine)
			
			Run % COMMANDINPUT,, UseErrorLevel
			If ErrorLevel
				Message("Invalid command", GetErrorString(A_LastError))
			Else
				UpdateCommandHistory(COMMANDINPUT)
		}
	}
		
	; Clearing
	PARAMETER =
	COMMANDINPUT =
	HISTORYCOUNTER = 0
	tempCmd =
	tipScrollMode := False
	literalMode := False
	Return
	
SC029::Gosub, CMD_suspend ;SUSPEND ALL HOTKEYS

#a::
	WinGetTitle, activeTitle, A
	WinSet, AlwaysOnTop, Toggle, A
	Message("Toggled always on top", activeTitle)
	Return
	
#IfWinActive notesWindow
	
	>^Right::NotesTab("r")
	>^Left::NotesTab("l")
	>^Up::NotesTab("b")
	>^Down::NotesTab("s")
		
	~Backspace::
	~Enter::
	~Tab::
		RefreshNotes()
		Return
	
#If WinActive("ahk_class AutoHotkeyGUI") or WinActive("ahk_class Notepad") ;Fixes ctrl+backspace in notes and notepad

	^Backspace::
		Send ^+{Left}{Backspace}
		Return
	
#IfWinActive msgWindow

	Esc::
		cancelUpload := True
		Return

#IfWinActive commandWindow ;Command history and autocomplete logic

	Esc::
		COMMANDINPUT = 
		tempCmd =
		HISTORYCOUNTER = 0
		GuiControl,2:,commandBox,
		autoClear := True ; Used to disable the resize animation
		FadeGUI(2,"commandWindow")
		Return
		
	Up::
		If tipScrollMode and tipLines > 1
		{
			tipSelectedLine -= tipSelectedLine > 1 ? 1 : -tipLines + 1
			UpdateTipSelection()
			Return
		}
		
		If (CommandHistory.MaxIndex()-HISTORYCOUNTER != 0)
			HISTORYCOUNTER++
		GuiControl,2:,commandBox,% CommandHistory[CommandHistory.MaxIndex()-HISTORYCOUNTER+1]
		SendInput {End}
		Return
		
	Down::
		If tipLines > 1
		{
			tipScrollMode := True
			tipSelectedLine += tipSelectedLine < tipLines ? 1 : -tipLines + 1
			UpdateTipSelection()
			Return
		}
		
		If (HISTORYCOUNTER != 0)
			HISTORYCOUNTER--
		GuiControl,2:,commandBox,% CommandHistory[CommandHistory.MaxIndex()-HISTORYCOUNTER+1]
		SendInput {End}
		Return
		
	Backspace::
		Send {Backspace}
		If (guessLength = 0 and textLength >= threshold)
			Send {Backspace}
		Return
		
	Delete::
		literalMode := True
		Return
		
	Tab::
		If (fileMode and (foundMatch := GetFilePath(boxText, tipSelectedLine)))
		{
			If InStr(FileExist(foundMatch), "D") ; Is a directory
				GuiControl, 2:, commandBox, % foundMatch "\"
			Else	
				GuiControl, 2:, commandBox, % foundMatch
			Send {End}
			Return
		}
		Else If (path := learnasArray[RTrim(boxText)]) ; If it is a learnas command
		{
			If InStr(FileExist(path), "D") ; Is a directory
				GuiControl, 2:, commandBox, % path "\"
			Else	
				GuiControl, 2:, commandBox, % path
			Send {End}
			Return
		}
		; Falls through to Enter:: and Space:: if not in file mode

	Enter::
		If persistent
			Goto CommandExecute
			
	Space::
		If (autocompleteStyle = "New" and !tempParam and StrLen(tempCmd) >= threshold and (foundMatch := TopMatches(tempCmd, commandArray, tipSelectedLine)))
		{
			GuiControl, 2:, commandBox, % foundMatch
			Send {End}{Space}
		}
		Else If (guessLength = 0 and textLength >= threshold)
			Send {End}{Space}
		Else
			Send {Space}
		Return

;==========================================================================================
;=========TIMERS===========================================================================
;==========================================================================================
msgOff:
	FadeGUI(3,"msgWindow",1)
	Return
	
timer:
	idleTime = 0
	Loop {
		SoundPlay, C:\Program Files (x86)\Worms Armageddon\FESfx\increaseiconnumber.WAV
		Message("Alarm",,,,80)
		If (A_TimeIdlePhysical < idleTime)
			Break
		idleTime := A_TimeIdlePhysical
		Sleep, 100
	}
	Return

;==========================================================================================
;=========PROCEDURES=======================================================================
;==========================================================================================

CommandBoxChanged:
	GuiControlGet, boxText, 2:, commandBox
	
	If autocompleteStyle = New
	{
		If autoClear
		{
			autoClear := False
			Return
		}
		
		If literalMode
		{
			Slide(2, "commandWindow", commandBoxH)
			Return
		}
		
		If RegExMatch(boxText, "S)^([a-zA-Z]:|\.)\\.*")
		{
			fileMode := True
			tempCmd = fileMode
			tempParam := boxText
		}
		Else
		{
			fileMode := False
			tempParamArray := DecomposeCommand(boxText)
			tempCmd := tempParamArray[1]
			tempParam := tempParamArray[2]
		}
		
		WinGetPos,,,, winH, commandWindow
		
		If ((tip := GetTip(tempCmd, tempParam)) and tip != oldTip)
		{
			StringReplace, tip_fixed, tip, &, && ; Fixes ampersands in tips showing as underlines for following letter
			GuiControl, 2:, commandTip, % tip_fixed
			GuiControl, 2:, tipSelector, >
			
			If (tipLines > tipMaxLines)
				tipLines := tipMaxLines
						
			slideHeight := Round(commandBoxH + tipTextSize*tipLines + tipTextSize*tipLineHeight*(tipLines-1) + tipLineOffset)
			If (winH != slideHeight)
				Slide(2, "commandWindow", slideHeight)
				
			tipSelectedLine = 1
			UpdateTipSelection()
		}
		Else If (!tip and winH != commandBoxH)
			Slide(2, "commandWindow", commandBoxH)
			
		oldTip := tip
	}
	
	Else If autocompleteStyle = Old
	{
		If (boxText = lastText)
			Return
		lastText := boxText
		textLength := StrLen(boxText)
		If (textLength >= threshold)
		{
			TopMatches := TopMatches(boxText, commandArray, 1)
			guessLength := StrLen(TopMatches)-StrLen(boxText)
			If (TopMatches = "" or guessLength = 0)
				Return
			GuiControl, 2:, commandBox, %TopMatches%
			Send {End}+{Left %guessLength%}
		}
	}
	
	Sleep 50 ; Limit CPU usage
	If GetKeyState("CapsLock", "P") ; Loops indefinitely if caps lock is held, getting rid of lag
		Goto CommandBoxChanged
		
	Return
	

;==========================================================================================
;=========FUNCTIONS========================================================================
;==========================================================================================
FadeGUI(targetGUI,targetWindow,destroy=0) {	
	startTime := A_TickCount
	
	WinGet, winTransparency, Transparent, %targetWindow%
	
	Loop, %fadeSteps% {
		If (A_TickCount - startTime > 2000) ; Timeout if the processor is too slow
			Break
		transparency := winTransparency-A_Index/(fadeSteps/winTransparency)
		WinSet, Transparent, %transparency%, %targetWindow%
	} 
	Gui, %targetGUI%:Hide
	If destroy
		Gui, %targetGUI%:Destroy
}

; Prints message	
Message(msg, text="", size=-1, width=0, timeout=2000, focus=0, manualClose=0) {
	global messageGUI
	global msgLabel, textLabel
	global commandLine
	
	transparency = 150
	
	If commandLine ; Supresses messages if the script is called from the command line and write to a file instead
	{
		FileDelete, temp\output.txt
		StringReplace, text, text, `n, |, All
		FileAppend, %msg%|%text%, temp\output.txt
		Return
	}
	
	If size = -1
		size := messageTextSize ; cannot set a default value to be a variable, so a bypass
	
	IfWinExist, msgWindow
		Gui, 3:Destroy
	
	If timeout = 0 ; never close
		focus = 1
	
	Gui 3:+AlwaysOnTop -Caption +ToolWindow
	Gui, 3:Color, %messageBackground%
	Gui, 3:Font,% "s" size
	Gui, 3:Font,, %messageFont%
	
	widthString := (width = 0) ? "" : "w" width

	If msg
		Gui, 3:Add, Text, Center %widthString% c%messageForeground% vmsgLabel, %msg%
		
	Gui, 3:Font,% "s" Round(size*0.7)
	
	If text
	{
		If FileExist(text)
		{
			Gui, 3:Add, Picture, Center gPictureLink, %text%
			transparency = OFF
		}
		Else
			Gui, 3:Add, Text, Left y+0 c%messageForeground% %widthString% vtextLabel, %text%
	}
	
	; GuiControlGet, msgLabel, 3:Pos
	; GuiControlGet, textLabel, 3:Pos
	; If (msgLabelW > A_ScreenWidth/2)
		; GuiControl, 3:Move, msgLabel, % "w" A_ScreenWidth/2
	; If (textLabelW > A_ScreenWidth/2)
		; GuiControl, 3:Move, textLabel, % "w" A_ScreenWidth/2

	Gui, 3:Show,% "AutoSize Center" (!focus ? " NoActivate" : ""), msgWindow
	WinSet, Transparent, %transparency%, msgWindow
	
	If timeout > 0
	{
		SetTimer, msgOff, -%timeout%
		If focus
		{
			timeout /= 1000.0
			Input, keyPressed, L1 V T%timeout%
			If !manualClose
				FadeGUI(3,"msgWindow",1)
			Return keyPressed
		}
	}
	Else If focus
	{
		Input, keyPressed, L1 V
		If !manualClose
			FadeGUI(3,"msgWindow",1)
		Return keyPressed
	}
}

; Volume controller
Volume(direction) {
	global volumeProgressBar
	
	MouseGetPos, MouseX, MouseY
	If (MouseX = 0) or (MouseX = A_ScreenWidth-1)
	{
		If MouseX = 0
			volumeStep = 3
		Else If (MouseX = A_ScreenWidth-1)
			volumeStep = 1
		If direction = Up
			Send {Volume_up %volumeStep%}
		Else If direction = Down
			Send {Volume_down %volumeStep%}
	}
	Else If (MouseY = A_ScreenHeight-1)
	{
		;;;;
	}
	Else
		normalKey := (direction = "Up") ? "{WheelUp}" : "{WheelDown}"
	Send %normalKey%
}

; Notes controller
NotesTab(cmd) {
	global tabIndex
	global notesFontSize1, notesFontSize2
	global configXML
	notesFontSize := tabIndex = 1 ? notesFontSize1 : notesFontSize2
	
	If (cmd = "r" || cmd = "l") ;next or previous tab
	{
		If tabIndex = 1
		{
			tabIndex = 2
			GuiControl, 4:Focus, notesTab%tabIndex%
			xpath(configXML, "/notes/@focused/text()", tabIndex)
			xpath_save(configXML, "config.xml")
			
		}
		Else
		{
			tabIndex = 1
			GuiControl, 4:Focus, notesTab%tabIndex%
			xpath(configXML, "/notes/@focused/text()", tabIndex)
			xpath_save(configXML, "config.xml")
		}
		RefreshNotes()
	}
	Else If cmd = b ;bigger text
	{
		If (notesFontSize < 20 and notesFontSize >= 10)
			sizeStep = 2
		Else If (notesFontSize < 10)
			sizeStep = 1
		Else
			sizeStep = 10
		notesFontSize := notesFontSize + sizeStep
		notesFontSize%tabIndex% := notesFontSize
		Gui, 4:Font, s%notesFontSize% cWhite
		GuiControl,4:Font, notesTab%tabIndex%
		GuiControl, 4:, sizeLabel%tabIndex%, %notesFontSize%
		
		xpath(configXML, "/notes/note[" . tabIndex . "]/@fontSize/text()", notesFontSize)
		xpath_save(configXML, "config.xml")
		
		RefreshNotes()
	}
	Else If cmd = s ;smaller text
	{
		If (notesFontSize <= 20 and notesFontSize > 10)
			sizeStep = 2
		Else If (notesFontSize <= 10 and notesFontSize > 1)
			sizeStep = 1
		Else If (notesFontSize = 1)
			sizeStep = 0
		Else
			sizeStep = 10
		notesFontSize := notesFontSize - sizeStep
		notesFontSize%tabIndex% := notesFontSize
		Gui, 4:Font, s%notesFontSize% cWhite
		GuiControl,4:Font, notesTab%tabIndex%
		GuiControl, 4:, sizeLabel%tabIndex%, %notesFontSize%
		
		xpath(configXML, "/notes/note[" . tabIndex . "]/@fontSize/text()", notesFontSize)
		xpath_save(configXML, "config.xml")
		
		RefreshNotes()
	}
	Else
	{
	}
}

RefreshNotes() {
	GuiControl, 4:MoveDraw, sizeLabel1
	GuiControl, 4:MoveDraw, sizeLabel2
	; GuiControl, 4:MoveDraw, separator
}

RefreshCommandsList() {
	global configXML, scriptFile, newCommands, oldCommands
	fileCommands := []
	counter = 0
	
	; Find new commands in the script and add them to the config file
	FileRead, scriptFile, %A_ScriptFullPath%
	Loop {
		counter := RegExMatch(scriptFile, "S)CMD_(\w*):", found, ++counter)
		If found1
		{
			fileCommands[found1] := True
			xmlRead := xpath(configXML, "/commands/regular/cmd[@name='" found1 "']/text()")
			If xmlRead =
			{
				xpath(configXML, "/commands/regular/cmd[+1]/@name/text()", found1)
				xpath(configXML, "/commands/regular/cmd[@name='" . found1 . "']/text()", 0)
				newCommands := newCommands ? newCommands ", " found1 : found1
			}
		}
		If counter = 0
			Break
	}
	
	; Remove old commands that do not exist in the script any more
	regularNames := xpath(configXML, "/commands/regular/cmd/@name/text()")
	StringSplit, regularNames, regularNames, `,
	Loop, %regularNames0%
	{
		If !fileCommands[regularNames%A_Index%]
		{
			oldCommands := oldCommands ? oldCommands ", " regularNames%A_Index% : regularNames%A_Index%
			xpath(configXML, "/commands/regular/cmd[@name='" regularNames%A_Index% "']/remove()")
		}
	}
	
	If newCommands or oldCommands
		xpath_save(configXML, "config.xml")
}

LoadConfig() {
	global configXML
	global commandArray := []
	global learnasArray := []
	
	commandNames := xpath(configXML, "/commands/*/cmd/@name/text()")
	commandUsages := xpath(configXML, "/commands/*/cmd/text()")
	learnasNames := xpath(configXML, "/commands/learnas/cmd/@name/text()")
	learnasPaths := xpath(configXML, "/commands/learnas/cmd/@path/text()")

	StringSplit, commandNames, commandNames, `,
	StringSplit, commandUsages, commandUsages, `,
	StringSplit, learnasNames, learnasNames, `,
	StringSplit, learnasPaths, learnasPaths, `,

	Loop, %commandNames0%
		commandArray[commandNames%A_Index%] := commandUsages%A_Index%
		
	Loop, %learnasNames0%
		learnasArray[learnasNames%A_Index%] := learnasPaths%A_Index%
}

UpdateCommandUsage(commandName) {
	global configXML
	
	curUsage := xpath(configXML, "/commands/*/cmd[@name='" commandName "']/text()")
	curUsage += 1
	xpath(configXML, "/commands/*/cmd[@name='" commandName "']/text()", curUsage)
	xpath_save(configXML,"config.xml")
	Return
}

UpdateCommandHistory(newEntry) {
	global CommandHistory, HISTORYLENGTH
	
	CommandHistory.Insert(newEntry)
	If (CommandHistory.MaxIndex() = HISTORYLENGTH+1)
		CommandHistory.Remove(1)
	Return
}

Debug(message) {
	global debugPID
	
	IfWinNotExist, ahk_pid %debugPID%
		Run, notepad.exe,, Min, debugPID
	WinWait, ahk_pid %debugPID%
	WinSetTitle, ahk_pid %debugPID%,, Debug output
	FormatTime, timeStamp,, [HH:mm:ss] `
	Control, EditPaste, % timeStamp message "`r`n",, ahk_pid %debugPID%
}

RouteOutput(input, target) {
	If target = copy
	{
		Clipboard := input
		Message("Data copied to clipboard")
	}
	Else If target = put
		Send % input
	Else
		Message(input)
}

; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; ~~~ Command helper slider window-ish thing ~~~
; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

GetTip(cmd, param) {
	global tipLines = 1
	global commandArray, scriptFile, boxText
	
	If IsLabel("GetTip-" cmd)
		Goto GetTip-%cmd%
	Else
		Goto GetTip-autocomplete

	GetTip-s:
		windowMatches := GetWin(param, True)
		matchCount := windowMatches.MaxIndex()
		tipLines := matchCount ? matchCount : 1
		Return % !param ? "" : !matchCount ? "Window not found" : GetList(windowMatches,, "", "nokey")
		
	GetTip-x:
		windowMatches := GetWin(param, True)
		matchCount := windowMatches.MaxIndex()
		tipLines := matchCount ? matchCount : 1
		Return % matchCount ? GetList(windowMatches,, "", "nokey") : param ? "Window not found" : ""
		
	GetTip-kill:
		If !param
			Return
		
		For process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process where Name like '" param "%'")
		{
			processes := processes "`n" process.Name
			tipLines := A_Index
		}
		Return % LTrim(processes, "`n")
		
	GetTip-fileMode:
		If StrLen(param) < threshold
			Return
			
		Loop, %param%*, 1
		{
			fileMatches := fileMatches ? fileMatches "`n" A_LoopFileName : A_LoopFileName
			tipLines := A_Index
			If (tipLines = tipMaxLines)
				Break
		}
		Return % fileMatches
		
	GetTip-tip:
		tipLines := 9
		Return "1`n2`n3`n4`n5`n6`n7`n8`n9"
	
	GetTip-autocomplete:
		If StrLen(cmd) < threshold
			Return
			
		If SubStr(boxText, 0) = A_Space or param ; You already know what you're doing if you're typing parameters
		{
			If !RegExMatch(scriptFile, "CMD_" cmd ": `; (.*)", paramTip)
				Return
			Else
				Return % cmd " " paramTip1
		}
		commandMatches := TopMatches(cmd, commandArray)
		tipLines := commandMatches.MaxIndex()
		Return % GetList(commandMatches,, "", "nokey")
}

UpdateTipSelection() {
	global tipSelectedLine, tipSelector
	selectorString =
	Loop, % tipSelectedLine - 1
		selectorString := selectorString "`n"
	GuiControl, 2:, tipSelector, % selectorString ">"
	Sleep, 75
}

; animation
Slide(guiNumber, windowName, newValue, options="") {
	global boxText, sliding
	If sliding
		Return

	sliding := True
	WinGetPos,, winY,, winH, % windowName
	If not InStr(options, "relative")
		newValue := newValue - winH
		
	points := SineTransition(slideSteps, winH, newValue)
	Loop, %slideSteps%
	{
		Gui, %guiNumber%:Show, % (InStr(options, "center") ? "Center ": "") "h" points[A_Index]
		Sleep, 5
	}
	
	If redrawFixEnable
	{
		; GuiControl, %guiNumber%:, commandBox, % boxText
		Send ^a{End}
	}
	
	sliding := False
}

SineTransition(steps, start, change) {
	points := []
	Loop, %steps%
		points[A_Index] := start + Round(change*(Sin(3.14159/2*A_Index/steps)))
	Return points
}

; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; ~~~ Calculator functions ~~~
; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Calc(expression) {
	n := "\d+\.?\d*"
	StringReplace, expression, expression, %A_Space%,, All
	expression := RegExReplace(expression, "(" n ")\(", "$1*(")
	
	FindOperation(expression, "\((-" n ")\)(\^)(-?" n ")")
	
	If RegExMatch(expression, "\((.*)\)", bracketContents)
		expression := RegExReplace(expression, "\Q" bracketContents "\E", Calc(bracketContents1))
	
	FindOperation(expression, "(" n ")(\^)(-?" n ")")
	FindOperation(expression, "(-?" n ")([*/])(-?" n ")")
	FindOperation(expression, "(-?" n ")([+\-])(-?" n ")")
	
	If expression is number
		Return % expression != Floor(expression) ? expression : Floor(expression)
}

FindOperation(ByRef expression, pattern) {
	Loop
		If i := RegExMatch(expression, pattern, expr, i := 1)
			expression := RegExReplace(expression, "\Q" expr "\E", Operate(expr1, expr3, expr2))
	Until !i
}

Operate(operand1, operand2, operator) {
	IfEqual, operator, +, Return % operand1 + operand2
	IfEqual, operator, -, Return % operand1 - operand2
	IfEqual, operator, *, Return % operand1 * operand2
	IfEqual, operator, /, Return % operand1 / operand2
	IfEqual, operator, ^, Return % operand1 ** operand2
}

; ~~~~~~~~~~~~~~~~~
; ~~~ Utilities ~~~
; ~~~~~~~~~~~~~~~~~

SecToTime(val) {
	d := val//86400
	h := (val-86400*d)//3600
	m := (val-86400*d-3600*h)//60
	s := val-86400*d-3600*h-60*m
	Return % (d=0?"":d "d") (h=0?"":h "h") (m=0?"":m "m") (s=0?"":s "s") 
}

TimeToSec(str) {
	If not RegExMatch(str, "d|h|m|s")
		Return

	d := RegExMatch(str, "(\d+)d", d) ? d1 : 0
	h := RegExMatch(str, "(\d+)h", h) ? h1 : 0
	m := RegExMatch(str, "(\d+)m", m) ? m1 : 0
	s := RegExMatch(str, "(\d+)s", s) ? s1 : 0
	Return % d*86400 + h*3600 + m*60 + s
}

GetFilePath(filePattern, index=1, fullPath=True) {
	Loop, %filePattern%*, 1
		If (A_Index = index)
			Return % fullPath ? A_LoopFileFullPath : A_LoopFileName
}

GetDirectory(path) {
	Return SubStr(path, 1, InStr(path, "\", false, 0))
}

GetWin(title, arrayMode=False, index=1) {
	global activeTitle
	titleMatch := []
	defaultSetting := A_DetectHiddenWindows
	DetectHiddenWindows, Off
	
	If title =
	{
		WinGetTitle, match, %activeTitle%
		titleMatch[1] := match
		DetectHiddenWindows, %defaultSetting%
		Return % !arraymode ? titleMatch[index] : titleMatch
	}
	
	WinGet, id, list,,, Program Manager ; can't simply use WinGetTitle because titles are case sensitive
	Loop, %id%
	{
		this_id := id%A_Index%
		WinGetTitle, match, ahk_id %this_id%
		If(InStr(match,title) > 0 and match != "commandWindow")
			titleMatch.Insert(match)
	}
	DetectHiddenWindows, %defaultSetting%
	Return % !arraymode ? titleMatch[index] : titleMatch
}

GetErrorString(Errornumber) { ; By Thalon (http://www.autohotkey.com/community/viewtopic.php?p=141050)
   VarSetCapacity(ErrorString, 1024)      ;String to hold the error-message.
   
   DllCall("FormatMessage"
         , UINT, 0x00001000         ;FORMAT_MESSAGE_FROM_SYSTEM: The function should search the system message-table resource(s) for the requested message.
         , UINT, NULL               ;A handle to the module that contains the message table to search.
         , UINT, Errornumber
         , UINT, 0                     ;Language-ID is automatically retreived
         , Str, ErrorString
         , UINT, 1024               ;Buffer-Length
         , str, "")               ;An array of values that are used as insert values in the formatted message. (not used)
   
   StringReplace, ErrorString, ErrorString, `r`n, %A_Space%, All      ;Replaces newlines by A_Space for inline-output
   
   return %ErrorString%
}

ArrayLength(array) {
	counter = 0
	For index in array
		counter++
	Return counter
}

DecomposeCommand(inputString, expectedNumber=2) {
	length := InStr(inputString,A_Space)-1
	If length = -1 ;No parameter
		returnArray := [inputString]
	Else ;Extract parameter
	{
		If (expectedNumber > 1 or expectedNumber <= 0)
		{
			returnArray := [SubStr(inputString,1,length)]
			For key, value in DecomposeCommand(SubStr(inputString,length+2,StrLen(inputString)-length), --expectedNumber)
				returnArray.Insert(value)
		}
		Else
			returnArray := [inputString]			
	}
	Return returnArray
}

GetList(array, delimeter="`n", separator="'", options="") {

	If options contains nokey
	{
		For key, value in array
		total := total . separator . value . separator . delimeter
	}
	Else If options contains novalue
	{
		For key, value in array
		total := total . separator . key . separator . delimeter
	}	
	Else
	{
		For key, value in array
		total := total . separator . key . separator . ": " . separator . value . separator . delimeter
	}
	StringTrimRight, total, total, StrLen(delimeter)
	Return total
}

ArrayMatch(string, array) {
	If string =
		Return
	
	matches := Object()

	For key, value in array
	{
		subString := SubStr(key, 1, StrLen(string))
		If subString = %string%
			matches.Insert(key)
	}
	Return matches
}

TopMatches(string, array, index = 0) {
	If !string
		Return
		
	matches := [0]

	For key, value in array
	{
		subString := SubStr(key,1,StrLen(string))
		If (subString = string)
		{
			Loop, % matchesLength := matches.MaxIndex()
			{
				If (value > array[matches[A_Index]])
				{
					matches.Insert(A_Index, key)
					Break
				}
			}
		}
		
	}
	matches.Remove(matches.MaxIndex())
	
	If index
		Return % matches[index]
	Else
		Return matches
}

;==========================================================================================
;=========CUSTOM COMMANDS==================================================================
;==========================================================================================

;=========SYSTEM & SCRIPT COMMANDS=========================================================

; Reloads AHK script
CMD_reload:
	Reload
	Return

; Exit AHK
CMD_exit:
	ExitApp
	Return

; Suspend AHK script
CMD_suspend:
	Message("Hotkeys off",,,,500)
	suspended := True
	Suspend
	Return

; Open My Computer	
CMD_computer:
	Run ::{20d04fe0-3aea-1069-a2d8-08002b30309d}
	Return

; Shutdown
CMD_shutdown:
	Shutdown, 1
	Return

; Restart	
CMD_reboot:
	Shutdown, 2
	Return

; Turn off screen softly
CMD_screen: ; {on | off}
	If PARAMETER = off
		SendMessage, 0x112, 0xF170, 2,, Program Manager
	Else
		MouseMove,1,0,,R
	Return

; Sleep Windows	
CMD_sleep:
	DllCall("PowrProf\SetSuspendState", "int", 0, "int", 0, "int", 0)
	Return

; Lock Windows
CMD_lock:
	DllCall("LockWorkStation", "int", 0, "int", 0, "int", 0)
	Return

; Caps Lock switch	
CMD_caps:
	SetCapslockState, % GetKeyState("CapsLock", "T") ? "Off" : "On"
	Return

; Switch to window which title starts with [PARAMETER]
CMD_s:
	If PARAMETER =
		Message("No target specified")

	Else
	{
		winTitle := GetWin(PARAMETER)
		If winTitle =
			Message("Window not found")
		Else
			WinActivate, % GetWin(PARAMETER,, tipSelectedLine)
	}
	
	Return

; Maximize current window	
CMD_+:
	WinMaximize A
	Return

; Minimize current window
CMD_-:
	WinMinimize A
	Return

; Close current window	
CMD_x:
	winTitle := GetWin(PARAMETER)
	If winTitle =
		Message("Window not found")
	Else
		WinClose, % GetWin(PARAMETER,, tipSelectedLine)
	Return
		
;=========CONFIGURATION COMMANDS===========================================================

; Opens file, folder or URL with new alias	
CMD_learnas: ; command_alias
	If (PARAMETER = "")
	{
		Message("No alias specified")
		Return
	}
	Else If (InStr(PARAMETER,A_Space) != 0)
	{
		Message("No spaces allowed in alias")
		Return
	}
	Else If commandArray[PARAMETER]
	{
		Message("The alias is already taken")
		Return
	}
	
	OldClipboard := ClipboardAll
	Clipboard =
	Send ^c
	ClipWait,2
	
	xpath(configXML, "/commands/learnas/cmd[+1]/@name/text()", PARAMETER)
	xpath(configXML, "/commands/learnas/cmd[@name=" . PARAMETER . "]/@path/text()", Clipboard)
	xpath(configXML, "/commands/learnas/cmd[@name=" . PARAMETER . "]/text()", 0)
	xpath_save(configXML, "config.xml")
	
	commandArray[PARAMETER] := 0
	learnasArray[PARAMETER] := Clipboard
	
	Message("Command learned: " . PARAMETER, "Path: " . Clipboard)
	Clipboard := OldClipboard
	; LoadConfig()

	Return
	
CMD_unlearn: ; command_alias
	If (PARAMETER = "")
	{
		Message("No command specified")
		Return
	}
	If (xpath(configXML, "/commands/learnas/cmd[@name=" . PARAMETER . "]/text()") = "")
	{
		Message("Command not found")
		Return
	}
	
	xpath(configXML, "/commands/learnas/cmd[@name=" . PARAMETER . "]/remove()")
	xpath_save(configXML, "config.xml")
	commandArray.Remove(PARAMETER)
	learnasArray.Remove(PARAMETER)
	Message("Command unlearned: " . PARAMETER)
	
	Return
	
CMD_edit: ; {script | config | hosts}
	textEditor = C:\Program Files\Sublime Text 2\sublime_text.exe
	If PARAMETER = script
		Run, %textEditor% %A_ScriptFullPath%,, UseErrorLevel
	Else If PARAMETER = config
		Run, %textEditor% %A_ScriptDir%\config.xml,, UseErrorLevel
	Else If PARAMETER = hosts
		Run, %textEditor% C:\windows\system32\drivers\etc\hosts,, UseErrorLevel
	Else
		Message("Invalid parameter")
	If ErrorLevel
		Message("Notepad++ installation not found")
	Return 

CMD_cmds:
	Message("Command usage",GetList(commandArray, "`t"),16,A_ScreenWidth - 200,0)
	Return
	
;=========DYNAMIC COMMANDS=================================================================
	
CMD_exec:
	OldClipboard := ClipboardAll
	Clipboard =
	Send ^c
	ClipWait,2
	; FileAppend, %Clipboard%`nF8::ExitApp, temp\temp.ahk
	FileAppend, %Clipboard%, temp\temp.ahk
	Clipboard := OldClipboard
	Message("Executing code")
	RunWait, temp\temp.ahk
	FileDelete, temp\temp.ahk
	Return 

; Inputs keystrokes in one bunch	
CMD_send: ; text
	SendInput %PARAMETER%
	Return
	
;=========INFORMATION COMMANDS=============================================================	
	
CMD_about:
	Message("automate 1.0.1", "Commands: " ArrayLength(commandArray) "`nRun time: " SecToTime(Floor((A_TickCount - startTime)/1000)) "`nWorking directory: " A_WorkingDir "`nDeveloped by Siim Lepik`nEdited by Silver Taza", 20, , 5000)
	Return
	
CMD_date: ; [{copy | put}]
	RouteOutput(A_DD " " A_MMMM " " A_YYYY, PARAMETER)
	Return
	
CMD_wordcount:
	wordCount = 0
	counter = 0
	ClipSaved := ClipboardAll
	Clipboard =
	Send ^c
	ClipWait, 2
	Clipboard := Trim(Clipboard)
	Loop, Parse, Clipboard, %A_Tab%%A_Space%`n`r–—•
	{
		If (A_LoopField != "")
		{
			wordCount++
			; words := words " '" A_LoopField "'"
		}
	}
	; MsgBox % words
	Message("Words: " wordCount)
	Clipboard := ClipSaved
	Return
	
CMD_ip: ; [local] [{copy | put}]
	parameterArray := DecomposeCommand(PARAMETER)
	If (parameterArray[1] = "local")
		ipAddress := A_IPAddress1
	Else
	{
		HTTPRequest("http://cfaj.freeshell.org/ipaddr.cgi", ipAddress)
		parameterArray[2] := parameterArray[1] ; If you don't specify 'local', then the external IP is assumed
	}
	
	RouteOutput(Trim(ipAddress,"`n"), parameterArray[2])
	Return
	
CMD_song: ; [{copy | put}]
	songTitle := Winamp("Title")
	
	If songTitle = 0
	{
		Message("Winamp not running")
		Return
	}
	start := InStr(songTitle,". ") + 1
	end := InStr(songTitle," - Winamp")
	StringMid,songTitle,songTitle,start,end-start
	
	
	If PARAMETER = copy
		Clipboard := songTitle
	Else if PARAMETER = put
		SendInput % songTitle
	Else
		Message(songTitle,,,,5000)
	Return

;=========MISCELLANEOUS AUTOMATION=========================================================

CMD_timer: ; {time_length | off}
	If PARAMETER = off
	{
		SetTimer, timer, off
		Message("Timer disabled")
	}
	Else
	{
		If period := TimeToSec(PARAMETER)
		{
			SetTimer, timer, % -period*1000
			alarmTime =
			alarmTime += TimeToSec(PARAMETER), seconds
			Message("The alarm will sound at " SubStr(alarmTime, 9, 2) ":" SubStr(alarmTime, 11, 2) ":" SubStr(alarmTime, 13, 2))
		}
		Else
			Message("Invalid time specified")
	}
	Return
	
CMD_notes:
	IfWinNotExist, notesWindow
	{
		notesFontSize1 := xpath(configXML, "/notes/note[1]/@fontSize/text()")
		notesFontSize2 := xpath(configXML, "/notes/note[2]/@fontSize/text()")
		tabIndex := xpath(configXML, "/notes/@focused/text()")
		
		Gui 4:+AlwaysOnTop -Caption +ToolWindow
		Gui, 4:Color,Black, Black
		Gui, 4:Margin,-1,-1
		
		notesWidth := A_ScreenWidth / 2 + 4
		windowWidth := A_ScreenWidth + 10
		notesHeight := A_ScreenHeight + 10
		notes2x := notesWidth - 2
		
		Gui, 4:Font, s%notesFontSize1%, %notesFont%
		Gui, 4:Add, Edit, w%notesWidth% h%notesHeight% x-1 y-1 cWhite WantTab vnotesTab1 HwndnotesTabHwnd1 -vScroll		
		Gui, 4:Font, s%notesFontSize2%
		Gui, 4:Add, Edit, w%notesWidth% h%notesHeight% xp+%notes2x% yp+0 cWhite WantTab vnotesTab2 HwndnotesTabHwnd2 -vScroll		
		
		; Gui, 4:Add, Picture,xp+-2 yp+0 w4 h60 vseparator, frame.png

		notesText1 := xpath(configXML, "/notes/note[1]/text()")
		notesText2 := xpath(configXML, "/notes/note[2]/text()")
		StringReplace, notesText1, notesText1, &#44;, `,, All
		StringReplace, notesText1, notesText1, &lt;, <, All
		StringReplace, notesText2, notesText2, &#44;, `,, All
		StringReplace, notesText2, notesText2, &lt;, <, All
		
		; Debug("Read XML files. First note text: " . notesText1 . "; second: " . notesText2)
		
		label1x := A_ScreenWidth / 2 - 20
		label2x := A_ScreenWidth - 20
		labely := 5
		
		Gui, 4:Font, s10 norm
		Gui, 4:Add, Text, x%label1x% y%labely% vsizeLabel1 cSilver Right, %notesFontSize1%
		Gui, 4:Add, Text, x%label2x% y%labely% vsizeLabel2 cSilver Right, %notesFontSize2%
		
		notesVisible := False
		firstStart := True
	}
	If !notesVisible
	{
		Gui, 4:Show,X-1 Y-1 w%windowWidth% h%notesHeight%,notesWindow
		If firstStart
		{
			Gui, 4:Show
			
			Control, EditPaste, %notesText1%,, ahk_id %notesTabHwnd1%
			Control, EditPaste, %notesText2%,, ahk_id %notesTabHwnd2%
			
			ControlSend,,{End}, ahk_id notesTabHwnd1
			ControlSend,,{End}, ahk_id notesTabHwnd2
			
			GuiControl, 4:Focus, notesTab%tabIndex%
				
			GuiControl, 4:MoveDraw, sizeLabel1
			GuiControl, 4:MoveDraw, sizeLabel2
			; GuiControl, 4:MoveDraw, separator
			firstStart := False
		}
		WinSet, Transparent, 220, notesWindow
		notesVisible := True
	}
	Else
	{
		FadeGUI(4,"notesWindow")
		notesVisible := False
		GuiControlGet, notesText1, 4:, notesTab1
		GuiControlGet, notesText2, 4:, notesTab2

		StringReplace, notesText1, notesText1, <, &lt;, All
		StringReplace, notesText2, notesText2, <, &lt;, All
		
		xpath(configXML, "/notes/note[1]/text()", notesText1)
		xpath(configXML, "/notes/note[2]/text()", notesText2)
		xpath_save(configXML, "config.xml")
	}
	
	Return
		
;==========================================================================================
;=========EXIT SUB=========================================================================
;==========================================================================================

ExitSub:
	IfWinExist, ahk_pid %debugPID%
		Process, Close, %debugPID%
		
	ExitApp
		
;==========================================================================================
;=========HOTSTRINGS=======================================================================
;==========================================================================================

#IfWinActive
	
:c?*::.P:::Ρ
:c?*::.p:::р
:?*::.o:::ο
:?*::.9:::﴿
:?*::.8:::﴾
:c?*::.d:::ԁ
:c?*::.D:::D

:*?B0:\=:: ; Inline calculator
	ClipSaved := ClipboardAll
	Clipboard =
	Input, expression, V*,, \
	Send % "+{Left " StrLen(expression)+2 "}^c"
	ClipWait, 2
	expression := SubStr(Clipboard, 3, StrLen(Clipboard)-3)
	Send % (result := Calc(expression)) ? result : "{Right}"
	Clipboard := ClipSaved
	Return

#IfWinActive commandWindow ahk_class AutoHotkeyGUI

:?*::::::\ ; Replaces :: with :\ in file mode

#If !WinActive("ahk_class QWidget") and !WinActive("commandWindow") ;Don't allow these in LyX or the command window

:?*:---::—
:?*:+-::±
:?*:~=::≈
:?*:\alpha::α
:?*:\beta::β
:?*:\gamma::γ
:?*:\delta::δ
:?*:\Delta::Δ
:?*:\epsilon::ε
:?*:\zeta::ζ
:?*:\eta::η
:?*:\theta::θ
:?*:\Theta::Θ
:?*:\lambda::λ
:?*:\mu::μ
:?*:\nu::ν
:?*:\pi::π
:?*:\Pi::Π
:?*:\rho::ρ
:?*:\tau::τ
:?*:\phi::φ
:?*:\Phi::Φ
:?*:\omega::ω
:?*:\Omega::Ω