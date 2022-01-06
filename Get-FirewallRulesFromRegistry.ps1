param(
    [string]$path
)

function Get-Rules
{
    param($path)

    if ($path -match 'SharedAccess')
    {
        $type = 'Local'
    }
    else
    {
        $type = 'GPO'
    }

    if ($path.StartsWith('HKLM'))
    {
        # Query from local machine's online registry
        Get-Item $path | Select-Object -ExpandProperty property | ForEach-Object {
            $name = $_
            $string = (Get-ItemProperty -Path $path -Name $name).$_
            $rule = [PSCustomObject]@{
                'Name'   = $name
                'Type'   = $type
                'String' = $string
            }
            [void]$rules.Add($rule)
        }
    }
    else
    {
        # Query from offline registry hive
        $hive.GetKey($path).Values | Select-Object ValueName, ValueData | ForEach-Object {
            $name = $_.ValueName
            $string = $_.ValueData
            $rule = [PSCustomObject]@{
                'Name'   = $name
                'Type'   = $type
                'String' = $string
            }
            [void]$rules.Add($rule)
        }
    }

    $rules | ForEach-Object {
        $rule = $_
        $name = $rule.Name
        $rule.String.Split('|') | ForEach-Object {
            $value = $_
            if ($value)
            {
                $propertyName = $value.Split('=')[0]
                $propertyValue = $value.Split('=')[1]
                # The registry string represents each profile as different values: Profile=Public|Profile=Domain
                # This will add them into a single comma-separated Profile property in the PowerShell object, making it easier to filter if needed
                if ($propertyName -eq 'Profile' -and $rule.Profile)
                {
                    $propertyValue = "$($rule.Profile),$propertyValue"
                }
                $rule | Add-Member -NotePropertyName $propertyName -NotePropertyValue $propertyValue -Force
            }
        }
        $rule | Add-Member -NotePropertyName 'DisplayName' -NotePropertyValue $rule.Name -Force
        $rule | Add-Member -NotePropertyName 'Name' -NotePropertyValue $name -Force

        if (!$rule.Profile)
        {
            $rule | Add-Member -NotePropertyName 'Profile' -NotePropertyValue 'Any' -Force
        }
    }
}

function Repair-Hive
{
    param(
        [string]$HiveFile
    )

    Write-Output ('Checking/Repairing hive {0}' -f $HiveFile)
    & "$PSScriptRoot\ChkReg.exe" /R /F $HiveFile *> $null
    if ($LASTEXITCODE -eq 0)
    {
        return $true

    }
    return $false
}

$localRulesPath = 'HKLM:\SYSTEM\CurrentControlSet\services\SharedAccess\Parameters\FirewallPolicy\FirewallRules'
$gpoRulesPath = 'HKLM:\Software\Policies\Microsoft\WindowsFirewall\FirewallRules'
$rules = New-Object System.Collections.ArrayList
$output = [PSCustomObject]@{}

if ($path)
{
    if (Test-Path $path)
    {
        Write-Output $path
        Add-Type -Path $PSScriptRoot\NLog.dll
        Add-Type -Path $PSScriptRoot\NFluent.dll
        Add-Type -Path $PSScriptRoot\Registry.dll
    }
    else
    {
        Write-Output "Path not found: $path"
        exit
    }

    $SystemFile = Get-ChildItem -Path $path -Recurse -Include SYSTEM
    if ($SystemFile)
    {
        if ($SystemFile.count -gt 0)
        {
            $SystemHiveRepaired = Repair-Hive -HiveFile $SystemFile
            if ($SystemHiveRepaired)
            {
                $hive = New-Object Registry.RegistryHiveOnDemand($SystemFile)
                if ($hive)
                {
                    $current = ($hive.GetKey('Select').Values | Where-Object ValueName -EQ 'Current').ValueData
                    $computerName = ($hive.GetKey("ControlSet00$current\Control\ComputerName\ComputerName").Values | Where-Object ValueName -EQ 'ComputerName').ValueData
                    $RDPTcp = $hive.GetKey("ControlSet00$Current\Control\Terminal Server\WinStations\RDP-Tcp").Values | Select-Object ValueName, ValueData
                    $portNumber = [int]($RDPTcp | Where-Object ValueName -EQ 'PortNumber').ValueData

                    Get-Rules "ControlSet00$current\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules"
                }
            }
        }
    }
    else
    {
        Write-Output 'No SYSTEM hive found'
        exit
    }

    $SoftwareFile = Get-ChildItem -Path $path -Recurse -Include SOFTWARE
    if ($SoftwareFile)
    {
        if ($SoftwareFile.count -gt 0)
        {
            $SoftwareHiveRepaired = Repair-Hive -HiveFile $SoftwareFile
            if ($SoftwareHiveRepaired)
            {
                $hive = New-Object Registry.RegistryHiveOnDemand($SoftwareFile)
                if ($hive)
                {
                    $osVersion = ($hive.GetKey('Microsoft\Windows NT\CurrentVersion').Values | Where-Object ValueName -EQ 'ProductName').ValueData

                    Get-Rules 'Policies\Microsoft\WindowsFirewall\FirewallRules'
                }
            }
        }
    }
    else
    {
        Write-Output 'No SYSTEM hive found'
        exit
    }
}
else
{
    $portNumber = Get-ItemPropertyValue -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name 'PortNumber'
    $osVersion = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'ProductName'
    $computerName = Get-ItemPropertyValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName' -Name 'ComputerName'

    if (Test-Path $localRulesPath)
    {
        get-rules -path $localRulesPath
    }

    if (Test-Path $gpoRulesPath)
    {
        get-rules -path $gpoRulesPath
    }
}

#Firewall Rule and the Firewall Rule Grammar Rule
#https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-gpfas/2efe0b76-7b4a-41ff-9050-1023f8196d16

$rdpAllowRules = $rules | Where-Object {$_.Action -eq 'Allow' -and `
        $_.Active -eq 'TRUE' -and `
        $_.Dir -eq 'In' -and `
        # Default Azure RDP NSG rule is TCP only, not UDP, so only check for TCP
        $_.Protocol -eq '6' -and `
    ($_.LPort -eq $portNumber -or !($_.LPort)) -and `
    (!($_.App) -or $_.App -eq 'System' -or ($_.App.Endswith('svchost.exe') -and ($_.Svc -eq 'termservice' -or $_.Svc -eq '*'))) -and `
        !($_.RPort) -and `
        !($_.LA4) -and `
        !($_.RA4) -and `
        !($_.RA6) -and `
        !($_.Security) -and `
        !($_.IFType) -and `
        !($_.AppPkgId) -and `
        !($_.Platform) -and `
        !($_.Platform2) -and `
        !($_.LUAuth) -and `
        !($_.RUAuth) -and `
        !($_.LPort2_10) -and `
        !($_.ComptId) -and `
        !($_.TTK2_27)
}

$rdpBlockRules = $rules | Where-Object {$_.Action -eq 'Block' -and `
        $_.Active -eq 'TRUE' -and `
        $_.Dir -eq 'In' -and `
        $_.Protocol -eq '6' -and # Default Azure RDP NSG rule is TCP only, not UDP, so only check for TCP
                                ($_.LPort -eq $portNumber -or !($_.LPort)) -and `
    (!($_.App) -or ($_.App.Endswith('svchost.exe') -and ($_.Svc -eq 'termservice' -or $_.Svc -eq '*'))) `
}

$global:r = $rules
$global:a = $rdpAllowRules
$global:b = $rdpBlockRules

if ($rdpAllowRules -and !$rdpBlockRules)
{
    $isGuestOSFirewallNotBlocking = $true
    $result = 'AllowRule_Yes_BlockRule_No'
    $message = 'Found RDP allow rule. No RDP block rule found. No action needed. RDP traffic is allowed.'
}
elseif (!$rdpAllowRules -and !$rdpBlockRules)
{
    $isGuestOSFirewallNotBlocking = $false
    $result = 'AllowRule_No_BlockRule_No'
    $message = "No RDP allow rule found. No RDP block rule found. Add an Allow rule for port $portNumber to permit RDP traffic."
}
elseif ($rdpAllowRules -and $rdpBlockRules)
{
    $isGuestOSFirewallNotBlocking = $false
    $result = 'AllowRule_Yes_BlockRule_Yes'
    $message = 'Found RDP allow rule. Found RDP block rule. Disable or remove the following block rule(s) to permit RDP traffic.'
    $message += "$($rdpBlockRules.Name)"
}
elseif (!$rdpAllowRules -and $rdpBlockRules)
{
    $isGuestOSFirewallNotBlocking = $false
    $result = 'AllowRule_No_BlockRule_Yes'
    $message = 'No RDP allow rule found. Found RDP block rule. Disable or remove the block rule(s) to permit RDP traffic.'
    $message += "$($rdpBlockRules.Name)"
}

$rulesCount = ($rules | Measure-Object).Count
$rdpAllowRulesCount = ($rdpAllowRules | Measure-Object).Count
$rdpBlockRulesCount = ($rdpBlockRules | Measure-Object).Count

$output | Add-Member -NotePropertyName 'computerName' -NotePropertyValue $computerName -Force
$output | Add-Member -NotePropertyName 'osVersion' -NotePropertyValue $osVersion -Force
$output | Add-Member -NotePropertyName 'portNumber' -NotePropertyValue $portNumber -Force
$output | Add-Member -NotePropertyName 'rules' -NotePropertyValue $rules -Force
$output | Add-Member -NotePropertyName 'rdpAllowRules' -NotePropertyValue $rdpAllowRules -Force
$output | Add-Member -NotePropertyName 'rdpBlockRules' -NotePropertyValue $rdpBlockRules -Force
$output | Add-Member -NotePropertyName 'rulesCount' -NotePropertyValue $rulesCount -Force
$output | Add-Member -NotePropertyName 'rdpAllowRulesCount' -NotePropertyValue $rdpAllowRulesCount -Force
$output | Add-Member -NotePropertyName 'rdpBlockRulesCount' -NotePropertyValue $rdpBlockRulesCount -Force
$output | Add-Member -NotePropertyName 'message' -NotePropertyValue $message -Force
$output | Add-Member -NotePropertyName 'result' -NotePropertyValue $result -Force
$output | Add-Member -NotePropertyName 'isGuestOSFirewallNotBlocking' -NotePropertyValue $isGuestOSFirewallNotBlocking -Force

$gpoPublicEnableFirewall = (Get-ItemProperty -Path 'HKLM:SOFTWARE\Policies\Microsoft\WindowsFirewall\PublicProfile' -Name 'EnableFirewall' -ErrorAction SilentlyContinue).EnableFireWall
$gpoDomainEnableFirewall = (Get-ItemProperty -Path 'HKLM:SOFTWARE\Policies\Microsoft\WindowsFirewall\DomainProfile' -Name 'EnableFirewall' -ErrorAction SilentlyContinue).EnableFireWall
$gpoStandardEnableFirewall = (Get-ItemProperty -Path 'HKLM:SOFTWARE\Policies\Microsoft\WindowsFirewall\StandardProfile' -Name 'EnableFirewall' -ErrorAction SilentlyContinue).EnableFireWall
$gpoPrivateEnableFirewall = (Get-ItemProperty -Path 'HKLM:SOFTWARE\Policies\Microsoft\WindowsFirewall\PrivateProfile' -Name 'EnableFirewall' -ErrorAction SilentlyContinue).EnableFireWall
$localPublicEnableFirewall = (Get-ItemProperty -Path 'HKLM:SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\PublicProfile' -Name 'EnableFirewall' -ErrorAction SilentlyContinue).EnableFireWall
$localDomainEnableFirewall = (Get-ItemProperty -Path 'HKLM:SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\DomainProfile' -Name 'EnableFirewall' -ErrorAction SilentlyContinue).EnableFireWall
$localStandardEnableFirewall = (Get-ItemProperty -Path 'HKLM:SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\StandardProfile' -Name 'EnableFirewall' -ErrorAction SilentlyContinue).EnableFireWall
$localPrivateEnableFirewall = (Get-ItemProperty -Path 'HKLM:SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\PrivateProfile' -Name 'EnableFirewall' -ErrorAction SilentlyContinue).EnableFireWall
$gpoPublicNoExceptions = (Get-ItemProperty -Path 'HKLM:SOFTWARE\Policies\Microsoft\WindowsFirewall\PublicProfile' -Name 'DoNotAllowExceptions' -ErrorAction SilentlyContinue).DoNotAllowExceptions
$gpoDomainNoExceptions = (Get-ItemProperty -Path 'HKLM:SOFTWARE\Policies\Microsoft\WindowsFirewall\DomainProfile' -Name 'DoNotAllowExceptions' -ErrorAction SilentlyContinue).DoNotAllowExceptions
$gpoStandardNoExceptions = (Get-ItemProperty -Path 'HKLM:SOFTWARE\Policies\Microsoft\WindowsFirewall\StandardProfile' -Name 'DoNotAllowExceptions' -ErrorAction SilentlyContinue).DoNotAllowExceptions
$gpoPrivateNoExceptions = (Get-ItemProperty -Path 'HKLM:SOFTWARE\Policies\Microsoft\WindowsFirewall\PrivateProfile' -Name 'DoNotAllowExceptions' -ErrorAction SilentlyContinue).DoNotAllowExceptions
$localPublicNoExceptions = (Get-ItemProperty -Path 'HKLM:SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\PublicProfile' -Name 'DoNotAllowExceptions' -ErrorAction SilentlyContinue).DoNotAllowExceptions
$localDomainNoExceptions = (Get-ItemProperty -Path 'HKLM:SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\DomainProfile' -Name 'DoNotAllowExceptions' -ErrorAction SilentlyContinue).DoNotAllowExceptions
$localStandardNoExceptions = (Get-ItemProperty -Path 'HKLM:SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\StandardProfile' -Name 'DoNotAllowExceptions' -ErrorAction SilentlyContinue).DoNotAllowExceptions
$localPrivateNoExceptions = (Get-ItemProperty -Path 'HKLM:SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\PrivateProfile' -Name 'DoNotAllowExceptions' -ErrorAction SilentlyContinue).DoNotAllowExceptions

$profiles = [PSCustomObject]@{
    gpoPublicEnableFirewall     = if ($gpoPublicEnableFirewall -ge 0) {$gpoPublicEnableFirewall} else {'Not Present'}
    gpoDomainEnableFirewall     = if ($gpoDomainEnableFirewall -ge 0) {$gpoDomainEnableFirewall} else {'Not Present'}
    gpoStandardEnableFirewall   = if ($gpoStandardEnableFirewall -ge 0) {$gpoStandardEnableFirewall} else {'Not Present'}
    gpoPrivateEnableFirewall    = if ($gpoPrivateEnableFirewall -ge 0) {$gpoPrivateEnableFirewall} else {'Not Present'}
    localPublicEnableFirewall   = if ($localPublicEnableFirewall -ge 0) {$localPublicEnableFirewall} else {'Not Present'}
    localDomainEnableFirewall   = if ($localDomainEnableFirewall -ge 0) {$localDomainEnableFirewall} else {'Not Present'}
    localStandardEnableFirewall = if ($localStandardEnableFirewall -ge 0) {$localStandardEnableFirewall} else {'Not Present'}
    localPrivateEnableFirewall  = if ($localPrivateEnableFirewall -ge 0) {$localPrivateEnableFirewall} else {'Not Present'}
    gpoPublicNoExceptions       = if ($gpoPublicNoExceptions -ge 0) {$gpoPublicNoExceptions} else {'Not Present'}
    gpoDomainNoExceptions       = if ($gpoDomainNoExceptions -ge 0) {$gpoDomainNoExceptions} else {'Not Present'}
    gpoStandardNoExceptions     = if ($gpoStandardNoExceptions -ge 0) {$gpoStandardNoExceptions} else {'Not Present'}
    gpoPrivateNoExceptions      = if ($gpoPrivateNoExceptions -ge 0) {$gpoPrivateNoExceptions} else {'Not Present'}
    localPublicNoExceptions     = if ($localPublicNoExceptions -ge 0) {$localPublicNoExceptions} else {'Not Present'}
    localDomainNoExceptions     = if ($localDomainNoExceptions -ge 0) {$localDomainNoExceptions} else {'Not Present'}
    localStandardNoExceptions   = if ($localStandardNoExceptions -ge 0) {$localStandardNoExceptions} else {'Not Present'}
    localPrivateNoExceptions    = if ($localPrivateNoExceptions -ge 0) {$localPrivateNoExceptions} else {'Not Present'}
}

$output | Add-Member -NotePropertyName 'profiles' -NotePropertyValue $profiles -Force

$outputMessage = $output.message

Write-Host "`n$outputMessage" -ForegroundColor Cyan

$output.profiles

$output | Select-Object -Property portNumber, rulesCount, rdpAllowRulesCount, rdpBlockRulesCount, isGuestOSFirewallNotBlocking, result

$separator = "`n$('='*40)`n"
Write-Host "$($separator)RDP allow rules found: $rdpAllowRulesCount$($separator)" -ForegroundColor Cyan
$rdpAllowRules

Write-Host "$($separator)RDP block rules found: $rdpBlockRulesCount$($separator)" -ForegroundColor Cyan
$rdpBlockRules