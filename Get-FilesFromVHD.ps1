param(
    [string]$vhdPath,
    [string]$outputPath,
    [string]$drive
)

$startTime = Get-Date

if (Test-Path -Path $vhdPath)
{
    Write-Output "Mounting VHD: $vhdPath"
    try
    {
        Mount-DiskImage -ImagePath $vhdPath -Access ReadOnly -ErrorAction Stop | Out-Null
    }
    catch
    {
        Write-Output ('Unable to mount ' + $vhdPath + ' If attached to a VM, make sure that VM is not running.')
        exit
    }
}
else
{
    Write-Error "File not found: $vhdPath"
}

# Assign next available drive letters for each partition on the mounted VHD
Get-DiskImage -ImagePath $vhdPath | Get-Disk | Get-Partition | ForEach-Object {
    if (!$_.DriveLetter)
    {
        $_ | Add-PartitionAccessPath -AssignDriveLetter -ErrorAction Stop
    }
}

# Get paths to \Boot\BCD and \Windows since they can be on the same partition or on wo different partitions
Get-DiskImage -ImagePath $vhdPath | Get-Disk | Get-Partition | ForEach-Object {
    if (Test-Path -Path "$($_.DriveLetter):\Boot\BCD")
    {
        $bcdPath = "$($_.DriveLetter):\Boot\BCD"
    }
    if (Test-Path -Path "$($_.DriveLetter):\Windows")
    {
        $winPath = "$($_.DriveLetter):\Windows"
        $drive = "$($_.DriveLetter):"
    }
}

if ($bcdPath -and $winPath)
{
    Write-Output "\Boot\BCD path: $bcdPath"
    Write-Output "\Windows path: $winPath"
}
else
{
    if (!$bcdPath)
    {
        Write-Output "\Boot\BCD not found on any partitions on VHD $vhdPath"
    }
    if (!$winPath)
    {
        Write-Output "\Windows not found on any partitions on VHD $vhdPath"
    }
    exit
}

if (!(Test-Path -Path $outputPath))
{
    New-Item -Path $outputPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
}

$vhd = Get-Item -Path $vhdpath
$outputPath = "$($outputPath)\$($vhd.BaseName)_$(Get-Date -Format yyyyMMddhhmmss)"
New-Item -Path $outputPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
$url = 'https://raw.githubusercontent.com/Azure/azure-diskinspect-service/master/pyServer/manifests/windows/windowsupdate'
Write-Output "Downloading manifest: $url"
$manifestFile = "$env:temp\manifest$((get-date).Ticks)"
$webClient = New-Object System.Net.WebClient
$webClient.DownloadFile($url, $manifestFile)
$manifest = get-content -path $manifestFile
$lines = $manifest | Where-Object {$_.StartsWith('copy')} | ForEach-Object {"$drive$($_.Replace('copy,','').Replace('/','\').Split(',')[0])"}
$lines | ForEach-Object {
    $line = $_
    # The use of New-Item below is a way to maintain the source directory structure when source path for Copy-Item is a single file
    # The use of Get-ChildItem below is to get the full path of the file for New-Item
    # The manifest lines can't be used as-is for that since some contain wildcards
    if ($line -match '\\Boot\\BCD')
    {
        $sourceFilePath = $bcdPath
        $destinationFilePath = "$outputPath\$($sourceFilePath.Substring(3))"
        New-Item -Path $destinationFilePath -ItemType File -Force -ErrorAction Stop | Out-Null
        $command = "Copy-Item -Path '$($sourceFilePath)' -Destination '$($destinationFilePath)' -Force"
        Write-Output $command
        Invoke-Expression -Command $command
    }
    elseif ($line -match '\\\*\\')
    {
        Get-ChildItem -Path $line -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            $sourceFilePath = $_.FullName
            $destinationFilePath = "$outputPath\$($sourceFilePath.Substring(3))"
            New-Item -Path $destinationFilePath -ItemType File -Force -ErrorAction Stop | Out-Null
            $command = "Copy-Item -Path '$($sourceFilePath)' -Destination '$($destinationFilePath)' -Force"
            Write-Output $command
            Invoke-Expression -Command $command
        }
    }
    else
    {
        Get-ChildItem -Path $line -ErrorAction SilentlyContinue | ForEach-Object {
            $sourceFilePath = $_.FullName
            $destinationFilePath = "$outputPath\$($sourceFilePath.Substring(3))"
            New-Item -Path $destinationFilePath -ItemType File -Force -ErrorAction Stop | Out-Null
            $command = "Copy-Item -Path '$($sourceFilePath)' -Destination '$($destinationFilePath)' -Force"
            Write-Output $command
            Invoke-Expression -Command $command
        }
    }
}

[Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem') | Out-Null
$zipfilePath = "$outputPath.zip"
Write-Output "Creating zip file: $zipfilePath"
[System.IO.Compression.ZipFile]::CreateFromDirectory($outputPath,$zipfilePath,'Optimal',$false)

Get-DiskImage -ImagePath $vhdPath | Get-Disk | Get-Partition | ForEach-Object {
    Write-Output "Removing drive letter $($_.DriveLetter): from partition number $($_.PartitionNumber) on VHD $vhdPath"
    $_ | Remove-PartitionAccessPath -AccessPath "$($_.DriveLetter):"
}

Write-Output "Dismounting VHD $vhdPath"
Dismount-DiskImage -ImagePath $vhdPath | Out-Null

$scriptDuration = New-TimeSpan -Start $startTime -End (Get-Date)
Write-Output "Script Duration: $('{0:hh}:{0:mm}:{0:ss}.{0:ff}' -f $scriptDuration)"
Write-Output "Zip file path: $zipFilePath"
Write-Output "Output path: $outputPath"
