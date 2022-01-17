<#
TODO:

Additional shell customizations
Install KE https://aka.ms/ke
Import KE connections
Install Visio

# wmic path Win32_TerminalServiceSetting where AllowTSConnections="0" call SetAllowTSConnections "1"
# reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f
# netsh advfirewall firewall set rule group="remote desktop" new enable=Yes
# Download and run from CMD
# @"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "(New-Object System.Net.WebClient).DownloadFile('https://aka.ms/bootstrap','c:\my\bootstrap.ps1');iex 'c:\my\bootstrap.ps1 -sysinternals'"
# Download and run from PS
# (New-Object System.Net.WebClient).DownloadFile('https://aka.ms/bootstrap','c:\my\bootstrap.ps1'); iex 'c:\my\bootstrap.ps1 -sysinternals'
# Run from RDP client
# Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force; Invoke-Expression ((New-Object Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
# Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force; \\tsclient\c\onedrive\my\bootstrap.ps1 -group VM
#>
[CmdletBinding()]
param(
    [ValidateSet('PC', 'VM', 'VSAW', 'All')]
    [string]$group,
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
    $apps = Get-Content -Path $PSScriptRoot\apps.json | ConvertFrom-Json
    $appNames = $apps.Name
    $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($appNames)
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
    # Alias Write-PSFMessage to Write-PSFMessage until confirming PSFramework module is installed
    Set-Alias -Name Write-PSFMessage -Value Write-Output
    $PSDefaultParameterValues['Write-PSFMessage:Level'] = 'Output'
    if ($PSVersionTable.PSVersion -ge [Version]'5.1')
    {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
       <# 2008R2/Win7 don't support TLS1.2 until PS5.1/WMF are installed, before then this will result in error:
        PS C:\> [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Exception setting "SecurityProtocol": "Cannot convert value "3312" to type "System.Net.SecurityProtocolType" due to invalid enumeration values. Specify one of the following enumeration values and try again. The possible enumeration values are "Ssl3, Tls"."
        #>
    }

    Invoke-ExpressionWithLogging -command "schtasks /delete /tn bootstrap /f"

    $appsJsonFileUrl = 'https://raw.githubusercontent.com/craiglandis/ps/master/apps.json'
    $appsJsonFilePath = "$PSScriptRoot\apps.json"
    if (!(Test-Path -Path $appsJsonFilePath -PathType Leaf))
    {
        (New-Object Net.Webclient).DownloadFile($appsJsonFileUrl, $appsJsonFilePath)
    }
    $apps = Get-Content -Path $appsJsonFilePath | ConvertFrom-Json

    if ($show)
    {
        $apps = $apps | Where-Object {$_.Groups -contains $group}
        $appCount = ($apps | Measure-Object).Count
        Write-PSFMessage "`nGroup: $group, Count: $appCount"
        Write-PSFMessage $apps
        exit
    }

    #$win32_OperatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem
    $win32_OperatingSystem = Get-WmiObject -Class Win32_OperatingSystem
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

    $ErrorActionPreference = 'SilentlyContinue'
    $chocoVersion = choco -v
    $ErrorActionPreference = 'Continue'

    if ($chocoVersion)
    {
        Write-PSFMessage "Chocolatey $chocoVersion already installed"
    }
    else
    {
        # Chocolatey install requires at least PS3. Clean install of 2008R2/Win7 only have PS2, so need to manually get PS5.1 installed on those
        if ($PSVersionTable.PSVersion -lt [Version]'3.0')
        {
            $installWmfScriptUrl = 'https://raw.githubusercontent.com/craiglandis/ps/master/install-wmf.ps1'
            $installWmfScriptFilePath = "$env:TEMP\$($installWmfScriptUrl.Split('/')[-1])"
            (New-Object System.Net.WebClient).DownloadFile($installWmfScriptUrl, $installWmfScriptFilePath)
            Invoke-ExpressionWithLogging -command $installWmfScriptFilePath
            # The install WMF script will issue a retart on its own
            exit
        }
        else
        {
            Invoke-ExpressionWithLogging -command "Invoke-Expression ((New-Object Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"

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

    # 14393+ definitely have PS5.1, 10240 and 10586 may not, but nobody uses those early days Win10 builds anymore anyway.
    # The chocolatey package checks if PowerShell 5.1 is installed, if so, it does not try to install it
    Invoke-ExpressionWithLogging -command "choco install powershell -y"
    if ($LASTEXITCODE -eq 3010)
    {
        Write-PSFMessage "Creating onstart scheduled task to run script again at startup"
        $scriptPath = "$env:SystemRoot\Temp\$scriptName"
        Invoke-ExpressionWithLogging -command "Copy-Item -Path $PSCommandPath -Destination $scriptPath"
        Invoke-ExpressionWithLogging -command "schtasks /create /tn bootstrap /sc onstart /delay 0000:30 /rl highest /ru system /tr `"powershell.exe -executionpolicy bypass -file $scriptPath`" /f"
        Invoke-ExpressionWithLogging -command "Restart-Computer -Force"
    }

    # This needs to be before Set-PSRepository, otherwise Set-PSRepository will prompt to install it
    if ($PSEdition -eq 'Desktop')
    {
        Write-PSFMessage 'Verifying Nuget 2.8.5.201+ is installed'
        $nuget = Get-PackageProvider -Name nuget -ErrorAction SilentlyContinue -Force
        if (!$nuget -or $nuget.Version -lt [Version]'2.8.5.201')
        {
            Invoke-ExpressionWithLogging -command 'Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force'
        }
        else
        {
            Write-PSFMessage "Nuget $($nuget.Version) already installed"
        }
    }

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
        Invoke-ExpressionWithLogging -command "Invoke-Expression ((New-Object Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"
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

    if ($isWin11 -or $isWin10)
    {
        # Install winget since it is not installed by default. It is supported on Win10/Win11 but not WS22 although you can get it working on WS22
        # Preview version didn't work, said it needed Microsoft.UI.Xaml 2.7.0 even after I installed Microsoft.UI.Xaml 2.7.0
        # $wingetAppXPackageUrl = 'https://github.com/microsoft/winget-cli/releases/download/v1.2.3411-preview/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
        $vcLibsUrl = 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx'
        $vcLibsFileName = $vcLibsUrl.Split('/')[-1]
        $vcLibsFilePath = "$env:TEMP\$vcLibsFileName"
        (New-Object System.Net.WebClient).DownloadFile($vcLibsUrl, $vcLibsFilePath)
        if (Test-Path -Path $vcLibsFilePath -PathType Leaf)
        {
            Invoke-ExpressionWithLogging -command "Add-AppPackage -Path $vcLibsFilePath"
        }

        $wingetAppXPackageUrl = 'https://github.com/microsoft/winget-cli/releases/download/v1.1.12653/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
        $wingetAppXPackageFileName = $wingetAppXPackageUrl.Split('/')[-1]
        $wingetAppXPackageFilePath = "$env:TEMP\$wingetAppXPackageFileName"
        (New-Object System.Net.WebClient).DownloadFile($wingetAppXPackageUrl, $wingetAppXPackageFilePath)

        if (Test-Path -Path $wingetAppXPackageFilePath -PathType Leaf)
        {
            Invoke-ExpressionWithLogging -command "Add-AppPackage -Path $wingetAppXPackageFilePath"
        }

        <#
        winget install --id Microsoft.Office --exact --silent --accept-package-agreements --accept-source-agreements
        Install-Package Microsoft.UI.Xaml -Version 2.7.1-prerelease.211026002

        # didn't need the license file but keeping it here just in case
        # $wingetAppXPackageLicenseUrl = 'https://github.com/microsoft/winget-cli/releases/download/v1.1.12653/9c0fe2ce7f8e410eb4a8f417de74517e_License1.xml'
        # $wingetAppXPackageLicenseFileName = $wingetAppXPackageLicenseUrl.Split('/')[-1]
        # $wingetAppXPackageLicenseFilePath = "$env:TEMP\$wingetAppXPackageLicenseFileName"
        # (New-Object System.Net.WebClient).DownloadFile($wingetAppXPackageLicenseUrl, $wingetAppXPackageLicenseFilePath)
        #if ((Test-Path -Path $wingetAppXPackageFilePath -PathType Leaf) -and (Test-Path -Path $wingetAppXPackageLicenseFilePath -PathType Leaf))
        #{
        #    Invoke-ExpressionWithLogging -command "Add-AppxProvisionedPackage -Online -PackagePath $wingetAppXPackageFilePath -LicensePath $wingetAppXPackageLicenseFilePath"
        #}

        #Register-PackageSource -provider NuGet -name nugetRepository -location https://www.nuget.org/api/v2
        #Install-Package Microsoft.UI.Xaml -Force
        # Install-Package Microsoft.VCLibs.140.00.UWPDesktop -Force
        #Get-Package Microsoft.UI.Xaml
        #>
    }

    if ($group -ne 'All')
    {
        $apps = $apps | Where-Object {$_.Groups -contains $group}
    }

    Write-PSFMessage "Mode: $group"
    Write-PSFMessage "$($apps.Count) apps to be installed"
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
        }
        elseif ($appName -and !$useChocolatey)
        {
            $command = "winget install --id $appName --exact --silent --accept-package-agreements --accept-source-agreements"
            Invoke-ExpressionWithLogging -command $command
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
    }

    if (Test-Path -Path $myPath -PathType Container)
    {
        Write-PSFMessage "$myPath already exists, don't need to create it"
    }
    else
    {
        Invoke-ExpressionWithLogging -command "New-Item -Path $myPath -Type Directory -Force | Out-Null"
    }

    # https://stackoverflow.com/questions/714877/setting-windows-powershell-environment-variables
    Write-PSFMessage "Adding $toolsPath and $myPath to user Path environment variable"
    $newUserPath = "$env:Path;$toolsPath;$myPath"
    Invoke-ExpressionWithLogging -command "[Environment]::SetEnvironmentVariable('Path', '$newUserPath', 'User')"

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

    if ($group -eq 'PC' -or $group -eq 'VM')
    {
        # Download some Nirsoft tools into the tools path
        Invoke-ExpressionWithLogging -command "Invoke-Expression ((New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/craiglandis/ps/master/Get-NirsoftTools.ps1'))"
    }

    # autohotkey.portable - couldn't find a way to specify a patch for this package
    # (portable? https://www.autohotkey.com/download/ahk.zip)

    # https://www.thenickmay.com/how-to-install-autohotkey-even-without-administrator-access/
    # It works - the .ahk file must be named AutoHotkeyU64.ahk, then you run AutoHotkeyU64.exe
    # copy-item -Path \\tsclient\c\onedrive\ahk\AutoHotkey.ahk -Destination c:\my\ahk\AutoHotkeyU64.ahk
    $vsCodeSystemPath = "$env:ProgramFiles\Microsoft VS Code\Code.exe"
    $vsCodeUserPath = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe"
    if ((Test-Path -Path $vsCodeSystemPath -PathType Leaf) -or (Test-Path -Path $vsCodeUserPath -PathType Leaf))
    {
        $vsCodeSettingsJsonUrl = 'https://raw.githubusercontent.com/craiglandis/ps/master/vscode_settings.json'
        $vsCodeSettingsJsonPath = "$env:APPDATA\Code\User\settings.json"
        Write-PSFMessage "Downloading $vsCodeSettingsJsonUrl"
        (New-Object System.Net.WebClient).DownloadFile($vsCodeSettingsJsonUrl, $vsCodeSettingsJsonPath)
    }
    else
    {
        Write-PSFMessage "VSCode not installed, skipping download of $vsCodeSettingsJsonUrl"
    }

    Invoke-ExpressionWithLogging -command "Update-Help -Force -ErrorAction SilentlyContinue"
    $pwshFilePath = "$env:ProgramFiles\PowerShell\7\pwsh.exe"
    if (Test-Path -Path $pwshFilePath -PathType Leaf)
    {
        Invoke-ExpressionWithLogging -Command "& `'$pwshFilePath`' -NoProfile -NoLogo -Command Update-Help -Force -ErrorAction SilentlyContinue"
    }

    New-Item -ItemType SymbolicLink -Path "$env:SystemDrive\od" -Target "$env:SystemDrive\OneDrive"
    New-Item -ItemType SymbolicLink -Path "$env:SystemDrive\my" -Target "$env:SystemDrive\OneDrive\My"
    New-Item -ItemType SymbolicLink -Path "$env:SystemDrive\bin" -Target "$env:SystemDrive\OneDrive\Tools"

    # To remove the symbolic links (Remove-Item won't do it):
    #(Get-Item -Path "$env:SystemDrive\od").Delete()
    #(Get-Item -Path "$env:SystemDrive\my").Delete()
    #(Get-Item -Path "$env:SystemDrive\bin").Delete()

    $scriptDuration = '{0:hh}:{0:mm}:{0:ss}.{0:ff}' -f (New-TimeSpan -Start $scriptStartTime -End (Get-Date))
    Write-PSFMessage "$scriptName duration: $scriptDuration"

    $psFrameworkLogPath = Get-PSFConfigValue -FullName PSFramework.Logging.FileSystem.LogPath
    $psFrameworkLogFile = Get-ChildItem -Path $psFrameworkLogPath | Sort-Object LastWriteTime -desc | Select-Object -First 1
    $psFrameworkLogFilePath = $psFrameworkLogFile.FullName
    Copy-Item -Path $psFrameworkLogFilePath -Destination "$env:USERPROFILE\Desktop"
    Copy-Item -Path "$env:ProgramData\chocolatey\logs\chocolatey.log" -Destination "$env:USERPROFILE\Desktop"

    Invoke-ExpressionWithLogging -command 'Restart-Computer -Force'
}
