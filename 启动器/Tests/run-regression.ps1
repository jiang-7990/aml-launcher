# AML 回归脚本（无窗口、无交互）
# 用法: powershell.exe -NoProfile -ExecutionPolicy Bypass -File Tests\run-regression.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$global:Root = $root
$pass = 0; $fail = 0
function Check([string]$Name, [scriptblock]$Body) {
    try {
        $r = & $Body
        if ($r) { $script:pass++; Write-Host ("[PASS] " + $Name) -ForegroundColor Green }
        else { $script:fail++; Write-Host ("[FAIL] " + $Name) -ForegroundColor Red }
    } catch {
        $script:fail++; Write-Host ("[FAIL] " + $Name + " -> " + $_.Exception.Message) -ForegroundColor Red
    }
}
. (Join-Path $root 'Launcher\lib\Common.ps1')
. (Join-Path $root 'Launcher\lib\Config.ps1')
. (Join-Path $root 'Launcher\ui\AddGameWindow.ps1')

Check 'config.ini 可读且 mode 合法' {
    $c = Read-GlobalConfig
    $c.Mode -in @('auto','link','copy') -and (Test-Path -LiteralPath $c.ConfigPath)
}
Check 'scan-lists.ini 解析出三个段' {
    $l = Get-ScanLists
    ($null -ne $l.Exclude) -and ($null -ne $l.SkipDirs) -and ($null -ne $l.Include)
}
Check '游戏列表非空' { @(Get-AllGames).Count -ge 1 }
Check '原生 DLL 可用（SetWindowTheme / PglIcon）' {
    Add-Type -Path (Join-Path $root 'Launcher\cache\PglNative.dll')
    $m = [PglWin].GetMethod('SetWindowTheme')
    $ico = [PglIcon]::Extract((Get-Process -Id $PID).Path, 32)
    ($null -ne $m) -and ($ico -ne [IntPtr]::Zero)
}
Check 'Write-Ini 往返 + UTF8 BOM' {
    $tmp = Join-Path $env:TEMP ('aml-reg-' + [guid]::NewGuid().ToString('N') + '.ini')
    $ini = [ordered]@{ 'game' = [ordered]@{ name = '测试'; exe = 'a.exe' } }
    Write-Ini $ini $tmp
    $bytes = [IO.File]::ReadAllBytes($tmp)
    $ok = ($bytes.Length -gt 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    $back = Read-Ini $tmp
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    $ok -and ((Get-IniValue $back 'game' 'name' '') -eq '测试')
}
Check '备份保留策略（保留 2 份）' {
    $old = $global:Root
    $tmp = Join-Path $env:TEMP ('aml-ret-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path (Join-Path $tmp 'Backups\G') -Force | Out-Null
    foreach ($n in '20200101_000000','20200102_000000','20200103_000000','20200104_000000') {
        New-Item -ItemType Directory -Path (Join-Path $tmp ('Backups\G\' + $n)) -Force | Out-Null
    }
    $global:Root = $tmp
    Invoke-Retention -LogKeepDays 14 -BackupKeep 2
    $left = @(Get-ChildItem (Join-Path $tmp 'Backups\G') -Directory).Count
    $global:Root = $old
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    $left -eq 2
}
Check '扫描 [include] 覆盖工具规则' {
    $old = $global:Root
    $tmp = Join-Path $env:TEMP ('aml-scan-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path (Join-Path $tmp 'Launcher') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tmp 'GameDir') -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $tmp 'GameDir\game_setup.exe') | Out-Null
    New-Item -ItemType File -Path (Join-Path $tmp 'GameDir\unins000.exe') | Out-Null
    Set-Content -LiteralPath (Join-Path $tmp 'Launcher\scan-lists.ini') -Value "[include]`r`ngame_setup`r`n" -Encoding UTF8
    $global:Root = $tmp
    $list = @(Get-AddGameExeList (Join-Path $tmp 'GameDir'))
    $global:Root = $old
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    ($list.Count -eq 1) -and ($list[0].Kind -eq 'game') -and ($list[0].Rel -eq 'game_setup.exe')
}
Write-Host ''
Write-Host ("PASS=" + $pass + "  FAIL=" + $fail)
if ($fail -gt 0) { exit 1 } else { exit 0 }