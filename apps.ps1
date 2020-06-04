Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

reg add "HKCU\SOFTWARE\Microsoft\ServerManager" /v DoNotOpenServerManagerAtLogon /t REG_DWORD /d 1 /f

cinst 7zip -y
cinst googlechrome -y
cinst notepadplusplus -y
cinst sysinternals -y
cinst windirstat -y
cinst microsoft-windows-terminal -y
cinst autohotkey -y
cinst powershell-core -y
<#
cinst greenshot -y
cinst vscode -y
cinst python -y
https://github.com/microsoft/winget-cli/releases/download/v0.1.4331-preview/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.appxbundle
Add-AppxPackage -Path Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.appxbundle
#>
