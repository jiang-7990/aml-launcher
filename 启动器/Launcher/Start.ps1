#Requires -Version 5.1
<#
U盘游戏启动器 - 主入口

用法：
  Start.ps1                 菜单选择游戏
  Start.ps1 PvZ             直接启动（可用 id、名称或名称片段）
  Start.ps1 -List           只列出游戏
  可选 -NoPause             结束时不等待按键
#>
param(
    [Parameter(Position = 0)]
    [string]$Game,
    [string]$Root,
    [switch]$List,
    [switch]$NoPause,
    [switch]$Console,
    [switch]$Learn,
    [switch]$Direct,
    [switch]$AddGame
)

$ErrorActionPreference = 'Stop'

$global:Root = if ($Root) { $Root } else { Split-Path -Parent $PSScriptRoot }
$libDir = Join-Path $PSScriptRoot 'lib'

. (Join-Path $libDir 'Common.ps1')
. (Join-Path $libDir 'State.ps1')
. (Join-Path $libDir 'Config.ps1')
. (Join-Path $libDir 'Snapshot.ps1')
. (Join-Path $libDir 'Sync.ps1')
. (Join-Path $libDir 'Link.ps1')
. (Join-Path $libDir 'Launch.ps1')
. (Join-Path $libDir 'Learn.ps1')
. (Join-Path $libDir 'Registry.ps1')
. (Join-Path $libDir 'Restore.ps1')
. (Join-Path $libDir 'Mappings.ps1')
. (Join-Path $libDir 'Uninstall.ps1')
. (Join-Path (Join-Path $PSScriptRoot 'ui') 'Menu.ps1')

$logDir = Join-Path $global:Root 'Logs'
Ensure-Dir $logDir
$global:LogFile = Join-Path $logDir ('launcher_{0}.log' -f (Get-Date -Format 'yyyyMMdd'))

$exitCode = 0
$isGui = $false
try {
    Write-Log ("启动器根目录: " + $global:Root)
    $global:Config = Read-GlobalConfig

    $isGui = (-not $Game) -and (-not $List) -and (-not $Console) -and (-not $AddGame) -and (-not $Learn)
    if ($isGui) {
        $mutex = New-Object System.Threading.Mutex($false, 'Local\AML_Launcher_SingleInstance')
        if (-not $mutex.WaitOne(0)) {
            Write-Log '已有启动器实例在运行，激活现有窗口。'
            try {
                $sh = New-Object -ComObject WScript.Shell
                [void]$sh.AppActivate('AML')
            } catch { }
            return
        }
        $global:AmlMutex = $mutex
        Invoke-Retention -LogKeepDays $global:Config.LogKeepDays -BackupKeep $global:Config.BackupKeep
    }

    $games = @(Get-AllGames)

    if ($AddGame) {
        . (Join-Path (Join-Path $PSScriptRoot 'ui') 'MainWindow.ps1')
        . (Join-Path (Join-Path $PSScriptRoot 'ui') 'LearnWindow.ps1')
        . (Join-Path (Join-Path $PSScriptRoot 'ui') 'AddGameWindow.ps1')
        . (Join-Path (Join-Path $PSScriptRoot 'ui') 'SettingsWindow.ps1')
        . (Join-Path (Join-Path $PSScriptRoot 'ui') 'RestoreDialog.ps1')
        . (Join-Path (Join-Path $PSScriptRoot 'ui') 'SaveLocationWindow.ps1')
        Show-AddGameWindow $null
        return
    }

    if ($List) {
        Write-Host ''
        if ($games.Count -eq 0) {
            Write-Host 'Games 目录里还没有游戏。' -ForegroundColor Yellow
        } else {
            Write-Host '可用游戏：' -ForegroundColor Cyan
            foreach ($g in $games) {
                $exeShown = if ($g.Exe) { $g.Exe } else { '(未找到 exe)' }
                Write-Host ('  {0,-12} {1,-20} {2}' -f $g.Id, $g.Name, $exeShown)
            }
        }
        Write-Host ''
        return
    }

    if ($Learn) {
        if (-not $Game) { throw '使用 -Learn 时要指定游戏，例如：启动器.cmd -Learn PvZ杂交版' }
        $lt = Get-GameById $Game
        if (-not $lt) { throw ("找不到游戏：" + $Game) }
        . (Join-Path (Join-Path $PSScriptRoot 'ui') 'MainWindow.ps1')
        . (Join-Path (Join-Path $PSScriptRoot 'ui') 'LearnWindow.ps1')
        Show-LearnWindow $lt $null
        return
    }

    if ($Game) {
        $target = Get-GameById $Game
        if (-not $target) { throw ("找不到游戏：" + $Game) }
    } elseif (-not $Console) {
        $isGui = $true
        . (Join-Path (Join-Path $PSScriptRoot 'ui') 'MainWindow.ps1')
        . (Join-Path (Join-Path $PSScriptRoot 'ui') 'LearnWindow.ps1')
        . (Join-Path (Join-Path $PSScriptRoot 'ui') 'AddGameWindow.ps1')
        . (Join-Path (Join-Path $PSScriptRoot 'ui') 'SettingsWindow.ps1')
        . (Join-Path (Join-Path $PSScriptRoot 'ui') 'RestoreDialog.ps1')
        . (Join-Path (Join-Path $PSScriptRoot 'ui') 'SaveLocationWindow.ps1')
        . (Join-Path (Join-Path $PSScriptRoot 'ui') 'UninstallDialog.ps1')
        Show-MainWindow -Games $games -Config $global:Config -Root $global:Root
        return
    } else {
        if ($games.Count -eq 0) {
            throw ("Games 目录里没有游戏。请把游戏文件夹放到 " + (Join-Path $global:Root 'Games'))
        }
        $target = Show-GameMenu -Games $games -Root $global:Root
        if (-not $target) {
            Write-Log '已取消。'
            return
        }
    }

    Write-Log ("选择游戏: {0} ({1})" -f $target.Name, $target.Id)
    foreach ($m in $target.Mappings) {
        Write-Log ("映射 {0}: {1} <- {2} [{3}]" -f $m.Id, $m.Kind, $m.Local, $m.Store)
    }

    $launchMode = if ($Direct) { 'direct' } else { 'auto' }
    Start-Game $target -LaunchMode $launchMode
    Write-Log '全部完成。' 'OK'
}
catch {
    Write-Log ('启动失败：' + $_.Exception.Message) 'ERROR'
    if ($_.ScriptStackTrace) { Write-Log ($_.ScriptStackTrace) 'DEBUG' }
    $exitCode = 1
}
finally {
    if (-not $NoPause -and -not $isGui) {
        Write-Host ''
        [void](Read-Host '按回车关闭窗口')
    }
}

exit $exitCode
