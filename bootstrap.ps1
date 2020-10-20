Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

reg add "HKCU\SOFTWARE\Microsoft\ServerManager" /v DoNotOpenServerManagerAtLogon /t REG_DWORD /d 1 /f

cinst 7zip.install -y
cinst notepadplusplus.install -y
#cinst microsoft-edge -y
#cinst googlechrome -y
#Chocolatey install of sysinternals is slow, will download zip instead
#cinst sysinternals -y
cinst windirstat -y
cinst microsoft-windows-terminal -y
cinst autohotkey -y
cinst powershell-core -y
cinst azcopy10 -y

$uri = "http://live.sysinternals.com/Files/SysinternalsSuite.zip"
$myPath = "$env:SystemDrive\my"
$outFile = "$myPath\SysinternalsSuite.zip"
if (!(test-path $myPath)) {new-item -Path $myPath -ItemType Directory -Force}
Invoke-WebRequest -UseBasicParsing -Uri $uri -OutFile $outFile -Verbose
Expand-Archive -LiteralPath $outFile -DestinationPath $myPath -Force

<#
cinst crystaldiskmark -y
cinst nircmd -y
cinst iperf3 -y
cinst windbg -y
cinst gpu-z -y
cinst screentogif -y
cinst speccy -y
cinst beyondcompare -y
cinst nmap -y
cinst tightvnc -y
cinst cpu-z.install -y
cinst dotnetcore-runtime -y
cinst microsoft-edge -y
cinst postman -y
cinst fiddler -y
cinst wireshark -y
cinst winscp.install -y
cinst treesizefree -y
cinst az.powershell -y
cinst azure-cli -y
cinst git.install -y
cinst microsoftazurestorageexplorer -y
cinst vscode -y
cinst python -y
cinst greenshot -y
cinst powershell -y # WMF+PS5.1
cinst putty.install -y
cinst dotnetfx -y # .NET Framework 4.8

$exeUri = 'https://download.microsoft.com/download/B/E/1/BE1F235A-836D-42AC-9BC1-8F04C9DA7E9D/vc_uwpdesktop.140.exe'
$exeName = $exeUri.Split('/')[-1]
Invoke-WebRequest -Uri $exeUri -OutFile $exeName
Start-Process -FilePath $exeName -ArgumentList '/install /quiet /norestart' -Wait
$packageUri = 'https://github.com/microsoft/winget-cli/releases/download/v0.1.42241-preview/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.appxbundle'
$packageName = $packageUri.Split('/')[-1]
Invoke-WebRequest -Uri $packageUri -OutFile $packageName
Add-AppxPackage -Path $packageName

choco install chocolatey-core.extension
#>
