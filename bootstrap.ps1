# Download and run from CMD
# @"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "(New-Object System.Net.WebClient).DownloadFile('https://aka.ms/bootstrap','c:\my\bootstrap.ps1');iex 'c:\my\bootstrap.ps1 -sysinternals'" 
# Download and run from PS
# (New-Object System.Net.WebClient).DownloadFile('https://aka.ms/bootstrap','c:\my\bootstrap.ps1'); iex 'c:\my\bootstrap.ps1 -sysinternals'
param(
    [switch]$nirsoft,
    [switch]$steamcmd,
    [switch]$sysinternals    
)

if ($PSBoundParameters.Count -eq 0)
{
    $all = $true
}

Write-Output "`$PSBoundParameters.Count: $($PSBoundParameters.Count)"

Write-Output "Setting execution policy"
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

Write-Output "Creating $($PROFILE.AllUsersAllHosts)"
New-Item -Path $PROFILE.AllUsersAllHosts -Type File -Force | Out-Null

#Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Console\TrueTypeFont' -Name '000' -Value 'CaskaydiaCove Nerd Font'

# This needs to be before Set-PSRepository, otherwise Set-PSRepository will prompt to install it
if (!$IsCoreCLR)
{
    $nuget = Get-PackageProvider -Name nuget -ErrorAction SilentlyContinue -Force
    if ($nuget)
    {        
        if ($nuget.Version -lt [Version]'2.8.5.201')
        {   
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
        }
    }
}  

#Register-PSRepository -Name PSGallery –SourceLocation 'https://www.powershellgallery.com/api/v2' -InstallationPolicy Trusted
Write-Output "Trusting PSGallery"
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

Write-Output "Setting default parameter values"
$PSDefaultParameterValues.Add('Install-Module:Scope', 'AllUsers')
$PSDefaultParameterValues.Add('Install-Module:AllowClobber', $true)
$PSDefaultParameterValues.Add('Install-Module:Force', $true)

Write-Output "Installing Az module"
Install-Module -Name Az
Write-Output "Installing Az.Tools.Predictor module"
Install-Module -Name Az.Tools.Predictor
Write-Output "Installing ImportExcel module"
Install-Module -Name ImportExcel
Write-Output "Installing PSScriptAnalyzer module"
Install-Module -Name PSScriptAnalyzer
Write-Output "Installing Pester module"
Install-Module -Name Pester
# If VSCode is running, PSReadLine install may fail with a misleading error saying it needs elevation (even if install was from elevated PS)
# Workaround is to close VSCode, then install PSReadLine
Write-Output "Installing PSReadLine module"
Install-Module -Name PSReadLine -AllowPrerelease
Install-Module -Name oh-my-posh -AllowPrerelease
Install-Module -Name PowerShellGet
Install-Module -Name PSWindowsUpdate
Install-Module -Name PackageManagement
Install-Module -Name SHiPS
Install-Module -Name posh-git
Install-Module -Name PoshRSJob
Install-Module -Name posh-gist
Install-Module -Name Terminal-Icons

$url = 'https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/CascadiaCode.zip'
$filePath = "$env:temp\CascadiaCode.zip"
$folderPath = "$env:temp\CascadiaCode"
(New-Object System.Net.WebClient).DownloadFile($url, $filePath)
Expand-Archive -Path $filePath -DestinationPath $folderPath
$fontsFolder = (New-Object -ComObject Shell.Application).Namespace(0x14)
get-childitem $folderPath | foreach{$fontsFolder.CopyHere($_.FullName, 16)}
# C:\Users\<username>\AppData\Local\Microsoft\Windows\Fonts

if ($sysinternals -or $all)
{
    #Chocolatey install of sysinternals is slow, download/extract zip is faster
    $uri = 'http://live.sysinternals.com/Files/SysinternalsSuite.zip'
    $myPath = "$env:SystemDrive\tools"
    $outFile = "$myPath\SysinternalsSuite.zip"
    if (!(test-path $myPath)) {new-item -Path $myPath -ItemType Directory -Force}
    Invoke-WebRequest -UseBasicParsing -Uri $uri -OutFile $outFile -Verbose
    Expand-Archive -LiteralPath $outFile -DestinationPath $myPath -Force
    Remove-Item -Path $outFile -Force
    if ($sysinternals -and !$all)
    {
        exit
    }
}

if ($nirsoft -or $all)
{
    $uri = 'https://www.nirsoft.net/utils/fulleventlogview-x64.zip'
    $myPath = "$env:SystemDrive\tools"
    $outFile = "$myPath\fulleventlogview-x64.zip"
    if (!(test-path $myPath)) {new-item -Path $myPath -ItemType Directory -Force}
    Invoke-WebRequest -UseBasicParsing -Uri $uri -OutFile $outFile -Verbose
    Expand-Archive -LiteralPath $outFile -DestinationPath $myPath -Force
    Remove-Item -Path $outFile -Force
    if ($nirsoft -and !$all)
    {
        exit
    }
    # https://www.nirsoft.net/utils/uninstallview-x64.zip
    # https://www.nirsoft.net/utils/eventlogchannelsview-x64.zip
    # https://www.nirsoft.net/utils/encrypted_registry_view.html
    # https://www.nirsoft.net/toolsdownload/rdpv.zip
}

if ($steamcmd -or $all)
{
    $uri = 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip'
    $myPath = "$env:SystemDrive\tools"
    $outFile = "$myPath\steamcmd.zip"
    if (!(test-path $myPath)) {new-item -Path $myPath -ItemType Directory -Force}
    Invoke-WebRequest -UseBasicParsing -Uri $uri -OutFile $outFile -Verbose
    Expand-Archive -LiteralPath $outFile -DestinationPath $myPath -Force
    Remove-Item -Path $outFile -Force
    if ($steamcmd -and !$all)
    {
        exit
    }
}

iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Disable Server Manager from starting at Windows startup
reg add "HKCU\SOFTWARE\Microsoft\ServerManager" /v DoNotOpenServerManagerAtLogon /t REG_DWORD /d 1 /f
reg add "HKCU\SOFTWARE\Microsoft\ServerManager" /v DoNotPopWACConsoleAtSMLaunch /t REG_DWORD /d 1 /f
# Enable "Always show all icons in the notification area"
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v EnableAutoTray /t REG_DWORD /d 0 /f
# Show hidden files and folders
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Hidden /t REG_DWORD /d 1 /f
# Show file extensions
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideFileExt /t REG_DWORD /d 0 /f

# Get the name of the builtin local adminstrator account
$admin = get-localuser | where {$_.Enabled -and $_.SID.ToString().Endswith('-500')} | select -first 1
$adminName = $admin.Name
# Associate AutoHotkey .AHK extension with VSCode for editing
# VSCode location if installed as user
# $value = '\"C:\Users\' + $adminName + '\AppData\Local\Programs\Microsoft VS Code\Code.exe\" \"%1\'
# VSCode location if installed by chocolatey
$value = '\"C:\Program Files\Microsoft VS Code\Code.exe\" \"%1\'
New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Classes\AutoHotkeyScript\Shell\Edit\Command' -Name '(default)' -Value $value -PropertyType String -Force -ErrorAction SilentlyContinue

<# https://docs.chocolatey.org/en-us/faqs#what-is-the-difference-between-packages-no-suffix-as-compared-to.install.portable
What is the difference between packages named *.install (i. e. autohotkey.install), *.portable (i. e. autohotkey.portable) and * (i. e. autohotkey)?
tl;dr: Nearly 100% of the time, the package with no suffix (autohotkey in this example) is going to ensure the *.install. 
Still not sure why you would call the .install version specifically.
#>

choco install 7zip.install -y
choco install autohotkey -y # \\tsclient\c\OneDrive\My\Import-ScheduledTasks.ps1
choco install az.powershell -y
choco install azcopy10 -y
choco install azure-cli -y
choco install beyondcompare -y
choco install cpu-z.install -y
choco install crystaldiskmark -y
choco install everything -y
choco install fiddler -y
choco install gpu-z -y
choco install graphviz -y
choco install greenshot -y
choco install microsoft-edge -y
choco install microsoft-windows-terminal -y # not supported on Server SKUs
choco install microsoftazurestorageexplorer -y
choco install notepadplusplus.install -y
choco install powershell-core -y
choco install putty.portable -y
choco install screentogif -y
choco install vscode.install -y
choco install winscp.portable -y
choco install wireshark -y
choco install wiztree -y

Update-Help -Force -ErrorAction SilentlyContinue

<#
# https://docs.chocolatey.org/en-us/faqs#what-is-the-difference-between-packages-no-suffix-as-compared-to.install.portable
choco install autohotkey.portable -y
choco install autohotkey -y
choco install dotnetcore-runtime -y
choco install dotnetfx -y # .NET Framework 4.8
choco install etcher -y
choco install rufus.portable -y
choco install git.install -y
choco install googlechrome -y
choco install graphviz -y
choco install imagemagick.app -y
choco install iperf3 -y
choco install lessmsi -y
choco install microsoft-windows-terminal -y
choco install nircmd -y
choco install nmap -y
choco install postman -y
choco install powerbi -y
choco install powershell -y # WMF+PS5.1
choco install powertoys -y
choco install pswindowsupdate -y
choco install python3 -y
choco install speccy -y
choco install tightvnc -y
choco install treesizefree -y
choco install vscode -y
choco install windbg -y
choco install windirstat -y

#Chocolatey install of sysinternals is slow, will download zip instead
choco install sysinternals -y
cuninst sysinternals -y

$exeUri = 'https://download.microsoft.com/download/B/E/1/BE1F235A-836D-42AC-9BC1-8F04C9DA7E9D/vc_uwpdesktop.140.exe'
$exeName = $exeUri.Split('/')[-1]
Invoke-WebRequest -Uri $exeUri -OutFile $exeName
Start-Process -FilePath $exeName -ArgumentList '/install /quiet /norestart' -Wait
#https://github.com/microsoft/terminal/releases/download/v1.5.3142.0/Microsoft.WindowsTerminalPreview_1.5.3142.0_8wekyb3d8bbwe.msixbundle
$packageUri = 'https://github.com/microsoft/winget-cli/releases/download/v0.1.42241-preview/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.appxbundle'
$packageName = $packageUri.Split('/')[-1]
Invoke-WebRequest -Uri $packageUri -OutFile $packageName
Add-AppxPackage -Path $packageName

choco install chocolatey-core.extension
#>
