# Launch.ps1 - 启动游戏、处理映射、等待进程（Job Object 进程树）、退出后回写

function Resolve-WaitMode {
    param([string]$Mode)
    if (-not $Mode) { return 'process' }
    $m = $Mode.ToLowerInvariant()
    if ($m -in @('process', 'tree', 'none')) { return $m }
    if ($m -like 'name:*' -and $m.Substring(5).Trim()) { return $m }
    Write-Log ("未知 wait 策略 '{0}'，按 process 处理" -f $Mode) 'WARN'
    return 'process'
}

function Initialize-JobApi {
    if ('PglJob' -as [type]) { return }
    $nativeDll = Join-Path $global:Root 'Launcher\cache\PglNative.dll'
    if (Test-Path -LiteralPath $nativeDll) {
        try { Add-Type -Path $nativeDll } catch { }
        if ('PglJob' -as [type]) { return }
    }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class PglJob {
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern IntPtr CreateJobObject(IntPtr lpJobAttributes, string lpName);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool AssignProcessToJobObject(IntPtr hJob, IntPtr hProcess);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool QueryInformationJobObject(IntPtr hJob, int infoClass, IntPtr lpInfo, int cbInfo, IntPtr lpReturnLength);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool CloseHandle(IntPtr hObject);

    [StructLayout(LayoutKind.Sequential)]
    struct BASIC {
        public long TotalUserTime;
        public long TotalKernelTime;
        public long ThisPeriodTotalUserTime;
        public long ThisPeriodTotalKernelTime;
        public uint TotalPageFaultCount;
        public uint TotalProcesses;
        public uint ActiveProcesses;
        public uint TotalTerminatedProcesses;
    }

    public static IntPtr Create() { return CreateJobObject(IntPtr.Zero, null); }

    public static bool Assign(IntPtr job, IntPtr process) { return AssignProcessToJobObject(job, process); }

    public static int Active(IntPtr job) {
        int len = Marshal.SizeOf(typeof(BASIC));
        IntPtr buf = Marshal.AllocHGlobal(len);
        try {
            if (!QueryInformationJobObject(job, 1, buf, len, IntPtr.Zero)) { return -1; }
            BASIC b = (BASIC)Marshal.PtrToStructure(buf, typeof(BASIC));
            return (int)b.ActiveProcesses;
        } finally {
            Marshal.FreeHGlobal(buf);
        }
    }

    public static void Close(IntPtr job) { if (job != IntPtr.Zero) { CloseHandle(job); } }
}
'@
}

function New-GameJob {
    param([Diagnostics.Process]$Proc)
    try {
        Initialize-JobApi
        $job = [PglJob]::Create()
        if ($job -eq [IntPtr]::Zero) { return [IntPtr]::Zero }
        if (-not [PglJob]::Assign($job, $Proc.Handle)) {
            [PglJob]::Close($job)
            return [IntPtr]::Zero
        }
        return $job
    } catch {
        Write-Log ("进程树跟踪不可用，退回轮询：" + $_.Exception.Message) 'WARN'
        return [IntPtr]::Zero
    }
}

function Test-ProcAlive {
    param([int]$ProcessId)
    try {
        $null = Get-Process -Id $ProcessId -ErrorAction Stop
        return $true
    } catch { return $false }
}

function Wait-ProcessTreeEnd {
    param([IntPtr]$Job, [int]$StartPid, [string]$TargetName)

    $baseName = $null
    if ($TargetName) { $baseName = ($TargetName -replace '\.exe$', '') }

    if ($Job -ne [IntPtr]::Zero) {
        $zeroStreak = 0
        $sawTarget = $false
        $startAt = Get-Date
        while ($true) {
            if ($baseName -and -not $sawTarget) {
                $hit = @(Get-Process -Name $baseName -ErrorAction SilentlyContinue)
                if ($hit.Count -gt 0) {
                    $sawTarget = $true
                    Write-Log ("检测到游戏主进程: {0} (PID {1})" -f $hit[0].ProcessName, $hit[0].Id) 'OK'
                }
            }

            $n = [PglJob]::Active($Job)
            if ($n -le 0) {
                $zeroStreak++
                if ($zeroStreak -ge 2) {
                    if ($baseName -and -not $sawTarget) {
                        Write-Log ("启动器已退出，但没等到主进程 {0}" -f $baseName) 'WARN'
                    }
                    return
                }
            } else {
                $zeroStreak = 0
            }

            if ($baseName -and -not $sawTarget -and ((Get-Date) - $startAt).TotalSeconds -gt 120) {
                Write-Log ("等了 120 秒仍没看到 {0}，放弃等待" -f $baseName) 'WARN'
                return
            }
            Start-Sleep -Milliseconds 400
        }
    }

    # 兜底：没有 Job 时，先用一次 WMI 全表找后代，再用 Get-Process 轮询
    if ($baseName) {
        $deadline = (Get-Date).AddSeconds(120)
        while ($true) {
            $hit = @(Get-Process -Name $baseName -ErrorAction SilentlyContinue)
            if ($hit.Count -gt 0) {
                Write-Log ("检测到游戏主进程: {0} (PID {1})" -f $hit[0].ProcessName, $hit[0].Id) 'OK'
                break
            }
            if ((Get-Date) -gt $deadline) {
                Write-Log ("等了 120 秒仍没看到 {0}，放弃等待" -f $baseName) 'WARN'
                return
            }
            Start-Sleep -Milliseconds 400
        }
        $pids = @(Get-Process -Name $baseName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)
        $emptyStreak = 0
        while ($true) {
            $alive = @($pids | Where-Object { Test-ProcAlive ([int]$_) })
            if ($alive.Count -eq 0) {
                $emptyStreak++
                if ($emptyStreak -ge 2) { return }
            } else { $emptyStreak = 0 }
            Start-Sleep -Milliseconds 400
        }
    }

    $known = New-Object 'System.Collections.Generic.HashSet[int]'
    [void]$known.Add($StartPid)
    $table = @(Get-CimInstance Win32_Process -Property ProcessId, ParentProcessId -ErrorAction SilentlyContinue)
    $changed = $true
    while ($changed) {
        $changed = $false
        foreach ($p in $table) {
            if ($known.Contains([int]$p.ParentProcessId) -and -not $known.Contains([int]$p.ProcessId)) {
                [void]$known.Add([int]$p.ProcessId)
                $changed = $true
            }
        }
    }
    $emptyStreak = 0
    while ($true) {
        $alive = @($known | Where-Object { Test-ProcAlive ([int]$_) })
        if ($alive.Count -eq 0) {
            $emptyStreak++
            if ($emptyStreak -ge 2) { return }
        } else { $emptyStreak = 0 }
        Start-Sleep -Milliseconds 400
    }
}

function Start-Game {
    param($Game, [string]$LaunchMode = 'auto')

    $LaunchMode = $LaunchMode.ToLowerInvariant()
    if ($LaunchMode -notin @('auto', 'launcher', 'direct')) { $LaunchMode = 'auto' }
    if ($LaunchMode -eq 'launcher') { $useLauncher = $true }
    elseif ($LaunchMode -eq 'direct') { $useLauncher = $false }
    else { $useLauncher = [bool]$Game.HasLauncher }
    if ($useLauncher -and -not $Game.HasLauncher) {
        throw '这个游戏没有配置启动器进程。'
    }

    $targetExe = if ($useLauncher) { $Game.Launcher } else { $Game.Exe }
    $targetArgs = if ($useLauncher) { $Game.LauncherArgs } else { $Game.Args }
    $launchLabel = if ($useLauncher) { '启动器' } else { '游戏' }
    $targetWorkDir = if ($useLauncher) { Split-Path -Parent $Game.Launcher } else { $Game.WorkDir }

    Write-Log ("=== 启动 {0} ({1})，方式：{2} ===" -f $Game.Name, $Game.Id, $launchLabel) 'OK'

    if (-not $targetExe -or -not (Test-Path -LiteralPath $targetExe)) {
        $shown = if ($targetExe) { $targetExe } else { $Game.Dir }
        throw ("找不到{0}程序：{1}" -f $launchLabel, $shown)
    }
    if (-not (Test-UsbWritable $global:Root)) {
        throw 'U 盘不可写（只读开关或权限问题），已停止启动。'
    }

    if (@($Game.RegistryMappings).Count -gt 0) {
        Import-GameRegistry $Game
    }

    $waitMode = if ($useLauncher) { 'tree' } else { Resolve-WaitMode $Game.Wait }

    $modes = @{}
    foreach ($m in $Game.Mappings) {
        if ($m.Kind -eq 'dir') {
            $store = Get-MappingStorePath $Game $m
            New-StoreSnapshot $Game $store
            $modes[$m.Id] = Invoke-DirMapping $Game $m
        } elseif ($m.Kind -eq 'file') {
            $local = Expand-Vars $m.Local $Game
            $store = Get-MappingStorePath $Game $m
            Sync-FileIn $store $local
            $modes[$m.Id] = 'file'
        } else {
            Write-Log ("暂不支持的映射类型：{0}" -f $m.Kind) 'WARN'
        }
    }

    $hasCopy = @($modes.Values | Where-Object { $_ -eq 'copy' }).Count -gt 0
    if ($hasCopy -and $waitMode -in @('process', 'none')) {
        Write-Log ("复制模式必须等游戏真正结束，wait 已从 {0} 改为 tree" -f $waitMode) 'WARN'
        $waitMode = 'tree'
    }

    Write-Log ("启动{0}进程: {1} {2}" -f $launchLabel, $targetExe, $targetArgs)

    if ($waitMode -eq 'tree' -or $waitMode -like 'name:*') {
        try { Initialize-JobApi } catch { Write-Log ("Job API 初始化失败: " + $_.Exception.Message) 'WARN' }
    }

    $spArgs = @{
        FilePath         = $targetExe
        WorkingDirectory = $targetWorkDir
        PassThru         = $true
    }
    if ($targetArgs) { $spArgs['ArgumentList'] = $targetArgs }
    if ($Game.RunAs) { $spArgs['Verb'] = 'RunAs' }

    $proc = Start-Process @spArgs
    $job = [IntPtr]::Zero

    try {
        if ($waitMode -eq 'process') {
            Write-Log ("进程 PID={0}，等待游戏退出..." -f $proc.Id)
            $proc.WaitForExit()
        } elseif ($waitMode -ne 'none') {
            $job = New-GameJob -Proc $proc
            $target = $null
            if ($waitMode -like 'name:*') { $target = $waitMode.Substring(5).Trim() }
            Write-Log ("进程 PID={0}，等待策略 {1}（Job={2}）..." -f $proc.Id, $waitMode, ($job -ne [IntPtr]::Zero))
            Wait-ProcessTreeEnd -Job $job -StartPid $proc.Id -TargetName $target
        }
    } finally {
        if ($job -ne [IntPtr]::Zero) { [PglJob]::Close($job) }
    }

    Write-Log '游戏已退出。' 'OK'

    if (@($Game.RegistryMappings).Count -gt 0) {
        Export-GameRegistry $Game
    }

    foreach ($m in $Game.Mappings) {
        if ($m.Kind -eq 'dir' -and $modes[$m.Id] -eq 'copy') {
            $store = Get-MappingStorePath $Game $m
            $local = Expand-Vars $m.Local $Game
            Sync-DirOut $Game $store $local
        } elseif ($m.Kind -eq 'file') {
            $store = Get-MappingStorePath $Game $m
            $local = Expand-Vars $m.Local $Game
            Sync-FileOut $store $local
        }
    }

    $modeSummary = if ($hasCopy) { 'copy' } else { 'link' }
    Set-GameLastRun $Game.Id $modeSummary
    Write-Log ("=== 结束 {0} ===" -f $Game.Name) 'OK'
}
