$ahkFilePath = "$env:SystemDrive\OneDrive\my\ahk.ahk"
$exeFolderPath = "$env:ProgramFiles\AutoHotkey"
$exeFilePath = "$exeFolderPath\AutoHotkey.exe"
$ahkFileUrl = 'https://raw.githubusercontent.com/craiglandis/ps/master/ahk.ahk'
$ahkFileName = $ahkFileUrl.Split('/')[-1]
(New-Object Net.Webclient).DownloadFile($ahkFileUrl, $ahkFilePath)

Write-Output "Checking if AutoHotkey is installed"
if (Test-Path -Path $exeFilePath -PathType Leaf)
{
    Write-Output "AutoHotkey already installed"
}
else
{
    Write-Output "AutoHotkey not installed, installing it now"
    Invoke-Expression ((New-Object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
    choco install autohotkey -y
}

$taskName = 'AutoHotkey'
$argument = "/c Start `"$exeFilePath`" $ahkFilePath"
$action = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument $argument
$trigger = New-ScheduledTaskTrigger -AtLogOn
$userId = "$env:userdomain\$env:username"
$principal = New-ScheduledTaskPrincipal -UserId $userId -RunLevel Highest -LogonType Interactive
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Compatibility Win8
$task = New-ScheduledTask -Action $action -Principal $principal -Trigger $trigger -Settings $settings
Register-ScheduledTask -TaskName $taskName -InputObject $task -Force
Start-ScheduledTask -TaskName $taskName