# Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force; \\tsclient\c\onedrive\my\Set-Cursor.ps1
$cursorsUrl = 'https://github.com/craiglandis/ps/raw/master/cursors.zip'
$cursorsFile = $cursorsUrl.Split('/')[-1]
$cursorsFilePath = "$env:temp\$cursorsFile"
(New-Object System.Net.Webclient).DownloadFile($cursorsUrl, $cursorsFilePath)

$cursorsFolder = "$env:LOCALAPPDATA\Microsoft\Windows\Cursors"
$cursorsFolderBackup = "$($cursorsFolder).bak"
Write-Output "Cursors folder: $cursorsFolder"

if (Test-Path -Path $cursorsFolder -PathType Container)
{
    Write-Output "Creating Cursors folder backup: $cursorsFolderBackup"
    $command = "New-Item -Path $cursorsFolderBackup -ItemType Directory -Force"
    Write-Output $command
    Invoke-Expression -Command $command

    Write-Output "Backing up cursors to $cursorsFolderBackup"
    $command = "Copy-Item -Path `"$cursorsFolder\*`" -Destination $cursorsFolderBackup -Force -ErrorAction SilentlyContinue"
    Write-Output $command
    Invoke-Expression -Command $command

    Write-Output "Removing contents of cursors folder $cursorsFolder"
    $command = "Remove-Item -Path `"$cursorsFolder\*`" -ErrorAction SilentlyContinue"
    Write-Output $command
    Invoke-Expression -Command $command
}
else
{
    Write-Output "Cursors folder does not exist, creating it"
    $command = "New-Item -Path $cursorsFolder -ItemType Directory -Force"
    Write-Output $command
    Invoke-Expression -Command $command
}

Write-Output "Extracting $cursorsFilePath to cursors folder $cursorsFolder"
$command = "Expand-Archive -Path $cursorsFilePath -DestinationPath $cursorsFolder"
Write-Output $command
Invoke-Expression -Command $command

Write-Output "Updating mouse settings in registry"
if ((Test-Path -LiteralPath 'HKCU:\SOFTWARE\Microsoft\Accessibility') -ne $true) {New-Item 'HKCU:\SOFTWARE\Microsoft\Accessibility' -Force -ErrorAction SilentlyContinue | Out-Null}
New-ItemProperty -LiteralPath 'HKCU:\SOFTWARE\Microsoft\Accessibility' -Name 'CursorColor' -Value 12582656 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -LiteralPath 'HKCU:\SOFTWARE\Microsoft\Accessibility' -Name 'TextScaleFactor' -Value 100 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -LiteralPath 'HKCU:\SOFTWARE\Microsoft\Accessibility' -Name 'CursorType' -Value 6 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -LiteralPath 'HKCU:\SOFTWARE\Microsoft\Accessibility' -Name 'CursorSize' -Value 3 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null

if ((Test-Path -LiteralPath 'HKCU:\Control Panel\Cursors') -ne $true) {New-Item 'HKCU:\Control Panel\Cursors' -Force -ErrorAction SilentlyContinue | Out-Null}
New-ItemProperty -LiteralPath 'HKCU:\Control Panel\Cursors' -Name 'AppStarting' -Value "$cursorsFolder\busy_eoa.cur" -PropertyType ExpandString -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -LiteralPath 'HKCU:\Control Panel\Cursors' -Name 'Arrow' -Value "$cursorsFolder\arrow_eoa.cur" -PropertyType ExpandString -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -LiteralPath 'HKCU:\Control Panel\Cursors' -Name 'ContactVisualization' -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -LiteralPath 'HKCU:\Control Panel\Cursors' -Name 'Crosshair' -Value "$cursorsFolder\cross_eoa.cur" -PropertyType ExpandString -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -LiteralPath 'HKCU:\Control Panel\Cursors' -Name 'CursorBaseSize' -Value 80 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -LiteralPath 'HKCU:\Control Panel\Cursors' -Name 'GestureVisualization' -Value 31 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -LiteralPath 'HKCU:\Control Panel\Cursors' -Name 'Hand' -Value "$cursorsFolder\link_eoa.cur" -PropertyType ExpandString -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -LiteralPath 'HKCU:\Control Panel\Cursors' -Name 'Help' -Value "$cursorsFolder\helpsel_eoa.cur" -PropertyType ExpandString -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -LiteralPath 'HKCU:\Control Panel\Cursors' -Name 'IBeam' -Value "$cursorsFolder\ibeam_eoa.cur" -PropertyType ExpandString -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -LiteralPath 'HKCU:\Control Panel\Cursors' -Name 'No' -Value "$cursorsFolder\unavail_eoa.cur" -PropertyType ExpandString -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -LiteralPath 'HKCU:\Control Panel\Cursors' -Name 'NWPen' -Value "$cursorsFolder\pen_eoa.cur" -PropertyType ExpandString -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -LiteralPath 'HKCU:\Control Panel\Cursors' -Name 'Scheme Source' -Value 2 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -LiteralPath 'HKCU:\Control Panel\Cursors' -Name 'SizeAll' -Value "$cursorsFolder\move_eoa.cur" -PropertyType ExpandString -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -LiteralPath 'HKCU:\Control Panel\Cursors' -Name 'SizeNESW' -Value "$cursorsFolder\nesw_eoa.cur" -PropertyType ExpandString -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -LiteralPath 'HKCU:\Control Panel\Cursors' -Name 'SizeNS' -Value "$cursorsFolder\ns_eoa.cur" -PropertyType ExpandString -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -LiteralPath 'HKCU:\Control Panel\Cursors' -Name 'SizeNWSE' -Value "$cursorsFolder\nwse_eoa.cur" -PropertyType ExpandString -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -LiteralPath 'HKCU:\Control Panel\Cursors' -Name 'SizeWE' -Value "$cursorsFolder\ew_eoa.cur" -PropertyType ExpandString -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -LiteralPath 'HKCU:\Control Panel\Cursors' -Name 'UpArrow' -Value "$cursorsFolder\up_eoa.cur" -PropertyType ExpandString -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -LiteralPath 'HKCU:\Control Panel\Cursors' -Name 'Wait' -Value "$cursorsFolder\wait_eoa.cur" -PropertyType ExpandString -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -LiteralPath 'HKCU:\Control Panel\Cursors' -Name '(default)' -Value 'Windows Aero' -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -LiteralPath 'HKCU:\Control Panel\Cursors' -Name 'Person' -Value "$cursorsFolder\person_eoa.cur" -PropertyType ExpandString -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -LiteralPath 'HKCU:\Control Panel\Cursors' -Name 'Pin' -Value "$cursorsFolder\pin_eoa.cur" -PropertyType ExpandString -Force -ErrorAction SilentlyContinue | Out-Null

Write-Output "Refreshing mouse cursor"
$CSharpSig = @'
[DllImport("user32.dll", EntryPoint = "SystemParametersInfo")]
public static extern bool SystemParametersInfo(
    uint uiAction,
    uint uiParam,
    uint pvParam,
    uint fWinIni);
'@
$cursorRefresh = Add-Type -MemberDefinition $CSharpSig -Name WinAPICall -Namespace SystemParamInfo -PassThru
$cursorRefresh::SystemParametersInfo(0x0057, 0, $null, 0)