#requires -Version 5.1
<#
U 盘游戏启动器 · 环境验证脚本

在真实 U 盘上验证启动器依赖的关键能力：
  1. 目录联接（junction）指向 U 盘目录，读写是否正常
  2. 把本机真实存档目录替换成联接（模拟 PvZ 的 ProgramData 场景）
  3. 双跳链路：存档目录 -> 挂载点 -> U 盘（换盘符时只重建第二跳）
  4. 非管理员能否在 C:\ProgramData 下建目录、替换目录
  5. icacls 授权、fsutil 解析、robocopy 接管与 /XJ 行为
  6. 只读文件检测

只在自己创建的临时目录里操作，默认结束自动清理；-Keep 保留现场。
用法：
  powershell -NoProfile -ExecutionPolicy Bypass -File 环境验证.ps1 -UsbRoot F:\
#>
[CmdletBinding()]
param(
    [string]$UsbRoot = '',
    [string]$ReportPath = '',
    [switch]$Keep
)

$ErrorActionPreference = 'Stop'
$script:Results = New-Object System.Collections.ArrayList
$script:Junctions = New-Object System.Collections.ArrayList
$script:CreatedDirs = New-Object System.Collections.ArrayList

function Add-Result {
    param([string]$Id, [string]$Name, [bool]$Ok, [string]$Detail = '')
    $tag = if ($Ok) { 'PASS' } else { 'FAIL' }
    $color = if ($Ok) { 'Green' } else { 'Red' }
    Write-Host ("[{0}] {1} {2}" -f $tag, $Id, $Name) -ForegroundColor $color
    if ($Detail) { Write-Host ("       " + $Detail) -ForegroundColor DarkGray }
    [void]$script:Results.Add([pscustomobject]@{ Id = $Id; Name = $Name; Ok = $Ok; Detail = $Detail })
}

function New-TestDir {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        [void]$script:CreatedDirs.Add($Path)
    }
    return $Path
}

function New-Junction {
    param([string]$Link, [string]$Target)
    if (Test-Path -LiteralPath $Link) { throw "联接已存在: $Link" }
    New-Item -ItemType Junction -Path $Link -Target $Target -ErrorAction Stop | Out-Null
    [void]$script:Junctions.Add($Link)
    return $Link
}

function Remove-Junction {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    try { [IO.Directory]::Delete($Path) }
    catch { & cmd.exe /c ('rmdir "{0}"' -f $Path) 2>$null | Out-Null }
}

function Test-Junction {
    param([string]$Path)
    try {
        $a = [IO.File]::GetAttributes($Path)
        return (($a -band [IO.FileAttributes]::ReparsePoint) -ne 0)
    } catch { return $false }
}

function Get-JunctionTarget {
    param([string]$Path)
    # fsutil 的标签随系统语言变化，直接抓 \??\ 开头的替换名，避免依赖英文标签
    $lines = & fsutil.exe reparsepoint query "$Path" 2>$null
    foreach ($l in $lines) {
        if ($l -match '\\\?\?\\(.+)$') { return $Matches[1].Trim() }
    }
    return $null
}

function Find-UsbVolume {
    # 优先可移动卷；其次 USB 总线上的固定卷（USB SSD 常见）
    $vols = Get-CimInstance Win32_LogicalDisk
    foreach ($v in $vols) {
        if ($v.DriveType -eq 2) { return ($v.DeviceID + '\') }
    }
    $disks = Get-CimInstance Win32_DiskDrive | Where-Object { $_.InterfaceType -eq 'USB' }
    foreach ($d in $disks) {
        foreach ($p in (Get-CimAssociatedInstance -InputObject $d -ResultClassName Win32_DiskPartition)) {
            foreach ($l in (Get-CimAssociatedInstance -InputObject $p -ResultClassName Win32_LogicalDisk)) {
                return ($l.DeviceID + '\')
            }
        }
    }
    return $null
}

function Invoke-Robocopy {
    param([string]$Source, [string]$Dest, [string[]]$Extra)
    $argv = @($Source, $Dest, '/E', '/NFL', '/NDL', '/NJH', '/NJS', '/R:1', '/W:1') + $Extra
    $out = & robocopy.exe @argv 2>&1
    return @{ Code = $LASTEXITCODE; Output = ($out -join "`n") }
}

# ---------------------------------------------------------------- 环境信息
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
$os = (Get-CimInstance Win32_OperatingSystem)
$osName = $os.Caption + ' ' + $os.Version
$psv = $PSVersionTable.PSVersion.ToString()

Write-Host ''
Write-Host '=== U 盘游戏启动器 · 环境验证 ===' -ForegroundColor Cyan

if (-not $UsbRoot) { $UsbRoot = Find-UsbVolume }
if (-not $UsbRoot) { throw '没有找到 U 盘。请插上 U 盘，或用 -UsbRoot F:\ 指定盘符。' }
$UsbRoot = $UsbRoot.TrimEnd('\') + '\'
if (-not (Test-Path -LiteralPath $UsbRoot)) { throw "U 盘路径不存在: $UsbRoot" }

$driveLetter = $UsbRoot.Substring(0, 1)
$vol = Get-Volume -DriveLetter $driveLetter -ErrorAction SilentlyContinue
$fsType = if ($vol) { $vol.FileSystem } else { '未知' }
$freeMB = [math]::Round((Get-PSDrive -Name $driveLetter).Free / 1MB, 1)
$totalGB = if ($vol) { [math]::Round($vol.Size / 1GB, 1) } else { 0 }

Write-Host ("U 盘: {0}  文件系统: {1}  容量: {2} GB  空闲: {3} MB" -f $UsbRoot, $fsType, $totalGB, $freeMB)
Write-Host ("系统: {0}  PowerShell {1}  管理员: {2}" -f $osName, $psv, $isAdmin)

if ($freeMB -lt 20) { throw "U 盘空闲空间不足 20 MB（当前 $freeMB MB）" }
if ($driveLetter -eq $env:SystemDrive.Substring(0, 1)) { throw '拒绝在系统盘上做验证' }

$usbTest = Join-Path $UsbRoot ("._pgl_verify_" + $PID)
$pdRoot = "C:\ProgramData\PGL_verify_$PID"
$tempRoot = Join-Path $env:TEMP ("pgl_verify_" + $PID)
$localRoot = Join-Path $env:LOCALAPPDATA ("PGL_verify_" + $PID)

New-TestDir $usbTest | Out-Null
New-TestDir $tempRoot | Out-Null

Add-Result 'T01' '环境信息' $true ("{0}; PS {1}; 管理员={2}; U盘={3} {4} {5}GB 空闲{6}MB" -f $osName, $psv, $isAdmin, $UsbRoot, $fsType, $totalGB, $freeMB)

# ---------------------------------------------------------------- T02 U 盘可写
try {
    Set-Content -LiteralPath (Join-Path $usbTest 'hello.txt') -Value 'hello 你好' -Encoding UTF8
    $ok = Test-Path -LiteralPath (Join-Path $usbTest 'hello.txt')
    Add-Result 'T02' 'U 盘可写' $ok
} catch {
    Add-Result 'T02' 'U 盘可写' $false $_.Exception.Message
}

# ---------------------------------------------------------------- T03 联接指到 U 盘
try {
    $store = New-TestDir (Join-Path $usbTest 'store')
    $link = Join-Path $tempRoot 'link1'
    New-Junction $link $store | Out-Null
    $isJ = Test-Junction $link
    $tgt = Get-JunctionTarget $link
    Set-Content -LiteralPath (Join-Path $link 'through-link.txt') -Value 'via junction' -Encoding UTF8
    $seen = Test-Path -LiteralPath (Join-Path $store 'through-link.txt')
    Add-Result 'T03' '目录联接指向 U 盘（创建/识别/写入）' ($isJ -and $seen -and $tgt) ("目标解析: " + $tgt)
} catch {
    Add-Result 'T03' '目录联接指向 U 盘（创建/识别/写入）' $false $_.Exception.Message
}

# ---------------------------------------------------------------- T04 联接读回
try {
    $store = Join-Path $usbTest 'store'
    $link = Join-Path $tempRoot 'link1'
    $txt = (Get-Content -LiteralPath (Join-Path $store 'through-link.txt') -Raw).Trim()
    $viaLink = (Get-Content -LiteralPath (Join-Path $link 'through-link.txt') -Raw).Trim()
    Add-Result 'T04' '联接读回一致' (($txt -eq 'via junction') -and ($viaLink -eq 'via junction')) ("直读=$viaLink")
} catch {
    Add-Result 'T04' '联接读回一致' $false $_.Exception.Message
}

# ---------------------------------------------------------------- T05 中文+空格路径
try {
    $storeCn = New-TestDir (Join-Path $usbTest '存档 测试')
    $linkCn = Join-Path $tempRoot '链接 测试'
    New-Junction $linkCn $storeCn | Out-Null
    Set-Content -LiteralPath (Join-Path $linkCn '进度 1.dat') -Value 'save-data' -Encoding UTF8
    $ok = Test-Path -LiteralPath (Join-Path $storeCn '进度 1.dat')
    Add-Result 'T05' '中文与空格路径' $ok
} catch {
    Add-Result 'T05' '中文与空格路径' $false $_.Exception.Message
}

# ---------------------------------------------------------------- T06 ProgramData 可建目录
$pdOk = $false
try {
    New-TestDir $pdRoot | Out-Null
    $pdOk = Test-Path -LiteralPath $pdRoot
    Add-Result 'T06' '非管理员可在 ProgramData 建目录' $pdOk $pdRoot
} catch {
    Add-Result 'T06' '非管理员可在 ProgramData 建目录' $false $_.Exception.Message
}

# ---------------------------------------------------------------- T07 替换真实目录为联接（PvZ 场景）
if ($pdOk) {
    try {
        $A = Join-Path $pdRoot 'PlantsVsZombies'
        New-TestDir $A | Out-Null
        New-TestDir (Join-Path $A 'userdata') | Out-Null
        Set-Content -LiteralPath (Join-Path $A 'userdata\save.dat') -Value 'old-save' -Encoding UTF8
        $store2 = New-TestDir (Join-Path $usbTest 'store2')
        Move-Item -LiteralPath (Join-Path $A 'userdata') -Destination (Join-Path $store2 'userdata')
        Remove-Item -LiteralPath $A -Force
        New-Junction $A $store2 | Out-Null
        $readable = Test-Path -LiteralPath (Join-Path $A 'userdata\save.dat')
        Set-Content -LiteralPath (Join-Path $A 'userdata\progress.dat') -Value 'new-progress' -Encoding UTF8
        $wrote = Test-Path -LiteralPath (Join-Path $store2 'userdata\progress.dat')
        Add-Result 'T07' '把真实存档目录替换为联接（非管理员）' ($readable -and $wrote) ("旧档可见=$readable 新档落U盘=$wrote")
    } catch {
        Add-Result 'T07' '把真实存档目录替换为联接（非管理员）' $false $_.Exception.Message
    }
} else {
    Add-Result 'T07' '把真实存档目录替换为联接（非管理员）' $false '跳过：ProgramData 不可写'
}

# ---------------------------------------------------------------- T08 双跳链路
if ($pdOk) {
    try {
        $store3 = New-TestDir (Join-Path $usbTest 'store3')
        $mntDir = New-TestDir (Join-Path $pdRoot 'mnt')
        $M = Join-Path $mntDir 'g1'
        New-Junction $M $store3 | Out-Null
        $A2 = Join-Path $pdRoot 'Game2'
        New-Junction $A2 $M | Out-Null
        Set-Content -LiteralPath (Join-Path $A2 'chain.txt') -Value 'chain' -Encoding UTF8
        $landed = Test-Path -LiteralPath (Join-Path $store3 'chain.txt')
        $back = (Get-Content -LiteralPath (Join-Path $A2 'chain.txt') -Raw).Trim()
        Add-Result 'T08' '双跳：存档目录 -> 挂载点 -> U 盘' ($landed -and ($back -eq 'chain')) ("U盘落盘=$landed 读回=$back")
    } catch {
        Add-Result 'T08' '双跳：存档目录 -> 挂载点 -> U 盘' $false $_.Exception.Message
    }
} else {
    Add-Result 'T08' '双跳：存档目录 -> 挂载点 -> U 盘' $false '跳过：ProgramData 不可写'
}

# ---------------------------------------------------------------- T09 重建第二跳（模拟换盘符）
if ($pdOk) {
    try {
        $store4 = New-TestDir (Join-Path $usbTest 'store4')
        Set-Content -LiteralPath (Join-Path $store4 'new.txt') -Value 'new-store' -Encoding UTF8
        $M = Join-Path $pdRoot 'mnt\g1'
        $A2 = Join-Path $pdRoot 'Game2'
        Remove-Junction $M
        New-Junction $M $store4 | Out-Null
        $seesNew = Test-Path -LiteralPath (Join-Path $A2 'new.txt')
        $oldGone = -not (Test-Path -LiteralPath (Join-Path $A2 'chain.txt'))
        $tgt = Get-JunctionTarget $A2
        $aStillM = $tgt -and ($tgt -like '*mnt\g1')
        Add-Result 'T09' '重建第二跳（模拟换盘符/换 U 盘）' ($seesNew -and $oldGone -and $aStillM) ("A 仍指向挂载点=$aStillM 新档可见=$seesNew")
    } catch {
        Add-Result 'T09' '重建第二跳（模拟换盘符/换 U 盘）' $false $_.Exception.Message
    }
} else {
    Add-Result 'T09' '重建第二跳（模拟换盘符/换 U 盘）' $false '跳过：ProgramData 不可写'
}

# ---------------------------------------------------------------- T10 拆联接不伤目标
if ($pdOk) {
    try {
        Remove-Junction (Join-Path $pdRoot 'Game2')
        Remove-Junction (Join-Path $pdRoot 'PlantsVsZombies')
        Remove-Junction (Join-Path $pdRoot 'mnt\g1')
        $ok1 = Test-Path -LiteralPath (Join-Path $usbTest 'store4\new.txt')
        $ok2 = Test-Path -LiteralPath (Join-Path $usbTest 'store2\userdata\save.dat')
        Add-Result 'T10' '拆联接不删除目标内容' ($ok1 -and $ok2)
    } catch {
        Add-Result 'T10' '拆联接不删除目标内容' $false $_.Exception.Message
    }
} else {
    Add-Result 'T10' '拆联接不删除目标内容' $false '跳过'
}

# ---------------------------------------------------------------- T11 icacls 授权
if ($pdOk) {
    try {
        $mnt = Join-Path $pdRoot 'mnt'
        $out = & icacls.exe "$mnt" /grant "*S-1-5-32-545:(OI)(CI)M" 2>&1
        $ok = ($LASTEXITCODE -eq 0)
        Add-Result 'T11' 'icacls 给 Users 组修改权限' $ok ("退出码=$LASTEXITCODE")
    } catch {
        Add-Result 'T11' 'icacls 给 Users 组修改权限' $false $_.Exception.Message
    }
} else {
    Add-Result 'T11' 'icacls 给 Users 组修改权限' $false '跳过'
}

# ---------------------------------------------------------------- T12 fsutil 解析
try {
    $store4 = Join-Path $usbTest 'store4'
    $pl = Join-Path $tempRoot 'parse-link'
    New-Junction $pl $store4 | Out-Null
    $tgt = Get-JunctionTarget $pl
    $ok = $tgt -and ($tgt -like '*store4')
    Add-Result 'T12' 'fsutil 解析联接目标' ([bool]$ok) ("解析到: " + $tgt)
    Remove-Junction $pl
} catch {
    Add-Result 'T12' 'fsutil 解析联接目标' $false $_.Exception.Message
}

# ---------------------------------------------------------------- T13 robocopy 接管（/E /MOVE）
try {
    $src = Join-Path $tempRoot 'adopt-src'
    New-TestDir (Join-Path $src 'sub') | Out-Null
    Set-Content -LiteralPath (Join-Path $src 'a.txt') -Value 'AAA' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $src 'sub\b.txt') -Value 'BBB' -Encoding UTF8
    $oldTime = (Get-Date).AddDays(-3)
    (Get-Item -LiteralPath (Join-Path $src 'a.txt')).LastWriteTime = $oldTime
    $dst = New-TestDir (Join-Path $usbTest 'adopt-dst')
    $r = Invoke-Robocopy $src $dst @('/MOVE')
    $moved = (-not (Test-Path -LiteralPath (Join-Path $src 'a.txt'))) -and (Test-Path -LiteralPath (Join-Path $dst 'sub\b.txt'))
    $mt = (Get-Item -LiteralPath (Join-Path $dst 'a.txt')).LastWriteTime
    $mtOk = [math]::Abs(($mt - $oldTime).TotalSeconds) -lt 5
    Add-Result 'T13' 'robocopy /E /MOVE 接管并保留时间' ($r.Code -lt 8 -and $moved -and $mtOk) ("退出码={0} 源已清空={1} 时间保留={2}" -f $r.Code, $moved, $mtOk)
} catch {
    Add-Result 'T13' 'robocopy /E /MOVE 接管并保留时间' $false $_.Exception.Message
}

# ---------------------------------------------------------------- T14 robocopy /XJ
try {
    $parent = Join-Path $tempRoot 'parent'
    New-TestDir $parent | Out-Null
    Set-Content -LiteralPath (Join-Path $parent 'normal.txt') -Value 'N' -Encoding UTF8
    $outside = New-TestDir (Join-Path $usbTest 'outside')
    Set-Content -LiteralPath (Join-Path $outside 'secret.txt') -Value 'S' -Encoding UTF8
    New-Junction (Join-Path $parent 'jump') $outside | Out-Null

    $dstXj = Join-Path $usbTest 'with-xj'
    $r1 = Invoke-Robocopy $parent $dstXj @('/XJ')
    $noFollow = -not (Test-Path -LiteralPath (Join-Path $dstXj 'jump\secret.txt'))
    $dstNo = Join-Path $usbTest 'no-xj'
    $r2 = Invoke-Robocopy $parent $dstNo @()
    $followed = Test-Path -LiteralPath (Join-Path $dstNo 'jump\secret.txt')
    Add-Result 'T14' 'robocopy /XJ 不跟随联接' ($noFollow -and $followed) ("/XJ 未跟随=$noFollow 默认跟随=$followed")
} catch {
    Add-Result 'T14' 'robocopy /XJ 不跟随联接' $false $_.Exception.Message
}

# ---------------------------------------------------------------- T15 只读文件检测
try {
    $ro = Join-Path $tempRoot 'readonly.txt'
    Set-Content -LiteralPath $ro -Value 'ro' -Encoding UTF8
    (Get-Item -LiteralPath $ro).IsReadOnly = $true
    $failed = $false
    try { [IO.File]::WriteAllText($ro, 'x') } catch { $failed = $true }
    (Get-Item -LiteralPath $ro).IsReadOnly = $false
    Add-Result 'T15' '只读文件写入被拒（可检测）' $failed
} catch {
    Add-Result 'T15' '只读文件写入被拒（可检测）' $false $_.Exception.Message
}

# ---------------------------------------------------------------- 清理
function Invoke-Cleanup {
    foreach ($j in @($script:Junctions)) { Remove-Junction $j }
    foreach ($d in @($usbTest, $pdRoot, $tempRoot, $localRoot)) {
        if (-not (Test-Path -LiteralPath $d)) { continue }
        $safe = ($d -like 'C:\ProgramData\PGL_verify_*') -or
                ($d -like "$env:TEMP\pgl_verify_*") -or
                ($d -like "$env:LOCALAPPDATA\PGL_verify_*") -or
                ($d -like ($UsbRoot + '._pgl_verify_*'))
        if (-not $safe) { throw "拒绝删除非测试目录: $d" }
        Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($Keep) {
    Write-Host ''
    Write-Host '保留现场（-Keep）：' -ForegroundColor Yellow
    Write-Host ("  U 盘测试目录: " + $usbTest)
    Write-Host ("  ProgramData:  " + $pdRoot)
    Add-Result 'T16' '清理测试现场' $true '已跳过（-Keep）'
} else {
    try {
        Invoke-Cleanup
        $left = @($usbTest, $pdRoot) | Where-Object { Test-Path -LiteralPath $_ }
        Add-Result 'T16' '清理测试现场' ($left.Count -eq 0)
    } catch {
        Add-Result 'T16' '清理测试现场' $false $_.Exception.Message
    }
}

# ---------------------------------------------------------------- 报告
$fail = @($script:Results | Where-Object { -not $_.Ok }).Count
$pass = $script:Results.Count - $fail

$lines = New-Object System.Collections.ArrayList
[void]$lines.Add('# U 盘游戏启动器 · 环境验证报告')
[void]$lines.Add('')
[void]$lines.Add("- 时间：$ts")
[void]$lines.Add("- 机器：$env:COMPUTERNAME / $env:USERNAME")
[void]$lines.Add("- 系统：$osName")
[void]$lines.Add("- PowerShell：$psv")
[void]$lines.Add("- 管理员：$isAdmin")
[void]$lines.Add("- U 盘：$UsbRoot（$fsType，$totalGB GB，空闲 $freeMB MB）")
[void]$lines.Add('')
[void]$lines.Add("结果：**$pass 通过 / $fail 失败**")
[void]$lines.Add('')
[void]$lines.Add('| 编号 | 项目 | 结果 | 说明 |')
[void]$lines.Add('|---|---|---|---|')
foreach ($r in $script:Results) {
    $mark = if ($r.Ok) { 'PASS' } else { 'FAIL' }
    $detail = ($r.Detail -replace '\|', '\|') -replace "`r?`n", ' '
    [void]$lines.Add("| $($r.Id) | $($r.Name) | $mark | $detail |")
}
[void]$lines.Add('')
[void]$lines.Add('## 结论')
[void]$lines.Add('')
if ($fail -eq 0) {
    [void]$lines.Add('- 关键链路全部通过：联接指向 U 盘、真实目录替换、双跳、换盘符重建、robocopy 接管均可用。')
} else {
    [void]$lines.Add("- 有 $fail 项失败，见上表。失败项决定实现时要走的降级分支。")
}
if ($fsType -ne 'NTFS') {
    [void]$lines.Add("- 本次 U 盘文件系统为 $fsType，已覆盖该文件系统。")
} else {
    [void]$lines.Add('- 本次 U 盘为 NTFS；exFAT / FAT32 未覆盖，需要另一支 U 盘复跑本脚本。')
}

if (-not $ReportPath) { $ReportPath = Join-Path $PSScriptRoot ("验证报告_$ts.md") }
$lines -join "`r`n" | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host ''
Write-Host ("报告: " + $ReportPath) -ForegroundColor Cyan
Write-Host ("结果: {0} 通过 / {1} 失败" -f $pass, $fail) -ForegroundColor $(if ($fail -eq 0) { 'Green' } else { 'Yellow' })

exit $fail
