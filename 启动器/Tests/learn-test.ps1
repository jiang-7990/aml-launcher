# Tests/learn-test.ps1 - 学习模式无界面回归：快照 → 跑 LearnTest → 快照 → 候选
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
$global:LogFile = Join-Path $root ('Logs\learntest_{0}.log' -f (Get-Date -Format 'HHmmss'))
$global:Config = Read-GlobalConfig

$g = Read-GameProfile -Id 'LearnTest' -GameDir (Join-Path $root 'Games\LearnTest')
Write-Host ('exe=' + $g.Exe)

$sw = [Diagnostics.Stopwatch]::StartNew()
$before = New-LearnSnapshot $g 'before'
Write-Host ('before: {0:n1}s' -f $sw.Elapsed.TotalSeconds)

Start-Process -FilePath $g.Exe -Wait

$after = New-LearnSnapshot $g 'after'
Write-Host ('after: {0:n1}s' -f $sw.Elapsed.TotalSeconds)

$c = @(Compare-LearnSnapshots $before $after $g)
$c | Select-Object -First 8 Score, Files, SizeMB, Local, Dir | Format-Table -AutoSize | Out-String -Width 240
