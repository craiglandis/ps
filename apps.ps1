Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

reg add "HKCU\SOFTWARE\Microsoft\ServerManager" /v DoNotOpenServerManagerAtLogon /t REG_DWORD /d 1 /f

cinst 7zip.install -y
cinst notepadplusplus.install -y
cinst googlechrome -y
cinst sysinternals -y
cinst windirstat -y
cinst microsoft-windows-terminal -y
cinst autohotkey -y
cinst powershell-core -y
cinst azcopy10 -y
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
https://github.com/microsoft/winget-cli/releases/download/v0.1.4331-preview/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.appxbundle
Add-AppxPackage -Path Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.appxbundle

choco install chocolatey-core.extension
#>