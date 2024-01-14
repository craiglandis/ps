param(
    [string]$searchString
)
$cfg = @'
[General]
ToolTipTimeAutoPop=-1
ToolTipTimeInitial=10
ToolTipTimeReshow=10
ShowInfoTip=1
ShowGridLines=0
SaveFilterIndex=0
MainFont=00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
ShowFoundDuringScan=1
LookAtKeys=1
LookAtValues=1
LookAtData=1
CaseSensitive=1
AddKeyEntries=0
KeysOnly=0
TimeFilter=0
LastTimeUnit=2
LastTimeValue=5
UnicodeSearch=1
UseLenRange=0
UseValueTypes=0
ValueTypes=2
BaseKeys=3
UseBaseKeys=1
UseRemoteComputer=0
RemoteComputer=
AutoStartRemoteRegistry=0
BaseKey=
Find=placeholder
ExcludeList=HKLM\Software\Classes, HKCU\Software\Classes
UseExcludeList=1
MaxNumOfItems=10000
MatchMode=1
LenFrom=0
LenTo=100
3264BitMode=0
SubKeyDepth=-1
KeyOwnerFilter=0
KeyOwnerList=
TimeFrom=14-01-2024 02:14:15
TimeTo=14-01-2024 03:14:15
WinPos=2C 00 00 00 02 00 00 00 03 00 00 00 FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF B6 00 00 00 B6 00 00 00 36 03 00 00 96 02 00 00
OptionsWinPos=2C 00 00 00 00 00 00 00 01 00 00 00 FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF BD 00 00 00 71 00 00 00 2F 03 00 00 DC 02 00 00
Columns=64 00 00 00 64 00 01 00 64 00 02 00 64 00 03 00 64 00 04 00 64 00 05 00 64 00 06 00
Sort=0
'@
$cfg = $cfg.Replace('Find=placeholder',"Find=$searchString")
$binPath = 'C:\BIN'
$cfgPath = "$binPath\regscanner.cfg"
$cfg | Out-File -FilePath $cfgPath -Force

$exeName = 'regscanner.exe'
$exePath = "$binPath\$exeName"
if ((Test-Path -Path $exePath -PathType Leaf) -eq $false)
{
    if ((Test-Path -Path $binPath -PathType Leaf) -eq $false)
    {
        New-Item -Path $binPath -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
    }
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    $uri = 'https://www.nirsoft.net/utils/regscanner-x64.zip'
    $zipPath = "$binPath\regscanner-x64.zip"
    Invoke-WebRequest -Uri $uri -OutFile $zipPath
    Add-Type -Assembly System.IO.Compression.Filesystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $exePath)
    # Expand-Archive -Path $zipPath -DestinationPath $binPath
}
$xmlPath = "$binPath\regscanner.xml"
Remove-Item -Path $xmlPath -Force -ErrorAction SilentlyContinue
invoke-expression "& $exePath /cfg $cfgPath /sxml $xmlPath"
do {
    Start-Sleep -Milliseconds 100
} until (Test-Path -Path $xmlPath -PathType Leaf)
[xml]$result = get-content -path $xmlPath -raw
$global:objects = $result.registry_report.item | Select-Object registry_key,name,type,data
$global:strings = New-Object System.Collections.Generic.List[String]
foreach ($object in $global:objects)
{
    $string = "$($object.registry_key)\$($object.name) $($object.type) $($object.data)"
    $strings.Add($string)
}
$global:strings
$txtPath = "$env:TEMP\regscanner.txt"
$global:strings | Out-File -FilePath $txtPath
# ConsoleHost is a local session, ServerRemoteHost is a remote session
if ($host.Name -eq 'ConsoleHost')
{
    $global:objects | Out-GridView
    Invoke-Item -Path $txtPath
}
