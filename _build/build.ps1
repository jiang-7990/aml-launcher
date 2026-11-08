param(
    [string]$Root = 'E:\deepseek work\AML',
    [string]$OutDir = ''
)
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrEmpty($OutDir)) {
    $OutDir = Join-Path $Root ('PvZ-U' + [char]0x76D8 + [char]0x7248)
}
$src = Join-Path $Root '_build'

if (Test-Path $OutDir) { Remove-Item $OutDir -Recurse -Force }
New-Item -ItemType Directory -Path $OutDir | Out-Null

$gbk = [Text.Encoding]::GetEncoding(936)
$utf8bom = New-Object Text.UTF8Encoding($true)

foreach ($f in Get-ChildItem $src -Filter *.src) {
    $text = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8)
    $text = $text -replace "`r`n", "`n"
    $text = $text -replace "`n", "`r`n"
    $name = $f.BaseName
    $dest = Join-Path $OutDir $name
    if ($name -like '*.cmd') {
        [IO.File]::WriteAllText($dest, $text, $gbk)
    } else {
        [IO.File]::WriteAllText($dest, $text, $utf8bom)
    }
    Write-Output ("built: " + $dest)
}

$zip = $OutDir + '.zip'
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $OutDir '*') -DestinationPath $zip -CompressionLevel Optimal
Write-Output ("zipped: " + $zip)
Write-Output "--- files ---"
Get-ChildItem $OutDir | Select-Object Name, Length | Format-Table -AutoSize
