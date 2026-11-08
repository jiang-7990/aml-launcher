# Snapshot.ps1 - 存档快照与保留策略

function New-StoreSnapshot {
    param($Game, [string]$Store)
    if (-not (Test-Path -LiteralPath $Store)) { return }
    if (-not (Test-StoreHasData $Store)) { return }

    $limit = if ($Game.MaxSnapshotMB -gt 0) { $Game.MaxSnapshotMB } else { $global:Config.MaxSnapshotMB }
    $size = Get-DirSizeMB $Store
    if ($size -gt $limit) {
        Write-Log ("存档 {0} MB 超过快照上限 {1} MB，跳过本次快照" -f $size, $limit) 'WARN'
        return
    }

    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
    $dest = Join-Path $global:Root ("Snapshots\$($Game.Id)\$stamp")
    Copy-Tree $Store $dest -Exclude $global:Config.ExcludeDirs | Out-Null
    Write-Log "快照: $dest"
    Remove-OldSnapshots $Game
}

function Remove-OldSnapshots {
    param($Game)
    $root = Join-Path $global:Root ("Snapshots\$($Game.Id)")
    if (-not (Test-Path -LiteralPath $root)) { return }
    $keep = [int]$global:Config.SnapshotKeep
    if ($keep -lt 1) { $keep = 1 }
    $dirs = @(Get-ChildItem -LiteralPath $root -Directory | Sort-Object Name -Descending)
    $i = 0
    foreach ($d in $dirs) {
        $i++
        if ($i -gt $keep) {
            Remove-Item -LiteralPath $d.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
