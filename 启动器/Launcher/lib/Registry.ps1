# Registry.ps1 - HKCU 注册表存档的导入/导出（reg.exe，免管理员）

function Get-RegStoreDir {
    param($Game)
    return (Join-Path (Join-Path $global:Root ('Data\' + $Game.Id)) 'registry')
}

function Get-RegStoreFile {
    param($Game, $Name)
    $safe = ($Name -replace '[^A-Za-z0-9\._\-]', '-')
    if (-not $safe) { $safe = 'reg' }
    return (Join-Path (Get-RegStoreDir $Game) ($safe + '.reg'))
}

function Export-GameRegistryKey {
    param([string]$Key, [string]$File)
    Ensure-Dir (Split-Path -Parent $File)
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = & reg.exe export $Key $File /y 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $old
    if ($code -ne 0) {
        throw ("导出注册表失败（{0}）：{1}" -f $Key, ($out -join ' '))
    }
}

function Import-GameRegistryKey {
    param([string]$Key, [string]$File)
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = & reg.exe import $File 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $old
    if ($code -ne 0) {
        throw ("导入注册表失败（{0}）：{1}" -f $File, ($out -join ' '))
    }
}

# 启动前：U 盘有 .reg 就导入；没有则先把本机现状导出当基线
function Import-GameRegistry {
    param($Game)
    $maps = @($Game.RegistryMappings)
    if ($maps.Count -eq 0) { return }
    foreach ($r in $maps) {
        if (-not $r.Key) { continue }
        $file = Get-RegStoreFile $Game $r.Name
        if (Test-Path -LiteralPath $file) {
            try {
                Import-GameRegistryKey $r.Key $file
                Write-Log ("注册表已导入：{0} <- {1}" -f $r.Key, (Split-Path -Leaf $file)) 'OK'
            } catch {
                Write-Log $_.Exception.Message 'WARN'
            }
        } else {
            try {
                Export-GameRegistryKey $r.Key $file
                Write-Log ("注册表首次接管，已导出基线：{0} -> {1}" -f $r.Key, (Split-Path -Leaf $file)) 'OK'
            } catch {
                Write-Log ("注册表基线导出失败，本次不跟随：{0}" -f $_.Exception.Message) 'WARN'
            }
        }
    }
}

# 退出后：把当前 HKCU 状态导出回 U 盘
function Export-GameRegistry {
    param($Game)
    $maps = @($Game.RegistryMappings)
    if ($maps.Count -eq 0) { return }
    foreach ($r in $maps) {
        if (-not $r.Key) { continue }
        $file = Get-RegStoreFile $Game $r.Name
        try {
            Export-GameRegistryKey $r.Key $file
            Write-Log ("注册表已回写：{0} -> {1}" -f $r.Key, (Split-Path -Leaf $file)) 'OK'
        } catch {
            Write-Log ("注册表回写失败：{0}" -f $_.Exception.Message) 'WARN'
        }
    }
}

# 还原到本机时用：把 U 盘的 .reg 导回本机
function Restore-GameRegistry {
    param($Game)
    $maps = @($Game.RegistryMappings)
    if ($maps.Count -eq 0) { return @() }
    $notes = @()
    foreach ($r in $maps) {
        if (-not $r.Key) { continue }
        $file = Get-RegStoreFile $Game $r.Name
        if (-not (Test-Path -LiteralPath $file)) { continue }
        try {
            Import-GameRegistryKey $r.Key $file
            $notes += ('注册表已还原：' + $r.Key)
        } catch {
            $notes += ('注册表还原失败：' + $r.Key + '（' + $_.Exception.Message + '）')
        }
    }
    return $notes
}
