param(
    [string]$driveLetter
)

if ($driveLetter)
{
    # Specifying drive letter as "E" or "E:" or "E:\" will all end up as "E:"
    $driveLetter = "$($driveLetter.Chars(0)):"
    $packages = dism /format:table /image:$driveLetter /get-packages
}
else
{
    $packages = dism /format:table /online /get-packages
}

# 'install pending' is a substring of 'uninstall pending' - so only need to match on 'install pending' to get both the 'install pending' and 'uninstall pending' packages, which is what we want. since the former is a sub
$packages | Select-String -SimpleMatch 'install pending' | ForEach-Object {
    $line = $_
    if ([string]::IsNullOrEmpty($line) -eq $false)
    {
        $line = $line.ToString()
        $packageName = $line.Split(' ')[0]
        dism /image:$driveLetter /Remove-Package /PackageName:$packageName
    }
}
