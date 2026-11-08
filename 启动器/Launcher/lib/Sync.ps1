# Sync.ps1 - 复制模式（目录与单文件）

function Sync-DirIn {
    param([string]$Store, [string]$Local)
    Ensure-Dir (Split-Path -Parent $Local)
    if (-not (Test-Path -LiteralPath $Store)) {
        Ensure-Dir $Local
        return
    }
    if (-not (Test-StoreHasData $Store)) {
        Ensure-Dir $Local
        return
    }
    Write-Log "复制模式：U 盘 -> 本机  $Local"
    Copy-Tree $Store $Local | Out-Null
}

function Sync-DirOut {
    param($Game, [string]$Store, [string]$Local)
    if (-not (Test-Path -LiteralPath $Local)) { return }
    if (Test-Junction $Local) { throw "复制模式却遇到联接，已停止回写: $Local" }
    New-StoreSnapshot $Game $Store
    Write-Log "复制模式：本机 -> U 盘  $Store"
    Copy-Tree $Local $Store | Out-Null
}

function Sync-FileIn {
    param([string]$StoreFile, [string]$LocalFile)
    Ensure-Dir (Split-Path -Parent $LocalFile)
    if (Test-Path -LiteralPath $StoreFile) {
        Copy-Item -LiteralPath $StoreFile -Destination $LocalFile -Force
        $t = (Get-Item -LiteralPath $StoreFile).LastWriteTime
        (Get-Item -LiteralPath $LocalFile).LastWriteTime = $t
    } elseif (Test-Path -LiteralPath $LocalFile) {
        Ensure-Dir (Split-Path -Parent $StoreFile)
        Copy-Item -LiteralPath $LocalFile -Destination $StoreFile -Force
    }
}

function Sync-FileOut {
    param([string]$StoreFile, [string]$LocalFile)
    if (-not (Test-Path -LiteralPath $LocalFile)) { return }
    if (Test-Path -LiteralPath $LocalFile -PathType Container) { return }
    Ensure-Dir (Split-Path -Parent $StoreFile)
    Copy-Item -LiteralPath $LocalFile -Destination $StoreFile -Force
}
