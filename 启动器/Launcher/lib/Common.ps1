# Common.ps1 - 基础工具：日志、路径变量、INI、联接、文件复制
# 依赖：$global:Root（启动器根目录）、$global:LogFile

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO','OK','WARN','ERROR','DEBUG')]
        [string]$Level = 'INFO'
    )
    $line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    if ($global:LogFile) {
        try { Add-Content -LiteralPath $global:LogFile -Value $line -Encoding UTF8 } catch { }
    }
    $color = switch ($Level) {
        'OK'    { 'Green' }
        'WARN'  { 'Yellow' }
        'ERROR' { 'Red' }
        'DEBUG' { 'DarkGray' }
        default { 'Gray' }
    }
    Write-Host $line -ForegroundColor $color
}

function Ensure-Dir {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Expand-Vars {
    param([string]$Text, $Game)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $Text }
    return [regex]::Replace($Text, '%([A-Za-z0-9_]+)%', {
        param($m)
        $name = $m.Groups[1].Value.ToUpperInvariant()
        switch ($name) {
            'GAMEDIR'    { if ($Game) { return $Game.Dir } else { return $m.Value } }
            'GAMEID'     { if ($Game) { return $Game.Id } else { return $m.Value } }
            'ROOT'       { return $global:Root }
            'DOCUMENTS'  { return [Environment]::GetFolderPath('MyDocuments') }
            'SAVEDGAMES' { return (Join-Path $env:USERPROFILE 'Saved Games') }
            'LOCALLOW'   { return (Join-Path $env:USERPROFILE 'AppData\LocalLow') }
            default {
                $v = [Environment]::GetEnvironmentVariable($name)
                if ($v) { return $v }
                return $m.Value
            }
        }
    })
}

function Read-Ini {
    param([string]$Path)
    $ini = [ordered]@{}
    if (-not (Test-Path -LiteralPath $Path)) { return $ini }
    $section = ''
    foreach ($raw in (Get-Content -LiteralPath $Path -Encoding UTF8)) {
        $line = $raw.Trim()
        if ($line -eq '' -or $line.StartsWith(';') -or $line.StartsWith('#')) { continue }
        if ($line -match '^\[(.+)\]$') {
            $section = $Matches[1].Trim().ToLowerInvariant()
            if (-not $ini.Contains($section)) { $ini[$section] = [ordered]@{} }
            continue
        }
        $idx = $line.IndexOf('=')
        if ($idx -lt 0) { continue }
        $k = $line.Substring(0, $idx).Trim().ToLowerInvariant()
        $v = $line.Substring($idx + 1).Trim()
        if ($v.Length -ge 2) {
            if (($v.StartsWith('"') -and $v.EndsWith('"')) -or ($v.StartsWith("'") -and $v.EndsWith("'"))) {
                $v = $v.Substring(1, $v.Length - 2)
            }
        }
        if (-not $ini.Contains($section)) { $ini[$section] = [ordered]@{} }
        $ini[$section][$k] = $v
    }
    return $ini
}

function Write-Ini {
    param($Ini, [string]$Path)
    $sb = New-Object System.Text.StringBuilder
    foreach ($s in $Ini.Keys) {
        [void]$sb.AppendLine('[' + $s + ']')
        foreach ($k in $Ini[$s].Keys) {
            [void]$sb.AppendLine(('{0}={1}' -f $k, $Ini[$s][$k]))
        }
        [void]$sb.AppendLine('')
    }
    Ensure-Dir (Split-Path -Parent $Path)
    $enc = New-Object System.Text.UTF8Encoding($true)
    [IO.File]::WriteAllText($Path, $sb.ToString(), $enc)
}

function Get-IniValue {
    param($Ini, [string]$Section, [string]$Key, $Default = '')
    $s = $Section.ToLowerInvariant()
    $k = $Key.ToLowerInvariant()
    if ($Ini -and $Ini.Contains($s)) {
        $sec = $Ini[$s]
        if ($sec.Contains($k)) { return $sec[$k] }
    }
    return $Default
}

function Convert-ToBool {
    param($Value, [bool]$Default = $false)
    if ($null -eq $Value) { return $Default }
    $s = ([string]$Value).Trim().ToLowerInvariant()
    if ($s -in @('1','true','yes','on','y')) { return $true }
    if ($s -in @('0','false','no','off','n','')) { return $false }
    return $Default
}

# ---------------------------------------------------------------- 联接

function Test-Junction {
    param([string]$Path)
    try {
        $a = [IO.File]::GetAttributes($Path)
        return (($a -band [IO.FileAttributes]::ReparsePoint) -ne 0)
    } catch { return $false }
}

function New-Junction {
    param([string]$Link, [string]$Target)
    Ensure-Dir (Split-Path -Parent $Link)
    Ensure-Dir $Target
    if (Test-Path -LiteralPath $Link) { throw "路径已存在，无法创建联接: $Link" }
    New-Item -ItemType Junction -Path $Link -Target $Target -ErrorAction Stop | Out-Null
}

function Remove-Junction {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    if (-not (Test-Junction $Path)) { throw "不是联接，拒绝按联接删除: $Path" }
    try {
        [IO.Directory]::Delete($Path)
    } catch {
        & cmd.exe /c ('rmdir "{0}"' -f $Path) 2>$null | Out-Null
    }
}

function Get-JunctionTarget {
    param([string]$Path)
    $lines = & fsutil.exe reparsepoint query "$Path" 2>$null
    foreach ($l in $lines) {
        if ($l -match '\\\?\?\\(.+)$') { return $Matches[1].Trim() }
    }
    return $null
}

function Test-StoreHasData {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $first = Get-ChildItem -LiteralPath $Path -Force -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    return ($null -ne $first)
}

# ---------------------------------------------------------------- 复制

function Copy-Tree {
    param(
        [string]$Source,
        [string]$Dest,
        [switch]$Move,
        [switch]$Purge,
        [string[]]$Exclude = @()
    )
    if (-not (Test-Path -LiteralPath $Source)) { return 0 }
    Ensure-Dir $Dest
    $rcArgs = @($Source, $Dest, '/E', '/XJ', '/COPY:DAT', '/DCOPY:T', '/R:1', '/W:1', '/NFL', '/NDL', '/NJH', '/NJS')
    if ($Move) { $rcArgs += '/MOVE' }
    if ($Purge) { $rcArgs += '/PURGE' }
    if ($Exclude -and $Exclude.Count -gt 0) {
        $rcArgs += '/XD'
        foreach ($x in $Exclude) { if ($x) { $rcArgs += $x } }
    }
    $out = & robocopy.exe @rcArgs 2>&1
    $code = $LASTEXITCODE
    if ($code -ge 8) {
        throw ('robocopy 失败（退出码 {0}）: {1}' -f $code, (($out | Select-Object -Last 6) -join ' | '))
    }
    return $code
}

function Get-DirSizeMB {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return 0 }
    $sum = (Get-ChildItem -LiteralPath $Path -Force -Recurse -File -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
    if (-not $sum) { return 0 }
    return [math]::Round($sum / 1MB, 1)
}

function Get-MachineTag {
    $name = $env:COMPUTERNAME
    foreach ($c in [IO.Path]::GetInvalidFileNameChars()) { $name = $name.Replace($c, '_') }
    return $name
}

function Test-UsbWritable {
    param([string]$Root)
    if (-not (Test-Path -LiteralPath $Root)) { return $false }
    $probe = Join-Path $Root ('.pgl_write_probe_' + [guid]::NewGuid().ToString('N'))
    try {
        Set-Content -LiteralPath $probe -Value 'ok' -Encoding UTF8
        Remove-Item -LiteralPath $probe -Force
        return $true
    } catch { return $false }
}

function Invoke-Retention {
    param([int]$LogKeepDays = 14, [int]$BackupKeep = 3)
    try {
        $logDir = Join-Path $global:Root 'Logs'
        if (Test-Path -LiteralPath $logDir) {
            $cut = (Get-Date).AddDays(-[math]::Max(1, $LogKeepDays))
            Get-ChildItem -LiteralPath $logDir -Filter 'launcher_*.log' -File -ErrorAction SilentlyContinue | ForEach-Object {
                if ($_.LastWriteTime -lt $cut) { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
            }
        }
    } catch { }
    try {
        $bkRoot = Join-Path $global:Root 'Backups'
        if (Test-Path -LiteralPath $bkRoot) {
            Get-ChildItem -LiteralPath $bkRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                $gameDir = $_
                $dirs = @(Get-ChildItem -LiteralPath $gameDir.FullName -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending)
                if ($dirs.Count -gt $BackupKeep) {
                    $dirs | Select-Object -Skip $BackupKeep | ForEach-Object {
                        Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    Write-Log ("备份清理: {0} 保留最近 {1} 份" -f $gameDir.Name, $BackupKeep)
                }
            }
        }
    } catch { }
}
