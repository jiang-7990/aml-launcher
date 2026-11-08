param([switch]$DeleteStore, [string]$GameId = 'RestoreTest')
$ErrorActionPreference = 'Stop'
$root = 'E:\deepseek work\AML\启动器'
$global:Root = $root
. "$root\Launcher\lib\Common.ps1"
. "$root\Launcher\lib\State.ps1"
. "$root\Launcher\lib\Config.ps1"
. "$root\Launcher\lib\Snapshot.ps1"
. "$root\Launcher\lib\Sync.ps1"
. "$root\Launcher\lib\Link.ps1"
. "$root\Launcher\lib\Restore.ps1"
$global:LogFile = Join-Path $root 'Logs\restore-test.log'
$global:Config = Read-GlobalConfig
$g = Get-GameById $GameId
if (-not $g) { throw ('找不到游戏：' + $GameId) }
$notes = Restore-GameToLocal $g -DeleteStore:$DeleteStore
$notes | ForEach-Object { Write-Host ('note: ' + $_) }
foreach ($m in $g.Mappings) {
    $local = Expand-Vars $m.Local $g
    Write-Host ('local=' + $local)
    Write-Host ('isJunction=' + (Test-Junction $local))
    Write-Host ('owner=' + (Get-LocalOwner $local))
    if (Test-Path -LiteralPath $local) {
        Get-ChildItem -LiteralPath $local -File -ErrorAction SilentlyContinue | ForEach-Object { Write-Host ('  file: ' + $_.Name + ' = ' + $_.Length) }
    }
    $store = Get-MappingStorePath $g $m
    Write-Host ('storeExists=' + (Test-Path -LiteralPath $store))
}
