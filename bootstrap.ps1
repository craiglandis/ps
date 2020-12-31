#@"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "(New-Object System.Net.WebClient).DownloadFile('https://aka.ms/bootstrap','c:\my\bootstrap.ps1');iex 'c:\my\bootstrap.ps1 -sysinternals'" 
param(
    [switch]$sysinternals
)

if ($PSBoundParameters.Count -eq 0)
{
    $all = $true
}

#Write-Output "`$PSBoundParameters.Count: $($PSBoundParameters.Count)"

Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

if ($sysinternals -or $all)
{
    #Chocolatey install of sysinternals is slow, download/extract zip is faster
    $uri = "http://live.sysinternals.com/Files/SysinternalsSuite.zip"
    $myPath = "$env:SystemDrive\tools"
    $outFile = "$myPath\SysinternalsSuite.zip"
    if (!(test-path $myPath)) {new-item -Path $myPath -ItemType Directory -Force}
    Invoke-WebRequest -UseBasicParsing -Uri $uri -OutFile $outFile -Verbose
    Expand-Archive -LiteralPath $outFile -DestinationPath $myPath -Force
    if ($sysinternals -and !$all)
    {
        exit
    }
}

iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

reg add "HKCU\SOFTWARE\Microsoft\ServerManager" /v DoNotOpenServerManagerAtLogon /t REG_DWORD /d 1 /f
reg add "HKCU\SOFTWARE\Microsoft\ServerManager" /v DoNotPopWACConsoleAtSMLaunch /t REG_DWORD /d 1 /f

choco install 7zip.install -y
choco install autohotkey.portable -y
choco install az.powershell -y
choco install azcopy10 -y
choco install azure-cli -y
choco install beyondcompare -y
choco install cpu-z.install -y
choco install crystaldiskmark -y
choco install everything -y
choco install fiddler -y
choco install gpu-z -y
choco install greenshot -y
choco install microsoft-edge -y
choco install microsoft-windows-terminal -y
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
