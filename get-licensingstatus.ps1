# One-liner that can be run frominside VM to download and run the script:
# set-executionpolicy bypass -scope process -force; iex ((new-object system.net.webclient).DownloadString('https://raw.githubusercontent.com/craiglandis/ps/master/get-licensingstatus.ps1'))

enum LicenseStatus {
    Unlicensed = 0
    Licensed = 1
    OOBGrace = 2
    OOTGrace = 3
    NonGenuineGrace = 4
    Notification = 5
    ExtendedGrace = 6
}

$win32_ComputerSystem = get-ciminstance -ClassName Win32_ComputerSystem
$win32_OperatingSystem = get-ciminstance -ClassName Win32_OperatingSystem
if ($win32_OperatingSystem)
{
    $osVersion = "$($win32_OperatingSystem.Caption) $($win32_OperatingSystem.Version)"
}

$instanceMetadata = Invoke-RestMethod -Headers @{'Metadata' = 'true'} -Method 'GET' -Uri 'http://169.254.169.254/metadata/instance?api-version=2019-06-01'

if ([string]::IsNullOrEmpty($instanceMetadata.compute.publisher))
{
    $createdFromMarketplaceImage = $false
}
else
{
    $createdFromMarketplaceImage = $true
    $marketplaceImage = "$($instanceMetadata.compute.publisher)|$($instanceMetadata.compute.offer)|$($instanceMetadata.compute.sku)|$($instanceMetadata.compute.version)"
}

$publicIpAddressFromIpInfo = (Invoke-RestMethod -Uri http://checkip.amazonaws.com/).Trim()
$azureKmsFullyQualifiedName = 'kms.core.windows.net'
$azureKmsIpAddress = '23.102.135.246'
$azureKmsIpAddressResolvedFromDNS = resolve-dnsname -Name $azureKmsFullyQualifiedName
if ($azureKmsIpAddressResolvedFromDNS)
{
    $azureKmsIpAddressResolvedFromDNS = $azureKmsIpAddressResolvedFromDNS.IPAddress
}
$azureKmsPortPingSucceeded = test-netconnection -ComputerName $azureKmsIpAddress -Port 1688 -InformationLevel Quiet

$filter = "ApplicationID = '55c92734-d682-4d71-983e-d6ec3f16059f' AND PartialProductKey IS NOT NULL"
$softwareLicensingProduct = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter $filter
#@{Label="Grace period (days)"; Expression={$_.graceperiodremaining/1440}}

$status = [PSCustomObject][Ordered]@{
    ResourceId = $instanceMetadata.compute.resourceId
    SubscriptionId = $instanceMetadata.compute.subscriptionId
    ResourceGroupName = $instanceMetadata.compute.resourceGroupName
    VMName = $instanceMetadata.compute.name
    ComputerName = $env:COMPUTERNAME
    OsVersion = $osVersion
    InstallDateUtc = get-date $win32_OperatingSystem.InstallDate.ToUniversalTime() -f yyyy-MM-ddTHH:mm:ssZ
    LastBootUpTimeUtc = get-date $win32_OperatingSystem.LastBootUpTime.ToUniversalTime() -f yyyy-MM-ddTHH:mm:ssZ
    LocalDateTimeUtc = get-date $win32_OperatingSystem.LocalDateTime.ToUniversalTime() -f yyyy-MM-ddTHH:mm:ssZ
    PartOfDomain = $win32_ComputerSystem.PartOfDomain
    Domain = $win32_ComputerSystem.Domain
    DomainRole = $win32_ComputerSystem.DomainRole
    VMID = $instanceMetadata.compute.vmId
    AzureKmsIpAddress = $azureKmsIpAddress
    AzureKmsIpAddressResolvedFromDNS = $azureKmsIpAddressResolvedFromDNS
    AzureKmsPortPingSucceeded = $azureKmsPortPingSucceeded
    PublicIpAddress = $instanceMetadata.network.interface.ipv4.ipAddress.publicIpAddress
    PublicIpAddressFromIpInfo = $publicIpAddressFromIpInfo
    PrivateIpAddress = $instanceMetadata.network.interface.ipv4.ipAddress.privateIpAddress
    #$instanceMetadata.network.interface.ipv6.ipAddress.publicIpAddress
    #$instanceMetadata.network.interface.ipv6.ipAddress.privateIpAddress
    MACAddress = $instanceMetadata.network.interface.macAddress
    VMSize = $instanceMetadata.compute.vmSize
    CreatedFromMarketplaceImage = $createdFromMarketplaceImage
    MarketplaceImage = $marketplaceImage
    VMScaleSetName = $instanceMetadata.compute.vmScaleSetName
    Location = $instanceMetadata.compute.location
    Environment = $instanceMetadata.compute.azEnvironment
    LicenseStatus = [LicenseStatus]$softwareLicensingProduct.LicenseStatus
    LicenseStatusReason = $softwareLicensingProduct.LicenseStatusReason
    GracePeriodRemaining = $softwareLicensingProduct.GracePeriodRemaining
    LicenseType = $softwareLicensingProduct.ProductKeyChannel
    PartialProductKey = $softwareLicensingProduct.PartialProductKey
    LicenseFamily = $softwareLicensingProduct.LicenseFamily
    KMSHostName = $softwareLicensingProduct.DiscoveredKeyManagementServiceMachineName
    KMSHostAddress = $softwareLicensingProduct.DiscoveredKeyManagementServiceMachineIPAddress
    DiscoveredKeyManagementServiceMachineIpAddress = $softwareLicensingProduct.DiscoveredKeyManagementServiceMachineIpAddress
    DiscoveredKeyManagementServiceMachinePort = $softwareLicensingProduct.DiscoveredKeyManagementServiceMachinePort
    VLActivationInterval = $softwareLicensingProduct.VLActivationInterval
    VLActivationType = $softwareLicensingProduct.VLActivationType
    VLActivationTypeEnabled = $softwareLicensingProduct.VLActivationTypeEnabled
    VLRenewalInterval = $softwareLicensingProduct.VLRenewalInterval
}

$status

$events = Get-WinEvent -FilterHashtable @{LogName = 'Application'; ProviderName = 'Microsoft-Windows-Security-SPP'; Id = 12288,12289} -ErrorAction SilentlyContinue
if (($events | measure-object).Count -gt 0)
{
    "Showing the 5 most recent activation events`n"
    $events | Sort-Object RecordId -Descending | format-list @{Label = 'SystemTime'; Expression = {([xml]$_.ToXML()).Event.System.TimeCreated.SystemTime}}, LogName, ProviderName, Id, Message
}
else
{
    "No activation events found"
}
