#(new-object System.Net.WebClient).DownloadFile('https://raw.githubusercontent.com/craiglandis/ps/master/get-licensingstatus.ps1',"$pwd\get-licensingstatus.ps1")

enum LicenseStatus {
    Unlicensed = 0
    Licensed = 1
    OOBGrace = 2
    OOTGrace = 3
    NonGenuineGrace = 4
    Notification = 5
    ExtendedGrace = 6
}

$instanceMetadata = Invoke-RestMethod -Headers @{"Metadata"="true"} -URI http://169.254.169.254/metadata/instance?api-version=2019-03-11 -Method get

"Querying instance metadata"
if ([string]::IsNullOrEmpty($instanceMetadata.publisher))
{
    $createdFromMarketplaceImage = $false
}
else
{
    $createdFromMarketplaceImage = $true
    $marketplaceImage = "$($instanceMetadata.publisher).$($instanceMetadata.offer).$($instanceMetadata.sku).$($instanceMetadata.version)"
}

$publicIpAddressFromIpInfo = (invoke-restmethod http://ipinfo.io/json).ip
$azureKmsFullyQualifiedName = 'kms.core.windows.net'
$azureKmsIpAddress = '23.102.135.246'
$azureKmsIpAddressResolvedFromDNS = resolve-dnsname -Name $azureKmsFullyQualifiedName
$azureKmsPortPingSucceeded = test-netconnection -ComputerName $azureKmsIpAddress -Port 1688 -InformationLevel Quiet

"Querying SoftwareLicensingProduct`n"
$filter = "ApplicationID = '55c92734-d682-4d71-983e-d6ec3f16059f' AND PartialProductKey IS NOT NULL"
$softwareLicensingProduct = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter $filter
#@{Label="Grace period (days)"; Expression={$_.graceperiodremaining/1440}}

$status = [PSCustomObject][Ordered]@{
    ResourceId = $instanceMetadata.resourceId
    SubscriptionId = $instanceMetadata.subscriptionId
    ResourceGroupName = $instanceMetadata.resourceGroupName
    VMName = $instanceMetadata.name
    ComputerName = $env:COMPUTERNAME
    VMID = $instanceMetadata.vmId
    AzureKmsIpAddress = $azureKmsIpAddress
    AzureKmsIpAddressResolvedFromDNS = $azureKmsIpAddressResolvedFromDNS
    AzureKmsPortPingSucceeded = $azureKmsPortPingSucceeded
    PublicIpAddress = $instanceMetadata.network.interface.ipv4.ipAddress.publicIpAddress
    PublicIpAddressFromIpInfo = $publicIpAddressFromIpInfo
    PrivateIpAddress = $instanceMetadata.network.interface.ipv4.ipAddress.privateIpAddress
    #$instanceMetadata.network.interface.ipv6.ipAddress.publicIpAddress
    #$instanceMetadata.network.interface.ipv6.ipAddress.privateIpAddress
    MACAddress = $instanceMetadata.network.interface.macAddress
    VMSize = $instanceMetadata.vmSize
    CreatedFromMarketplaceImage = $createdFromMarketplaceImage
    MarketplaceImage = $marketplaceImage
    VMScaleSetName = $instanceMetadata.vmScaleSetName
    Location = $instanceMetadata.location
    Environment = $instanceMetadata.azEnvironment
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

"`nGetting activation events`n"
$events = Get-WinEvent -FilterHashtable @{LogName = 'Application'; ProviderName = 'Microsoft-Windows-Security-SPP'; Id = 12288,12289} -ErrorAction SilentlyContinue
$events | format-list @{Label = 'SystemTime'; Expression = {([xml]$_.ToXML()).Event.System.TimeCreated.SystemTime}}, Id, Message
if (($events | measure).Count -gt 0)
{
    "Showing the 5 most recent activation events`n"
    $events | sort RecordId -Descending | format-list @{Label = 'SystemTime'; Expression = {([xml]$_.ToXML()).Event.System.TimeCreated.SystemTime}}, LogName, ProviderName, Id, Message
}
else
{
    "No activation events found"
}

<#
   ForEach-Object {
    [PSCustomObject]@{
     Result = ($_.Properties)[1].Value
     'Minimum count needed to activate' = ($_.Properties)[2].Value
     'KMS client FQDN' = ($_.Properties)[3].Value
     'Client Machine ID (CMID)' = ($_.Properties)[4].Value
     'Client TimeStamp' = ($_.Properties)[5].Value
     'is client VM?' = [bool]($_.Properties)[6].Value
     'License State' = ($_.Properties)[7].Value
     'Time State to expiration (min)' = ($_.Properties)[8].Value
     GUID = ($_.Properties)[9].Value
    }
   }
#>