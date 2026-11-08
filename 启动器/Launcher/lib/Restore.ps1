# Restore.ps1 - 把 U 盘上的存档还原到本机：拆联接 / 复制回本机 / 导回注册表

function Restore-GameToLocal {
    param($Game, [switch]$DeleteStore)

    if (-not $Game -or (@($Game.Mappings).Count -eq 0 -and @($Game.RegistryMappings).Count -eq 0)) {
        return @('这个游戏没有配置存档映射，无需还原。')
    }

    $cfg = Read-GlobalConfig
    $notes = New-Object System.Collections.ArrayList

    foreach ($map in $Game.Mappings) {
        $local = Expand-Vars $map.Local $Game
        $store = Get-MappingStorePath $Game $map

        if ($map.Kind -eq 'file') {
            if (Test-Path -LiteralPath $store) {
                Ensure-Dir (Split-Path -Parent $local)
                Copy-Item -LiteralPath $store -Destination $local -Force
                [void]$notes.Add(('文件已还原：{0}' -f $map.Local))
            } else {
                [void]$notes.Add(('跳过 {0}：U 盘没有对应文件' -f $map.Local))
            }
            continue
        }

        if (-not (Test-Path -LiteralPath $store)) {
            [void]$notes.Add(('跳过 {0}：U 盘没有对应存档' -f $map.Local))
            continue
        }

        Clear-DanglingJunction $local
        if (Test-Junction $local) {
            Remove-Junction $local
            [void]$notes.Add(('已拆联接：{0}' -f $map.Local))
        } elseif (Test-Path -LiteralPath $local) {
            $bak = Backup-LocalDir $Game $map $local
            [void]$notes.Add(('本机旧目录已备份：{0}' -f $bak))
        }

        Ensure-Dir (Split-Path -Parent $local)
        Copy-Tree $store $local -Purge -Exclude $cfg.ExcludeDirs | Out-Null
        [void]$notes.Add(('目录已还原：{0}' -f $map.Local))
    }

    if (@($Game.RegistryMappings).Count -gt 0) {
        foreach ($n in @(Restore-GameRegistry $Game)) {
            if ($n) { [void]$notes.Add($n) }
        }
    }

    foreach ($map in $Game.Mappings) {
        Remove-LocalOwner (Expand-Vars $map.Local $Game)
    }

    if ($DeleteStore) {
        foreach ($map in $Game.Mappings) {
            $store = Get-MappingStorePath $Game $map
            if (-not (Test-Path -LiteralPath $store)) { continue }
            if ($map.Kind -eq 'file') {
                Remove-Item -LiteralPath $store -Force -ErrorAction SilentlyContinue
            } else {
                Remove-Item -LiteralPath $store -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        $regDir = Get-RegStoreDir $Game
        if (Test-Path -LiteralPath $regDir) {
            Remove-Item -LiteralPath $regDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        $gameData = Join-Path $global:Root ('Data\' + $Game.Id)
        if ((Test-Path -LiteralPath $gameData) -and @(Get-ChildItem -LiteralPath $gameData -Force -ErrorAction SilentlyContinue).Count -eq 0) {
            Remove-Item -LiteralPath $gameData -Force -ErrorAction SilentlyContinue
        }
        [void]$notes.Add('U 盘上的存档副本已删除。')
    }

    Write-Log ('还原到本机：{0}（{1} 条文件映射，{2} 条注册表映射）' -f $Game.Id, @($Game.Mappings).Count, @($Game.RegistryMappings).Count) 'OK'
    return @($notes)
}
