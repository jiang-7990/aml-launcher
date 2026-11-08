# State.ps1 - 本机映射归属记录（版本隔离：同一个本机存档目录被多个游戏轮流使用时，记住它现在属于谁）

function Get-StatePath {
    $guid = $null
    try {
        $guid = (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Cryptography' -Name MachineGuid -ErrorAction Stop).MachineGuid
    } catch { }
    if (-not $guid) { $guid = $env:COMPUTERNAME }
    foreach ($c in [IO.Path]::GetInvalidFileNameChars()) { $guid = $guid.Replace($c, '_') }
    $dir = Join-Path $global:Root 'Launcher\state'
    Ensure-Dir $dir
    return (Join-Path $dir ($guid + '.ini'))
}

function Get-PathKey {
    param([string]$Path)
    $sha = [Security.Cryptography.SHA1]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($Path.ToLowerInvariant())
        $hash = ([BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '')
        return $hash.Substring(0, 16).ToLowerInvariant()
    } finally { $sha.Dispose() }
}

function Get-LocalOwner {
    param([string]$Local)
    $ini = Read-Ini (Get-StatePath)
    $sec = 'mapping.' + (Get-PathKey $Local)
    if (-not $ini.Contains($sec)) { return $null }
    return [pscustomobject]@{
        Local  = Get-IniValue $ini $sec 'local' $Local
        Game   = Get-IniValue $ini $sec 'game' ''
        Store  = Get-IniValue $ini $sec 'store' ''
        Updated = Get-IniValue $ini $sec 'updated' ''
    }
}

function Set-LocalOwner {
    param([string]$Local, [string]$GameId, [string]$Store)
    $path = Get-StatePath
    $ini = Read-Ini $path
    $sec = 'mapping.' + (Get-PathKey $Local)
    if (-not $ini.Contains($sec)) { $ini[$sec] = [ordered]@{} }
    $ini[$sec]['local'] = $Local
    $ini[$sec]['game'] = $GameId
    $ini[$sec]['store'] = $Store
    $ini[$sec]['updated'] = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    Write-Ini $ini $path
}

function Remove-LocalOwner {
    param([string]$Local)
    $path = Get-StatePath
    if (-not (Test-Path -LiteralPath $path)) { return }
    $ini = Read-Ini $path
    $sec = 'mapping.' + (Get-PathKey $Local)
    if (-not $ini.Contains($sec)) { return }
    $ini.Remove($sec)
    Write-Ini $ini $path
}

function Get-OwnerStorePath {
    param($Owner)
    if (-not $Owner -or -not $Owner.Game) { return $null }
    return (Join-Path (Join-Path $global:Root ('Data\' + $Owner.Game)) $Owner.Store)
}

function Set-GameLastRun {
    param([string]$GameId, [string]$Mode)
    $path = Get-StatePath
    $ini = Read-Ini $path
    $sec = 'game.' + $GameId.ToLowerInvariant()
    if (-not $ini.Contains($sec)) { $ini[$sec] = [ordered]@{} }
    $ini[$sec]['lastrun'] = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    if ($Mode) { $ini[$sec]['mode'] = $Mode }
    Write-Ini $ini $path
}

function Get-GameLastRun {
    param([string]$GameId)
    $ini = Read-Ini (Get-StatePath)
    $sec = 'game.' + $GameId.ToLowerInvariant()
    return (Get-IniValue $ini $sec 'lastrun' '')
}
