# To use in cloud shell:
# (New-Object Net.Webclient).DownloadFile('https://raw.githubusercontent.com/craiglandis/ps/master/New-AzILB.ps1', 'New-AzILB.ps1')
# ./New-AzILB.ps1 -resourceGroupName lbtestrg11 -location westus2 -userName craig -password <password>
# ./New-AzILB.ps1 -resourceGroupName lbtestrg12 -location westus2 -userName craig -password <password> -createNatGateway
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$resourceGroupName,
    [string]$location,
    [string]$userName,
    [string]$password,
    [switch]$createNatGateway
)

function Out-Log
{
    param(
        [string]$text,
        [string]$prefix = 'timespan',
        [switch]$raw
    )
    if ($raw)
    {
        $text
    }
    elseif ($prefix -eq 'timespan' -and $startTime)
    {
        $timespan = New-TimeSpan -Start $startTime -End (Get-Date)
        $prefixString = '[{0:mm}:{0:ss}.{0:ff}]' -f $timespan
    }
    elseif ($prefix -eq 'both' -and $startTime)
    {
        $timestamp = Get-Date -Format 'yyyy-MM-dd hh:mm:ss'
        $timespan = New-TimeSpan -Start $startTime -End (Get-Date)
        $prefixString = "$($timestamp) $('[{0:mm}:{0:ss}]' -f $timespan)"
    }
    else
    {
        $prefixString = Get-Date -Format 'yyyy-MM-dd hh:mm:ss'
    }
    Write-Host $prefixString -NoNewline -ForegroundColor Cyan
    Write-Host " $text"
    # "$prefixString text" | Out-File $logFilePath -Append
}

$scriptStartTime = Get-Date
$scriptStartTimeString = Get-Date -Date $scriptStartTime -Format yyyyMMddHHmmss
$scriptFullName = $MyInvocation.MyCommand.Path
$scriptPath = Split-Path -Path $scriptFullName
$scriptName = Split-Path -Path $scriptFullName -Leaf
$scriptBaseName = $scriptName.Split('.')[0]

$PSDefaultParameterValues['*:ErrorAction'] = 'Stop'
$PSDefaultParameterValues['*:WarningAction'] = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'

if ($password)
{
    $passwordSecureString = $password | ConvertTo-SecureString -AsPlainText -Force
}
else
{
    [securestring]$passwordSecureString = Read-Host -AsSecureString -Prompt "Password to use for the VM"
}

Out-Log "Creating resource group"
$resourceGroup = New-AzResourceGroup -Name $resourceGroupName -Location $location

if ($createNatGateway)
{
    Out-Log "Creating public IP for NAT gateway"
    $publicIpName = "$($resourceGroupName)ngpip1"
    $sku = 'Standard'
    $allocationMethod = 'Static'
    $publicIp = New-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name $publicIpName -Location $location -Sku $sku -AllocationMethod $allocationMethod

    Out-Log "Creating NAT gateway"
    $natGatewayName = "$($resourceGroupName)ng1"
    $sku = 'Standard'
    $natGateway = New-AzNatGateway -Location $location -ResourceGroupName $resourceGroupName -Name $natGatewayName -IdleTimeoutInMinutes 10 -Sku $sku -PublicIpAddress $publicIp
}

Out-Log "Creating backend subnet config"
$beSubnetName = 'beSubnet1'
$addressPrefix = '10.1.0.0/24'
if ($createNatGateway)
{
    $subnetConfig = New-AzVirtualNetworkSubnetConfig -Name $beSubnetName -AddressPrefix $addressPrefix -NatGateway $natGateway
}
else
{
    $subnetConfig = New-AzVirtualNetworkSubnetConfig -Name $beSubnetName -AddressPrefix $addressPrefix
}

Out-Log "Creating bastion subnet"
$bastionSubnetName = 'AzureBastionSubnet'
$bastionSubnetAddressPrefix = '10.1.1.0/24'
$bastsubnetConfig = New-AzVirtualNetworkSubnetConfig -Name $bastionSubnetName -AddressPrefix $bastionSubnetAddressPrefix

Out-Log "Creating virtual network"
$vnetName = "$($resourceGroupName)vn1"
$addressPrefix = '10.1.0.0/16'
$vnet = New-AzVirtualNetwork -Name $vnetName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix $addressPrefix -Subnet $subnetConfig,$bastsubnetConfig

Out-Log "Creating public IP for bastion host"
$bastionPipName = "$($resourceGroupName)bastionpip1"
$sku = 'Standard'
$allocationMethod = 'Static'
$bastionPublicIp = New-AzPublicIpAddress -Name $bastionPipName -ResourceGroupName $resourceGroupName -Location $location -Sku $sku -AllocationMethod $allocationMethod

Out-Log "Creating bastion host"
$bastionName = "$($resourceGroupName)bastion1"
New-AzBastion -Name $bastionName -ResourceGroupName $resourceGroupName -PublicIpAddress $bastionPublicIp -VirtualNetwork $vnet -AsJob

Out-Log "Creating NSG rule"
$nsgRuleName = 'AllowHTTP'
$nsgRuleDescription = 'Allow HTTP'
$nsgRule = New-AzNetworkSecurityRuleConfig -Name $nsgRuleName -Description $nsgRuleDescription -Protocol '*' -SourcePortRange '*' -DestinationPortRange '80' -SourceAddressPrefix 'Internet' -DestinationAddressPrefix '*' -Access 'Allow' -Priority '2000' -Direction 'Inbound'

Out-Log "Creating NSG"
$nsgName = "$($resourceGroupName)nsg1"
$nsg = New-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRule

Out-Log "Creating LB FE config"
$feConfigName = "$($resourceGroupName)feConfig1"
$feConfig = New-AzLoadBalancerFrontendIpConfig -Name $feConfigName -PrivateIpAddress '10.1.0.4' -SubnetId $vnet.subnets[0].Id

Out-Log "Creating LB BE config"
$beConfig = New-AzLoadBalancerBackendAddressPoolConfig -Name "$($resourceGroupName)beConfig1"

Out-Log "Creating probe"
$probeName = "$($resourceGroupName)probe1"
$probe = New-AzLoadBalancerProbeConfig -Name $probeName -Protocol 'tcp' -Port '80' -IntervalInSeconds '360' -ProbeCount '5'

Out-Log "Creating LB rule"
$lbRuleName = "$($resourceGroupName)lbRule1"
$lbRule = New-AzLoadBalancerRuleConfig -Name $lbRuleName -Protocol 'tcp' -FrontendPort '80' -BackendPort '80' -IdleTimeoutInMinutes '15' -FrontendIpConfiguration $feConfig -BackendAddressPool $beConfig -EnableTcpReset

Out-Log "Creating LB"
$lbName = "$($resourceGroupName)lb1"
$sku = 'Standard'
$lb = New-AzLoadBalancer -Name $lbName -ResourceGroupName $resourceGroupName -Location $location -Sku $sku -FrontendIpConfiguration $feConfig -BackendAddressPool $beConfig -LoadBalancingRule $lbRule -Probe $probe

$bepool = $lb | Get-AzLoadBalancerBackendAddressPoolConfig

Out-Log "Creating NIC"
$nic = New-AzNetworkInterface -Name "$($resourceGroupName)vm1nic1" -ResourceGroupName $resourceGroupName -Location $location -Subnet $vnet.Subnets[0] -NetworkSecurityGroup $nsg -LoadBalancerBackendAddressPool $bepool

Out-Log "Creating VM"
$vmsz = @{
    VMName = "$($resourceGroupName)vm1"
    VMSize = 'Standard_DS1_v2'
}
$vmos = @{
    ComputerName = "$($resourceGroupName)vm1"
    Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ($userName, $passwordSecureString)
}
$vmimage = @{
    PublisherName = 'MicrosoftWindowsServer'
    Offer = 'WindowsServer'
    Skus = '2022-datacenter-smalldisk'
    Version = 'latest'
}
$vmConfig = New-AzVMConfig @vmsz `
    | Set-AzVMOperatingSystem @vmos -Windows `
    | Set-AzVMSourceImage @vmimage `
    | Add-AzVMNetworkInterface -Id $nic.Id

New-AzVM -VM $vmConfig -ResourceGroupName $resourceGroupName -Location $location -Zone 1 -AsJob

$scriptDuration = '{0:hh}:{0:mm}:{0:ss}.{0:ff}' -f (New-TimeSpan -Start $scriptStartTime -End (Get-Date))
Out-Log "$scriptName duration: $scriptDuration"
