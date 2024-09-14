# https://aka.ms/DeprecatedImagesFAQ
param(
    [string]$resourceGroupName = '*',
    [string]$name = '*',
    [switch]$txt,
    [switch]$all,
    [switch]$show
)

$scriptStartTime = Get-Date
$scriptFullName = $MyInvocation.MyCommand.Path
$scriptPath = Split-Path -Path $scriptFullName
$scriptName = Split-Path -Path $scriptFullName -Leaf
$scriptBaseName = $scriptName.Split('.')[0]

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
            $vm.StorageProfile.ImageReference | Add-Member -MemberType NoteProperty -Name AlternativeOption -Value $image.ImageDeprecationStatus.AlternativeOption -Force
            $vm.StorageProfile.ImageReference | Add-Member -MemberType NoteProperty -Name ImageState -Value $image.ImageDeprecationStatus.ImageState -Force
            $vm.StorageProfile.ImageReference | Add-Member -MemberType NoteProperty -Name ImageUrn -Value $urn -Force
            if ($image.ImageDeprecationStatus.ScheduledDeprecationTime)
            {
                $scheduledDeprecationTime = Get-Date $image.ImageDeprecationStatus.ScheduledDeprecationTime -Format 'yyyy-MM-ddTHH:mm:ssZ'
            }
            $vm.StorageProfile.ImageReference | Add-Member -MemberType NoteProperty -Name ScheduledDeprecationTime -Value $scheduledDeprecationTime -Force
        }
    }

    $vmName = @{Name = 'VM'; Expression = {$_.Name}}
    $rgName = @{Name = 'RG'; Expression = {$_.ResourceGroupName}}
    $imageState = @{Name = 'ImageState'; Expression = {$_.StorageProfile.ImageReference.ImageState}}
    $scheduledDeprecationTime = @{Name = 'ScheduledDeprecationTime'; Expression = {$_.StorageProfile.ImageReference.ScheduledDeprecationTime}}
    $alternativeOption = @{Name = 'AlternativeOption'; Expression = {$_.StorageProfile.ImageReference.AlternativeOption}}
    $imageUrn = @{Name = 'ImageUrn'; Expression = {$_.StorageProfile.ImageReference.ImageUrn}}

    $vms = $vms | Select-Object $vmName, $rgName, $imageState, $scheduledDeprecationTime, $imageUrn, $alternativeOption | Sort-Object ScheduledDeprecationTime

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
        Write-Output "`nShowing VMs from images scheduled for deprecation (use -all to show all VMs):"
        $table = $vmsFromImagesScheduledForDeprecation | Format-Table -AutoSize | Out-String -Width 4096
    }
    $table = "`n$($table.Trim())`n"
    Write-Output $table
    #$global:dbgvms = $vmsFromImagesScheduledForDeprecation

    #exit

    if ($vmsFromImagesScheduledForDeprecationCount -ge 1 -or ($all -and [string]::IsNullOrEmpty($vms) -eq $false))
    {
        $context = Get-AzContext
        $subscriptionId = $context.Subscription.Id

        $fileName = $scriptBaseName
        if ([string]::IsNullOrEmpty($subscriptionId) -eq $false)
        {
            $fileName = [System.String]::Concat($fileName, "-$subscriptionId")
        }
        if ([string]::IsNullOrEmpty($PSBoundParameters['resourceGroupName']) -eq $false)
        {
            $fileName = [System.String]::Concat($fileName, "-$($PSBoundParameters['resourceGroupName'])")
        }
        if ([string]::IsNullOrEmpty($PSBoundParameters['name']) -eq $false)
        {
            $fileName = [System.String]::Concat($fileName, "-$($PSBoundParameters['name'])")
        }

        $csvPath = "$PWD\$fileName.csv"
        $jsonPath = "$PWD\$fileName.json"
        $txtPath = "$PWD\$fileName.txt"

        if ($all)
        {
            $vms | Export-Csv -Path $csvPath
            $vms | ConvertTo-Json | Out-File -FilePath $jsonPath
        }
        else
        {
            $vmsFromImagesScheduledForDeprecation | Export-Csv -Path $csvPath
            $vmsFromImagesScheduledForDeprecation | ConvertTo-Json | Out-File -FilePath $jsonPath
        }
        $table | Out-File -FilePath $txtPath

        Write-Output "Writing output files to current directory $PWD`n"

        if (Test-Path -Path $csvPath -PathType Leaf)
        {
            Write-Output " CSV: $csvPath"
        }
        if (Test-Path -Path $jsonPath -PathType Leaf)
        {
            Write-Output "JSON: $jsonPath"
        }
        if (Test-Path -Path $csvPath -PathType Leaf)
        {
            Write-Output " TXT: $txtPath"
        }
    }
}

$scriptTimespan = New-TimeSpan -Start $scriptStartTime -End (Get-Date)
$scriptSeconds = [Math]::Round($scriptTimespan.TotalSeconds, 1)
Write-Output "`n$($scriptSeconds)s"
