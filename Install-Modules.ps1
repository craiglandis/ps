<#
start cmd /k pwsh -NoLogo -NoProfile -NoExit -File C:\OneDrive\my\Install-Modules.ps1
start cmd /k powershell -NoLogo -NoProfile -NoExit -File C:\OneDrive\my\Install-Modules.ps1

start cmd /k pwsh -NoLogo -NoProfile -NoExit -Command Install-Module PowerShellGet -Force -AllowClobber
start cmd /k pwsh -NoLogo -NoProfile -NoExit -Command Install-Module PowerShellGet -Force -AllowClobber -AllowPrerelease

Az.Tools.Predictor is broken in latest version 0.5.0, so keeping it uninstalled for now

C:\>pwsh -noprofile -nologo -command Uninstall-Module -Name Az.Tools.Predictor

C:\>powershell -noprofile -nologo -command Uninstall-Module -Name Az.Tools.Predictor

https://github.com/Azure/azure-powershell/issues/16586

#>

param(
    [string]$name,
    [switch]$listOnly,
    [switch]$uninstallSuperseded,
    [switch]$uninstallUnspecifiedModules,
    [switch]$installAzModules
)

function out-log
{
    param(
        [string]$text,
        [string]$prefix = 'Both',
        [switch]$raw
    )

    If ($raw)
    {
        $text
    }
    ElseIf ($prefix -eq 'Timespan' -and $startTime)
    {
        $timespan = New-TimeSpan -Start $startTime -End (Get-Date)
        #$timespanString = '[{0:hh}:{0:mm}:{0:ss}.{0:ff}]' -F $timespan
        $prefixString = '[{0:mm}:{0:ss}.{0:ff}]' -F $timespan
    }
    ElseIf ($prefix -eq 'Both' -and $startTime)
    {
        $timestamp = Get-Date -Format 'yyyy-MM-dd hh:mm:ss'
        $timespan = New-Timespan -Start $startTime -End (Get-Date)
        #$timespanString = "$($timestamp) $('[{0:hh}:{0:mm}:{0:ss}.{0:ff}]' -F $timespan)"
        $prefixString = "$($timestamp) $('[{0:mm}:{0:ss}]' -F $timespan)"
    }
    else
    {
        $prefixString = Get-Date -Format 'yyyy-MM-dd hh:mm:ss'
    }
    Write-Host $prefixString -NoNewLine -ForeGroundColor Cyan
    Write-Host " $text"
    "$prefixString $text" | Out-File $logFilePath -Append
}

$startTime = Get-Date
$logFilePath = "$($PSCommandPath.Substring(0, $PSCommandPath.Length - 4))_$env:COMPUTERNAME.log"
$PSDefaultParameterValues = @{
    'Write-Color:LogFile' = $logFilePath
    'Write-Color:LogTime' = $true
    'Write-Color:ShowTime' = $true
    'Write-Color:TimeFormat' = 'yyyy-MM-dd HH:mm:ss'
	#'Get-Module:ListAvailable' = $true
    #'Find-Module:AllowPrerelease' = $true
    # Uninstall-Module -AllowPrerelease makes it uninstall the prerelease version instead of the release version
    # This script will install release versions except for a few exceptions, so don't want to make -AllowPrerelease the default
    #'Uninstall-Module:AllowPrerelease' = $true
    # This script will install release versions except for a few exceptions, so don't want to make -AllowPrerelease the default
    #'Install-Module:AllowPrerelease' = $true
    #'Install-Module:AllowClobber' = $true
	#'Install-Module:Force' = $true
    #'Install-Module:Repository' = 'PSGallery'
    #'Install-Module:Scope' = 'CurrentUser'
    #'Install-Module:SkipPublisherCheck' = $true
}

# This needs to be before Set-PSRepository, otherwise Set-PSRepository will prompt to install it
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

#Write-Color "Log: ", $logFilePath -Color Gray, White

# First make sure PSWriteColor is installed since the script relies on its Write-Color cmdlet for logging
$moduleName = 'PSWriteColor'
if (Get-Module -Name $moduleName -ListAvailable)
{
    Write-Color "$moduleName already installed, no need to install it"
}
else
{
    if ($listOnly)
    {
        Write-Output "$moduleName not installed, will install it since the script uses it for logging. Will uninstall it at end of script"
        $uninstallPSWriteColor = $true
    }
    $command = "Install-Module -Name $moduleName -Repository PSGallery -Scope CurrentUser -AllowClobber -Force"
    Invoke-Expression -Command $command
    if (Get-Module -Name $moduleName -ListAvailable)
    {
        Write-Color "Running: ", $command -Color Gray, Cyan
    }
    else
    {
        Write-Output "Unable to install $moduleName module needed for logging"
        exit
    }
}

# PowerShellGet 1.6.0 or higher is required to install prerelease modules on PS5.1. Without that there is no -AllowPrerelease parameter.
# https://github.com/PowerShell/PSReadLine#install-from-powershellgallery-preferred
$moduleName = 'PowerShellGet'
$powerShellGetInstalledVersions = Get-Module -Name $moduleName -ListAvailable
$powerShellGetLatestInstalledVersion = $powerShellGetInstalledVersions | Sort-Object {[Version]$_.Version} | Select-Object -Last 1
Write-Color "$($powerShellGetLatestInstalledVersion.Version) is the latest $moduleName installed version"
$powerShellGetLatestGalleryVersion = Find-Module -Name $moduleName
Write-Color "$($powerShellGetLatestGalleryVersion.Version) is the latest $moduleName gallery version"
if ($powerShellGetLatestInstalledVersion.Version -ge $powerShellGetLatestGalleryVersion.Version)
{
    Write-Color "Latest $moduleName version is already installed $($powerShellGetLatestInstalledVersion.Version)"
}
else
{
    if ($listOnly)
    {
        Write-Color "-listOnly specified, skipping PowerShellGet install"
    }
    else
    {
        $command = "Install-Module -Name $moduleName -Repository PSGallery -Scope CurrentUser -AllowClobber -Force"
        Write-Color "Running: ", $command -Color Gray, Cyan
        Invoke-Expression -Command $command
        $powerShellGetInstalledVersions = Get-Module -Name $moduleName -ListAvailable
        $powerShellGetLatestInstalledVersion = $powerShellGetInstalledVersions | Sort-Object {[Version]$_.Version} | Select-Object -Last 1
        $packageManagementInstalledVersions = Get-Module -Name PackageManagement -ListAvailable
        $packageManagementLatestInstalledVersion = $packageManagementInstalledVersions | Sort-Object {[Version]$_.Version} | Select-Object -Last 1

        # Remove and import PackageManagement and PowerShellGet to make sure it's using the latest installed version so the -AllowPrerelease parameter is available
        Remove-Module -Name PackageManagement
        Remove-Module -Name $moduleName
        Import-Module -Name PackageManagement -RequiredVersion $packageManagementLatestInstalledVersion.Version
        Import-Module -Name $moduleName -RequiredVersion $powerShellGetLatestInstalledVersion.Version -Force

        if ($powerShellGetLatestInstalledVersion.Version -ge $powerShellGetLatestGalleryVersion.Version)
        {
            Write-Color "Latest $moduleName release version is already installed $($powerShellGetLatestInstalledVersion.Version)"
            # Now that a version that supports -AllowPrerelease is installed, install it again with -AllowPrerelease to get latest prerelease version
            $command = "Install-Module -Name $moduleName -Repository PSGallery -Scope CurrentUser -AllowClobber -AllowPrerelease -Force"
            Write-Color "Running: ", $command -Color Gray, Cyan
            Invoke-Expression -Command $command
            $powerShellGetInstalledVersions = Get-Module -Name $moduleName -ListAvailable
            $powerShellGetLatestInstalledVersion = $powerShellGetInstalledVersions | Sort-Object {[Version]$_.Version} | Select-Object -Last 1
            Write-Color "$moduleName version $($powerShellGetLatestInstalledVersion.Version) is now installed"
        }
        else
        {
            Write-Color "Unable to install $moduleName module. Installing prerelease modules (-AllowPreRelease) on PS5.1 requires PowerShellGet 1.6.0 or higher"
            exit
        }
    }
}

if ($listOnly)
{
    Write-Color "-listOnly specified, skipping Microsoft-Windows-TaskScheduler/Operational config changes"
}
else
{
    $log = Get-WinEvent -ListLog 'Microsoft-Windows-TaskScheduler/Operational'

    if ($log.MaximumSizeInBytes -lt 104857600)
    {
        Write-Color "Changing log size from $([Math]::Round($($($log.MaximumSizeInBytes)/1MB),0))MB to $([Math]::Round($(104857600/1MB),0))MB" # -Color Gray, White
        #Out-Log "Changing log size from $([Math]::Round($($($log.MaximumSizeInBytes)/1MB),0))MB to $([Math]::Round($(104857600/1MB),0))MB"
        $log.MaximumSizeInBytes = 104857600
        $log.SaveChanges()
    }

    if ($log.IsEnabled = $false)
    {
        Write-Color "Changing IsEnabled from $($log.IsEnabled) to True"
        #Out-Log "Changing IsEnabled from $($log.IsEnabled) to True"
        $log.IsEnabled = $true
        $log.SaveChanges()
    }
}

# PowerShellGet is updated earlier in the script. PowerShellGet updates PackageManagement so no need to explicitly update PackageManagement
# PSScriptAnalyzer is often in use if VSCode is running, but it's fine if it fails in that situation (if needed, could explore having it kill VSCode if running)
# Az.Accounts is first in the list because installing Az.Tools.Installer will fail if Az.Accounts isn't installed
# The format is <moduleName>,<AllowPrerelease>,<SkipPublisherCheck>,<PSEditionDesktop>,<PSEditionCore>
# TODO: Add a fourth property for the scenario - PC vs. VM vs. vSAW
# Az.Tools.Predictor,True,False,False,True - leaving this out until bug is fixed post 0.5.0 release
$modules = @'
Az.Accounts,False,False
Az.Tools.Installer,True,False
CustomizeWindows11
ImportExcel,False,False
Microsoft.PowerShell.ConsoleGuiTools,True,False,False,True
Microsoft.PowerShell.GraphicalTools,True,False,False,True
Microsoft.PowerShell.FileUtility,True,False,False,True
Microsoft.PowerShell.SecretManagement,False,False
NTFSSecurity,False,False
oh-my-posh,True,False
Pester,False,True
posh-git,False,False
posh-gist,False,False
PoshRSJob,False,False
PowerShellCookbook,False,False
Profiler,False,False
PSDevOps,False,False
PSFramework,False,False
PSGraph,False,False
PSReadLine,True,False
PSScriptAnalyzer,False,False
PSScriptTools,False,False
PSWindowsUpdate,False,False
PSWordCloud,False,False,False,True
PSWriteHTML,False,False
Scour,False,False
SHiPS,False,False
Terminal-Icons,True,False
'@
$modules = $modules.Split("`n").Trim()

<#
AzurePSDrive,False,False
#>

if ($name)
{
    $modules = $name
}

# Get-InstalledModule returns just installed modules but not native inbox modules
$command = "Get-InstalledModule"
Write-Color $command
$installedModules = Invoke-Expression -Command $command
if (!$name)
{
    Write-Color $installedModules.Count, " modules installed" -Color Green, Gray
}

if ($listOnly)
{
    Write-Color "-listOnly specified, skipping unspecified module uninstall"
}
else
{
    Write-Color "Module(s) to check: ", $(if ($modules.Count -gt 1) {$modules -join ', '} else {$modules}) -Color Gray, Blue
    if ($uninstallUnspecifiedModules -and !$name)
    {
        $unspecifiedModules = Get-InstalledModule | Where-Object {$_.Name -notin $modules -and $_.Name -ne 'Az' -and !$_.Name.Startswith('Az.')} | Sort-Object -Property Name
        if ($unspecifiedModules -and $unspecifiedModules.Count -gt 0)
        {
            Write-Color $unspecifiedModules.Count, " unspecified modules will be uninstalled" -Color Cyan, Gray
            foreach ($unspecifiedModule in $unspecifiedModules) {
                $command = "Get-Module -Name $($unspecifiedModule.Name) -ListAvailable"
                Write-Color "Running: ", $command -Color Gray, White
                $unspecifiedModuleVersions = Invoke-Expression -Command $command
                if ($unspecifiedModuleVersions)
                {
                    Write-Color $unspecifiedModuleVersions.Count, " version(s) of ", $($unspecifiedModule.Name), " are installed. All versions will be uninstalled" -Color Cyan, Gray, Cyan, Gray
                    foreach ($unspecifiedModuleVersion in $unspecifiedModuleVersions) {
                        Write-Color "Uninstalling ", $($unspecifiedModuleVersion.Name), " version ", $($unspecifiedModuleVersion.Version) -Color Gray, Cyan, Gray, Cyan
                        $unspecifiedModuleVersion | Uninstall-Module #-WhatIf # -ErrorAction Stop
                    }
                }
                else
                {
                    Write-Color "No unspecified module versions to uninstall."
                }
            }
        }
        else
        {
            Write-Color "No unspecified modules found. Nothing to uninstall."
        }
    }
}

<#
$moduleName = 'PSScriptTools'
$latest = Get-InstalledModule -Name $moduleName
Get-InstalledModule -Name $moduleName -AllVersions | where-object {$_.Version -ne $latest.Version} | Uninstall-Module -WhatIf
#>

# -AsJob -ThrottleLimit 30 -Parallel - didn't provide a simple speed up, needed more work, for example, it kept showing that modules weren't installed that were
$modules | Sort-Object | ForEach-Object {#$installedModules | Where-Object Name -eq $moduleName | Sort-Object Version -Descending | Select-Object -First 1}

    # Determine latest installed version of the module
    #$moduleName = $_.Trim()
    Remove-Variable -Name moduleName -Force -ErrorAction SilentlyContinue
    Remove-Variable -Name allowPrerelease -Force -ErrorAction SilentlyContinue
    Remove-Variable -Name skipPublisherCheck -Force -ErrorAction SilentlyContinue

    $moduleName = $_.Split(',')[0]
    $allowPrerelease = $_.Split(',')[1]
    $skipPublisherCheck = $_.Split(',')[2]
    $supportsPSEditionDesktop = $_.Split(',')[3]
    $supportsPSEditionCore = $_.Split(',')[4]

    if ($moduleName)
    {
        $moduleName = $moduleName.Trim()
        if ($allowPrerelease)
        {
            $allowPrerelease = $allowPrerelease.Trim()
        }
        else
        {
            $allowPrerelease = 'False'
        }
        if ($skipPublisherCheck)
        {
            $skipPublisherCheck = $skipPublisherCheck.Trim()
        }
        else
        {
            $skipPublisherCheck = 'False'
        }
        if ($supportsPSEditionDesktop)
        {
            $supportsPSEditionDesktop = $supportsPSEditionDesktop.Trim()
        }
        else
        {
            $supportsPSEditionDesktop = 'True'
        }
        if ($supportsPSEditionCore)
        {
            $supportsPSEditionCore = $supportsPSEditionCore.Trim()
        }
        else
        {
            $supportsPSEditionCore = 'True'
        }
    }
    else
    {
        Write-Color "Module name not specified"
        return
    }

    if (($PSEdition -eq 'Desktop' -and $supportsPSEditionDesktop -eq 'False') -or ($PSEdition -eq 'Core' -and $supportsPSEditionCore -eq 'False'))
    {
        Write-Color "$moduleName is not supported on this version of PowerShell (`$PSEdition: $PSEdition)" -Color Yellow
        return
    }

    # Since $installedModules is the Get-InstalledModule output and Get-InstalledModule ONLY returns the latest version of each installed module relying on that to determine the latest installed version
    $latestInstalledModule = $installedModules | Where-Object Name -eq $moduleName
    #$ErrorActionPreference = 'SilentlyContinue'
    # Determine latest PSGallery version of the module
    # Find-Module only returns the latest version unless -AllVersions is specified, so don't need to sort for latest
    $command = "Find-Module -Name $moduleName"
    if ($allowPrerelease -eq 'True')
    {
        $command = "$command -AllowPrerelease"
    }
    Write-Color "Running: ", $command -Color Gray, White
    $galleryModule = Invoke-Expression -Command $command
    $galleryVersion = $galleryModule.Version.ToString()

    if ($latestInstalledModule)
    {
        $installedVersion = $latestInstalledModule.Version.ToString()
    }
    else
    {
        $installedVersion = 'Not Installed'
    }

    $global:debugInstalledVersion = $installedVersion
    $global:debugGalleryVersion = $galleryVersion

    if ($installedVersion -eq 'Not Installed')
    {
        if ($listOnly)
        {
            Write-Color $moduleName, " is not installed. Latest PSGallery version is ", $galleryVersion -Color Cyan, Gray, Cyan
        }
        else
        {
            Write-Color $moduleName, " is not installed. Installing latest PSGallery version ", $galleryVersion -Color Cyan, Gray, Cyan
            $command = "Install-Module -Name $moduleName -Repository PSGallery -Scope CurrentUser -AllowClobber -Force"
            if ($allowPrerelease -eq 'True')
            {
                $command = "$command -AllowPrerelease"
            }
            if ($skipPublisherCheck -eq 'True')
            {
                $command = "$command -SkipPublisherCheck"
            }
            Write-Color "Running: ", $command -Color Gray, White
            $result = Invoke-Expression -Command $command
            $command = "Get-Module -Name $moduleName -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1"
            Write-Color "Running: ", $command -Color Gray, White
            $installedModule = Invoke-Expression -Command $command
            $installedVersion = $installedModule.Version.ToString()
            Write-Color $moduleName, " installed version is ", $installedVersion -Color Green, Gray, Green
        }
    }
    elseif ($galleryVersion -eq $installedVersion)
    {
        if ($listOnly)
        {
            Write-Color "-listOnly specified, skipping uninstall of superseded modules"
        }
        else
        {
            if ($uninstallSuperseded)
            {
                Write-Color "Latest installed version: ", $installedVersion -Color Gray, Green
                $command = "Get-InstalledModule -Name $moduleName -AllVersions"
                Write-Color "Running: ", $command -Color Gray, White
                $installedVersions = Invoke-Expression -Command $command
                if ($installedVersions.Count -gt 1)
                {
                    Write-Color "Uninstalling ", $($installedVersions.Count-1), " superseded versions of ", $moduleName -Color Gray, Green, Gray, Green
                    $installedVersions | Where-Object {$_.Version -ne $installedVersion} | ForEach-Object {
                        $command = "Uninstall-Module -Name $($_.Name) -RequiredVersion $($_.Version) -Verbose"
                        if ($allowPrerelease -eq 'True')
                        {
                            $command = "$command -AllowPrerelease"
                        }
                        Write-Color "Running: ", $command -Color Gray, White
                        $result = Invoke-Expression -Command $command
                    }
                    <#
                        $installedVersions | Where-Object {$(if ($_.PrivateData.PSData.Prerelease) {"$($_.Version)-$($_.PrivateData.PSData.Prerelease)"} else {"$($_.Version)"}) -ne $installedVersion} | ForEach-Object {
                        Write-Color "Uninstalling ", $($_.Name), " version ", $($_.Version) -Color Gray, Green, Gray, Green
                        $_ | Uninstall-Module #-ErrorAction Stop
                        #$command = "Uninstall-Module -Name $($_.Name) -RequiredVersion $($_.Version)"
                        #Write-Color "Running: ", $command -Color Gray, White
                        #Invoke-Expression -Command $command
                    }
                    #>
                }
                else
                {
                    Write-Color "No superseded versions to uninstall. ", $installedVersion, " is the only installed version of ", $moduleName -Color Gray, Green, Gray, Green
                }
            }
        }
        Write-Color $moduleName, " Installed: ", $installedVersion, " PSGallery: ", $installedVersion, "" -Color Green, Gray, Green, Gray, Green
    }
    elseif ($galleryVersion -gt $installedVersion)
    {
        if ($listOnly)
        {
            Write-Color "-listOnly specified, skipping uninstall of superseded modules"
        }
        else
        {
            if ($uninstallSuperseded)
            {
                Write-Color "Latest installed version: ", $installedVersion -Color Gray, Green
                $command = "Get-InstalledModule -Name $moduleName -AllVersions"
                Write-Color "Running: ", $command -Color Gray, White
                $installedVersions = Invoke-Expression -Command $command
                if ($installedVersions.Count -gt 1)
                {
                    Write-Color "Uninstalling ", $($installedVersions.Count-1), " superseded versions of ", $moduleName -Color Gray, Green, Gray, Green
                    $installedVersions | Where-Object {$_.Version -ne $installedVersion} | ForEach-Object {
                        $command = "Uninstall-Module -Name $($_.Name) -RequiredVersion $($_.Version) -Verbose"
                        if ($allowPrerelease -eq 'True')
                        {
                            $command = "$command -AllowPrerelease"
                        }
                        Write-Color "Running: ", $command -Color Gray, White
                        $result = Invoke-Expression -Command $command
                    }
                    <#
                        $installedVersions | Where-Object {$(if ($_.PrivateData.PSData.Prerelease) {"$($_.Version)-$($_.PrivateData.PSData.Prerelease)"} else {"$($_.Version)"}) -ne $installedVersion} | ForEach-Object {
                        Write-Color "Uninstalling ", $($_.Name), " version ", $($_.Version) -Color Gray, Green, Gray, Green
                        $_ | Uninstall-Module #-ErrorAction Stop
                        #$command = "Uninstall-Module -Name $($_.Name) -RequiredVersion $($_.Version)"
                        #Write-Color "Running: ", $command -Color Gray, White
                        #Invoke-Expression -Command $command
                    }
                    #>
                }
                else
                {
                    Write-Color "No superseded versions to uninstall. ", $installedVersion, " is the only installed version of ", $moduleName -Color Gray, Green, Gray, Green
                }
            }
        }

        if ($listOnly)
        {
            Write-Color $moduleName, " Installed: ", $installedVersion, " PSGallery: ", $galleryVersion, "" -Color Green, Gray, Green, Gray, Cyan
        }
        else
        {
            Write-Color $moduleName, " Installed: ", $installedVersion, " PSGallery: ", $galleryVersion, "" -Color Green, Gray, Green, Gray, Cyan
            Write-Color "Updating ", $moduleName, " from ", $installedVersion, " to latest PSGallery version ", $galleryVersion -Color Gray, Green, Gray, Green, Gray, Cyan
            $command = "Install-Module -Name $moduleName -Repository PSGallery -Scope CurrentUser -AllowClobber -Force"
            if ($allowPrerelease -eq 'True')
            {
                $command = "$command -AllowPrerelease"
            }
            if ($skipPublisherCheck -eq 'True')
            {
                $command = "$command -SkipPublisherCheck"
            }
            Write-Color "Running: ", $command -Color Gray, White
            $result = Invoke-Expression -Command $command
            $command = "Get-Module -Name $moduleName -ListAvailable | Sort-Object Version | Select-Object -Last 1"
            Write-Color "Running: ", $command -Color Gray, White
            $installedModule = Invoke-Expression -Command $command
            $installedVersion = $installedModule.Version.ToString()
            Write-Color $moduleName, " installed version is ", $installedVersion -Color Green, Gray, Green
            #Out-Log "$moduleName installed version is $installedVersion"
        }
    }
    else
    {
        # PSGallery version being older than installed version should only happen if a prerelease version is installed but -AllowPreRelease wasn't specified for Find-Module when checking PSGallery
        Write-Color $moduleName, " Installed: ", $installedVersion, " PSGallery: ", $installedVersion, "" -Color Green, Gray, Green, Gray, Magenta
        #Out-Log "$moduleName installed version $installedVersion is newer than the PSGallery version $galleryVersion which should only happen if Install-Module was run with -AllowPreRelease, but Find-Module was run without -AllowPreRelease"
    }
}

if ($listOnly)
{
    Write-Color "-listOnly specified"
}
else
{
    if ($installAzModules)
    {
        $moduleName = 'Az.Tools.Installer'
        $command = "Get-Module -Name $moduleName -ListAvailable"
        Write-Color $command
        $azToolsInstaller = Invoke-Expression -Command $command
        if ($azToolsInstaller)
        {
            $command = "Set-PSRepository -Name PSGallery -InstallationPolicy Trusted"
            Write-Color $command
            $result = Invoke-Expression -Command $command
            $command = "Install-AzModule -Repository PSGallery -Scope CurrentUser -RemovePrevious -Force"
            Write-Color $command
            $result = Invoke-Expression -Command $command
            #Update-AzModule -RemovePrevious -Force
            #Uninstall-AzModule -RemoveAzureRm -AllVersion -Force
        }
        else
        {
            Write-Color $moduleName, " is not installed" -Color Cyan,Gray
        }
    }
    else
    {
        Write-Color "-installAzModules $installAzModules"
    }
}

$installedModules = Get-InstalledModule | Where-Object {$_.Name -ne 'Az' -and !$_.Name.Startswith('Az.')} | Sort-Object -Property Name | Format-Table -AutoSize Name, Version, @{Name = 'IsPrerelease'; Expression = {$_.AdditionalMetadata.IsPrerelease}} | Out-String
Write-Color $installedModules -Color Gray

$scriptDuration = New-Timespan -Start $startTime -End (Get-Date)
Write-Color "Script Duration: ", "$('{0:hh}:{0:mm}:{0:ss}.{0:ff}' -f $scriptDuration)" -Color Gray, Cyan
Write-Color "Log: ", $logFilePath -Color Gray, Cyan