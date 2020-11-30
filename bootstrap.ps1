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
choco install notepadplusplus.install -y
choco install microsoft-edge -y
choco install windirstat -y
choco install microsoft-windows-terminal -y
choco install autohotkey -y
choco install powershell-core -y
choco install azcopy10 -y
choco install vscode -y

Update-Help -Force -ErrorAction SilentlyContinue

<#
choco install crystaldiskmark -y
choco install nircmd -y
choco install iperf3 -y
choco install windbg -y
choco install gpu-z -y
choco install screentogif -y
choco install speccy -y
choco install beyondcompare -y
choco install nmap -y
choco install tightvnc -y
choco install cpu-z.install -y
choco install dotnetcore-runtime -y
choco install postman -y
choco install fiddler -y
choco install wireshark -y
choco install winscp.install -y
choco install treesizefree -y
choco install az.powershell -y
choco install azure-cli -y
choco install git.install -y
choco install microsoftazurestorageexplorer -y
choco install vscode -y
choco install python -y
choco install greenshot -y
choco install powershell -y # WMF+PS5.1
choco install putty.install -y
choco install dotnetfx -y # .NET Framework 4.8
choco install googlechrome -y
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
