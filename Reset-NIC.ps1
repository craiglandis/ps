<#
This script automates steps from doc: https://docs.microsoft.com/en-us/troubleshoot/azure/virtual-machines/reset-network-interface

To put a VM in a relevant problem state for testing, run this PowerShell command from within the Windows guest (VM will immediately lose network connectivity):

Disable-NetAdapter -Name * -Confirm:$false
#>

param(
    [string]$resourceGroupName = 'rg',
    [string]$vmName = 'ws22eph',
    [switch]$deallocate,
    [switch]$static,
    [switch]$dynamic
)

function Write-Console
{
    param(
        [string]$text
    )

    $timespan = '[{0:mm}:{0:ss}]' -f (New-timespan -Start $scriptStartTime -End (Get-Date))
    Write-Host "$timespan " -NoNewline -ForegroundColor Cyan
    Write-Host $text
}

function Get-VMStatus
{
    param(
        [string]$resourceGroupName,
        [string]$vmName
    )

    $vmStatus = Get-AzVM -ResourceGroupName $resourceGroupName -Name $vmName -Status
    $powerState = ($vmStatus.Statuses | Where-Object {$_.Code -match 'PowerState'}).Code.Split('/')[1]
    $vmAgentStatusTimestamp = $vmStatus.VMAgent.Statuses.Time
    $vmAgentStatusTimestampString = Get-Date -Date $vmAgentStatusTimestamp -Format yyyy-MM-ddTHH:mm:ss
    Write-Console "VM agent status timestamp: $vmAgentStatusTimestampString VM power state: $powerState"
    $vmStatus = [PSCustomObject]@{
        PowerState = $powerState
        VmAgentStatusTimestamp = $vmAgentStatusTimestamp
        VmAgentStatusTimestampString = $vmAgentStatusTimestampString
    }
    return $vmStatus
}

function Get-PrimaryNic
{
    param(
        [string]$resourceGroupName,
        [string]$vmName
    )
    $vm = Get-AzVM -ResourceGroupName $resourceGroupName -Name $vmName
    if ($vm.NetworkProfile.NetworkInterfaces.Count -gt 1)
    {
        $primaryNicId = ($vm.NetworkProfile.NetworkInterfaces | Where-Object Primary -EQ $true).Id
    }
    else
    {
        $primaryNicId = $vm.NetworkProfile.NetworkInterfaces.Id
    }
    $primaryNic = Get-AzNetworkInterface -ResourceId $primaryNicId
    $primaryIpconfig = $primaryNic.IpConfigurations | Where-Object Primary -EQ $true
    $vnetName = $primaryIpconfig.Subnet.Id.Split('/')[8]
    $privateIpAllocationMethod = $primaryIpconfig.PrivateIpAllocationMethod
    $privateIpAddress = $primaryIpConfig.PrivateIpAddress
    $macAddress = $primaryNic.MacAddress

    Write-Console "Current private IP allocation method: $privateIpAllocationMethod"
    Write-Console "Current private IP address: $privateIpAddress"
    Write-Console "Current MAC address: $macAddress"

    $primaryNic = [PSCustomObject]@{
        Object                    = $primaryNic
        PrimaryIpConfig           = $primaryIpconfig
        PrivateIpAllocationMethod = $privateIpAllocationMethod
        PrivateIpAddress          = $privateIpAddress
        MacAddress                = $macAddress
        VnetName                  = $vnetName
    }
    return $primaryNic
}

function Set-PrivateIpAllocationMethod
{
    param(
        [string]$resourceGroupName,
        [string]$vmName,
        [string]$privateIpAddress
    )

    $primaryNic = Get-PrimaryNic -resourceGroupName $resourceGroupName -vmName $vmName

    if ($primaryNic.PrivateIpAllocationMethod -eq 'Static')
    {
        $newPrivateIpAllocationMethod = 'Dynamic'
    }
    elseif ($primaryNic.PrivateIpAllocationMethod -eq 'Dynamic' -or $privateIpAddress)
    {
        $newPrivateIpAllocationMethod = 'Static'
        if ($privateIpAddress)
        {
            $newPrivateIpAddress = $privateIpAddress
        }
        else
        {
            $ipAddressAvailabilityResult = Test-AzPrivateIPAddressAvailability -IPAddress $primaryNic.PrivateIpAddress -VirtualNetworkName $primaryNic.VnetName -ResourceGroupName $resourceGroupName
            $newPrivateIpAddress = $ipAddressAvailabilityResult.AvailableIPAddresses[0]
        }
        Write-Console "Changing private IP from $($primaryNic.PrivateIpAddress) to $newPrivateIpAddress"
        $primaryNic.PrimaryIpconfig.PrivateIpAddress = $newPrivateIpAddress
    }

    Write-Console "Changing PrivateIpAllocationMethod from $($primaryNic.PrivateIpAllocationMethod) to $newPrivateIpAllocationMethod"
    $vmStatusBefore = Get-VMStatus -ResourceGroupName $resourceGroupName -vmName $vmName
    $primaryNic.PrimaryIpConfig.PrivateIpAllocationMethod = $newPrivateIpAllocationMethod
    $result = $primaryNic.Object | Set-AzNetworkInterface

    $secondsToWait = 300
    do
    {
        $vmStatus = Get-VMStatus -ResourceGroupName $resourceGroupName -vmName $vmName
        Start-Sleep -Seconds 10
        $secondsElapsed += 10
    } until (($vmStatus.PowerState -eq 'running' -and $vmStatus.VmAgentStatusTimestamp -gt $vmStatusBefore.VmAgentStatusTimestamp) -or $secondsElapsed -ge $secondsToWait)

    $primaryNicAfter = Get-PrimaryNic -resourceGroupName $resourceGroupName -vmName $vmName
    if ($primaryNicAfter.PrivateIpAllocationMethod -eq $newPrivateIpAllocationMethod)
    {
        return $primaryNic
    }
    else
    {
        return $false
    }
}

Set-StrictMode -Version 3.0
$scriptStartTime = Get-Date
$scriptFullName = $MyInvocation.MyCommand.Path
$scriptName = Split-Path -Path $scriptFullName -Leaf
$PSDefaultParameterValues['*:ErrorAction'] = 'Stop'
$PSDefaultParameterValues['*:WarningAction'] = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'

$originalPrimaryNicSettings = Set-PrivateIpAllocationMethod -resourceGroupName $resourceGroupName -vmName $vmName
if ($originalPrimaryNicSettings)
{
    if ($originalPrimaryNicSettings.PrivateIpAllocationMethod -eq 'Static')
    {
        $result = Set-PrivateIpAllocationMethod -resourceGroupName $resourceGroupName -vmName $vmName -privateIpAddress $originalPrimaryNicSettings.PrivateIpAddress
    }
    else
    {
        $result = Set-PrivateIpAllocationMethod -resourceGroupName $resourceGroupName -vmName $vmName
    }
}

$scriptDuration = '{0:hh}:{0:mm}:{0:ss}.{0:ff}' -f (New-TimeSpan -Start $scriptStartTime -End (Get-Date))
Write-Console "$scriptName duration: $scriptDuration"