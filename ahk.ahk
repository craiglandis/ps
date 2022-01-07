#SingleInstance force

Menu, TRAY, Icon, C:\Program Files\AutoHotkey\AutoHotkey.exe, 4 ; red "H" icon to denote this script runs elevated

+^P:: ; *** CTRL+SHIFT+P for PowerShell 7 ***
SetTitleMatchMode RegEx
if WinExist("ahk_exe WindowsTerminal.exe")
{
    WinActivate
}
Else
{
    WindowsTerminalPreview := "C:\Users\" A_UserName "\AppData\Local\Microsoft\WindowsApps\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\wt.exe"
    WindowsTerminal := "C:\Users\" A_UserName "\AppData\Local\Microsoft\WindowsApps\wt.exe"
    if FileExist(WindowsTerminalPreview)
        Run, %WindowsTerminalPreview%, , max
    else if FileExist(WindowsTerminal)
        Run, %WindowsTerminal%, , max
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
    Run, "C:\Users\clandis\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Visual Studio Code\Visual Studio Code.lnk"
}
Return

+^R:: ; *** CTRL+SHIFT+R to reload AHK file***
Run, c:\onedrive\my\ahk.ahk, , Hide
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
