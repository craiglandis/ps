#Requires -PSEdition Desktop
param(
    $vmName,
    $bmpPath
)

function Get-VMBitmap {
    param
    (
        $vm,
        $x,
        $y
    )

    $vmms = Get-WmiObject -Namespace root\virtualization\v2 -Class Msvm_VirtualSystemManagementService

    # Get screenshot
    $image = $vmms.GetVirtualSystemThumbnailImage($vm, $x, $y).ImageData

    # Transform to bitmap
    $bmp = New-Object System.Drawing.Bitmap -Args $x,$y,Format16bppRgb565
    $rectangle = New-Object System.Drawing.Rectangle 0,0,$x,$y
    $bmpData = $bmp.LockBits($rectangle,'ReadWrite','Format16bppRgb565')
    [System.Runtime.InteropServices.Marshal]::Copy($Image, 0, $bmpData.Scan0, $bmpData.Stride*$bmpData.Height)
    $bmp.UnlockBits($bmpData)

    return $bmp
}

Add-Type -AssemblyName System.Drawing

$bmpFilePath = "$bmpPath\$vmName.bmp"

$msVmComputerSystem = Get-WmiObject -Namespace root\virtualization\v2 -Class Msvm_ComputerSystem -Filter "ElementName='$($vmName)'"

# Get current screen resolution
$msVmVideoHead = $msVmComputerSystem.GetRelated('Msvm_VideoHead')
$xResolution = $msVmVideoHead.CurrentHorizontalResolution[0]
$yResolution = $msVmVideoHead.CurrentVerticalResolution[0]

(Get-VMBitmap $msVmComputerSystem $xResolution $yResolution).Save($bmpFilePath)

if (Test-Path -Path $bmpFilePath -PathType Leaf)
{
    Write-Output $bmpFilePath
    Invoke-Item -Path $bmpFilePath
}
else
{
    Write-Error 'Failed to create VM bitmap'
}