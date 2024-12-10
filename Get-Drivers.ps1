param(
    [Alias('3rdparty')]
    [switch]$thirdparty,
    [string]$xlsxFolderPath = $env:TEMP,
    [switch]$show
)

$microsoftIssuers = @'
CN=Microsoft Code Signing PCA 2010, O=Microsoft Corporation, L=Redmond, S=Washington, C=US
CN=Microsoft Code Signing PCA 2011, O=Microsoft Corporation, L=Redmond, S=Washington, C=US
CN=Microsoft Code Signing PCA, O=Microsoft Corporation, L=Redmond, S=Washington, C=US
CN=Microsoft Windows Production PCA 2011, O=Microsoft Corporation, L=Redmond, S=Washington, C=US
CN=Microsoft Windows Third Party Component CA 2012, O=Microsoft Corporation, L=Redmond, S=Washington, C=US
CN=Microsoft Windows Third Party Component CA 2013, O=Microsoft Corporation, L=Redmond, S=Washington, C=US
CN=Microsoft Windows Third Party Component CA 2014, O=Microsoft Corporation, L=Redmond, S=Washington, C=US
CN=Microsoft Windows Verification PCA, O=Microsoft Corporation, L=Redmond, S=Washington, C=US
'@
$microsoftIssuers = $microsoftIssuers.Split("`n").Trim()

$wmiQuerySeconds = Measure-Command {$systemDrivers = Get-CimInstance -Query 'SELECT * FROM Win32_SystemDriver'} | Select-Object -ExpandProperty TotalSeconds
$wmiQuerySeconds = [Math]::Round($wmiQuerySeconds,2)

$driverCountFromWMI = $systemDrivers | Measure-Object | Select-Object -ExpandProperty Count
<#
AcceptPause
AcceptStop
Caption
CreationClassName
Description
DesktopInteract
DisplayName
ErrorControl
ExitCode
InstallDate
Name
PathName
PSComputerName
ServiceSpecificExitCode
ServiceType
Started
StartMode
StartName
State
Status
SystemCreationClassName
SystemName
TagId
#>
foreach ($systemDriver in $systemDrivers)
{
    $systemDriverPath = $systemDriver.PathName.Replace('\??\', '')
    $systemDriverFile = Get-Item -Path $systemDriverPath -ErrorAction SilentlyContinue
    if ($systemDriverFile)
    {
        $systemDriver | Add-Member -MemberType NoteProperty -Name Path -Value $systemDriverPath
        $systemDriver | Add-Member -MemberType NoteProperty -Name FileVersion -Value $systemDriverFile.VersionInfo.FileVersion
        $systemDriver | Add-Member -MemberType NoteProperty -Name FileVersionRaw -Value $systemDriverFile.VersionInfo.FileVersionRaw
        $systemDriver | Add-Member -MemberType NoteProperty -Name ProductVersion -Value $systemDriverFile.VersionInfo.ProductVersion
        $systemDriver | Add-Member -MemberType NoteProperty -Name ProductVersionRaw -Value $systemDriverFile.VersionInfo.ProductVersionRaw
        $systemDriver | Add-Member -MemberType NoteProperty -Name CompanyName -Value $systemDriverFile.VersionInfo.CompanyName
        $systemDriver | Add-Member -MemberType NoteProperty -Name LegalCopyright -Value $systemDriverFile.VersionInfo.LegalCopyright
    }

    $systemDriverFileSignature = Get-AuthenticodeSignature -FilePath $systemDriverPath -ErrorAction SilentlyContinue
    if ($systemDriverFileSignature)
    {
        $systemDriver | Add-Member -MemberType NoteProperty -Name Issuer -Value $systemDriverFileSignature.Signercertificate.Issuer
        $systemDriver | Add-Member -MemberType NoteProperty -Name Subject -Value $systemDriverFileSignature.Signercertificate.Subject
    }
}

$driverQuerySeconds = Measure-Command {$drivers = driverquery.exe /v /fo csv | ConvertFrom-Csv} | Select-Object -ExpandProperty TotalSeconds
$driverQuerySeconds = [Math]::Round($driverQuerySeconds,2)
$driverCountFromDriverquery = $drivers | Measure-Object | Select-Object -ExpandProperty Count

$issuers = $systemDrivers.Issuer | Sort-Object -Unique

Write-Output "$driverCountFromWMI drivers returned by Get-CimInstance -Query 'SELECT * FROM Win32_SystemDriver'"
Write-Output "$driverCountFromDriverquery drivers returned by driverquery.exe /v /fo csv | ConvertFrom-Csv"
Write-Output "$($wmiQuerySeconds)s to run Get-CimInstance -Query 'SELECT * FROM Win32_SystemDriver'"
Write-Output "$($driverQuerySeconds)s seconds to run driverquery.exe /v /fo csv | ConvertFrom-Csv"
$issuers

$global:dbgSystemDrivers = $systemDrivers

$runningSystemDrivers = $systemDrivers | Where-Object {$_.State -eq 'Running'}
$microsoftSystemDrivers = $systemDrivers | Where-Object {$_.Issuer -in $microsoftIssuers}
$thirdPartySystemDrivers = $systemDrivers | Where-Object {$_.Issuer -notin $microsoftIssuers}
$microsoftRunningSystemDrivers = $systemDrivers | Where-Object {$_.State -eq 'Running' -and $_.Issuer -in $microsoftIssuers}
$thirdPartyRunningSystemDrivers = $systemDrivers | Where-Object {$_.State -eq 'Running' -and $_.Issuer -notin $microsoftIssuers}

$global:dbgSystemDrivers = $systemDrivers
$global:dbgRunningSystemDrivers = $runningSystemDrivers
$global:dbgMicrosoftSystemDrivers = $microsoftSystemDrivers
$global:dbgMicrosoftRunningSystemDrivers = $microsoftRunningSystemDrivers
$global:dbgThirdPartySystemDrivers = $thirdPartySystemDrivers
$global:dbgThirdPartyRunningSystemDrivers = $thirdPartyRunningSystemDrivers

if ($show)
{
    $timestamp = Get-Date -Format yyyyMMddHHmmss
    $xlsxFilePath = "$xlsxFolderPath\Drivers_$($env:COMPUTERNAME)_$($timestamp).xlsx"
    $systemDrivers | Export-Excel -Path $xlsxFilePath -WorksheetName Win32_SystemDriver -TableStyle Medium12 -FreezeTopRow -AutoSize -MaxAutoSizeRows 3 -AutoFilter -NoNumberConversion * -ErrorAction Stop
    $drivers | Export-Excel -Path $xlsxFilePath -WorksheetName Driverquery -TableStyle Medium11 -FreezeTopRow -AutoSize -MaxAutoSizeRows 3 -AutoFilter -NoNumberConversion * -ErrorAction Stop
    Invoke-Item -Path $xlsxFilePath
}

#$runningDrivers | ft Name,FileVersionRaw,CompanyName,LegalCopyright,Issuer
# $runningDrivers | ft Name,Subject
if ($thirdparty)
{
    $thirdPartyRunningDrivers | Format-Table Name, DisplayName, CompanyName, Issuer, Path
}
else
{
    $runningDrivers | Format-Table Name, DisplayName, CompanyName, Issuer, Path
}

$signedDrivers = $drivers | Where-Object {$_.IsSigned}
$signedDrivers = $drivers | Where-Object {$_.IsSigned}
$systemDrivers = $systemDrivers | Where-Object {$_.IsSigned -and $_.Manufacturer -ne 'Microsoft' -and !($_.Manufacturer.StartsWith('(Standard')) -and !($_.Manufacturer.StartsWith('Standard')) -and !($_.Manufacturer.StartsWith('(Generic')) -and !($_.Manufacturer.StartsWith('Generic'))}

if ($3rdparty)
{
    $systemDrivers = $systemDrivers | Where-Object {$_.IsSigned -and $_.Manufacturer -ne 'Microsoft' -and !($_.Manufacturer.StartsWith('(Standard')) -and !($_.Manufacturer.StartsWith('Standard')) -and !($_.Manufacturer.StartsWith('(Generic')) -and !($_.Manufacturer.StartsWith('Generic'))}
}

if ($signed)
{
    $systemDrivers = $systemDrivers | Where-Object {$_.IsSigned -and $_.Manufacturer -ne 'Microsoft' -and !($_.Manufacturer.StartsWith('(Standard')) -and !($_.Manufacturer.StartsWith('Standard')) -and !($_.Manufacturer.StartsWith('(Generic')) -and !($_.Manufacturer.StartsWith('Generic'))}
}

if ($unsigned)
{

}

if ($verbose)
{
    $systemDrivers = Invoke-ExpressionWithLogging "$env:SystemRoot\System32\driverquery.exe /v /fo csv | ConvertFrom-Csv"
}
else
{
    $systemDrivers = Invoke-ExpressionWithLogging "$env:SystemRoot\System32\driverquery.exe /si /fo csv | ConvertFrom-Csv"
}
elseif ($3rdparty)
{
    $systemDrivers = driverquery /si /fo csv | ConvertFrom-Csv
}
else
{
    $systemDrivers = driverquery /si /fo csv | ConvertFrom-Csv
}

$systemDrivers
