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
ShowFoundDuringScan=1
LookAtKeys=0
LookAtValues=0
LookAtData=1
CaseSensitive=1
AddKeyEntries=0
KeysOnly=0
TimeFilter=0
LastTimeUnit=2
LastTimeValue=5
UnicodeSearch=0
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
MatchMode=2
LenFrom=0
LenTo=100
3264BitMode=0
KeyOwnerFilter=0
KeyOwnerList=
TimeFrom=01-01-2020 12:55:47
TimeTo=01-04-2021 13:55:47
WinPos=2C 00 00 00 02 00 00 00 03 00 00 00 FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF C0 00 00 00 C0 00 00 00 40 03 00 00 A0 02 00 00
OptionsWinPos=2C 00 00 00 00 00 00 00 01 00 00 00 FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF A7 01 00 00 38 00 00 00 19 04 00 00 A3 02 00 00
Columns=84 03 00 00 32 01 01 00 65 00 02 00 43 05 03 00 7D 00 04 00 33 00 05 00 0A 02 06 00
Sort=0
MainFont=00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
SubKeyDepth=-1
'@
$cfg = $cfg.Replace('Find=placeholder',"Find=$searchString")
$cfgPath = "$env:TEMP\regscanner.cfg"
$cfg | Out-File -FilePath $cfgPath -Force

$binPath = 'C:\BIN'
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
    Expand-Archive -Path $zipPath -DestinationPath $binPath
}
$xmlPath = "$binPath\regscanner.xml"
& $exePath /cfg $cfgPath /sxml $xmlPath
[xml]$result = get-content -path $xmlPath
$global:objects = $result.registry_report.item | Select-Object registry_key,name,type,data
$global:strings = New-Object System.Collections.Generic.List[String]
foreach ($object in $global:objects)
{
    $string = "$($object.registry_key)\$($object.name) $($object.type) $($object.data)"
    $strings.Add($string)
}
$global:strings
$global:objects | Out-GridView
$txtPath = "$env:TEMP\regscanner.txt"
$global:strings | Out-File -FilePath $txtPath
Invoke-Item -Path $txtPath
