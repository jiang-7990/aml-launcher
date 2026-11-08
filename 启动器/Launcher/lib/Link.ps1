# Link.ps1 - 目录联接：接管、备份、重建、自检、版本切换

function Backup-LocalDir {
    param($Game, $Map, [string]$Local)
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $dest = Join-Path $global:Root ("Backups\$($Game.Id)\$stamp\map$($Map.Id)")
    Write-Log "备份本机存档: $Local -> $dest"
    Copy-Tree $Local $dest | Out-Null
    return $dest
}

function Assert-LinkWorks {
    param([string]$Local, [string]$Store)
    $name = '.pgl_probe_' + [guid]::NewGuid().ToString('N')
    $probe = Join-Path $Local $name
    Set-Content -LiteralPath $probe -Value 'ok' -Encoding UTF8
    $landed = Test-Path -LiteralPath (Join-Path $Store $name)
    Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
    if (-not $landed) { throw "联接自检失败：写入没有落到 U 盘（$Local -> $Store）" }
}

function Clear-DanglingJunction {
    param([string]$Path)
    # 断链（例如 U 盘换了盘符）时 Test-Path 为假，但目录项还在
    if (Test-Path -LiteralPath $Path) { return }
    try { [IO.Directory]::Delete($Path) } catch { }
}

function Remove-RealDirContents {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

function Ensure-DirLink {
    param($Game, $Map, [string]$Local, [string]$Store)
    Ensure-Dir (Split-Path -Parent $Local)
    Ensure-Dir $Store
    Clear-DanglingJunction $Local

    if (Test-Path -LiteralPath $Local) {
        if (Test-Junction $Local) {
            $oldTarget = Get-JunctionTarget $Local
            if ($oldTarget -and ($oldTarget.TrimEnd('\') -ine $Store.TrimEnd('\'))) {
                Write-Log ("版本隔离：{0} 原指向 {1}，切换为 {2}" -f $Local, $oldTarget, $Store) 'OK'
            }
            Remove-Junction $Local
        } else {
            Backup-LocalDir $Game $Map $Local | Out-Null
            $owner = Get-LocalOwner $Local
            $ownerStore = Get-OwnerStorePath $owner

            if ($ownerStore -and $owner.Game -ne $Game.Id) {
                # 这个目录上一轮属于别的游戏：把留在本机的改动先还给它的存档
                Write-Log ("版本隔离：本机目录属于 {0}，先把改动回写到 {1}" -f $owner.Game, $ownerStore) 'OK'
                Copy-Tree $Local $ownerStore | Out-Null
                Remove-RealDirContents $Local
                Remove-Item -LiteralPath $Local -Recurse -Force -ErrorAction SilentlyContinue
            } elseif (-not (Test-StoreHasData $Store)) {
                Write-Log "接管本机存档到 U 盘: $Local -> $Store" 'OK'
                Copy-Tree $Local $Store -Move | Out-Null
                if (Test-Path -LiteralPath $Local) {
                    Remove-Item -LiteralPath $Local -Recurse -Force
                }
            } else {
                Write-Log "U 盘已有存档，本机旧档只备份不覆盖: $Local" 'WARN'
                Remove-Item -LiteralPath $Local -Recurse -Force
            }
        }
    }

    New-Junction $Local $Store
    Assert-LinkWorks $Local $Store
    Set-LocalOwner $Local $Game.Id $Map.Store
    Write-Log "联接就绪: $Local -> $Store" 'OK'
}

function Invoke-DirMapping {
    param($Game, $Map)
    $local = Expand-Vars $Map.Local $Game
    $store = Get-MappingStorePath $Game $Map
    $mode = $Map.Mode
    if (-not $mode -or $mode -eq 'auto') { $mode = $global:Config.Mode }
    if ($mode -eq 'link') { $mode = 'auto' }

    if ($mode -eq 'copy') {
        Clear-DanglingJunction $local
        if (Test-Junction $local) {
            Remove-Junction $local
            Ensure-Dir $local
        }

        $owner = Get-LocalOwner $local
        if ($owner -and $owner.Game -ne $Game.Id) {
            $ownerStore = Get-OwnerStorePath $owner
            if ($ownerStore -and (Test-Path -LiteralPath $local)) {
                Write-Log ("版本隔离：先把本机目录里 {0} 的改动回写" -f $owner.Game) 'OK'
                Copy-Tree $local $ownerStore | Out-Null
                Remove-RealDirContents $local
            }
        }

        Sync-DirIn $store $local
        Set-LocalOwner $local $Game.Id $Map.Store
        return 'copy'
    }

    try {
        Ensure-DirLink $Game $Map $local $store
        return 'link'
    } catch {
        Write-Log ("联接失败，降级复制：" + $_.Exception.Message) 'WARN'
        Sync-DirIn $store $local
        Set-LocalOwner $local $Game.Id $Map.Store
        return 'copy'
    }
}
