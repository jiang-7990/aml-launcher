# Uninstall.ps1 - 从启动器移除游戏：还原存档 / 删除配置 / 可选删除游戏文件

function Uninstall-Game {
    param($Game, [switch]$Restore, [switch]$DeleteFiles)

    $notes = New-Object System.Collections.ArrayList

    if ($Restore) {
        foreach ($n in @(Restore-GameToLocal $Game -DeleteStore)) {
            if ($n) { [void]$notes.Add($n) }
        }
    } else {
        [void]$notes.Add('U 盘上的存档副本保留在 Data\' + $Game.Id + '（下次重新添加同名游戏还能接上）。')
    }

    if ($Game.ProfilePath -and (Test-Path -LiteralPath $Game.ProfilePath)) {
        Remove-Item -LiteralPath $Game.ProfilePath -Force -ErrorAction SilentlyContinue
        [void]$notes.Add('配置已删除：Launcher\profiles\' + $Game.Id + '.ini')
    }

    $gameData = Join-Path $global:Root ('Data\' + $Game.Id)
    if ((Test-Path -LiteralPath $gameData) -and @(Get-ChildItem -LiteralPath $gameData -Force -ErrorAction SilentlyContinue).Count -eq 0) {
        Remove-Item -LiteralPath $gameData -Force -ErrorAction SilentlyContinue
    }

    $icons = Join-Path $global:Root ('Launcher\icons\' + $Game.Id + '.png')
    if ($icons -and (Test-Path -LiteralPath $icons)) {
        Remove-Item -LiteralPath $icons -Force -ErrorAction SilentlyContinue
    }

    if ($DeleteFiles) {
        $gamesRoot = Join-Path $global:Root 'Games'
        $full = [IO.Path]::GetFullPath($Game.Dir)
        $rootFull = [IO.Path]::GetFullPath($gamesRoot).TrimEnd('\') + '\'
        if ($full.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $full)) {
            Remove-Item -LiteralPath $full -Recurse -Force -ErrorAction SilentlyContinue
            [void]$notes.Add('游戏文件已删除：Games\' + $Game.Id)
        } else {
            [void]$notes.Add('游戏目录不在 Games\ 下，已跳过删除：' + $Game.Dir)
        }
    } else {
        [void]$notes.Add('游戏文件保留在 Games\' + $Game.Id + '，想彻底删除可手动删。')
    }

    Write-Log ('卸载游戏：{0}（还原={1}，删文件={2}）' -f $Game.Id, [bool]$Restore, [bool]$DeleteFiles) 'OK'
    return @($notes)
}
