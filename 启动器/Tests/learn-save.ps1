# Tests/learn-save.ps1 - 学习候选写回 profile，并验证接管
$root = Split-Path -Parent $PSScriptRoot
$global:Root = $root
$lib = Join-Path $root 'Launcher\lib'
. (Join-Path $lib 'Common.ps1')
. (Join-Path $lib 'State.ps1')
. (Join-Path $lib 'Config.ps1')
. (Join-Path $lib 'Snapshot.ps1')
. (Join-Path $lib 'Sync.ps1')
. (Join-Path $lib 'Link.ps1')
. (Join-Path $lib 'Launch.ps1')
. (Join-Path $lib 'Learn.ps1')
$global:LogFile = Join-Path $root ('Logs\learnsave_{0}.log' -f (Get-Date -Format 'HHmmss'))
$global:Config = Read-GlobalConfig

$g = Read-GameProfile -Id 'LearnTest' -GameDir (Join-Path $root 'Games\LearnTest')
$c = @(Compare-LearnSnapshots (Join-Path $root 'Launcher\state\learn\LearnTest\before.tsv') (Join-Path $root 'Launcher\state\learn\LearnTest\after.tsv') $g)
$sel = @($c | Where-Object { $_.Local -like '*LearnTest\saves' })
Write-Host ('选中: ' + ($sel | ForEach-Object { $_.Local }) )
$n = Save-LearnMappings $g $sel
Write-Host ('写入 {0} 条' -f $n)
Get-Content -LiteralPath $g.ProfilePath -Encoding UTF8 | ForEach-Object { Write-Host $_ }
