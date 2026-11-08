$ErrorActionPreference = 'Stop'
$root = 'E:\deepseek work\AML\启动器'
$global:Root = $root
. "$root\Launcher\lib\Common.ps1"
. "$root\Launcher\lib\State.ps1"
. "$root\Launcher\lib\Config.ps1"
. "$root\Launcher\lib\Snapshot.ps1"
. "$root\Launcher\lib\Sync.ps1"
. "$root\Launcher\lib\Link.ps1"
. "$root\Launcher\lib\Restore.ps1"
. "$root\Launcher\ui\MainWindow.ps1"
. "$root\Launcher\ui\RestoreDialog.ps1"
$global:LogFile = Join-Path $root 'Logs\restore-dialog-test.log'
$global:Config = Read-GlobalConfig

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public class Shot {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint f);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder sb, int max);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left,Top,Right,Bottom; }
}
'@

function Find-Window([string]$title) {
    $script:found = [IntPtr]::Zero
    $cb = [Shot+EnumProc]{ param($h, $l)
        $sb = New-Object Text.StringBuilder 128
        [void][Shot]::GetWindowText($h, $sb, 128)
        if ($sb.ToString() -eq $title) { $script:found = $h }
        return $true
    }
    [void][Shot]::EnumWindows($cb, [IntPtr]::Zero)
    return $script:found
}

$g = Get-GameById 'RestoreTest'

$shot = New-Object Windows.Forms.Timer
$shot.Interval = 900
$shot.Add_Tick({
        try {
            $h = Find-Window '还原到本机'
            if ($h -ne [IntPtr]::Zero) {
                $r = New-Object Shot+RECT
                [void][Shot]::GetWindowRect($h, [ref]$r)
                $bmp = New-Object Drawing.Bitmap ($r.Right - $r.Left), ($r.Bottom - $r.Top)
                $gfx = [Drawing.Graphics]::FromImage($bmp)
                $hdc = $gfx.GetHdc()
                [void][Shot]::PrintWindow($h, $hdc, 2)
                $gfx.ReleaseHdc($hdc); $gfx.Dispose()
                $bmp.Save('E:\deepseek work\AML\ui-restore.png', [Drawing.Imaging.ImageFormat]::Png)
                $bmp.Dispose()
                Write-Host 'shot saved'
            }
        } catch { Write-Host ('shot err: ' + $_.Exception.Message) }
        $shot.Stop()
    })

$click = New-Object Windows.Forms.Timer
$click.Interval = 1800
$click.Add_Tick({
        $click.Stop()
        try {
            if ($script:RestoreBtn) { $script:RestoreBtn.PerformClick(); Write-Host 'clicked restore' }
        } catch { Write-Host ('click err: ' + $_.Exception.Message) }
    })

$closeBox = New-Object Windows.Forms.Timer
$closeBox.Interval = 4200
$closeBox.Add_Tick({
        try {
            $h = Find-Window '还原完成'
            if ($h -ne [IntPtr]::Zero) {
                [void][Shot]::PostMessage($h, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
                Write-Host 'closed msgbox'
            }
        } catch { }
        $closeBox.Stop()
    })

$shot.Start(); $click.Start(); $closeBox.Start()
Show-RestoreDialog $g $null
$shot.Stop(); $click.Stop(); $closeBox.Stop()

$local = "$env:APPDATA\RestoreTest"
Write-Host ('isJunction=' + (Test-Junction $local))
Write-Host ('owner=' + (Get-LocalOwner $local))
if (Test-Path -LiteralPath $local) {
    Get-ChildItem -LiteralPath $local -File | ForEach-Object { Write-Host ('file=' + $_.Name + ' ' + $_.Length) }
}
Write-Host ('storeExists=' + (Test-Path -LiteralPath (Join-Path $root 'Data\RestoreTest\restoretest')))
