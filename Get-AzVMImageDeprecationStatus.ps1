$vms = Get-AzVM

foreach ($vm in $vms)
{
    $image = Get-AzVmImage -Location $vm.location -PublisherName $vm.StorageProfile.ImageReference.Publisher -Offer $vm.StorageProfile.ImageReference.Offer -Skus $vm.StorageProfile.ImageReference.Sku -Version $vm.StorageProfile.ImageReference.ExactVersion

    $imageDeprecationStatus = $image.ImageDeprecationStatus

    $vm.StorageProfile.ImageReference | Add-Member -MemberType NoteProperty -Name ImageState -Value $image.ImageDeprecationStatus.ImageState -Force
    $vm.StorageProfile.ImageReference | Add-Member -MemberType NoteProperty -Name ScheduledDeprecationTime -Value $image.ImageDeprecationStatus.ScheduledDeprecationTime -Force
    $vm.StorageProfile.ImageReference | Add-Member -MemberType NoteProperty -Name AlternativeOption -Value $image.ImageDeprecationStatus.AlternativeOption -Force
}

$imageState = @{Name = 'ImageState'; Expression={$_.StorageProfile.ImageReference.ImageState}}
$scheduledDeprecationTime = @{Name = 'ScheduledDeprecationTime'; Expression={$_.StorageProfile.ImageReference.ScheduledDeprecationTime}}
$alternativeOption = @{Name = 'AlternativeOption'; Expression={$_.StorageProfile.ImageReference.AlternativeOption}}

$vms | Format-Table Name,ResourceGroupName,$imageState,$scheduledDeprecationTime,$alternativeOption -AutoSize