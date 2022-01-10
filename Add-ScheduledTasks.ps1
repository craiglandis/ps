# Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force; \\tsclient\c\onedrive\my\Add-ScheduledTasks.ps1

function Add-ScheduledTask
{
    param(
        [string]$taskName,
        [string]$execute,
        [string]$argument
    )

    Write-PSFMessage "Creating scheduled task: taskName: $taskName execute: $execute argument: $argument"
    $action = New-ScheduledTaskAction -Execute $execute -Argument $argument
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $userId = "$env:userdomain\$env:username"
    $principal = New-ScheduledTaskPrincipal -UserId $userId -RunLevel Highest -LogonType Interactive
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Compatibility Win8
    $task = New-ScheduledTask -Action $action -Principal $principal -Trigger $trigger -Settings $settings
    Register-ScheduledTask -TaskName $taskName -InputObject $task -Force | Out-Null

    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue)
    {
        Write-PSFMessage "Scheduled task succesfully created: $taskName"
        Write-PSFMessage "Starting scheduled task: $taskName"
        Start-ScheduledTask -TaskName $taskName
    }
}

$scriptStartTime = Get-Date
$PSDefaultParameterValues['Write-PSFMessage:Level'] = 'Output'

if ($PSEdition -eq 'Desktop')
{
    $nuget = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue -Force
    if ($nuget)
    {
        if ($nuget.Version -lt [Version]'2.8.5.201')
        {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
        }
    }
}

Import-Module -Name PSFramework -ErrorAction SilentlyContinue
if (Get-Module -Name PSFramework)
{
    Write-PSFMessage "PSFramework module already loaded"
}
else
{
    Write-Output "PSFramework module not found, installing it"
    Install-Module -Name PSFramework -Repository PSGallery -Scope CurrentUser -AllowClobber -Force -ErrorAction SilentlyContinue
    Import-Module -Name PSFramework -ErrorAction SilentlyContinue
    if (Get-Module -Name PSFramework -ErrorAction SilentlyContinue)
    {
        Write-PSFMessage "PSFramework module install succeeded"
    }
    else
    {
        Write-Output "PSFramework module install failed"
        $command = "Set-Alias -Name Write-PSFMessage -Value Write-Output"
        Write-Output $command
        Invoke-Expression -Command $command
    }
}

$myFolderPath = "$env:SystemDrive\OneDrive\My"
$toolsFolderPath = "$env:SystemDrive\OneDrive\Tools"
$ahkExeFolderPath = "$env:ProgramFiles\AutoHotkey"
$ahkExeFilePath = "$ahkExeFolderPath\AutoHotkey.exe"
$ahkFileUrl = 'https://raw.githubusercontent.com/craiglandis/ps/master/ahk.ahk'
$ahkFileName = $ahkFileUrl.Split('/')[-1]
$ahkFilePath = "$myFolderPath\$ahkFileName"
$ahkNotElevatedFileUrl = 'https://raw.githubusercontent.com/craiglandis/ps/master/ahk_not_elevated.ahk'
$ahkNotElevatedFileName = $ahkNotElevatedFileUrl.Split('/')[-1]
$ahkNotElevatedFilePath = "$myFolderPath\$ahkNotElevatedFileName"

Write-PSFMessage "Checking if $myFolderPath exists"
if (Test-Path -Path $myFolderPath -PathType Container)
{
    Write-PSFMessage "$myFolderPath already exists, don't need to create it"
}
else
{
    Write-PSFMessage "$myFolderPath does not exist, creating it"
    New-Item -Path $myFolderPath -ItemType Directory | Out-Null
}

Write-PSFMessage "Checking if $toolsFolderPath exists"
if (Test-Path -Path $toolsFolderPath -PathType Container)
{
    Write-PSFMessage "$toolsFolderPath already exists, don't need to create it"
}
else
{
    Write-PSFMessage "$toolsFolderPath does not exist, creating it"
    New-Item -Path $toolsFolderPath -ItemType Directory -Force | Out-Null
}

Write-PSFMessage "Checking if AutoHotkey is installed"
if (Test-Path -Path $ahkExeFilePath -PathType Leaf)
{
    Write-PSFMessage "AutoHotkey already installed"
}
else
{
    Write-PSFMessage "AutoHotkey not installed, installing it now"
    Invoke-Expression ((New-Object Net.Webclient).DownloadString('https://chocolatey.org/install.ps1'))
    choco install autohotkey -y
}

Write-PSFMessage "Checking for $ahkFilePath"
if (Test-Path -Path $ahkFilePath -PathType Leaf)
{
    Write-PSFMessage "$ahkFilePath already present, no need to download it"
}
else
{
    Write-PSFMessage "$ahkFilePath not present, downloading it"
    Write-PSFMessage "Downloading $ahkFileUrl"
    (New-Object Net.Webclient).DownloadFile($ahkFileUrl, $ahkFilePath)
}

Write-PSFMessage "Checking for $ahkNotElevatedFilePath"
if (Test-Path -Path $ahkNotElevatedFilePath -PathType Leaf)
{
    Write-PSFMessage "$ahkNotElevatedFilePath already present, no need to download it"
}
else
{
    Write-PSFMessage "$ahkNotElevatedFilePath not present, downloading it"
    Write-PSFMessage "Downloading $ahkNotElevatedFileUrl"
    (New-Object Net.Webclient).DownloadFile($ahkNotElevatedFileUrl, $ahkNotElevatedFilePath)
}

$caffeineUrl = 'https://www.zhornsoftware.co.uk/caffeine/caffeine.zip'
$caffeineFolderPath = $toolsFolderPath
$caffeineExeFilePath = "$caffeineFolderPath\caffeine64.exe"
$caffeineZipFilePath = "$caffeineFolderPath\caffeine.zip"

Write-PSFMessage "Checking for $caffeineExeFilePath"
if (Test-Path -Path $caffeineExeFilePath -PathType Leaf)
{
    Write-PSFMessage "$caffeineExeFilePath already present, no need to download it"
}
else
{
    Write-PSFMessage "$caffeineExeFilePath not present, downloading it"
    (New-Object Net.Webclient).DownloadFile($caffeineUrl, $caffeineZipFilePath)
    Expand-Archive -Path $caffeineZipFilePath -DestinationPath $caffeineFolderPath
}

$execute = "$env:SystemRoot\System32\cmd.exe"

$taskName = 'AutoHotkey'
$argument = "/c Start `"$ahkExeFilePath`" $ahkFilePath"
Add-ScheduledTask -taskName $taskName -execute $execute -argument $argument

$taskName = 'AutoHotkey_Not_Elevated'
$argument = "/c Start `"$ahkExeFilePath`" $ahkNotElevatedFilePath"
Add-ScheduledTask -taskName $taskName -execute $execute -argument $argument

$taskName = 'Caffeine'
$argument = "/c Start $caffeineExeFilePath"
Add-ScheduledTask -taskName $taskName -execute $execute -argument $argument

Write-PSFMessage "Setting AutoHotkey Edit command to open AHK files in vscode instead of Notepad"
$vscodeUserPath = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe"
$vscodeSystemPath = "$env:ProgramFiles\Microsoft VS Code\Code.exe"
if (Test-Path -Path $vscodeUserPath -PathType Leaf)
{
    $regFileUrl = 'https://raw.githubusercontent.com/craiglandis/ps/master/AutoHotkeyScript_Edit_Command_VSCode_If_Installed_In_Users_username_AppData_Local_Programs_Microsoft_VS_Code.reg'
}
elseif (Test-Path -Path $vscodeSystemPath -PathType Leaf)
{
    $regFileUrl = 'https://raw.githubusercontent.com/craiglandis/ps/master/AutoHotkeyScript_Edit_Command_VSCode_If_Installed_In_Program_Files_Microsoft_VS_Code.reg'
}
else
{
    Write-PSFMessage "VSCode not installed. Skipping file association config."
}

if ($regFileUrl)
{
    $regFileName = $regFileUrl.Split('/')[-1]
    $regFilePath = "$myPath\$regFileName"
    Write-PSFMessage "Downloading $regFileUrl"
    (New-Object Net.Webclient).DownloadFile($regFileUrl, $regFilePath)
    reg import $regFilePath
}

$scriptDuration = '{0:hh}:{0:mm}:{0:ss}.{0:ff}' -f (New-TimeSpan -Start $scriptStartTime -End (Get-Date))
Write-PSFMessage "Script duration: $scriptDuration"
