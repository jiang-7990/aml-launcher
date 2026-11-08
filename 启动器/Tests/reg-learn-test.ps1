param([string]$Root = 'E:\deepseek work\AML\启动器')
$ErrorActionPreference = 'Stop'
$global:Root = $Root
$lib = Join-Path $Root 'Launcher\lib'
. (Join-Path $lib 'Common.ps1')
. (Join-Path $lib 'State.ps1')
. (Join-Path $lib 'Config.ps1')
. (Join-Path $lib 'Learn.ps1')
. (Join-Path $lib 'Registry.ps1')
$global:LogFile = Join-Path $Root 'Logs\reg-learn-test.log'
$global:Config = Read-GlobalConfig

$game = Read-GameProfile -Id 'RegTest' -GameDir (Join-Path $Root 'Games\RegTest')
Write-Host ('game=' + $game.Id + ' exe=' + $game.Exe)

$before = New-LearnSnapshot $game 'before'
$rb = New-LearnRegSnapshot $game 'before'
Start-Process -FilePath $game.Exe -Wait
Start-Sleep -Milliseconds 500
$after = New-LearnSnapshot $game 'after'
$ra = New-LearnRegSnapshot $game 'after'

$cands = @(Compare-LearnSnapshots $before $after $game)
$cands += @(Compare-LearnRegSnapshots $rb $ra $game)
Write-Host '--- candidates ---'
foreach ($c in $cands) {
    Write-Host ('[{0}] {1} score={2} files={3} size={4}' -f $c.Kind, $c.Local, $c.Score, $c.Files, $c.SizeMB)
}
$reg = @($cands | Where-Object { $_.Kind -eq 'registry' })
Write-Host ('regCandidates=' + $reg.Count)
if ($reg.Count -gt 0) {
    $n = Save-LearnMappings $game @($reg)
    Write-Host ('saved=' + $n)
    Write-Host '--- profile ---'
    Get-Content $game.ProfilePath | ForEach-Object { Write-Host $_ }
}
