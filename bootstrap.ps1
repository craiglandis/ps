# wmic path Win32_TerminalServiceSetting where AllowTSConnections="0" call SetAllowTSConnections "1"
# reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f
# netsh advfirewall firewall set rule group="remote desktop" new enable=Yes
# Download and run from CMD
# @"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "(New-Object System.Net.WebClient).DownloadFile('https://aka.ms/bootstrap','c:\my\bootstrap.ps1');iex 'c:\my\bootstrap.ps1 -sysinternals'"
# Download and run from PS
# (New-Object System.Net.WebClient).DownloadFile('https://aka.ms/bootstrap','c:\my\bootstrap.ps1'); iex 'c:\my\bootstrap.ps1 -sysinternals'
# Run from RDP client
# Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force; Invoke-Expression ((New-Object Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
# Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force; \\tsclient\c\onedrive\my\bootstrap.ps1 -group All
[CmdletBinding()]
param(
    [ValidateSet('PC', 'VM', 'VSAW', 'All')]
    [string]$group = 'PC',
    [switch]$show,
    [string]$toolsPath = 'C:\OneDrive\Tools',
    [string]$myPath = 'C:\OneDrive\My'
)
DynamicParam
{
    $ParameterName = 'app'
    $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
    $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
    $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
    $ParameterAttribute.Mandatory = $false
    $ParameterAttribute.Position = 1
    $AttributeCollection.Add($ParameterAttribute)
    $appsJsonFilePath = "$PSScriptRoot\apps.json"
    if (!(Test-Path -Path $appsJsonFilePath -PathType Leaf))
    {
        $appsJsonFileUrl = 'https://raw.githubusercontent.com/craiglandis/ps/master/apps.json'
        (New-Object Net.Webclient).DownloadFile($appsJsonFileUrl, $appsJsonFilePath)
    }
    $arrSet = (Get-Content -Path $PSScriptRoot\apps.json | ConvertFrom-Json).Name
    $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)
    $AttributeCollection.Add($ValidateSetAttribute)
    $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)
    $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
    return $RuntimeParameterDictionary
}
begin
{
    $app = $PsBoundParameters[$ParameterName]
}
process
{
    function Invoke-ExpressionWithLogging
    {
        param(
            [string]$command
        )
        Write-PSFMessage $command
        Invoke-Expression -Command $command
    }

    $scriptStartTime = Get-Date
    $scriptName = Split-Path -Path $PSCommandPath -Leaf
    $scriptBaseName = $scriptName.TrimEnd('ps1')
    # Alias Write-PSFMessage to Write-PSFMessage until confirming PSFramework module is installed
    Set-Alias -Name Write-PSFMessage -Value Write-Output
    $PSDefaultParameterValues['Write-PSFMessage:Level'] = 'Output'
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

    $appsJsonFilePath = "$PSScriptRoot\apps.json"
    if (!(Test-Path -Path $appsJsonFilePath -PathType Leaf))
    {
        $appsJsonFileUrl = 'https://raw.githubusercontent.com/craiglandis/ps/master/apps.json'
        (New-Object Net.Webclient).DownloadFile($appsJsonFileUrl, $appsJsonFilePath)
    }
    $apps = Get-Content -Path $appsJsonFilePath | ConvertFrom-Json

    if ($show)
    {
        $apps = $apps | Where-Object {$_.Groups -contains $group}
        Write-PSFMessage $apps
        exit
    }

    $win32_OperatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem
    $productType = $win32_OperatingSystem.ProductType
    $osVersion = ($win32_OperatingSystem | Select-Object @{Label = 'OSVersion'; Expression = {"$($_.Caption) $($_.Version)"}}).OSVersion

    # 1 = Workstation, 2 = Domain controller, 3 = Server
    switch ($productType)
    {
        1 {$isWindowsClient = $true}
        2 {$isWindowsServer = $true}
        3 {$isWindowsServer = $true}
    }

    # https://en.wikipedia.org/wiki/List_of_Microsoft_Windows_versions
    switch -regex ($osVersion)
    {
        '7601' {if ($isWindowsServer) {$os = 'WS08R2'; $isWS08R2 = $true} else {$os = 'WIN7'; $isWin7 = $true}}
        '9200' {if ($isWindowsServer) {$os = 'WS12'; $isWS12 = $true} else {$os = 'WIN8'; $isWin8 = $true}}
        '9600' {if ($isWindowsServer) {$os = 'WS12R2'; $isWS12R2 = $true} else {$os = 'WIN81'; $isWin81 = $true}}
        '10240' {$os = 'WIN10'; $isWin10 = $true} # 1507 Threshold 2
        '10586' {$os = 'WIN10'; $isWin10 = $true} # 1511 Threshold 2
        '14393' {if ($isWindowsServer) {$os = 'WS16'; $isWS16 = $true} else {$os = 'WIN10'; $isWin10 = $true}} # 1607 Redstone 1
        '15063' {$os = 'WIN10'; $isWin10 = $true} # RS2 1703 Redstone 2
        '16299' {if ($isWindowsServer) {$os = 'WS1709'} else {$os = 'WIN10'; $isWin10 = $true}} # 1709 (Redstone 3)
        '17134' {if ($isWindowsServer) {$os = 'WS1803'} else {$os = 'WIN10'; $isWin10 = $true}} # 1803 (Redstone 4)
        '17763' {if ($isWindowsServer) {$os = 'WS19'} else {$os = 'WIN10'; $isWin10 = $true}} # 1809 October 2018 Update (Redstone 5)
        '18362' {if ($isWindowsServer) {$os = 'WS1909'} else {$os = 'WIN10'; $isWin10 = $true}} # 1903 19H1 November 2019 Update
        '18363' {if ($isWindowsServer) {$os = 'WS1909'} else {$os = 'WIN10'; $isWin10 = $true}} # 1909 19H2 November 2019 Update
        '19041' {if ($isWindowsServer) {$os = 'WS2004'} else {$os = 'WIN10'; $isWin10 = $true}} # 2004 20H1 May 2020 Update
        '19042' {if ($isWindowsServer) {$os = 'WS20H2'} else {$os = 'WIN10'; $isWin10 = $true}} # 20H2 October 2020 Update
        '19043' {$os = 'WIN10'; $isWin10 = $true} # 21H1 May 2021 Update
        '19044' {$os = 'WIN10'; $isWin10 = $true} # 21H2 November 2021 Update
        '20348' {$os = 'WS22'; $isWS22 = $true} # 21H2
        '22000' {$os = 'WIN11'; $isWin11 = $true} # 21H2
        default {$os = 'Unknown'}
    }

    Write-PSFMessage "OS: $os ($osVersion)"
    Invoke-ExpressionWithLogging -command 'Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force'
    #$command = 'Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force'
    #Write-PSFMessage $command
    #Invoke-Expression -Command $command

    # This needs to be before Set-PSRepository, otherwise Set-PSRepository will prompt to install it
    if ($PSEdition -eq 'Desktop')
    {
        Write-PSFMessage 'Verifying Nuget 2.8.5.201+ is installed'
        $nuget = Get-PackageProvider -Name nuget -ErrorAction SilentlyContinue -Force
        if (!$nuget -or $nuget.Version -lt [Version]'2.8.5.201')
        {
            Invoke-ExpressionWithLogging -command 'Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force'
            #Write-PSFMessage 'Installing Nuget 2.8.5.201+'
            #Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
        }
        else
        {
            Write-PSFMessage "Nuget $($nuget.Version) already installed"
        }
    }

    #Register-PSRepository -Name PSGallery –SourceLocation 'https://www.powershellgallery.com/api/v2' -InstallationPolicy Trusted
    # Is this really necessary???
    # Invoke-ExpressionWithLogging -command 'Set-PSRepository -Name PSGallery -InstallationPolicy Trusted'
    #$command = 'Set-PSRepository -Name PSGallery -InstallationPolicy Trusted'
    #Write-PSFMessage $command
    #Invoke-Expression -Command $command

    # https://psframework.org/
    Import-Module -Name PSFramework -ErrorAction SilentlyContinue
    $psframework = Get-Module -Name PSFramework -ErrorAction SilentlyContinue
    if (!$psframework)
    {
        Write-PSFMessage 'PSFramework module not found, installing it'
        Install-Module -Name PSFramework -Repository PSGallery -Scope CurrentUser -AllowClobber -Force -ErrorAction SilentlyContinue
        Import-Module -Name PSFramework -ErrorAction SilentlyContinue
        $psframework = Get-Module -Name PSFramework -ErrorAction SilentlyContinue
        if (!$psframework)
        {
            Write-PSFMessage 'PSFramework module failed to install'
        }
    }

    if ($psframework)
    {
        Remove-Item Alias:Write-PSFMessage -Force -ErrorAction SilentlyContinue
        <#
        $paramSetPSFLoggingProvider = @{
            Name         = 'logfile'
            InstanceName = $scriptBaseName
            FilePath     = "$env:USERPROFILE\Desktop\$($scriptBaseName)_$(Get-Date -f yyyyMMddHHmmss)"
            Enabled      = $true
        }
        Set-PSFLoggingProvider @paramSetPSFLoggingProvider
        #>
        Write-PSFMessage "PSFramework module $($psframework.Version)"
    }

    $profileFile = $profile.CurrentUserCurrentHost
    if (Test-Path -Path $profileFile -PathType Leaf)
    {
        Write-PSFMessage "$profileFile already exists, don't need to create it"
    }
    else
    {
        Invoke-ExpressionWithLogging -command "New-Item -Path $profileFile -Type File -Force | Out-Null"
        #$command = "New-Item -Path $profileFile -Type File -Force | Out-Null"
        #Write-PSFMessage $command
        #Invoke-Expression -Command $command
    }

    $ErrorActionPreference = 'SilentlyContinue'
    $chocoVersion = choco -v
    $ErrorActionPreference = 'Continue'

    if ($chocoVersion)
    {
        Write-PSFMessage "Chocolatey $chocoVersion already installed"
    }
    else
    {
        #Write-PSFMessage "Installing Chocolatey"
        Invoke-ExpressionWithLogging -command "Invoke-Expression ((New-Object Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"
        #$command = "Invoke-Expression ((New-Object Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"
        #Write-PSFMessage $command
        #Invoke-Expression -Command $command
        $ErrorActionPreference = 'SilentlyContinue'
        $chocoVersion = choco -v
        $ErrorActionPreference = 'Continue'
        if ($chocoVersion)
        {
            Write-PSFMessage "Chocolatey $chocoVersion already installed"
        }
        else
        {
            Write-PSFMessage 'Chocolatey failed to install'
            exit
        }
    }

    if ($chocoVersion)
    {
        Write-PSFMessage "Chocolatey $chocoVersion successfully installed"
    }
    else
    {
        Write-PSFMessage 'Chocolatey install failed'
        exit
    }

    if ($group -ne 'All')
    {
        $apps | Where-Object {$_.Groups -contains $group}
    }

    Write-PSFMessage "Mode: $group"
    Write-PSFMessage "$($apps.Count) apps to be installed"

    #$apps | Where-Object {$_.Name -in '7-Zip','AutoHotkey', 'Sysinternals Suite', '.NET Desktop Runtime 6.0.1', 'Cascadia Font Family', 'Everything', 'Greenshot', 'Microsoft 365 Apps for enterprise', 'Microsoft Edge', 'Microsoft Teams', 'Notepad++', 'PowerShell', 'PowerShell Preview', 'Steam', 'Visual Studio Code', 'Windows Terminal', 'Windows Terminal Preview'} | ForEach-Object {
    #$apps | Where-Object {$_.Name -eq '7-Zip'} | ForEach-Object {
    $apps | ForEach-Object {

        $app = $_
        Write-PSFMessage "Installing: $($app.Name)"

        if ($app.ChocolateyName -and ($app.WingetName -or !$app.WingetName))
        {
            $appName = $app.ChocolateyName
            $useChocolatey = $true
            if ($app.ChocolateyParams)
            {
                $chocolateyParams = $app.ChocolateyParams
            }
            else
            {
                $chocolateyParams = $null
            }
        }
        elseif ($app.WingetName)
        {
            $appName = $app.WingetName
        }
        else
        {
            $appName = ''
        }

        if ($appName -and $useChocolatey)
        {
            Remove-Variable useChocolatey -Force
            $command = "choco install $appName -y"
            if ($chocolateyParams)
            {
                # EXAMPLE: choco install sysinternals --params "/InstallDir:C:\your\install\path"
                $command = "$command --params `"$chocolateyParams`""
                $command = $command.Replace('TOOLSPATH', $toolsPath)
                $command = $command.Replace('MYPATH', $myPath)
            }
            Invoke-ExpressionWithLogging -command $command
            #Write-PSFMessage $command
            #Invoke-Expression -Command $command
        }
        elseif ($appName -and !$useChocolatey)
        {
            $command = "winget install --id $appName --exact --silent --accept-package-agreements --accept-source-agreements"
            Invoke-ExpressionWithLogging -command $command
            #Write-PSFMessage $command
            #Invoke-Expression -Command $command
        }
    }

    <#
    The sysinternals package tries to create the specified InstallDir and fails if it already exists
    ERROR: Exception calling "CreateDirectory" with "1" argument(s): "Cannot create "C:\OneDrive\Tools" because a file or directory with the same name already exists."
    So don't precreate these, let the package create them, and if needed, make sure they are created after all package installs are done
    #>
    if (Test-Path -Path $toolsPath -PathType Container)
    {
        Write-PSFMessage "$toolsPath already exists, don't need to create it"
    }
    else
    {
        Invoke-ExpressionWithLogging -command "New-Item -Path $toolsPath -Type File -Force | Out-Null"
        #$command = "New-Item -Path $toolsPath -Type File -Force | Out-Null"
        #Write-PSFMessage $command
        #Invoke-Expression -Command $command
    }

    if (Test-Path -Path $myPath -PathType Container)
    {
        Write-PSFMessage "$myPath already exists, don't need to create it"
    }
    else
    {
        Invoke-ExpressionWithLogging -command "New-Item -Path $myPath -Type Directory -Force | Out-Null"
        #$command = "New-Item -Path $myPath -Type File -Force | Out-Null"
        #Write-PSFMessage $command
        #Invoke-Expression -Command $command
    }

    # https://stackoverflow.com/questions/714877/setting-windows-powershell-environment-variables
    Write-PSFMessage "Adding $toolsPath and $myPath to user Path environment variable"
    $newUserPath = "$env:Path;$toolsPath;$myPath"
    Invoke-ExpressionWithLogging -command "[Environment]::SetEnvironmentVariable('Path', '$newUserPath', 'User')"
    #$command = "[Environment]::SetEnvironmentVariable('Path', '$newUserPath', 'User')"
    #Write-PSFMessage $command
    #Invoke-Expression -Command $command

    $userPathFromRegistry = (Get-ItemProperty -Path 'HKCU:\Environment' -Name Path).Path
    $separator = "`n$('='*160)`n"
    Write-PSFMessage "$separator`$userPathFromRegistry: $userPathFromRegistry$separator"

    Invoke-ExpressionWithLogging -command 'Remove-Item "$env:public\Desktop\*.lnk" -Force'
    Invoke-ExpressionWithLogging -command 'Remove-Item "$env:userprofile\desktop\*.lnk" -Force'

    $webClient = New-Object System.Net.WebClient

    $scriptFileUrls = @(
        'https://raw.githubusercontent.com/craiglandis/ps/master/Set-Cursor.ps1',
        'https://raw.githubusercontent.com/craiglandis/ps/master/Set-Console.ps1',
        'https://raw.githubusercontent.com/craiglandis/ps/master/Add-ScheduledTasks.ps1'
    )

    $scriptFileUrls | ForEach-Object {
        Invoke-Expression ($webClient.DownloadString($_))
    }

    $regFileUrls = @(
        'https://raw.githubusercontent.com/craiglandis/ps/master/7-zip_auto_extract_downloaded_zip.reg',
        'https://raw.githubusercontent.com/craiglandis/ps/master/7-zip_double-click_extract_to_folder.reg'
    )

    $regFileUrls | ForEach-Object {
        $regFileUrl = $_
        $regFileName = $regFileUrl.Split('/')[-1]
        $webClient.DownloadFile($regFileUrl, $regFileName)
        if (Test-Path -Path $regFileName -PathType Leaf)
        {
            Invoke-ExpressionWithLogging -command "reg import $regFileName"
            #$command = "reg import $regFileName"
            #Write-PSFMessage $command
            #Invoke-Expression -Command $command
        }
    }

    $windowsTerminalSettingsUrl = 'https://raw.githubusercontent.com/craiglandis/ps/master/windows-terminal-settings.json'

    $windowsTerminalSettingsFilePaths = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
    )

    $windowsTerminalSettingsFilePaths | ForEach-Object {
        $windowsTerminalSettingsFilePath = $_
        if (Test-Path -Path $windowsTerminalSettingsFilePath -PathType Leaf)
        {
            Rename-Item -Path $windowsTerminalSettingsFilePath -NewName "$($windowsTerminalSettingsFilePath.Split('\')[-1]).original"
            (New-Object System.Net.WebClient).DownloadFile($windowsTerminalSettingsUrl, $windowsTerminalSettingsFilePath)
        }
    }

    if ($isWin11 -and $group -eq 'PC')
    {
        Invoke-ExpressionWithLogging -command 'wsl --install'
    }
    # Configure shell
    # Kusto Explorer https://aka.ms/ke
    # Import Kusto connections
    # Visio

    if ($isWindowsServer)
    {
        # Disable Server Manager from starting at Windows startup
        reg add 'HKCU\SOFTWARE\Microsoft\ServerManager' /v DoNotOpenServerManagerAtLogon /t REG_DWORD /d 1 /f
        reg add 'HKCU\SOFTWARE\Microsoft\ServerManager' /v DoNotPopWACConsoleAtSMLaunch /t REG_DWORD /d 1 /f
    }

    if ($isWin11)
    {
        reg add 'HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32' /f /ve
    }

    if ($isWin10)
    {
        # Enable "Always show all icons in the notification area"
        reg add 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' /v EnableAutoTray /t REG_DWORD /d 0 /f
    }

    # Config for all Windows versions
    # Show file extensions
    reg add 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' /v HideFileExt /t REG_DWORD /d 0 /f
    # Show hidden files
    reg add 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' /v Hidden /t REG_DWORD /d 1 /f
    # Show protected operating system files
    reg add 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' /v ShowSuperHidden /t REG_DWORD /d 0 /f
    # Explorer show compressed files color
    reg add 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' /v ShowCompColor /t REG_DWORD /d 1 /f
    # Taskbar on left instead of center
    reg add 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' /v TaskbarAl /t REG_DWORD /d 0 /f

    $nppSettingsZipUrl = 'https://github.com/craiglandis/ps/raw/master/npp-settings.zip'
    $nppSettingsZipFileName = $nppSettingsZipUrl.Split('/')[-1]
    $nppSettingsZipFilePath = "$env:temp\$nppSettingsZipFileName"
    $nppSettingsTempFolderPath = "$env:TEMP\$($nppSettingsZipFileName.Replace('.zip',''))"
    $nppSettingsFolderPath = 'C:\OneDrive\npp'
    $nppAppDataPath = "$env:APPDATA\Notepad++"
    $nppCloudFolderPath = "$nppAppDataPath\cloud"
    $nppCloudFilePath = "$nppCloudFolderPath\choice"

    if (Test-Path -Path $nppSettingsFolderPath -PathType Container)
    {
        Write-PSFMessage "$nppSettingsFolderPath already exists, don't need to create it"
    }
    else
    {
        Invoke-ExpressionWithLogging -command "New-Item -Path $nppSettingsFolderPath -Type Directory -Force | Out-Null"
    }

    (New-Object System.Net.WebClient).DownloadFile($nppSettingsZipUrl, $nppSettingsZipFilePath)
    Expand-Archive -Path $nppSettingsZipFilePath -DestinationPath $nppSettingsTempFolderPath -Force
    Copy-Item -Path $nppSettingsTempFolderPath\* -Destination $nppSettingsFolderPath
    Copy-Item -Path $nppSettingsTempFolderPath\* -Destination $nppAppDataPath

    if (Test-Path -Path $nppCloudFolderPath -PathType Container)
    {
        Write-PSFMessage "$nppSettingsFolderPath already exists, don't need to create it"
    }
    else
    {
        Invoke-ExpressionWithLogging -command "New-Item -Path $nppCloudFolderPath -Type Directory -Force | Out-Null"
    }
    Set-Content -Path "$env:APPDATA\Notepad++\cloud\choice" -Value $nppSettingsFolderPath -Force

    # The chocolatey package for Everything includes an old version (1.1.0.9) of the es.exe CLI tool
    # Delete that one, then download the latest (1.1.0.21) from the voidtools site
    Remove-Item -Path "$env:ProgramData\chocolatey\bin\es.exe" -Force
    Remove-Item -Path "$env:ProgramData\chocolatey\lib\Everything\tools\es.exe" -Force
    $esZipUrl = 'https://www.voidtools.com/ES-1.1.0.21.zip'
    $esZipFileName = $esZipUrl.Split('/')[-1]
    $esZipFilePath = "$env:TEMP\$esZipFileName"
    (New-Object System.Net.WebClient).DownloadFile($esZipUrl, $esZipFilePath)
    Expand-Archive -Path $esZipFilePath -DestinationPath $toolsPath -Force

    $esIniUrl = 'https://raw.githubusercontent.com/craiglandis/ps/master/es.ini'
    $esIniFileName = $esIniUrl.Split('/')[-1]
    $esIniFilePath = "$toolsPath\$esIniFileName"
    (New-Object System.Net.WebClient).DownloadFile($esIniUrl, $esIniFilePath)

    if ($group -in 'PC', 'VM')
    {
        # Download some Nirsoft tools into the tools path
        Invoke-ExpressionWithLogging -command "Invoke-Expression ((New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/craiglandis/ps/master/Get-NirsoftTools.ps1'))"
    }

    $ahkZipFileUrl = 'https://www.autohotkey.com/download/ahk.zip'
    $ahkZipFileName = $ahkZipFileUrl.Split('/')[-1]
    $ahkFolderPath = "$env:userprofile\downloads\$($ahkZipFileName.Replace('.zip',''))"
    (New-Object System.Net.WebClient).DownloadFile($ahkZipUrl, $ahkFolderPath)
    $ahkExeFilePath = "$ahkFolderPath\AutoHotkey.exe"

    $ahkFileUrl = 'https://raw.githubusercontent.com/craiglandis/ps/master/ahk.ahk'
    $ahkFileName = $ahkFileUrl.Split('/')[-1]
    $ahkFilePath = "$myFolderPath\$ahkFileName"
    $ahkNotElevatedFileUrl = 'https://raw.githubusercontent.com/craiglandis/ps/master/ahk_not_elevated.ahk'
    $ahkNotElevatedFileName = $ahkNotElevatedFileUrl.Split('/')[-1]
    $ahkNotElevatedFilePath = "$myFolderPath\$ahkNotElevatedFileName"

    $ahkFilePath = ''
    Copy-Item -Path \\tsclient\c\onedrive\ahk\AutoHotkey.ahk -Destination c:\my\ahk\AutoHotkeyU64.ahk

    $ahkZipFileName =
    $ahkZipFilePath = "$env:userprofile\downloads"

    (New-Object System.Net.WebClient).DownloadFile($nppSettingsZipUrl, $nppSettingsZipFilePath)

    # autohotkey.portable - couldn't find a way to specify a patch for this package
    # (portable? https://www.autohotkey.com/download/ahk.zip)

    # https://www.thenickmay.com/how-to-install-autohotkey-even-without-administrator-access/
    # It works - the .ahk file must be named AutoHotkeyU64.ahk, then you run AutoHotkeyU64.exe
    # copy-item -Path \\tsclient\c\onedrive\ahk\AutoHotkey.ahk -Destination c:\my\ahk\AutoHotkeyU64.ahk

    $scriptDuration = '{0:hh}:{0:mm}:{0:ss}.{0:ff}' -f (New-TimeSpan -Start $scriptStartTime -End (Get-Date))
    Write-PSFMessage "$scriptName duration: $scriptDuration"

    $psFrameworkLogPath = Get-PSFConfigValue -FullName PSFramework.Logging.FileSystem.LogPath
    $psFrameworkLogFile = Get-ChildItem -Path $psFrameworkLogPath | Sort-Object LastWriteTime -desc | Select-Object -First 1
    $psFrameworkLogFilePath = $psFrameworkLogFile.FullName
    Copy-Item -Path $psFrameworkLogFilePath -Destination "$env:USERPROFILE\Desktop"
    Copy-Item -Path "$env:ProgramData\chocolatey\logs\chocolatey.log" -Destination "$env:USERPROFILE\Desktop"

    Invoke-ExpressionWithLogging -command 'Restart-Computer -Force'
    #$command = "Restart-Computer -Force"
    #Write-PSFMessage $command
    #Invoke-Expression -Command $command
}
