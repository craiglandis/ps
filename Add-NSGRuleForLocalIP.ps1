param (
    [string]$resourceGroupName,
    [string]$name,
    [ValidateSet('Beam', 'Quake', 'Xonotic')]
    [string]$game
)

$vm = Get-AzVM -ResourceGroupName $resourceGroupName -Name $name
$osType = $vm.StorageProfile.OsDisk.OsType

if ($vm.NetworkProfile.NetworkInterfaces.Count -gt 1)
{
    $nicId = ($vm.NetworkProfile.NetworkInterfaces | Where-Object Primary -eq $true).Id
}
else
{
    $nicId = $vm.NetworkProfile.NetworkInterfaces.Id
}

$nic = Get-AzNetworkInterface -ResourceId $nicId
$nicName = $nic.Name
# Check for NSG associated with the NIC
if ($nic.NetworkSecurityGroup.Id)
{
    $nicNsgId = $nic.NetworkSecurityGroup.Id
    $nicNsgName = $nicNsgId.Split('/')[8]
    $nicNsg = Get-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Name $nicNsgName
}

$ipConfig = $nic.IpConfigurations | Where-Object Primary -eq $true
$subnetId = $ipconfig.Subnet.Id
$subnetConfig = Get-AzVirtualNetworkSubnetConfig -ResourceId $subnetId
$subnetName = $subnetConfig.Name
# Check for NSG associated with the subnet
if ($subnetConfig.NetworkSecurityGroup.Id)
{
    $subnetNsgId = $subnetConfig.NetworkSecurityGroup.Id
    $subnetNsgName = $subnetNsgId.Split('/')[8]
    $subnetNsg = Get-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Name $subnetNsgName
}

#$vnetName = $nic.IpConfigurations.Subnet.Id.Split('/')[8]
#$vnet = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $resourceGroupName

if ($game)
{
    switch ($game) {
        'Beam' {$port = 30814}
        'Quake' {$port = 27960}
        'Xonotic' {$port = 26000}
    }
    $nsgRuleName = "Allow-Inbound-$port"
    $destinationPortRange = $port

    if ($nicNsg)
    {
        Write-Output "Adding NSG rule $nsgRuleName to NSG $nicNsgName attached to NIC $nicName"
        $nicNsgResult = $nicNsg | Add-AzNetworkSecurityRuleConfig -Name $nsgRuleName -Protocol * -Direction 'Inbound' -Priority 101 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange $destinationPortRange -Access 'Allow' -ErrorAction Stop | Set-AzNetworkSecurityGroup
        if ($nicNsgResult)
        {
            $subnetNsgResult.SecurityRules | Format-Table Name,Access,Priority,Direction,SourceAddressPrefix,DestinationPortRange -AutoSize
        }
    }

    if ($subnetNsg)
    {
        Write-Output "Adding NSG rule $nsgRuleName to NSG $subnetNsgName attached to subnet $subnetName"
        $subnetNsgResult = $subnetNsg | Add-AzNetworkSecurityRuleConfig -Name $nsgRuleName -Protocol * -Direction 'Inbound' -Priority 101 -SourceAddressPrefix -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange $destinationPortRange -Access 'Allow' -ErrorAction Stop | Set-AzNetworkSecurityGroup
        if ($subnetNsgResult)
        {
            $subnetNsgResult.SecurityRules | Format-Table Name,Access,Priority,Direction,SourceAddressPrefix,DestinationPortRange -AutoSize
        }
    }
}
else
{
    $localIpAddress = (Invoke-RestMethod -Uri https://checkip.amazonaws.com).Trim()
    $nsgRuleName = 'allow-from-local-ip'
    if ($osType -eq 'Windows')
    {
        $destinationPortRange = (3389,5986)
    }
    elseif ($osType -eq 'Linux')
    {
        $destinationPortRange = 22
    }

    if ($nicNsg)
    {
        Write-Output "Adding NSG rule $nsgRuleName to NSG $nicNsgName attached to NIC $nicName"
        $nicNsgResult = $nicNsg | Add-AzNetworkSecurityRuleConfig -Name $nsgRuleName -Protocol * -Direction 'Inbound' -Priority 100 -SourceAddressPrefix $localIpAddress -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange $destinationPortRange -Access 'Allow' -ErrorAction Stop | Set-AzNetworkSecurityGroup
        if ($nicNsgResult)
        {
            $subnetNsgResult.SecurityRules | Format-Table Name,Access,Priority,Direction,SourceAddressPrefix,DestinationPortRange -AutoSize
        }
    }

    if ($subnetNsg)
    {
        Write-Output "Adding NSG rule $nsgRuleName to NSG $subnetNsgName attached to subnet $subnetName"
        $subnetNsgResult = $subnetNsg | Add-AzNetworkSecurityRuleConfig -Name $nsgRuleName -Protocol * -Direction 'Inbound' -Priority 100 -SourceAddressPrefix $localIpAddress -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange $destinationPortRange -Access 'Allow' -ErrorAction Stop | Set-AzNetworkSecurityGroup
        if ($subnetNsgResult)
        {
            $subnetNsgResult.SecurityRules | Format-Table Name,Access,Priority,Direction,SourceAddressPrefix,DestinationPortRange -AutoSize
        }
    }
}