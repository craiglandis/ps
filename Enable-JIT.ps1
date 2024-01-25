param(
     [string]$resourceGroupName,
     [string]$vmName,
     [switch]$remove
)

if ($remove)
{
    $rg = Get-AzResourceGroup -Name $resourceGroupName
    $location = $rg.Location
    Remove-AzJitNetworkAccessPolicy -ResourceGroupName $resourceGroupName -Location $location -Name 'default'
}
else
{
    $ipAddress = Get-NetIPAddress -AddressFamily IPv4 -PrefixOrigin Dhcp -SuffixOrigin Dhcp -Type Unicast -AddressState Preferred
    $ipAddress = $ipAddress.IPAddress
    if ($ipAddress.StartsWith('10.'))
    {
        Out-Log "IP is $ipAddress, looks like you're on corpnet, so JIT access is needed"
    }
    else
    {
        Out-Log "IP is $ipAddress, you're not on corpnet, so JIT access is not needed"
        Out-Log "Enable JIT access anyway? [Y/N]"
        $answer = Read-Host
        if ($answer -eq 'N')
        {
            exit
        }
    }

    $vm = Get-AzVM -ResourceGroupName $resourceGroupName -Name $vmName
    $location = $vm.Location
    $resourceId = $vm.Id
    $subscriptionId = $resourceId.Split('/')[2]

    $JitPolicy = (@{
        id=$resourceId;
        ports=(@{
            number=5986;
            protocol="*";
            allowedSourceAddressPrefix=@("*");
            maxRequestAccessDuration="PT3H"},
            @{
             number=22;
             protocol="*";
             allowedSourceAddressPrefix=@("*");
             maxRequestAccessDuration="PT3H"},
             @{
             number=3389;
             protocol="*";
             allowedSourceAddressPrefix=@("*");
             maxRequestAccessDuration="PT3H"})})

    $JitPolicyArr=@($JitPolicy)
    Set-AzJitNetworkAccessPolicy -Kind 'Basic' -Location $location -Name 'default' -ResourceGroupName $resourceGroupName -VirtualMachine $JitPolicyArr -ErrorAction SilentlyContinue

    $JitPolicyVm1 = (
        @{
            id=$resourceId;
            ports=(
                @{
                    number=3389;
                    endTimeUtc = Get-Date (Get-Date -AsUTC).AddHours(3) -Format O;
                    allowedSourceAddressPrefix=@("*")
                },
                @{
                    number=5986;
                    endTimeUtc = Get-Date (Get-Date -AsUTC).AddHours(3) -Format O;
                    allowedSourceAddressPrefix=@("*")
                }
            )
        }
    )

    $JitPolicyArr=@($JitPolicyVm1)
    Start-AzJitNetworkAccessPolicy -ResourceId "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Security/locations/$location/jitNetworkAccessPolicies/default" -VirtualMachine $JitPolicyArr -ErrorAction SilentlyContinue
}