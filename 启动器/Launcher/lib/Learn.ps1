# Learn.ps1 - 学习模式：拍快照、对比差异、按目录打分、写回 profile
# 思路：启动前拍一次全盘（常用存档根）文件表，玩完再拍一次，diff 出新增/变大的文件，
#       按目录聚合打分，把候选目录给用户勾选，确认后写成 [mapping.N]。

$script:LearnSaveExt = @(
    '.sav', '.save', '.savegame', '.slot', '.profile', '.progress',
    '.usr', '.user', '.player', '.account', '.checkpoint', '.ros', '.rw'
)
$script:LearnNameHit = '(save|profile|progress|userdata|player|account|slot|checkpoint|settings|options|config|game)'
$script:LearnDirHit = '(save|saves|savegame|profile|userdata|progress|player|account)'

function Get-LearnRoots {
    param($Game)
    $r = @()
    $r += [pscustomobject]@{ Path = $env:APPDATA; Var = '%APPDATA%'; Label = 'APPDATA'; Depth = 4 }
    $r += [pscustomobject]@{ Path = $env:LOCALAPPDATA; Var = '%LOCALAPPDATA%'; Label = 'LOCALAPPDATA'; Depth = 4 }
    $r += [pscustomobject]@{ Path = (Join-Path $env:USERPROFILE 'AppData\LocalLow'); Var = '%LOCALLOW%'; Label = 'LocalLow'; Depth = 3 }
    $r += [pscustomobject]@{ Path = $env:ProgramData; Var = '%ProgramData%'; Label = 'ProgramData'; Depth = 3 }
    $r += [pscustomobject]@{ Path = [Environment]::GetFolderPath('MyDocuments'); Var = '%DOCUMENTS%'; Label = 'Documents'; Depth = 3 }
    $r += [pscustomobject]@{ Path = (Join-Path $env:USERPROFILE 'Saved Games'); Var = '%SAVEDGAMES%'; Label = 'SavedGames'; Depth = 3 }
    if ($Game -and $Game.Dir) {
        $r += [pscustomobject]@{ Path = $Game.Dir; Var = '%GAMEDIR%'; Label = 'GAMEDIR'; Depth = 4 }
    }
    return @($r | Where-Object { $_.Path -and (Test-Path -LiteralPath $_.Path) })
}

function Get-LearnSkipNames {
    $names = @{}
    $base = @(
        'temp', 'tmp', 'cache', 'code cache', 'gpucache', 'shadercache', 'shader_cache',
        'shader cache', 'crashpad', 'crashdumps', 'logs', 'log', 'node_modules', '.git',
        '.svn', 'microsoft', 'packages', 'windows', 'winsxs', 'installer', 'package cache',
        'nuget', 'pip', 'npm-cache', 'pnpm-store', 'yarn', 'd3dscache', 'nvidia', 'amd',
        'intel', 'wer', 'google', 'mozilla', 'bravesoftware', 'opera software', 'chromium',
        'microsoftedge', 'discord', 'slack', 'teams', 'spotify', 'steam', 'steamapps'
    )
    foreach ($n in $base) { $names[$n.ToLowerInvariant()] = $true }
    if ($global:Config -and $global:Config.ExcludeDirs) {
        foreach ($n in $global:Config.ExcludeDirs) {
            if ($n) { $names[$n.Trim().ToLowerInvariant()] = $true }
        }
    }
    return $names
}

function Get-LearnFileTable {
    param([string]$Root, $SkipNames, [int]$MaxEntries, [datetime]$Deadline, [int]$MaxDepth = 4)
    $map = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::OrdinalIgnoreCase)
    $stack = New-Object 'System.Collections.Generic.Stack[object]'
    $stack.Push(@($Root, 0))
    $count = 0
    $truncated = $false
    while ($stack.Count -gt 0) {
        if ($count -ge $MaxEntries -or (Get-Date) -gt $Deadline) { $truncated = $true; break }
        $item = $stack.Pop()
        $dir = [string]$item[0]
        $depth = [int]$item[1]
        try {
            $entries = @((New-Object IO.DirectoryInfo $dir).EnumerateFileSystemInfos())
        } catch { continue }
        foreach ($e in $entries) {
            $count++
            if ($count -ge $MaxEntries) { $truncated = $true; break }
            $attr = $e.Attributes
            if (($attr -band [IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
            if (($attr -band [IO.FileAttributes]::Directory) -ne 0) {
                if ($depth -ge $MaxDepth) { continue }
                if ($SkipNames.ContainsKey($e.Name.ToLowerInvariant())) { continue }
                $stack.Push(@($e.FullName, ($depth + 1)))
            } else {
                $fi = [IO.FileInfo]$e
                if ($fi.Length -gt 64MB) { continue }
                $map[$e.FullName] = @([long]$fi.Length, [long]$fi.LastWriteTimeUtc.Ticks)
            }
        }
    }
    return [pscustomobject]@{ Files = $map; Truncated = $truncated; Count = $count }
}

function New-LearnSnapshot {
    param($Game, [string]$Phase)

    $dir = Join-Path $global:Root ('Launcher\state\learn\' + $Game.Id)
    Ensure-Dir $dir
    $path = Join-Path $dir ($Phase + '.tsv')

    $roots = @(Get-LearnRoots $Game)
    $skip = Get-LearnSkipNames
    $all = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::OrdinalIgnoreCase)
    $budget = 200000
    $deadline = (Get-Date).AddSeconds(30)
    $truncated = $false

    foreach ($r in $roots) {
        if ($budget -le 0) { $truncated = $true; break }
        $t = Get-LearnFileTable -Root $r.Path -SkipNames $skip -MaxEntries $budget -Deadline $deadline -MaxDepth $r.Depth
        if ($t.Truncated) { $truncated = $true }
        $budget -= $t.Count
        foreach ($k in $t.Files.Keys) {
            if (-not $all.ContainsKey($k)) { $all[$k] = $t.Files[$k] }
        }
    }

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("path`tsize`tmtime")
    foreach ($k in $all.Keys) {
        $v = $all[$k]
        [void]$sb.AppendLine(("{0}`t{1}`t{2}" -f $k, $v[0], $v[1]))
    }
    [IO.File]::WriteAllText($path, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
    Write-Log ("学习快照[{0}]: {1} 个文件{2}" -f $Phase, $all.Count, $(if ($truncated) { '（已到上限，部分目录未扫）' } else { '' }))
    return $path
}

function Read-LearnSnapshot {
    param([string]$Path)
    $map = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::OrdinalIgnoreCase)
    if (-not (Test-Path -LiteralPath $Path)) { return $map }
    foreach ($line in [IO.File]::ReadLines($Path)) {
        if (-not $line -or $line.StartsWith("path`t")) { continue }
        $p = $line.Split([char]9)
        if ($p.Count -lt 3) { continue }
        $map[$p[0]] = @([long]$p[1], [long]$p[2])
    }
    return $map
}

function Get-LearnVarPath {
    param([string]$Path, $Roots)
    $best = $null
    foreach ($r in $Roots) {
        $prefix = $r.Path.TrimEnd('\') + '\'
        if ($Path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
            if (-not $best -or $r.Path.Length -gt $best.Path.Length) { $best = $r }
        }
    }
    if (-not $best) { return $Path }
    return $best.Var + '\' + $Path.Substring($best.Path.TrimEnd('\').Length + 1)
}

function Get-LearnFileScore {
    param([string]$Path, [long]$Size, $Game)

    $name = [IO.Path]::GetFileName($Path)
    $ext = [IO.Path]::GetExtension($name).ToLowerInvariant()
    $parent = [IO.Path]::GetFileName([IO.Path]::GetDirectoryName($Path))
    $score = 0

    if ($script:LearnSaveExt -contains $ext) { $score += 25 }
    if ($ext -in @('.sav', '.save', '.savegame', '.slot', '.profile', '.progress')) { $score += 10 }
    if ($name -match $script:LearnNameHit) { $score += 12 }
    if ($parent -match $script:LearnDirHit) { $score += 18 }
    if ($Game -and $Game.Name -and $Path.IndexOf($Game.Name, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $score += 15 }
    if ($Game -and $Game.Id -and $Path.IndexOf($Game.Id, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $score += 10 }
    if ($Path -match '\\AppData\\LocalLow\\') { $score += 20 }
    if ($ext -in @('.json', '.dat', '.xml', '.cfg', '.ini')) { $score += 6 }
    if ($Size -gt 0 -and $Size -lt 20MB) { $score += 3 }
    if ($Size -ge 64MB) { $score -= 10 }
    if ($ext -in @('.log', '.tmp', '.dmp', '.etl', '.pdb', '.obj')) { $score -= 40 }
    return $score
}

function Compare-LearnSnapshots {
    param([string]$BeforePath, [string]$AfterPath, $Game)

    $before = Read-LearnSnapshot $BeforePath
    $after = Read-LearnSnapshot $AfterPath
    $roots = @(Get-LearnRoots $Game)

    $dirs = @{}
    foreach ($p in $after.Keys) {
        $a = $after[$p]
        $isNew = -not $before.ContainsKey($p)
        $changed = $isNew
        if (-not $isNew) {
            $b = $before[$p]
            if ($b[0] -ne $a[0] -or $b[1] -ne $a[1]) { $changed = $true }
        }
        if (-not $changed) { continue }
        $ext = [IO.Path]::GetExtension($p).ToLowerInvariant()
        if ($ext -in @('.log', '.tmp', '.dmp', '.etl', '.pdb', '.obj')) { continue }
        $dir = [IO.Path]::GetDirectoryName($p)
        if (-not $dirs.ContainsKey($dir)) { $dirs[$dir] = New-Object System.Collections.ArrayList }
        [void]$dirs[$dir].Add([pscustomobject]@{
                Path  = $p
                Size  = [long]$a[0]
                Score = (Get-LearnFileScore $p ([long]$a[0]) $Game)
                New   = $isNew
            })
    }

    $candidates = @()
    foreach ($dir in $dirs.Keys) {
        $files = @($dirs[$dir])
        $scores = @($files | Sort-Object Score -Descending | Select-Object -First 5 | ForEach-Object { $_.Score })
        $sum = 0
        foreach ($s in $scores) { $sum += $s }
        $sum += [int]([math]::Log($files.Count + 1, 2) * 2)
        $totalSize = ($files | Measure-Object -Property Size -Sum).Sum
        $localVar = Get-LearnVarPath $dir $roots
        $candidates += [pscustomobject]@{
            Kind     = 'dir'
            Dir      = $dir
            Local    = $localVar
            Score    = $sum
            Files    = $files.Count
            SizeMB   = [math]::Round(($totalSize / 1MB), 2)
            Sample   = (($files | Sort-Object Score -Descending | Select-Object -First 3 |
                        ForEach-Object { [IO.Path]::GetFileName($_.Path) }) -join ', ')
            Store    = $null
        }
    }
    return @($candidates | Sort-Object @{ Expression = 'Score'; Descending = $true }, @{ Expression = 'Files'; Descending = $true })
}

function New-LearnStoreName {
    param([string]$LocalVar)
    $s = $LocalVar
    $s = $s -replace '^%[A-Za-z]+%[\\/]*', ''
    if (-not $s) { $s = 'root' }
    $s = $s.ToLowerInvariant() -replace '[\\/]', '-'
    $s = $s -replace '[^a-z0-9\._\-]', ''
    $s = $s.Trim('-')
    if ($s.Length -gt 48) { $s = $s.Substring(0, 48) }
    if (-not $s) { $s = 'save' }
    return $s
}

function Save-LearnMappings {
    param($Game, [array]$Candidates)

    $ini = Read-Ini $Game.ProfilePath
    if (-not $ini.Contains('game')) { $ini['game'] = [ordered]@{} }
    if (-not (Get-IniValue $ini 'game' 'name')) { $ini['game']['name'] = $Game.Name }
    if (-not (Get-IniValue $ini 'game' 'exe')) {
        $exeLeaf = Split-Path -Leaf $Game.Exe
        if ($exeLeaf) { $ini['game']['exe'] = $exeLeaf }
    }

    $existingStores = @()
    $maxN = 0
    $maxReg = 0
    foreach ($sec in @($ini.Keys)) {
        if ($sec -match '^mapping\.(\d+)$') {
            $n = [int]$Matches[1]
            if ($n -gt $maxN) { $maxN = $n }
            $st = Get-IniValue $ini $sec 'store' ''
            if ($st) { $existingStores += $st }
        } elseif ($sec -match '^registry\.(\d+)$') {
            $n = [int]$Matches[1]
            if ($n -gt $maxReg) { $maxReg = $n }
            $nm = Get-IniValue $ini $sec 'name' ''
            if ($nm) { $existingStores += $nm }
        }
    }

    $count = 0
    foreach ($c in $Candidates) {
        if (-not $c.Local) { continue }
        $store = New-LearnStoreName $c.Local
        $base = $store
        $k = 2
        while ($existingStores -contains $store) {
            $store = $base + '-' + $k
            $k++
        }
        $existingStores += $store
        if ($c.Kind -eq 'registry') {
            $maxReg++
            $ini['registry.' + $maxReg] = [ordered]@{
                name = $store
                key  = $c.Local
            }
        } else {
            $maxN++
            $ini['mapping.' + $maxN] = [ordered]@{
                kind     = 'dir'
                local    = $c.Local
                store    = $store
                optional = '0'
                mode     = 'auto'
                merge    = 'none'
            }
        }
        $count++
    }

    Write-Ini $ini $Game.ProfilePath
    Write-Log ("学习完成：写入 {0} 条存档映射到 {1}" -f $count, $Game.ProfilePath) 'OK'
    return $count
}

# ---- 注册表学习（HKCU\Software，键级 LastWriteTime 对比） ----

function New-LearnRegSnapshot {
    param($Game, [string]$Phase)

    $dir = Join-Path $global:Root ('Launcher\state\learn\' + $Game.Id)
    Ensure-Dir $dir
    $path = Join-Path $dir ($Phase + '.reg.tsv')

    $skipTop = @('microsoft', 'classes', 'policies', 'registeredapplications', 'clients', 'appcontainer', 'sync', 'themes')
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("key`tlastwrite`tvalues")
    $stack = New-Object System.Collections.Stack
    $stack.Push(@('Software', 0))
    $deadline = (Get-Date).AddSeconds(12)
    $count = 0
    while ($stack.Count -gt 0 -and $count -lt 80000 -and (Get-Date) -lt $deadline) {
        $cur = $stack.Pop()
        $sub = [string]$cur[0]
        $depth = [int]$cur[1]
        $key = $null
        try { $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($sub) } catch { }
        if (-not $key) { continue }
        $ticks = [long]0
        try { $ticks = $key.LastWriteTime.ToFileTimeUtc() } catch { }
        $vc = 0
        try { $vc = $key.ValueCount } catch { }
        [void]$sb.AppendLine(("HKCU\{0}`t{1}`t{2}" -f $sub, $ticks, $vc))
        $count++
        if ($depth -lt 8) {
            $names = @()
            try { $names = $key.GetSubKeyNames() } catch { }
            foreach ($n in $names) {
                if ($depth -eq 0 -and $skipTop -contains $n.ToLowerInvariant()) { continue }
                $stack.Push(@(($sub + '\' + $n), ($depth + 1)))
            }
        }
        $key.Close()
    }
    [IO.File]::WriteAllText($path, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
    Write-Log ("学习注册表快照[{0}]: {1} 个键" -f $Phase, $count)
    return $path
}

function Read-LearnRegSnapshot {
    param([string]$Path)
    $map = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::OrdinalIgnoreCase)
    if (-not (Test-Path -LiteralPath $Path)) { return $map }
    foreach ($line in [IO.File]::ReadLines($Path)) {
        if (-not $line -or $line.StartsWith("key`t")) { continue }
        $p = $line.Split([char]9)
        if ($p.Count -lt 3) { continue }
        $map[$p[0]] = @([long]$p[1], [int]$p[2])
    }
    return $map
}

function Get-LearnRegScore {
    param([string]$Key, $Game)
    $leaf = @($Key.Split('\'))[-1]
    $score = 0
    if ($Game -and $Game.Name -and $Key.IndexOf($Game.Name, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $score += 40 }
    if ($Game -and $Game.Id -and $Key.IndexOf($Game.Id, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $score += 20 }
    if ($leaf -match '(?i)(save|profile|player|progress|slot|user|settings|config)') { $score += 18 }
    if (($Key.Split('\')).Count -le 4) { $score += 5 }
    if ($Key -match '(?i)(uninstall|update|installer|crash|log)') { $score -= 50 }
    return $score
}

function Compare-LearnRegSnapshots {
    param([string]$BeforePath, [string]$AfterPath, $Game)

    $before = Read-LearnRegSnapshot $BeforePath
    $after = Read-LearnRegSnapshot $AfterPath
    $changed = @()
    foreach ($k in $after.Keys) {
        $a = $after[$k]
        $isNew = -not $before.ContainsKey($k)
        if (-not $isNew) {
            $b = $before[$k]
            if ($b[0] -eq $a[0] -and $b[1] -eq $a[1]) { continue }
        }
        $changed += [pscustomobject]@{
            Key    = $k
            Depth  = @($k.Split('\')).Count
            Score  = (Get-LearnRegScore $k $Game)
            Values = [int]$a[1]
            New    = $isNew
        }
    }

    $kept = @()
    foreach ($c in ($changed | Sort-Object @{ Expression = 'Score'; Descending = $true }, @{ Expression = 'Depth'; Descending = $false })) {
        $covered = $false
        foreach ($p in $kept) {
            if ($c.Key.StartsWith($p.Key + '\', [StringComparison]::OrdinalIgnoreCase)) { $covered = $true; break }
        }
        if (-not $covered) { $kept += $c }
    }

    $candidates = @()
    foreach ($c in $kept) {
        $candidates += [pscustomobject]@{
            Kind   = 'registry'
            Dir    = $c.Key
            Local  = $c.Key
            Score  = $c.Score
            Files  = $c.Values
            SizeMB = 0
            Sample = ''
            Store  = $null
        }
    }
    return @($candidates)
}