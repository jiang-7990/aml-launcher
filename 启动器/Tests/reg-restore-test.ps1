param([string]$Root = 'E:\deepseek work\AML\启动器')
$ErrorActionPreference = 'Stop'
$global:Root = $Root
$lib = Join-Path $Root 'Launcher\lib'
. (Join-Path $lib 'Common.ps1')
. (Join-Path $lib 'State.ps1')
. (Join-Path $lib 'Config.ps1')
. (Join-Path $lib 'Snapshot.ps1')
. (Join-Path $lib 'Sync.ps1')
. (Join-Path $lib 'Link.ps1')
. (Join-Path $lib 'Learn.ps1')
. (Join-Path $lib 'Registry.ps1')
. (Join-Path $lib 'Restore.ps1')
$global:LogFile = Join-Path $Root 'Logs\reg-restore-test.log'
$global:Config = Read-GlobalConfig

$game = Read-GameProfile -Id 'RegTest' -GameDir (Join-Path $Root 'Games\RegTest')
$notes = @(Restore-GameToLocal $game -DeleteStore)
foreach ($n in $notes) { Write-Host ('- ' + $n) }

$local = Expand-Vars '%APPDATA%\RegTest\saves' $game
Write-Host ('junction=' + (Test-Junction $local))
Write-Host ('localFile=' + (Test-Path (Join-Path $local 'slot1.sav')))
Write-Host ('storeExists=' + (Test-Path (Join-Path $Root 'Data\RegTest')))
Write-Host ('regKey=' + (Test-Path 'HKCU:\Software\RegTest'))
Write-Host ('regCounter=' + (Get-ItemProperty 'HKCU:\Software\RegTest' -Name counter -ErrorAction SilentlyContinue).counter)
