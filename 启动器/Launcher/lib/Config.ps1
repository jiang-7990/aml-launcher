# Config.ps1 - 全局配置、游戏配置读取、游戏扫描

function Read-GlobalConfig {
    $path = Join-Path $global:Root 'Launcher\config.ini'
    $ini = Read-Ini $path
    $mode = (Get-IniValue $ini 'general' 'mode' 'auto').ToLowerInvariant()
    if ($mode -notin @('auto','link','copy')) { $mode = 'auto' }
    $exRaw = Get-IniValue $ini 'general' 'exclude_dirs' 'shader_cache,logs,cache,temp'
    $exclude = @($exRaw -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    return [pscustomobject]@{
        Mode          = $mode
        SnapshotKeep  = [int](Get-IniValue $ini 'general' 'snapshot_keep' 5)
        MaxSnapshotMB = [int](Get-IniValue $ini 'general' 'max_snapshot_mb' 200)
        ExcludeDirs   = $exclude
        ScanExclude   = @((Get-IniValue $ini 'general' 'scan_exclude' '') -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        ScanSkipDirs  = @((Get-IniValue $ini 'general' 'scan_skip_dirs' '') -split '[,;]' | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ })
        TopMost       = ((Get-IniValue $ini 'general' 'topmost' '0') -eq '1')
        LogKeepDays   = [int](Get-IniValue $ini 'general' 'log_keep_days' 14)
        BackupKeep    = [int](Get-IniValue $ini 'general' 'backup_keep' 3)
        CopyWarnMB    = [int](Get-IniValue $ini 'general' 'copy_warn_mb' 512)
        Wallpaper        = (Get-IniValue $ini 'general' 'wallpaper' '')
        WallpaperOpacity = [int](Get-IniValue $ini 'general' 'wallpaper_opacity' 60)
        PanelOpacity     = [int](Get-IniValue $ini 'general' 'panel_opacity' 92)
        ConfigPath    = $path
    }
}

function Find-GameExe {
    param([string]$Dir)
    if (-not (Test-Path -LiteralPath $Dir)) { return '' }
    $candidates = @('PlantsVsZombies.exe', 'PvZ.exe', 'Game.exe', 'game.exe')
    foreach ($c in $candidates) {
        $p = Join-Path $Dir $c
        if (Test-Path -LiteralPath $p) { return $p }
    }
    $exe = Get-ChildItem -LiteralPath $Dir -Filter '*.exe' -File -ErrorAction SilentlyContinue |
           Sort-Object Length -Descending | Select-Object -First 1
    if ($exe) { return $exe.FullName }
    return ''
}

function Read-GameProfile {
    param([string]$Id, [string]$GameDir)

    $profilePath = Join-Path $global:Root ("Launcher\profiles\$Id.ini")
    $ini = Read-Ini $profilePath

    $game = [pscustomobject]@{
        Id          = $Id
        Name        = Get-IniValue $ini 'game' 'name' $Id
        Dir         = $GameDir
        Exe         = ''
        WorkDir     = $GameDir
        Args        = Get-IniValue $ini 'game' 'args' ''
        RunAs       = (Convert-ToBool (Get-IniValue $ini 'game' 'runas' '0'))
        Pinned      = (Convert-ToBool (Get-IniValue $ini 'game' 'pinned' '0'))
        Wait        = (Get-IniValue $ini 'game' 'wait' 'process').ToLowerInvariant()
        Launcher    = ''
        LauncherArgs = Get-IniValue $ini 'game' 'launcher_args' ''
        HasLauncher = $false
        MaxSnapshotMB = [int](Get-IniValue $ini 'game' 'max_snapshot_mb' 0)
        Mappings    = @()
        RegistryMappings = @()
        ProfilePath = $profilePath
        HasProfile  = (Test-Path -LiteralPath $profilePath)
    }

    $dirVal = Get-IniValue $ini 'game' 'dir' ''
    if ($dirVal) {
        if ([IO.Path]::IsPathRooted($dirVal)) { $GameDir = $dirVal }
        else { $GameDir = Join-Path $global:Root $dirVal }
        $game.Dir = $GameDir
        $game.WorkDir = $GameDir
    }

    $exeVal = Get-IniValue $ini 'game' 'exe' ''
    if ($exeVal) {
        if ([IO.Path]::IsPathRooted($exeVal)) { $game.Exe = $exeVal }
        else { $game.Exe = Join-Path $GameDir $exeVal }
    } else {
        $game.Exe = Find-GameExe $GameDir
    }

    $wd = Get-IniValue $ini 'game' 'workdir' ''
    if ($wd) {
        if ([IO.Path]::IsPathRooted($wd)) { $game.WorkDir = $wd }
        else { $game.WorkDir = Join-Path $GameDir $wd }
    } elseif ($game.Exe) {
        $game.WorkDir = Split-Path -Parent $game.Exe
    }

    $launcherVal = Get-IniValue $ini 'game' 'launcher' ''
    if ($launcherVal) {
        if ([IO.Path]::IsPathRooted($launcherVal)) { $game.Launcher = $launcherVal }
        else { $game.Launcher = Join-Path $GameDir $launcherVal }
        $game.HasLauncher = $true
    }

    $mapSections = @($ini.Keys | Where-Object { $_ -match '^mapping\.\d+$' } |
                     Sort-Object { [int]($_ -replace '^mapping\.', '') })
    foreach ($sec in $mapSections) {
        $n = [int]($sec -replace '^mapping\.', '')
        $kind = (Get-IniValue $ini $sec 'kind' 'dir').ToLowerInvariant()
        $local = Get-IniValue $ini $sec 'local' ''
        $store = Get-IniValue $ini $sec 'store' ''
        if (-not $store) { $store = 'map' + $n }
        if (-not $local) { continue }
        $game.Mappings += [pscustomobject]@{
            Id       = $n
            Kind     = $kind
            Local    = $local
            Store    = $store
            Optional = Convert-ToBool (Get-IniValue $ini $sec 'optional' '0')
            Mode     = (Get-IniValue $ini $sec 'mode' '').ToLowerInvariant()
            Merge    = (Get-IniValue $ini $sec 'merge' 'none').ToLowerInvariant()
        }
    }

    $regSections = @($ini.Keys | Where-Object { $_ -match '^registry\.\d+$' } |
                      Sort-Object { [int]($_ -replace '^registry\.', '') })
    foreach ($sec in $regSections) {
        $n = [int]($sec -replace '^registry\.', '')
        $key = Get-IniValue $ini $sec 'key' ''
        if (-not $key) { continue }
        $name = Get-IniValue $ini $sec 'name' ''
        if (-not $name) { $name = 'reg' + $n }
        $game.RegistryMappings += [pscustomobject]@{
            Id   = $n
            Name = $name
            Key  = $key
        }
    }

    return $game
}

function Get-AllGames {
    $gamesDir = Join-Path $global:Root 'Games'
    $list = @()
    $seen = @{}
    if (Test-Path -LiteralPath $gamesDir) {
        foreach ($d in (Get-ChildItem -LiteralPath $gamesDir -Directory -ErrorAction SilentlyContinue |
                        Sort-Object Name)) {
            $list += Read-GameProfile -Id $d.Name -GameDir $d.FullName
            $seen[$d.Name] = $true
        }
    }

    # 允许游戏放在 U 盘的其他位置：profile 里带 [game] dir= 的也列出来
    $profilesDir = Join-Path $global:Root 'Launcher\profiles'
    if (Test-Path -LiteralPath $profilesDir) {
        foreach ($f in (Get-ChildItem -LiteralPath $profilesDir -Filter '*.ini' -File -ErrorAction SilentlyContinue |
                        Sort-Object Name)) {
            $id = [IO.Path]::GetFileNameWithoutExtension($f.Name)
            if ($seen.ContainsKey($id)) { continue }
            $ini = Read-Ini $f.FullName
            $dv = Get-IniValue $ini 'game' 'dir' ''
            if (-not $dv) { continue }
            if ([IO.Path]::IsPathRooted($dv)) { $dirPath = $dv }
            else { $dirPath = Join-Path $global:Root $dv }
            if (Test-Path -LiteralPath $dirPath) {
                $list += Read-GameProfile -Id $id -GameDir $dirPath
                $seen[$id] = $true
            }
        }
    }
    return $list
}

function Get-GameById {
    param([string]$Key)
    $games = Get-AllGames
    $hit = $games | Where-Object {
        $_.Id -eq $Key -or $_.Name -eq $Key -or
        $_.Id -like "*$Key*" -or $_.Name -like "*$Key*"
    } | Select-Object -First 1
    return $hit
}

function Get-MappingStorePath {
    param($Game, $Map)
    return (Join-Path (Join-Path $global:Root ('Data\' + $Game.Id)) $Map.Store)
}

function Get-ScanLists {
    param([string]$Root = $global:Root)
    $result = @{ Exclude = @(); SkipDirs = @(); Include = @() }
    $path = Join-Path $Root 'Launcher\scan-lists.ini'
    if (-not (Test-Path -LiteralPath $path)) { return $result }
    $section = ''
    foreach ($line in [IO.File]::ReadAllLines($path)) {
        $s = $line.Trim()
        if (-not $s) { continue }
        if ($s.StartsWith(';') -or $s.StartsWith('#')) { continue }
        if ($s -match '^\[(.+)\]$') { $section = $matches[1].ToLowerInvariant(); continue }
        if ($section -eq 'exclude') { $result.Exclude += $s }
        elseif ($section -eq 'skip_dirs') { $result.SkipDirs += $s.ToLowerInvariant() }
        elseif ($section -eq 'include') { $result.Include += $s }
    }
    return $result
}