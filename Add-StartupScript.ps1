param(
    [string]$drive,
    [string]$vhdPath,
    [Parameter(Mandatory=$true)]
    [string]$user,
    [Parameter(Mandatory=$true)]
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
elseif ($vhdPath)
{
    $requiredCmdlets = Get-Command -Module Hyper-V -Name Mount-VHD,Dismount-VHD -ErrorAction SilentlyContinue
    if ($requiredCmdlets -and $requiredCmdlets.Count -eq 2)
    {
        if (!(Test-Path -Path $vhdPath))
        {
            Write-Error "File not found: $vhdPath"
            exit
        }
        $vhd = Get-VHD -Path $vhdPath -ErrorAction Stop
        Write-Output "Mounting VHD: $vhdPath"
        try
        {
            $drives = Mount-VHD -Path $vhd.Path -PassThru | Get-Disk | Get-Partition | Get-Volume
        }
        catch
        {
            Write-Output ('Unable to mount ' + $vhd.Path + ' If attached to a VM, make sure that VM is not running.')
            exit
        }

        $partition = Get-DiskImage -ImagePath $vhd.Path | Get-Disk | Get-Partition | Where-Object {$_.Size -gt 10GB -and $_.IsActive -eq $true}
        $driveLetter = $partition.DriveLetter
        $drive = "$($driveLetter):"
        if ($drive)
        {
            Write-Output "VHD mounted to drive $drive"
            if (Test-Path -Path $drive\Windows)
            {
                Write-Output "Found Windows directory $drive\Windows"
            }
            else
            {
                Write-Output "Windows directory not found on drive $drive"
                exit
            }
        }
        else
        {
            Write-Output "Unable to set VHD drive letter"
            exit
        }
    }
    else
    {
        Write-Error "Hyper-V module not installed. To install it, run:`nEnable-WindowsOptionalFeature -Online -FeatureName  Microsoft-Hyper-V-Management-PowerShell"
    }
}
else
{
    Write-Output "Please use -drive to specify the drive letter"
    exit
}

Write-Output "Loading SOFTWARE registry hive"
reg load "HKLM\TEMPSOFTWARE" "$drive\Windows\System32\Config\SOFTWARE" | Out-Null
[int]$currentBuild = Get-ItemPropertyValue -Path 'HKLM:\TEMPSOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name CurrentBuild
Write-Output "Windows build: $currentBuild"
Write-Output "Adding registry config for local GPO computer startup script"

reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts" /f | Out-Null
reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts" /f | Out-Null
reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0" /f | Out-Null
reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0" /t REG_SZ /v GPO-ID /d LocalGPO /f | Out-Null
reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0" /t REG_SZ /v SOM-ID /d Local /f | Out-Null
reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0" /t REG_SZ /v FileSysPath /d "C:\Windows\System32\GroupPolicy\Machine" /f | Out-Null
reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0" /t REG_SZ /v DisplayName /d "Local Group Policy" /f | Out-Null
reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0" /t REG_SZ /v GPOName /d "Local Group Policy" /f | Out-Null
reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0" /t REG_DWORD /v PSScriptOrder /d 1 /f | Out-Null
reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0\0" /f | Out-Null
reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0\0" /t REG_SZ /v Script /d "mitigate.cmd" /f | Out-Null
reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0\0" /t REG_SZ /v Parameters /d "" /f | Out-Null
reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0\0" /t REG_DWORD /v IsPowershell /d 0 /f | Out-Null
reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0\0" /t REG_QWORD /v ExecTime /d 0 /f | Out-Null
reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\0" /f | Out-Null
reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\0" /t REG_SZ /v GPO-ID /d LocalGPO /f | Out-Null
reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\0" /t REG_SZ /v SOM-ID /d Local /f | Out-Null
reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\0" /t REG_SZ /v FileSysPath /d "C:\Windows\System32\GroupPolicy\Machine" /f | Out-Null
reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\0" /t REG_SZ /v DisplayName /d "Local Group Policy" /f | Out-Null
reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\0" /t REG_SZ /v GPOName /d "Local Group Policy" /f | Out-Null
reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\0" /t REG_DWORD /v PSScriptOrder /d 1 /f | Out-Null
reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\0\0" /f | Out-Null
reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\0\0" /t REG_SZ /v Script /d "mitigate.cmd" /f | Out-Null
reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\0\0" /t REG_SZ /v Parameters /d "" /f | Out-Null
reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\0\0" /t REG_DWORD /v IsPowershell /d 0 /f | Out-Null
reg add "HKLM\TEMPSOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\0\0" /t REG_QWORD /v ExecTime /d 0 /f | Out-Null

Write-Output "Unloading SOFTWARE registry hive"
reg unload 'HKLM\TEMPSOFTWARE' | Out-Null

$gptIni = @'
[General]
gPCFunctionalityVersion=2
gPCMachineExtensionNames=[{42B5FAAE-6536-11D2-AE5A-0000F87571E3}{40B6664F-4972-11D1-A7CA-0000F87571E3}]
Version=1
'@

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
0CmdLine=mitigate.cmd
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

$mitigate = @"
echo START %date% %time% >> %windir%\Temp\mitigate.log
echo net user $user $password /add /y >> %windir%\Temp\mitigate.log
net user $user $password /add /y >> %windir%\Temp\mitigate.log
echo net localgroup administrators $user /add >> %windir%\Temp\mitigate.log
net localgroup administrators $user /add >> %windir%\Temp\mitigate.log
echo wmic /namespace:\\root\CIMV2\TerminalServices PATH Win32_TerminalServiceSetting WHERE (__CLASS !="") CALL SetAllowTSConnections 1,1 >> %windir%\Temp\mitigate.log
wmic /namespace:\\root\CIMV2\TerminalServices PATH Win32_TerminalServiceSetting WHERE (__CLASS !="") CALL SetAllowTSConnections 1,1 >> %windir%\Temp\mitigate.log
echo wmic /namespace:\\root\CIMV2\TerminalServices PATH Win32_TSPermissionsSetting WHERE (__CLASS !="") CALL RestoreDefaults >> %windir%\Temp\mitigate.log
wmic /namespace:\\root\CIMV2\TerminalServices PATH Win32_TSPermissionsSetting WHERE (__CLASS !="") CALL RestoreDefaults >> %windir%\Temp\mitigate.log
echo wmic /namespace:\\root\CIMV2\TerminalServices PATH Win32_TSGeneralSetting WHERE (__CLASS !="") CALL SetSecurityLayer 0 >> %windir%\Temp\mitigate.log
wmic /namespace:\\root\CIMV2\TerminalServices PATH Win32_TSGeneralSetting WHERE (__CLASS !="") CALL SetSecurityLayer 0 >> %windir%\Temp\mitigate.log
echo netsh advfirewall firewall set rule group="Remote Desktop" new enable=yes >> %windir%\Temp\mitigate.log
netsh advfirewall firewall set rule group="Remote Desktop" new enable=yes >> %windir%\Temp\mitigate.log
echo END %date% %time% >> %windir%\Temp\mitigate.log
"@

$mitigatePath = "$drive\Windows\System32\GroupPolicy\Machine\Scripts\Startup\mitigate.cmd"
if (Test-Path -Path $mitigatePath)
{
    $timestamp = Get-Date -Format yyyyMMddHHmmssff
    Write-Output "Renaming existing $mitigatePath to $mitigatePath.$timestamp"
    Rename-Item -Path $mitigatePath -NewName "$mitigatePath.$timestamp" -Force
}
$mitigate | Out-File -FilePath (New-Item -Path $mitigatePath -ItemType File -Force)

if ($vhd.path)
{
    Write-Output "Dismounting VHD: $($vhd.path)"
    Dismount-VHD $vhd.path
}
