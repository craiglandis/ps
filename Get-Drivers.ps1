param(
    [Alias('3rdparty')]
    [switch]$thirdparty,
    [string]$xlsxFolderPath = $env:TEMP,
    [switch]$show
)

function Out-Log
{
    param(
        [string]$text,
        [switch]$verboseOnly,
        [switch]$startLine,
        [switch]$endLine,
        [switch]$raw,
        [switch]$logonly,
        [ValidateSet('Black','Blue','Cyan','DarkBlue','DarkCyan','DarkGray','DarkGreen','DarkMagenta','DarkRed','DarkYellow','Gray','Green','Magenta','Red','White','Yellow')]
        [string]$color = 'White'
    )

    $utc = (Get-Date).ToUniversalTime()

    $logTimestampFormat = 'yyyy-MM-dd hh:mm:ssZ'
    $logTimestampString = Get-Date -Date $utc -Format $logTimestampFormat

    if ([string]::IsNullOrEmpty($script:scriptStartTimeUtc))
    {
        $script:scriptStartTimeUtc = $utc
        $script:scriptStartTimeUtcString = Get-Date -Date $utc -Format $logTimestampFormat
    }

    if ([string]::IsNullOrEmpty($script:lastCallTime))
    {
        $script:lastCallTime = $utc
    }

    $lastCallTimeSpan = New-TimeSpan -Start $script:lastCallTime -End $utc
    $lastCallTotalSeconds = $lastCallTimeSpan | Select-Object -ExpandProperty TotalSeconds
    $lastCallTimeSpanFormat = '{0:ss}.{0:ff}'
    $lastCallTimeSpanString = $lastCallTimeSpanFormat -f $lastCallTimeSpan
    $lastCallTimeSpanString = "$($lastCallTimeSpanString)s"
    $script:lastCallTime = $utc

    if ($verboseOnly)
    {
        $callstack = Get-PSCallStack
        $caller = $callstack | Select-Object -First 1 -Skip 1
        $caller = $caller.InvocationInfo.MyCommand.Name
        if ($caller -eq 'Invoke-ExpressionWithLogging')
        {
            $caller = $callstack | Select-Object -First 1 -Skip 2
            $caller = $caller.InvocationInfo.MyCommand.Name
        }

        if ($verbose)
        {
            $outputNeeded = $true
        }
        else
        {
            $outputNeeded = $false
        }
    }
    else
    {
        $outputNeeded = $true
    }

    if ($outputNeeded)
    {
        if ($raw -or $global:helperOutputRaw)
        {
            if ($logonly)
            {
                if ($logFilePath)
                {
                    $text | Out-File $logFilePath -Append
                }
            }
            else
            {
                Write-Host $text -ForegroundColor $color
                if ($logFilePath)
                {
                    $text | Out-File $logFilePath -Append
                }
            }
        }
        else
        {
            $timespan = New-TimeSpan -Start $script:scriptStartTimeUtc -End $utc

            $timespanFormat = '{0:mm}:{0:ss}'
            $timespanString = $timespanFormat -f $timespan

            $consolePrefixString = "$timespanString "
            $logPrefixString = "$logTimestampString $timespanString $lastCallTimeSpanString"

            if ($logonly -or $global:quiet)
            {
                if ($logFilePath)
                {
                    "$logPrefixString $text" | Out-File $logFilePath -Append
                }
            }
            else
            {
                if ($verboseOnly)
                {
                    $consolePrefixString = "$consolePrefixString[$caller] "
                    $logPrefixString = "$logPrefixString[$caller] "
                }

                if ($startLine)
                {
                    $script:startLineText = $text
                    Write-Host $consolePrefixString -NoNewline -ForegroundColor DarkGray
                    Write-Host "$text " -NoNewline -ForegroundColor $color
                }
                elseif ($endLine)
                {
                    Write-Host $text -ForegroundColor $color
                    if ($logFilePath)
                    {
                        "$logPrefixString $script:startLineText $text" | Out-File $logFilePath -Append
                    }
                }
                else
                {
                    Write-Host $consolePrefixString  -NoNewline -ForegroundColor DarkGray
                    Write-Host $text -ForegroundColor $color
                    if ($logFilePath)
                    {
                        "$logPrefixString $text" | Out-File $logFilePath -Append
                    }
                }
            }
        }
    }
}

function Invoke-ExpressionWithLogging
{
    param(
        [string]$command,
        [switch]$raw,
        [switch]$verboseOnly,
        [switch]$commandWhatIf
    )

    # This results in error:
    # Cannot convert argument "newChar", with value: "", for "Replace" to type "System.Char": "Cannot convert value "" to
    # type "System.Char". Error: "String must be exactly one character long.""
    # $command = $command.Replace($green, '').Replace($reset, '')

    # Write-Host "[HELPER] `$global:whatif: $global:whatif" -ForegroundColor Yellow
    # Write-Host "[HELPER] `$script:whatif: $script:whatif" -ForegroundColor Yellow
    # Write-Host "[HELPER] `$commandWhatIf: $commandWhatIf" -ForegroundColor Cyan
    # if ($global:whatif -and $commandWhatIf)
    if ($commandWhatIf)
    {
        Out-Log "[WHATIF] $command" -color Cyan
    }
    else
    {
        if ($verboseOnly)
        {
            if ($verbose)
            {
                if ($raw -or $global:helperOutputRaw)
                {
                    Out-Log $command -verboseOnly -raw
                }
                else
                {
                    Out-Log $command -verboseOnly
                }
            }
        }
        else
        {
            if ($raw -or $global:helperOutputRaw)
            {
                Out-Log $command -raw
            }
            else
            {
                Out-Log $command
            }
        }

        try
        {
            Invoke-Expression -Command $command
        }
        catch
        {
            $global:errorRecordObject = $PSItem
            Out-Log "`n$command`n" -raw -color Red
            Out-Log "$global:errorRecordObject" -raw -color Red
            if ($LASTEXITCODE)
            {
                Out-Log "`$LASTEXITCODE: $LASTEXITCODE`n" -raw -color Red
            }
        }
    }
}

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
