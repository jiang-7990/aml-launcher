# Menu.ps1 - 控制台菜单

function Show-GameMenu {
    param($Games, [string]$Root)

    while ($true) {
        Write-Host ''
        Write-Host '==============================================' -ForegroundColor Cyan
        Write-Host '            U盘游戏启动器（存档跟随）' -ForegroundColor Cyan
        Write-Host '==============================================' -ForegroundColor Cyan
        Write-Host ("  U盘: {0}" -f $Root) -ForegroundColor DarkGray
        Write-Host ("  模式: {0}    快照保留: {1} 份" -f $global:Config.Mode, $global:Config.SnapshotKeep) -ForegroundColor DarkGray
        Write-Host ''

        $i = 0
        foreach ($g in $Games) {
            $i++
            $ready = if ($g.Exe) { '' } else { '  [缺少 exe]' }
            Write-Host ("  [{0}] {1}{2}" -f $i, $g.Name, $ready) -ForegroundColor White
            Write-Host ("      {0}" -f $g.Id) -ForegroundColor DarkGray
        }

        Write-Host ''
        Write-Host '  输入编号或名称启动，直接回车退出。' -ForegroundColor DarkGray
        $ans = Read-Host '  > '
        if ([string]::IsNullOrWhiteSpace($ans)) { return $null }
        $ans = $ans.Trim()

        if ($ans -match '^\d+$') {
            $n = [int]$ans
            if ($n -ge 1 -and $n -le $Games.Count) { return $Games[$n - 1] }
            Write-Host '  编号超出范围。' -ForegroundColor Yellow
            continue
        }

        $hit = $Games | Where-Object {
            $_.Id -eq $ans -or $_.Name -eq $ans -or
            $_.Id -like "*$ans*" -or $_.Name -like "*$ans*"
        } | Select-Object -First 1
        if ($hit) { return $hit }
        Write-Host '  没有匹配的游戏。' -ForegroundColor Yellow
    }
}
