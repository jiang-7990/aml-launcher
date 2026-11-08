$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root = 'E:\deepseek work\AML\启动器'
$global:Root = $root
. "$root\Launcher\lib\Common.ps1"
. "$root\Launcher\lib\State.ps1"
. "$root\Launcher\lib\Config.ps1"
. "$root\Launcher\ui\MainWindow.ps1"
$global:LogFile = Join-Path $root 'Logs\card-menu-test.log'
$global:Config = Read-GlobalConfig
$script:UiRoot = $root
$script:LaunchButtons = @()
$script:DirectButtons = @()

$g = Get-GameById 'RestoreTest'
$card = New-GameCard $g
Write-Host ('card=' + $card.GetType().Name + ' size=' + $card.Width + 'x' + $card.Height)
$menu = $card.ContextMenuStrip
if (-not $menu) { Write-Host 'NO MENU ON CARD'; exit 1 }
Write-Host ('menuItems=' + $menu.Items.Count)
foreach ($it in $menu.Items) {
    $kind = $it.GetType().Name
    Write-Host ("  [{0}] text='{1}' enabled={2}" -f $kind, $it.Text, $it.Enabled)
}
$missing = 0
foreach ($c in $card.Controls) {
    if (-not $c.ContextMenuStrip) { $missing++; Write-Host ('child without menu: ' + $c.GetType().Name + ' ' + $c.Text) }
}
Write-Host ('children=' + $card.Controls.Count + ' missingMenu=' + $missing)

# 可选：把菜单真正弹出来并截图
$form = New-Object Windows.Forms.Form
$form.ClientSize = New-Object Drawing.Size(920, 140)
$form.BackColor = UiColor 'bg'
$form.FormBorderStyle = [Windows.Forms.FormBorderStyle]::FixedSingle
$form.StartPosition = [Windows.Forms.FormStartPosition]::CenterScreen
$form.Controls.Add($card)
$card.Location = New-Object Drawing.Point(20, 20)
$form.Show()
[Windows.Forms.Application]::DoEvents()
Start-Sleep -Milliseconds 300
$menu.Show($card, (New-Object Drawing.Point((UiPx 300), (UiPx 40))))
[Windows.Forms.Application]::DoEvents()
Start-Sleep -Milliseconds 400

Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public class MenuShot {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder sb, int max);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint f);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left,Top,Right,Bottom; }
}
'@
$myPid = 0
[void][MenuShot]::GetWindowThreadProcessId($form.Handle, [ref]$myPid)
$script:dd = [IntPtr]::Zero
$cb = [MenuShot+EnumProc]{ param($h, $l)
    $p = 0; [void][MenuShot]::GetWindowThreadProcessId($h, [ref]$p)
    if ($p -ne $myPid) { return $true }
    if ($h -ne $form.Handle -and [MenuShot]::IsWindowVisible($h)) { $script:dd = $h }
    return $true
}
[void][MenuShot]::EnumWindows($cb, [IntPtr]::Zero)
Write-Host ('dropdown=' + $script:dd)
if ($script:dd -ne [IntPtr]::Zero) {
    $r = New-Object MenuShot+RECT
    [void][MenuShot]::GetWindowRect($script:dd, [ref]$r)
    $bmp = New-Object Drawing.Bitmap ($r.Right - $r.Left), ($r.Bottom - $r.Top)
    $gfx = [Drawing.Graphics]::FromImage($bmp)
    $hdc = $gfx.GetHdc()
    [void][MenuShot]::PrintWindow($script:dd, $hdc, 2)
    $gfx.ReleaseHdc($hdc); $gfx.Dispose()
    $bmp.Save('E:\deepseek work\AML\ui-menu.png', [Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host 'saved ui-menu.png'
}
$menu.Close()
$form.Close()
