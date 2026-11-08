# Mappings.ps1 -- 存档映射的读写（给「存档位置」对话框用）
# 只维护 profile 里的 [mapping.N] 段；[game] 与 [registry.N] 原样保留。

function Get-MappingSectionKeys {
    param($Ini)
    $list = @()
    foreach ($s in $Ini.Keys) {
        if ($s -match '^mapping\.(\d+)$') {
            $list += [pscustomobject]@{ Section = $s; Num = [int]$Matches[1] }
        }
    }
    return @($list | Sort-Object Num)
}

function Save-ProfileIni {
    param($Game, $Ini)
    Write-Ini $Ini $Game.ProfilePath
}

function Update-GameMapping {
    param(
        $Game,
        [int]$Id,
        [string]$Local,
        [string]$Store,
        [string]$Mode = '',
        [string]$Kind = 'dir'
    )
    $notes = @()
    $ini = Read-Ini $Game.ProfilePath
    $sec = 'mapping.' + $Id
    if (-not $ini.Contains($sec)) { throw ("找不到映射段：" + $sec) }

    $oldLocal = [string](Get-IniValue $ini $sec 'local' '')
    $oldVar = if ($oldLocal) { Expand-Vars $oldLocal $Game } else { '' }

    $ini[$sec]['kind'] = $Kind
    $ini[$sec]['local'] = $Local
    $ini[$sec]['store'] = $Store
    if ($Mode -and $Mode -ne 'auto') { $ini[$sec]['mode'] = $Mode } else { if ($ini[$sec].Contains('mode')) { $ini[$sec].Remove('mode') } }

    # 本机路径变了：旧位置如果还是指过来的联接，拆掉（数据留在 U 盘）
    if ($oldVar -and ($oldVar -ne $Local)) {
        $oldExpanded = $oldVar
        if (Test-Path -LiteralPath $oldExpanded) {
            if (Test-Junction $oldExpanded) {
                Remove-Junction $oldExpanded
                $notes += ('已拆掉旧位置的联接：' + $oldExpanded + '（数据仍在 U 盘）')
            }
        }
    }

    Save-ProfileIni $Game $ini
    $notes += ('已更新：' + $Local)
    return @($notes)
}

function Add-GameMapping {
    param(
        $Game,
        [string]$Local,
        [string]$Store,
        [string]$Mode = '',
        [string]$Kind = 'dir'
    )
    $ini = Read-Ini $Game.ProfilePath
    $keys = @(Get-MappingSectionKeys $ini)
    $next = 1
    if ($keys.Count -gt 0) { $next = ($keys | Measure-Object Num -Maximum).Maximum + 1 }

    $sec = 'mapping.' + $next
    $ini[$sec] = [ordered]@{
        kind     = $Kind
        local    = $Local
        store    = $Store
        optional = '0'
    }
    if ($Mode -and $Mode -ne 'auto') { $ini[$sec]['mode'] = $Mode }
    $ini[$sec]['merge'] = 'none'

    Save-ProfileIni $Game $ini
    return ('已添加映射：' + $Local)
}

function Remove-GameMapping {
    param($Game, [int]$Id)
    $notes = @()
    $ini = Read-Ini $Game.ProfilePath
    $sec = 'mapping.' + $Id
    if (-not $ini.Contains($sec)) { throw ("找不到映射段：" + $sec) }

    $local = Expand-Vars ([string](Get-IniValue $ini $sec 'local' '')) $Game
    if ($local -and (Test-Path -LiteralPath $local) -and (Test-Junction $local)) {
        Remove-Junction $local
        $notes += ('已拆掉联接：' + $local + '（U 盘副本保留）')
    }
    $ini.Remove($sec)
    Save-ProfileIni $Game $ini
    $notes += '映射已删除。'
    return @($notes)
}
