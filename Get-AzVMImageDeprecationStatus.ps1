# https://aka.ms/DeprecatedImagesFAQ
param(
    [string]$resourceGroupName = '*',
    [string]$name = '*',
    [switch]$txt,
    [switch]$all,
    [switch]$show
)

$vms = Get-AzVM -ResourceGroupName $resourceGroupName -Name $name -ErrorAction Stop

if ([string]::IsNullOrEmpty($vms))
{
    Write-Output 'No VMs found'
}
else
{
    foreach ($vm in $vms)
    {
        $location = $vm.Location
        $publisher = $vm.StorageProfile.ImageReference.Publisher
        $offer = $vm.StorageProfile.ImageReference.Offer
        $sku = $vm.StorageProfile.ImageReference.Sku
        $exactVersion = $vm.StorageProfile.ImageReference.ExactVersion
        $urn = "$($publisher):$($offer):$($sku):$($exactVersion)"

        $image = Get-AzVMImage -Location $location -PublisherName $publisher -Offer $offer -Skus $sku -Version $exactVersion -ErrorAction SilentlyContinue

        $image | ForEach-Object {
            $vm.StorageProfile.ImageReference | Add-Member -MemberType NoteProperty -Name ImageState -Value $image.ImageDeprecationStatus.ImageState -Force
            $vm.StorageProfile.ImageReference | Add-Member -MemberType NoteProperty -Name ScheduledDeprecationTime -Value $image.ImageDeprecationStatus.ScheduledDeprecationTime -Force
            $vm.StorageProfile.ImageReference | Add-Member -MemberType NoteProperty -Name AlternativeOption -Value $image.ImageDeprecationStatus.AlternativeOption -Force
            $vm.StorageProfile.ImageReference | Add-Member -MemberType NoteProperty -Name ImageUrn -Value $urn -Force
        }
    }

    $vmName = @{Name = 'VM'; Expression = {$_.Name}}
    $rgName = @{Name = 'RG'; Expression = {$_.ResourceGroupName}}
    $imageState = @{Name = 'ImageState'; Expression = {$_.StorageProfile.ImageReference.ImageState}}
    $scheduledDeprecationTime = @{Name = 'ScheduledDeprecationTime'; Expression = {$_.StorageProfile.ImageReference.ScheduledDeprecationTime}}
    $alternativeOption = @{Name = 'AlternativeOption'; Expression = {$_.StorageProfile.ImageReference.AlternativeOption}}
    $imageUrn = @{Name = 'ImageUrn'; Expression = {$_.StorageProfile.ImageReference.ImageUrn}}

    $vms = $vms | Select-Object $vmName, $rgName, $imageState, $scheduledDeprecationTime, $alternativeOption, $imageUrn
    $global:dbgVms = $vms

    $totalVMCount = $vms | Measure-Object | Select-Object -ExpandProperty Count
    $vmsFromImagesScheduledForDeprecation = $vms | Where-Object ImageState -EQ 'ScheduledForDeprecation'
    $vmsFromImagesScheduledForDeprecationCount = $vmsFromImagesScheduledForDeprecation | Measure-Object | Select-Object -ExpandProperty Count
    Write-Output "`n$vmsFromImagesScheduledForDeprecationCount of $totalVMCount VMs are from images scheduled for deprecation"
    if ($all)
    {
        Write-Output "`nShowing all VMs:"
        $table = $vms | Format-Table -AutoSize | Out-String -Width 4096
    }
    else
    {
        Write-Output "`nShowing VMs from images scheduled for deprecation (use -all to show all VMs):`n"
        $table = $vmsFromImagesScheduledForDeprecation | Format-Table -AutoSize | Out-String -Width 4096
    }
    $table = "`n$($table.Trim())`n"
    Write-Output $table

    if ($txt)
    {
        $filePath = "Get-AzVMImageDeprecationStatus_$(Get-Date -Format yyyyMMddHHmmss).txt"
        $table | Out-File -FilePath $filePath
        if (Test-Path -Path $filePath -PathType Leaf)
        {
            Write-Output "Created output file: $filePath"
            if ($show)
            {
                Write-Output "Opening output file: $filePath"
                Invoke-Item -Path $filePath
            }
        }
    }
}
