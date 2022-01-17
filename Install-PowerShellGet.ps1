# If 2.2.5+ isn't installed, this script will need to be run twice
# First to get 2.2.5 installed because without that, -AllowPrerelease isn't supported
# Second time to specify -AllowPrerelease
# Hopefully once v3 is no longer a prerelease version, it'll be a one step process from 1.0.0.1 to v3
# Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force; \\tsclient\c\onedrive\my\Install-PowerShellGet.ps1
$powerShellGet = Get-Module -Name PowerShellGet -ListAvailable
$powerShellGetVersion = $powershellget.Version[0]
if ($powerShellGetVersion -ge [Version]'2.2.5')
{
    Install-Module -Name PowerShellGet -Scope CurrentUser -AllowClobber -Force -AllowPrerelease
}
else
{
    Install-Module -Name PowerShellGet -Scope CurrentUser -AllowClobber -Force
}

return $powerShellGetVersion