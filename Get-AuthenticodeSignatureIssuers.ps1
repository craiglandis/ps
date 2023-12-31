param(
    [string]$processName = '*'
)

$issuers = New-Object System.Collections.Generic.List[String]

$modules = Get-Process -Name $processName | Select-Object -ExpandProperty Modules -ErrorAction SilentlyContinue
$moduleFilePaths = $modules | Sort-Object -Unique FileName | Select-Object -ExpandProperty FileName -ErrorAction SilentlyContinue

foreach ($filePath in $moduleFilePaths)
{
    # $signature = Get-AuthenticodeSignature C:\MODULES\Az.Accounts\2.13.2\FuzzySharp.dll
    $signature = Get-AuthenticodeSignature -FilePath $filePath -ErrorAction SilentlyContinue
    $issuer = $signature.SignerCertificate.Issuer
    if ([string]::IsNullOrEmpty($issuer) -eq $false)
    {
        $issuers.Add($issuer)
    }
}
$issuers = $issuers | Sort-Object -Unique
$issuersCount = $issuers | Measure-Object | Select-Object -ExpandProperty Count
Write-Output "`nProcessName: $processName"
Write-Output "Unique Module Signature Issuers count: $issuersCount`n"
Write-Output $issuers
