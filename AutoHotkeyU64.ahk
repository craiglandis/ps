#SingleInstance force

+^P:: ; *** CTRL+SHIFT+O for (old) PowerShell ***
SetTitleMatchMode RegEx
;IfWinExist i).*Administrator: Windows PowerShell$
if WinExist("ahk_exe powershell.exe")
{
    WinActivate
}
Else
{
  ;ClassNN:	Windows.UI.Composition.DesktopWindowContentBridge1
  ;  Text:	DesktopWindowXamlSource
  Run powershell -nologo -windowstyle maximized -noexit -command set-location c:\ | out-null
  ;Run, wt new-tab "Windows PowerShell"
  ;send CTRL+SHIFT+2 if "PS 5.1" window title not detected
}
Return

+^C:: ; *** CTRL+SHIFT+C for VSCODE ***
SetTitleMatchMode RegEx
if WinExist("ahk_exe Code.exe")
{
    WinActivate
}
Else
{
    Run, "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Visual Studio Code\Visual Studio Code.lnk"
    ;Run, "C:\Users\clandis\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Visual Studio Code\Visual Studio Code.lnk"
}
Return

^+E:: ; *** CTRL+SHIFT+E for Edge ***
If WinExist("ahk_exe msedge.exe")
{
	WinActivate
	WinMaximize
    ;WinMove, , , 0, 0, 1280, 720
    SendInput ^t
}
Else
{
    Run, "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
    WinActivate
    ;WinMove, , , 0, 0, 1280, 720
    WinMaximize
    SendInput ^t
}
Return

+^R:: ; *** CTRL+SHIFT+R to reload AHK file***
Run, C:\OneDrive\Tools\AutoHotkeyU64.ahk, , Hide
Return

; *** Auto-replace strings ***
::!utc::
FormatTime, utc, %A_NowUTC%, yyyy-MM-ddTHH:mm:ssZ
SendInput %utc%
return

::!z::
FormatTime, utc, %A_NowUTC%, yyyy-MM-ddTHH:mm:ssZ
SendInput %utc%
return

::!local::
FormatTime, local, , yyyy-MM-ddTHH:mm:ss
SendInput %local%
return

::!now::
FormatTime, local, , yyyy-MM-ddTHH:mm:ss
SendInput %local%
return