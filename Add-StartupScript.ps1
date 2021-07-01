param(
    [string]$drive,
    [string]$user,
    [string]$password
)

if ($drive)
{
    $drive = $drive.Replace(':','')
    $drive = "$($drive):"

    if ((Test-Path -Path $drive) -eq $false)
    {
        Write-Output "$drive not found"
        exit
    }

    if ((Test-Path -Path "$drive\Windows") -eq $false)
    {
        Write-Output "$("$drive\Windows") not found"
        exit
    }
}
else
{
    Write-Output "Please use -drive to specify the drive letter"
    exit
}

reg load "HKLM\TEMPSOFTWARE" "$drive\Windows\System32\Config\SOFTWARE"
reg load "HKLM\TEMPSYSTEM" "$drive\Windows\System32\Config\SYSTEM"
$currentControlSet = ('ControlSet00' + [string](Get-ItemProperty HKLM:TEMPSYSTEM\Select).Current)

[int]$currentBuild = Get-ItemPropertyValue -Path 'HKLM:\TEMPSOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name CurrentBuild

Write-Output "Windows build: $currentBuild"
if ($currentBuild -ge 14393)
{
    reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts" /f
    reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts" /f
    reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0" /f
    reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0" /t REG_SZ /v GPO-ID /d LocalGPO /f
    reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0" /t REG_SZ /v SOM-ID /d Local /f
    reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0" /t REG_SZ /v FileSysPath /d "C:\Windows\System32\GroupPolicy\Machine" /f
    reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0" /t REG_SZ /v DisplayName /d "Local Group Policy" /f
    reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0" /t REG_SZ /v GPOName /d "Local Group Policy" /f
    reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0" /t REG_DWORD /v PSScriptOrder /d 1 /f
    reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0\0" /f
    reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0\0" /t REG_SZ /v Script /d "adduser.cmd" /f
    reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0\0" /t REG_SZ /v Parameters /d "" /f
    reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0\0" /t REG_DWORD /v IsPowershell /d 0 /f
    reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0\0" /t REG_QWORD /v ExecTime /d 0 /f
    reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\0" /f
    reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\0" /t REG_SZ /v GPO-ID /d LocalGPO /f
    reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\0" /t REG_SZ /v SOM-ID /d Local /f
    reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\0" /t REG_SZ /v FileSysPath /d "C:\Windows\System32\GroupPolicy\Machine" /f
    reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\0" /t REG_SZ /v DisplayName /d "Local Group Policy" /f
    reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\0" /t REG_SZ /v GPOName /d "Local Group Policy" /f
    reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\0" /t REG_DWORD /v PSScriptOrder /d 1 /f
    reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\0\0" /f
    reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\0\0" /t REG_SZ /v Script /d "adduser.cmd" /f
    reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\0\0" /t REG_SZ /v Parameters /d "" /f
    reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\0\0" /t REG_DWORD /v IsPowershell /d 0 /f
    reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\0\0" /t REG_QWORD /v ExecTime /d 0 /f

    reg unload 'HKLM\TEMPSOFTWARE'
    reg unload 'HKLM\TEMPSYSTEM'
}

if ($currentBuild -ge 14393)
{
$gptIni = @'
[General]
gPCMachineExtensionNames=[{42B5FAAE-6536-11D2-AE5A-0000F87571E3}{40B6664F-4972-11D1-A7CA-0000F87571E3}]
Version=4
'@
}
else
{
$gptIni = @'
[General]
gPCFunctionalityVersion=2
gPCMachineExtensionNames=[{42B5FAAE-6536-11D2-AE5A-0000F87571E3}{40B6664F-4972-11D1-A7CA-0000F87571E3}]
Version=1
'@
}

$gptIniPath = "$drive\Windows\System32\GroupPolicy\gpt.ini"
if (Test-Path -Path $gptIniPath)
{
    $timestamp = Get-Date -Format yyyyMMddHHmmssff
    $command = "Rename-Item -Path $gptIniPath -NewName $gptIniPath.$timestamp -Force"
    Write-Output $command
    Invoke-Expression -Command $command
}
Write-Output "Creating $gptIniPath"
$gptIni | Out-File -FilePath (New-Item -Path $gptIniPath -ItemType File -Force)

$scriptsIni = @'
[Startup]
0CmdLine=adduser.cmd
0Parameters=
'@
$scriptsIniPath = "$drive\Windows\System32\GroupPolicy\Machine\Scripts\scripts.ini"
if (test-path -Path $scriptsIniPath)
{
    $timestamp = Get-Date -Format yyyyMMddHHmmssff
    Write-Output "Renaming existing $scriptsIniPath to scripts.ini.$timestamp"
    Rename-Item -Path $scriptsIniPath -NewName "$scriptsIniPath.$timestamp" -Force
}
$scriptsIni | Out-File -FilePath (New-Item -Path $scriptsIniPath -ItemType File -Force)

$addUser = @"
echo %date% %time% >> %windir%\Temp\adduser.log
echo Creating new user >> %windir%\Temp\adduser.log
net user $user $password /add /y >> %windir%\Temp\adduser.log
echo Add new user to local administrators >> >> %windir%\Temp\adduser.log
net localgroup administrators $user /add >> %windir%\Temp\adduser.log
echo %date% %time% >> %windir%\Temp\adduser.log
"@

$addUserPath = "$drive\Windows\System32\GroupPolicy\Machine\Scripts\Startup\adduser.cmd"
if (Test-Path -Path $addUserPath)
{
    $timestamp = Get-Date -Format yyyyMMddHHmmssff
    Write-Output "Renaming existing $addUserPath to $addUserPath.$timestamp"
    Rename-Item -Path $addUserPath -NewName "$addUserPath.$timestamp" -Force
}
$addUser | Out-File -FilePath (New-Item -Path $addUserPath -ItemType File -Force)