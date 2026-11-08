# Tests\uninstall-dialog-test.ps1 - 打开卸载对话框、截图、点「取消」退出
$ErrorActionPreference = 'Stop'
$root = 'E:\deepseek work\AML\启动器'
$global:Root = $root
foreach ($f in 'Common', 'State', 'Config', 'Snapshot', 'Sync', 'Link', 'Restore', 'Uninstall') {
    . (Join-Path (Join-Path $root 'Launcher\lib') ($f + '.ps1'))
}
. "$root\Launcher\ui\MainWindow.ps1"
. "$root\Launcher\ui\UninstallDialog.ps1"
$global:LogFile = Join-Path $root 'Logs\uninstall-dialog-test.log'
$global:Config = Read-GlobalConfig

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public class UShot {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint f);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder sb, int max);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left,Top,Right,Bottom; }
}
'@

function Find-Window([string]$title) {
    $script:found = [IntPtr]::Zero
    $cb = [UShot+EnumProc]{ param($h, $l)
        $sb = New-Object Text.StringBuilder 128
        [void][UShot]::GetWindowText($h, $sb, 128)
        if ($sb.ToString() -eq $title) { $script:found = $h }
        return $true
    }
    [void][UShot]::EnumWindows($cb, [IntPtr]::Zero)
    return $script:found
}

$g = Get-GameById 'PvZ杂交版'
if (-not $g) { Write-Host 'SKIP: PvZ杂交版 不存在'; exit 0 }

$shot = New-Object Windows.Forms.Timer
$shot.Interval = 900
$shot.Add_Tick({
        try {
            $h = Find-Window '卸载游戏'
            if ($h -ne [IntPtr]::Zero) {
                $r = New-Object UShot+RECT
                [void][UShot]::GetWindowRect($h, [ref]$r)
                $bmp = New-Object Drawing.Bitmap ($r.Right - $r.Left), ($r.Bottom - $r.Top)
                $gfx = [Drawing.Graphics]::FromImage($bmp)
                $hdc = $gfx.GetHdc()
                [void][UShot]::PrintWindow($h, $hdc, 2)
                $gfx.ReleaseHdc($hdc); $gfx.Dispose()
                $bmp.Save('E:\deepseek work\AML\ui-uninstall.png', [Drawing.Imaging.ImageFormat]::Png)
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
        try { $script:UninstallForm.Close(); Write-Host 'closed dialog' } catch { Write-Host ('close err: ' + $_.Exception.Message) }
    })

$shot.Start(); $click.Start()
Show-UninstallDialog $g $null
$shot.Stop(); $click.Stop()
