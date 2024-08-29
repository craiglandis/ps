$vms = Get-AzVM

foreach ($vm in $vms)
{
    $publisher = $vm.StorageProfile.ImageReference.Publisher
    $offer = $vm.StorageProfile.ImageReference.Offer
    $sku = $vm.StorageProfile.ImageReference.Sku
    $exactVersion = $vm.StorageProfile.ImageReference.ExactVersion
    $urn = "$($publisher):$($offer):$($sku):$($exactVersion)"

    $image = Get-AzVMImage -Location $vm.location -PublisherName $vm.StorageProfile.ImageReference.Publisher -Offer $vm.StorageProfile.ImageReference.Offer -Skus $vm.StorageProfile.ImageReference.Sku -Version $vm.StorageProfile.ImageReference.ExactVersion

    $imageDeprecationStatus = $image.ImageDeprecationStatus

    $vm.StorageProfile.ImageReference | Add-Member -MemberType NoteProperty -Name ImageState -Value $image.ImageDeprecationStatus.ImageState -Force
    $vm.StorageProfile.ImageReference | Add-Member -MemberType NoteProperty -Name ScheduledDeprecationTime -Value $image.ImageDeprecationStatus.ScheduledDeprecationTime -Force
    $vm.StorageProfile.ImageReference | Add-Member -MemberType NoteProperty -Name AlternativeOption -Value $image.ImageDeprecationStatus.AlternativeOption -Force
    $vm.StorageProfile.ImageReference | Add-Member -MemberType NoteProperty -Name ImageUrn -Value $urn -Force
}


$vmName = @{Name = 'VM'; Expression = {$_.Name}}
$rgName = @{Name = 'RG'; Expression = {$_.ResourceGroupName}}
$imageState = @{Name = 'ImageState'; Expression = {$_.StorageProfile.ImageReference.ImageState}}
$scheduledDeprecationTime = @{Name = 'ScheduledDeprecationTime'; Expression = {$_.StorageProfile.ImageReference.ScheduledDeprecationTime}}
$alternativeOption = @{Name = 'AlternativeOption'; Expression = {$_.StorageProfile.ImageReference.AlternativeOption}}
$imageUrn = @{Name = 'ImageUrn'; Expression = {$_.StorageProfile.ImageReference.ImageUrn}}

$vms | Format-Table $vmName, $rgName, $imageUrn, $imageState, $scheduledDeprecationTime, $alternativeOption -AutoSize
