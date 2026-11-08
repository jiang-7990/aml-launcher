# Tests\uninstall-test.ps1 - 卸载流程回归：还原存档 + 删配置 + 保留游戏文件
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$global:Root = $root

foreach ($f in 'Common', 'State', 'Config', 'Snapshot', 'Sync', 'Link', 'Launch', 'Learn', 'Registry', 'Restore', 'Uninstall') {
    . (Join-Path (Join-Path $root 'Launcher\lib') ($f + '.ps1'))
}

$g = Get-GameById 'RegTest'
if (-not $g) { Write-Host 'SKIP: RegTest 不存在'; exit 0 }

Write-Host ('game=' + $g.Id + ' mappings=' + @($g.Mappings).Count + ' reg=' + @($g.RegistryMappings).Count)
$notes = Uninstall-Game $g -Restore
foreach ($n in @($notes)) { Write-Host ('note: ' + $n) }

$profilePath = Join-Path (Join-Path $root 'Launcher\profiles') 'RegTest.ini'
Write-Host ('profile exists=' + (Test-Path -LiteralPath $profilePath))
Write-Host ('data exists=' + (Test-Path -LiteralPath (Join-Path $root 'Data\RegTest')))
Write-Host ('icon exists=' + (Test-Path -LiteralPath (Join-Path $root 'Launcher\icons\RegTest.png')))
Write-Host ('game dir exists=' + (Test-Path -LiteralPath (Join-Path $root 'Games\RegTest')))
Write-Host ('local junction=' + (Test-Junction (Join-Path $env:APPDATA 'RegTest')))
Write-Host ('local exists=' + (Test-Path -LiteralPath (Join-Path $env:APPDATA 'RegTest')))
Write-Host ('reg key exists=' + (Test-Path 'HKCU:\Software\RegTest'))
