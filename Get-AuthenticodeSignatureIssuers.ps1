# Get-AuthenticodeSignatureIssuers.ps1
param(
    [string]$processName = '*'
)

$issuers = New-Object System.Collections.Generic.List[String]

$modules = Get-Process -Name $processName | Select-Object -ExpandProperty Modules
$moduleFilePaths = $modules | Sort-Object -Unique FileName | Select-Object -ExpandProperty FileName

foreach ($filePath in $moduleFilePaths)
{
    # $signature = Get-AuthenticodeSignature C:\MODULES\Az.Accounts\2.13.2\FuzzySharp.dll
    $signature = Get-AuthenticodeSignature -FilePath $filePath -ErrorAction SilentlyContinue
    $issuer = $signature.SignerCertificate.Issuer
    $issuers.Add($issuer)
}
$issuers = $issuers | Sort-Object -Unique
$issuersCount = $issuers | Measure-Object | Select-Object -ExpandProperty Count
$issuers
Out-Log "`nProcessName: $green$processName$reset Unique Module Signature Issuers: $cyan$issuersCount$reset" -raw