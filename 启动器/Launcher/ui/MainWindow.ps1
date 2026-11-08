# ui/MainWindow.ps1 - WinForms 主窗口（深色，左详情 / 右列表）
# 依赖：Start.ps1 已 dot-source lib\*.ps1，且 $global:Root / $global:Config / $global:LogFile 已就绪

$script:UiPalette = @{
    bg          = '#0F0F23'
    bg2         = '#151230'
    panel       = '#12102A'
    card        = '#1E1C35'
    cardHover   = '#252247'
    border      = '#302B52'
    borderHover = '#7C3AED'
    text        = '#E2E8F0'
    muted       = '#9DA6B8'
    accent      = '#7C3AED'
    accent2     = '#A78BFA'
    rose        = '#E11D48'
    roseHover   = '#BE123C'
    green       = '#34D399'
    greenBg     = '#123A2E'
    amber       = '#FBBF24'
    amberBg     = '#3A2E12'
    red         = '#EF4444'
    redBg       = '#3A1620'
}
$script:UiScale = 1.0
$script:Games = @()
$script:UiRoot = $null
$script:RunProc = $null
$script:RunningGame = $null
$script:Timer = $null
$script:StatusLabel = $null
$script:SubLabel = $null
$script:ListPanel = $null
$script:DetailPanel = $null
$script:SelectedId = $null
$script:SelectedGame = $null
$script:DetailEmpty = $null
$script:DetailIcon = $null
$script:DetailName = $null
$script:DetailMeta = $null
$script:DetailLog = $null
$script:LogTargetHeight = 0
$script:LayoutTimer = $null
$script:LayoutAnim = $null
$script:DetailButtons = @()
$script:DetailBtnPrimary = $null
$script:DetailBtnDirect = $null
$script:DetailBtnSave = $null
$script:DetailBtnLearn = $null
$script:Pencil = $null
$script:IconMenu = $null
$script:LastLogText = ''

function UiColor([string]$key) {
    $hex = $script:UiPalette[$key]
    if (-not $hex) { $hex = '#FF00FF' }
    return [Drawing.ColorTranslator]::FromHtml($hex)
}

function UiPx([double]$v) {
    return [int][math]::Round($v * $script:UiScale)
}

function UiFont([double]$pt, [string]$style) {
    $fs = [Drawing.FontStyle]::Regular
    if ($style -eq 'bold') { $fs = [Drawing.FontStyle]::Bold }
    return New-Object Drawing.Font('Microsoft YaHei UI', $pt, $fs, [Drawing.GraphicsUnit]::Point)
}

function New-UiRoundPath([Drawing.Rectangle]$rect, [int]$radius) {
    $path = New-Object Drawing.Drawing2D.GraphicsPath
    $d = $radius * 2
    if ($d -le 0) { $path.AddRectangle($rect); return $path }
    $path.AddArc($rect.X, $rect.Y, $d, $d, 180, 90)
    $path.AddArc($rect.Right - $d, $rect.Y, $d, $d, 270, 90)
    $path.AddArc($rect.Right - $d, $rect.Bottom - $d, $d, $d, 0, 90)
    $path.AddArc($rect.X, $rect.Bottom - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    return $path
}

function Set-UiRounded($ctrl, [int]$radius) {
    $rect = New-Object Drawing.Rectangle 0, 0, $ctrl.Width, $ctrl.Height
    $path = New-UiRoundPath $rect $radius
    $ctrl.Region = New-Object Drawing.Region $path
    $path.Dispose()
}

function Draw-UiChip($g, $info) {
    $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $rect = New-Object Drawing.Rectangle $info.X, $info.Y, $info.W, $info.H
    $path = New-UiRoundPath $rect (UiPx 9)
    $br = New-Object Drawing.SolidBrush $info.Bg
    $g.FillPath($br, $path)
    $br.Dispose()
    $path.Dispose()
    $fmt = New-Object Drawing.StringFormat
    $fmt.Alignment = [Drawing.StringAlignment]::Center
    $fmt.LineAlignment = [Drawing.StringAlignment]::Center
    $tb = New-Object Drawing.SolidBrush $info.Fg
    $g.DrawString($info.Text, $info.Font, $tb, (New-Object Drawing.RectangleF $info.X, $info.Y, $info.W, $info.H), $fmt)
    $tb.Dispose()
    $fmt.Dispose()
}

function Draw-UiPin($g, $info) {
    $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $col = if ($info.On) { UiColor 'accent2' } else { UiColor 'muted' }
    $br = New-Object Drawing.SolidBrush $col
    $cx = $info.X + [int]($info.W / 2)
    $top = $info.Y + (UiPx 3)
    $g.FillEllipse($br, ($cx - (UiPx 6)), $top, (UiPx 12), (UiPx 7))
    $pts = @(
        (New-Object Drawing.Point (($cx - (UiPx 4)), ($top + (UiPx 6)))),
        (New-Object Drawing.Point (($cx + (UiPx 4)), ($top + (UiPx 6)))),
        (New-Object Drawing.Point (($cx + (UiPx 1)), ($top + (UiPx 12)))),
        (New-Object Drawing.Point ($cx, ($top + (UiPx 17)))),
        (New-Object Drawing.Point (($cx - (UiPx 1)), ($top + (UiPx 12))))
    )
    $g.FillPolygon($br, $pts)
    $br.Dispose()
}
function New-UiGhostButton([string]$text, [int]$x, [int]$y, [int]$w) {
    $b = New-Object Windows.Forms.Button
    $b.Text = $text
    $b.Size = New-Object Drawing.Size($w, (UiPx 32))
    $b.Location = New-Object Drawing.Point($x, $y)
    $b.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $b.FlatAppearance.BorderSize = 0
    $b.BackColor = UiColor 'bg2'
    $b.ForeColor = UiColor 'muted'
    $b.Font = UiFont 9 'regular'
    $b.Cursor = [Windows.Forms.Cursors]::Hand
    $b.TabStop = $false
    $b.UseVisualStyleBackColor = $false
    $b.Add_MouseEnter({ $this.BackColor = UiColor 'cardHover'; $this.ForeColor = UiColor 'text' })
    $b.Add_MouseLeave({ $this.BackColor = UiColor 'bg2'; $this.ForeColor = UiColor 'muted' })
    Set-UiRounded $b (UiPx 9)
    return $b
}

function New-UiButton([string]$text, [int]$x, [int]$y, [int]$w, [int]$h, [string]$kind) {
    $b = New-Object Windows.Forms.Button
    $b.Text = $text
    $b.Size = New-Object Drawing.Size($w, $h)
    $b.Location = New-Object Drawing.Point($x, $y)
    $b.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $b.FlatAppearance.BorderSize = 0
    $b.Font = UiFont 10 'bold'
    $b.Cursor = [Windows.Forms.Cursors]::Hand
    $b.TabStop = $false
    $b.UseVisualStyleBackColor = $false
    if ($kind -eq 'primary') {
        $b.BackColor = UiColor 'rose'
        $b.ForeColor = [Drawing.Color]::White
        $b.FlatAppearance.MouseOverBackColor = UiColor 'roseHover'
    } else {
        $b.BackColor = UiColor 'bg2'
        $b.ForeColor = UiColor 'muted'
        $b.FlatAppearance.MouseOverBackColor = UiColor 'cardHover'
        $b.Add_MouseEnter({ $this.ForeColor = UiColor 'text' })
        $b.Add_MouseLeave({ $this.ForeColor = UiColor 'muted' })
    }
    Set-UiRounded $b (UiPx 10)
    return $b
}

function Get-UiGameModeText($Game) {
    $mode = $null
    if ($Game.Mappings -and $Game.Mappings.Count -gt 0) { $mode = $Game.Mappings[0].Mode }
    if (-not $mode) { $mode = $script:Config.Mode }
    switch ($mode) {
        'copy' { return '复制模式' }
        'link' { return '目录联接' }
        default { return '自动' }
    }
}

function Get-GameIconFile($Game) {
    return (Join-Path (Join-Path $global:Root 'Launcher\icons') ($Game.Id + '.png'))
}

function Set-GameIconBitmap($Game, $img) {
    $path = Get-GameIconFile $Game
    Ensure-Dir (Split-Path -Parent $path)
    $bmp = New-Object Drawing.Bitmap 64, 64
    $g = [Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([Drawing.Color]::Transparent)
    $side = [Math]::Min($img.Width, $img.Height)
    if ($side -lt 1) { $side = 1 }
    $src = New-Object Drawing.Rectangle ([int](($img.Width - $side) / 2)), ([int](($img.Height - $side) / 2)), $side, $side

    $minX = $img.Width; $minY = $img.Height; $maxX = -1; $maxY = -1
    for ($y = 0; $y -lt $img.Height; $y++) {
        for ($x = 0; $x -lt $img.Width; $x++) {
            if ($img.GetPixel($x, $y).A -gt 10) {
                if ($x -lt $minX) { $minX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }
    if ($maxX -ge $minX -and $maxY -ge $minY) {
        $bw = $maxX - $minX + 1
        $bh = $maxY - $minY + 1
        $bside = [Math]::Max($bw, $bh)
        $bx = [int]($minX - (($bside - $bw) / 2))
        $by = [int]($minY - (($bside - $bh) / 2))
        if ($bx -lt 0) { $bx = 0 }
        if ($by -lt 0) { $by = 0 }
        if ($bx + $bside -gt $img.Width) { $bside = $img.Width - $bx }
        if ($by + $bside -gt $img.Height) { $bside = [Math]::Min($bside, $img.Height - $by) }
        if ($bside -gt 1) { $src = New-Object Drawing.Rectangle $bx, $by, $bside, $bside }
    }

    $dst = New-Object Drawing.Rectangle 0, 0, 64, 64
    $g.DrawImage($img, $dst, $src, [Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()
    $bmp.Save($path, [Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    return $path
}

function Ensure-GameIcon($Game) {
    $path = Get-GameIconFile $Game
    if (Test-Path -LiteralPath $path) { return $path }
    if (-not $Game.Exe -or -not (Test-Path -LiteralPath $Game.Exe)) { return $null }
    try {
        $bmp = $null
        if ('PglIcon' -as [type]) {
            $hicon = [PglIcon]::Extract($Game.Exe, 256)
            if ($hicon -ne [IntPtr]::Zero) {
                $icoBig = [Drawing.Icon]::FromHandle($hicon)
                $bmp = $icoBig.ToBitmap()
                $icoBig.Dispose()
                [void][PglIcon]::DestroyIcon($hicon)
            }
        }
        if (-not $bmp) {
            $ico = [Drawing.Icon]::ExtractAssociatedIcon($Game.Exe)
            if (-not $ico) { return $null }
            $bmp = New-Object Drawing.Bitmap ([int]$ico.Width), ([int]$ico.Height)
            $g = [Drawing.Graphics]::FromImage($bmp)
            $g.Clear([Drawing.Color]::Transparent)
            $g.DrawIcon($ico, (New-Object Drawing.Rectangle 0, 0, $bmp.Width, $bmp.Height))
            $g.Dispose()
            $c = $bmp.GetPixel(0, 0)
            if ($c.A -eq 255 -and ((($c.R -lt 8) -and ($c.G -lt 8) -and ($c.B -lt 8)) -or (($c.R -gt 247) -and ($c.G -gt 247) -and ($c.B -gt 247)))) {
                $bmp.MakeTransparent($c)
            }
            $ico.Dispose()
        }
        $null = Set-GameIconBitmap $Game $bmp
        $bmp.Dispose()
        return $path
    } catch {
        return $null
    }
}
function Open-UiPath([string]$path) {
    if (Test-Path -LiteralPath $path) {
        Start-Process -FilePath 'explorer.exe' -ArgumentList ('"' + $path + '"') | Out-Null
    }
}

function Set-UiStatus([string]$text, [string]$kind) {
    if (-not $script:StatusLabel) { return }
    $script:StatusLabel.Text = $text
    switch ($kind) {
        'error' { $script:StatusLabel.ForeColor = UiColor 'red' }
        'warn' { $script:StatusLabel.ForeColor = UiColor 'amber' }
        'ok' { $script:StatusLabel.ForeColor = UiColor 'green' }
        default { $script:StatusLabel.ForeColor = UiColor 'muted' }
    }
}

function Save-TopMostSetting([bool]$on) {
    try {
        $path = Join-Path $script:UiRoot 'Launcher\config.ini'
        if (-not (Test-Path -LiteralPath $path)) { return }
        $lines = @(Get-Content -LiteralPath $path -Encoding UTF8)
        $val = if ($on) { '1' } else { '0' }
        $ok = $false
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^\s*topmost\s*=') { $lines[$i] = 'topmost=' + $val; $ok = $true; break }
        }
        if (-not $ok) {
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($lines[$i] -match '^\s*\[general\]') {
                    $head = @($lines[0..$i])
                    $tail = @()
                    if ($i + 1 -le $lines.Count - 1) { $tail = @($lines[($i + 1)..($lines.Count - 1)]) }
                    $lines = @($head + ('topmost=' + $val) + $tail)
                    $ok = $true
                    break
                }
            }
        }
        if ($ok) { [IO.File]::WriteAllText($path, (($lines -join "`r`n") + "`r`n"), (New-Object Text.UTF8Encoding $true)) }
    } catch { }
}

function Set-UiTopMost([bool]$on, [bool]$persist) {
    if (-not $script:MainForm) { return }
    $script:MainForm.TopMost = $on
    if ($script:TopButton) {
        if ($on) {
            $script:TopButton.BackColor = UiColor 'accent2'
            $script:TopButton.ForeColor = UiColor 'bg'
            $script:TopButton.FlatAppearance.MouseOverBackColor = UiColor 'accent2'
        } else {
            $script:TopButton.BackColor = UiColor 'panel'
            $script:TopButton.ForeColor = UiColor 'muted'
            $script:TopButton.FlatAppearance.MouseOverBackColor = UiColor 'card'
        }
    }
    if ($persist) { Save-TopMostSetting $on }
    Set-UiStatus ($(if ($on) { '窗口已置顶。' } else { '已取消置顶。' })) 'ok'
}

function Get-UiLogTail([int]$count = 1) {
    try {
        $f = $global:LogFile
        if (-not $f -or -not (Test-Path -LiteralPath $f)) { return $null }
        $lines = @(Get-Content -LiteralPath $f -ErrorAction Stop | Where-Object { $_ -notmatch 'MW: ' } | Select-Object -Last $count)
        if (-not $lines -or $lines.Count -eq 0) { return $null }
        if ($count -eq 1) {
            return ($lines[0] -replace '^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]\s*\[[A-Z]+\]\s*', '')
        }
        return ($lines -join "`r`n")
    } catch { }
    return $null
}

function Load-UiImage([string]$path) {
    try {
        if (-not (Test-Path -LiteralPath $path)) { return $null }
        $fs = [IO.File]::OpenRead($path)
        $tmp = [Drawing.Image]::FromStream($fs)
        $bmp = New-Object Drawing.Bitmap $tmp
        $tmp.Dispose()
        $fs.Dispose()
        return $bmp
    } catch {
        return $null
    }
}

function Set-DetailLayout {
    param([string]$Mode = 'idle', [bool]$Animate = $false)
    if (-not $script:DetailIcon -or -not $script:DetailName -or -not $script:DetailMeta) { return }
    if ($Mode -eq 'running') {
        $iconY = UiPx 20; $nameY = UiPx 24; $metaY = UiPx 56
        $logH = [int]$script:LogTargetHeight
    } else {
        $iconY = UiPx 120; $nameY = UiPx 124; $metaY = UiPx 156
        $logH = 0
    }
    if ($logH -lt 0) { $logH = 0 }

    if (-not $Animate) {
        $script:DetailIcon.Top = $iconY
        $script:DetailName.Top = $nameY
        $script:DetailMeta.Top = $metaY
        $script:DetailLog.Visible = ($logH -gt 0)
        $script:DetailLog.Height = $logH
        $script:DetailPanel.PerformLayout()
        $script:Pencil.Left = [Math]::Min($script:DetailName.Right + (UiPx 6), $script:DetailPanel.Width - (UiPx 44))
        $script:Pencil.Top = $script:DetailName.Top + [int](($script:DetailName.Height - $script:Pencil.Height) / 2)
        return
    }

    if (-not $script:LayoutTimer) {
        $script:LayoutTimer = New-Object Windows.Forms.Timer
        $script:LayoutTimer.Interval = 15
        $script:LayoutTimer.Add_Tick({
                $a = $script:LayoutAnim
                if (-not $a) { $script:LayoutTimer.Stop(); return }
                $a.Step++
                $p = [Math]::Min(1.0, $a.Step / $a.Steps)
                $e = 1 - [Math]::Pow(1 - $p, 3)
                $script:DetailIcon.Top = [int]($a.IconFrom + ($a.IconTo - $a.IconFrom) * $e)
                $script:DetailName.Top = [int]($a.NameFrom + ($a.NameTo - $a.NameFrom) * $e)
                $script:DetailMeta.Top = [int]($a.MetaFrom + ($a.MetaTo - $a.MetaFrom) * $e)
                $script:DetailLog.Height = [int]($a.LogFrom + ($a.LogTo - $a.LogFrom) * $e)
                $script:DetailPanel.PerformLayout()
                $script:Pencil.Left = [Math]::Min($script:DetailName.Right + (UiPx 6), $script:DetailPanel.Width - (UiPx 44))
                $script:Pencil.Top = $script:DetailName.Top + [int](($script:DetailName.Height - $script:Pencil.Height) / 2)
                if ($p -ge 1.0) {
                    $script:LayoutTimer.Stop()
                    $script:DetailLog.Visible = ($a.Mode -eq 'running')
                    $script:LayoutAnim = $null
                }
            })
    }
    if ($logH -gt 0) { $script:DetailLog.Visible = $true }
    $script:LayoutAnim = @{
        Step = 0; Steps = 18; Mode = $Mode
        IconFrom = $script:DetailIcon.Top; IconTo = $iconY
        NameFrom = $script:DetailName.Top; NameTo = $nameY
        MetaFrom = $script:DetailMeta.Top; MetaTo = $metaY
        LogFrom = $script:DetailLog.Height; LogTo = $logH
    }
    $script:LayoutTimer.Start()
}
function Update-DetailPanel {
    if (-not $script:DetailPanel) { return }
    $game = $script:SelectedGame
    if (-not $game) {
        $script:DetailEmpty.Visible = $true
        $script:DetailIcon.Visible = $false
        $script:DetailName.Visible = $false
        $script:DetailMeta.Visible = $false
        $script:DetailLog.Visible = $false
        $script:Pencil.Visible = $false
        foreach ($b in $script:DetailButtons) { $b.Visible = $false }
        return
    }

    $script:DetailEmpty.Visible = $false
    $script:DetailIcon.Visible = $true
    $script:DetailName.Visible = $true
    $script:DetailMeta.Visible = $true
    $script:DetailLog.Visible = $true
    $script:Pencil.Visible = $true

    $script:DetailName.Text = $game.Name
    $mode = Get-UiGameModeText $game
    $last = ''
    try {
        $st = Get-GameLastRun $game.Id
        if ($st -and $st.LastRun) { $last = ' · 上次 ' + $st.LastRun }
    } catch { }
    $script:DetailMeta.Text = $mode + $last

    $iconPath = Ensure-GameIcon $game
    if ($iconPath) {
        $img = Load-UiImage $iconPath
        if ($img) {
            if ($script:DetailIcon.Image) { $script:DetailIcon.Image.Dispose() }
            $script:DetailIcon.Image = $img
        }
    } else {
        $script:DetailIcon.Image = $null
    }

    # 名称右边的小编辑标志：紧贴名称右缘，并跟着名称长度走
    $script:DetailPanel.PerformLayout()
    $px = $script:DetailName.Right + (UiPx 6)
    if ($px -gt ($script:DetailPanel.Width - (UiPx 44))) { $px = $script:DetailPanel.Width - (UiPx 44) }
    $script:Pencil.Left = $px
    $script:Pencil.Top = $script:DetailName.Top + [int](($script:DetailName.Height - $script:Pencil.Height) / 2)

    $hasLauncher = [bool]$game.HasLauncher
    if ($hasLauncher) {
        $script:DetailBtnPrimary.Text = '拉起启动器'
        $script:DetailBtnPrimary.Visible = $true
        $script:DetailBtnPrimary.Top = $script:DetailButtonsTop
        $script:DetailBtnDirect.Visible = $true
        $script:DetailBtnDirect.Text = '直接启动'
        $script:DetailBtnSave.Visible = $true
        $script:DetailBtnSave.Text = '打开存档位置'
        $script:DetailBtnLearn.Visible = $true
        $script:DetailBtnLearn.Text = '学习存档位置'
        $script:DetailBtnDirect.Top = $script:DetailButtonsTop + (UiPx 48)
        $script:DetailBtnSave.Top = $script:DetailBtnDirect.Top
        $script:DetailBtnLearn.Top = $script:DetailBtnDirect.Top + (UiPx 46)
        $script:DetailLog.Height = $script:DetailButtonsTop - (UiPx 92) - (UiPx 12)
    } else {
        $script:DetailBtnPrimary.Text = '启动游戏'
        $script:DetailBtnPrimary.Visible = $true
        $script:DetailBtnPrimary.Top = $script:DetailButtonsTop + (UiPx 42)
        $script:DetailBtnDirect.Visible = $false
        $script:DetailBtnSave.Visible = $true
        $script:DetailBtnSave.Text = '打开存档位置'
        $script:DetailBtnLearn.Visible = $true
        $script:DetailBtnLearn.Text = '学习存档位置'
        $script:DetailBtnSave.Top = $script:DetailBtnPrimary.Top + (UiPx 48)
        $script:DetailBtnSave.Left = UiPx 16
        $script:DetailBtnSave.Width = UiPx 166
        $script:DetailBtnLearn.Top = $script:DetailBtnSave.Top
        $script:DetailBtnLearn.Left = UiPx 190
        $script:DetailBtnLearn.Width = UiPx 174
        $script:DetailLog.Height = $script:DetailBtnPrimary.Top - (UiPx 92) - (UiPx 12)
    }

    $running = $script:RunProc -and -not $script:RunProc.HasExited
    if ($running) { $script:DetailBtnPrimary.Text = '运行中' }
    $script:DetailBtnPrimary.Enabled = -not $running
    $script:DetailBtnDirect.Enabled = -not $running
    $script:DetailBtnLearn.Enabled = -not $running
    $script:DetailBtnPrimary.BackColor = if ($running) { UiColor 'bg2' } else { UiColor 'rose' }
    $script:DetailBtnPrimary.ForeColor = if ($running) { UiColor 'muted' } else { [Drawing.Color]::White }
    $script:LogTargetHeight = [Math]::Max(0, $script:DetailLog.Height)
    if ($running -and $script:MainForm) { $script:MainForm.ActiveControl = $null }
    if (-not $script:LayoutAnim) {
        $layoutMode = if ($running) { 'running' } else { 'idle' }
        Set-DetailLayout $layoutMode $false
    }
}

function Update-LogView {
    if (-not $script:DetailLog -or -not $script:DetailLog.Visible) { return }
    $text = Get-UiLogTail 200
    if (-not $text) { $text = '' }
    if ($text -ne $script:LastLogText) {
        $script:LastLogText = $text
        $script:DetailLog.Text = $text
        $script:DetailLog.SelectionStart = $script:DetailLog.TextLength
        $script:DetailLog.ScrollToCaret()
    }
}

function Update-GameList {
    if (-not $script:ListPanel) { return }
    $script:ListPanel.SuspendLayout()
    foreach ($c in @($script:ListPanel.Controls)) { $c.Dispose() }
    $script:ListPanel.Controls.Clear()

    try { $script:Games = @(Get-AllGames) } catch { $script:Games = @() }

    if ($script:Games.Count -eq 0) {
        $empty = New-Object Windows.Forms.Label
        $empty.Text = '还没有游戏' + [Environment]::NewLine + [Environment]::NewLine + '把游戏文件夹放进 Games\，再点上方「添加游戏」'
        $empty.AutoSize = $false
        $empty.Size = New-Object Drawing.Size((UiPx 600), (UiPx 140))
        $empty.Location = New-Object Drawing.Point((UiPx 20), (UiPx 30))
        $empty.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
        $empty.ForeColor = UiColor 'muted'
        $empty.BackColor = [Drawing.Color]::Transparent
        $empty.Font = UiFont 9.5 'regular'
        $script:ListPanel.Controls.Add($empty)
        $script:ListPanel.ResumeLayout($true)
        Update-DetailPanel
        return
    }

    if ($script:SelectedId) {
        $still = $script:Games | Where-Object { $_.Id -eq $script:SelectedId } | Select-Object -First 1
        if (-not $still) { $script:SelectedId = $null }
    }
    if (-not $script:SelectedId -and $script:Games.Count -gt 0) {
        $script:SelectedId = $script:Games[0].Id
    }
    $script:SelectedGame = $script:Games | Where-Object { $_.Id -eq $script:SelectedId } | Select-Object -First 1

    # 置顶卡片永远排最上面；没置顶时选中的卡排第一；其余保持原顺序
    $ordered = @()
    $used = @{}
    foreach ($g in @($script:Games | Where-Object { $_.Pinned } | Sort-Object Name)) {
        $ordered += $g
        $used[$g.Id] = $true
    }
    if ($script:SelectedGame -and -not $used.ContainsKey($script:SelectedGame.Id)) {
        $ordered += $script:SelectedGame
        $used[$script:SelectedGame.Id] = $true
    }
    foreach ($g in $script:Games) {
        if (-not $used.ContainsKey($g.Id)) { $ordered += $g; $used[$g.Id] = $true }
    }
    foreach ($g in $ordered) {
        $script:ListPanel.Controls.Add((New-GameCard $g))
    }

    $script:ListPanel.ResumeLayout($true)
    Fit-GameCards
    Update-DetailPanel

    if ($script:SubLabel) {
        $count = $script:Games.Count
        $script:SubLabel.Text = '{0}  ·  {1} 个游戏  ·  本机 {2}' -f $script:UiRoot, $count, $env:COMPUTERNAME
    }
    Update-LogView
}

function Fit-GameCards {
    if (-not $script:ListPanel) { return }
    $w = $script:ListPanel.ClientSize.Width - (UiPx 32)
    if ($w -lt (UiPx 300)) { return }
    foreach ($c in @($script:ListPanel.Controls)) {
        if ($c.Tag -eq 'hint') { $c.Width = $w; continue }
        if ($c -is [Windows.Forms.Panel]) {
            $c.Width = $w
            if ($c.ChipInfo) {
                $c.ChipInfo.X = $w - (UiPx 140)
            }
            if ($c.PinInfo) {
                $c.PinInfo.X = $w - (UiPx 44)
            }
            $c.Invalidate()
        }
    }
}

function New-GameCard {
    param($Game)
    $w = UiPx 600
    $h = UiPx 84
    $card = New-Object Windows.Forms.Panel
    $card.Size = New-Object Drawing.Size($w, $h)
    $card.Margin = New-Object Windows.Forms.Padding(0, 0, 0, (UiPx 10))
    $card.BackColor = [Drawing.Color]::Transparent
    $card.Tag = $Game
    $card.Cursor = [Windows.Forms.Cursors]::Hand

    $selected = ($script:SelectedId -eq $Game.Id)
    $card | Add-Member NoteProperty 'IsSelected' $selected -Force
    $card | Add-Member NoteProperty 'Hover' $false -Force

    $card.Add_Paint({
            param($s, $e)
            $g = $e.Graphics
            $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $rect = New-Object Drawing.Rectangle 0, 0, ($this.Width - 1), ($this.Height - 1)
            $path = New-UiRoundPath $rect (UiPx 12)
            $alpha = [int](255 * $script:CardOpacity / 100)
            $cardColor = UiColor 'card'
            $bg = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb($alpha, $cardColor))
            $g.FillPath($bg, $path)
            $bg.Dispose()
            $pinned = [bool]($this.PinInfo -and $this.PinInfo.On)
            if ($pinned) {
                $glow = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(85, (UiColor 'accent2'))), (UiPx 7)
                $g.DrawPath($glow, $path)
                $glow.Dispose()
            }
            $bc = if ($pinned) { UiColor 'accent2' } elseif ($this.IsSelected) { UiColor 'accent' } elseif ($this.Hover) { UiColor 'borderHover' } else { UiColor 'border' }
            $pw = if ($pinned) { 2.2 } else { 1.4 }
            $pen = New-Object Drawing.Pen $bc, (UiPx $pw)
            $g.DrawPath($pen, $path)
            $pen.Dispose()
            $path.Dispose()
            if ($this.ChipInfo) { Draw-UiChip $g $this.ChipInfo }
            if ($this.PinInfo) { Draw-UiPin $g $this.PinInfo }
        })

    $icon = New-Object Windows.Forms.PictureBox
    $icon.Size = New-Object Drawing.Size((UiPx 46), (UiPx 46))
    $icon.Location = New-Object Drawing.Point((UiPx 16), (UiPx 19))
    $icon.SizeMode = [Windows.Forms.PictureBoxSizeMode]::Zoom
    $icon.BackColor = [Drawing.Color]::Transparent
    $icon.Cursor = [Windows.Forms.Cursors]::Hand
    $iconPath = Ensure-GameIcon $Game
    if ($iconPath) {
        $img = Load-UiImage $iconPath
        if ($img) { $icon.Image = $img }
    }
    $card.Controls.Add($icon)

    $name = New-Object Windows.Forms.Label
    $name.Text = $Game.Name
    $name.AutoSize = $false
    $name.Size = New-Object Drawing.Size(($w - (UiPx 220)), (UiPx 24))
    $name.Location = New-Object Drawing.Point((UiPx 74), (UiPx 16))
    $name.Font = UiFont 11.5 'bold'
    $name.ForeColor = UiColor 'text'
    $name.BackColor = [Drawing.Color]::Transparent
    $name.Cursor = [Windows.Forms.Cursors]::Hand
    $card.Controls.Add($name)

    $exe = New-Object Windows.Forms.Label
    $exe.Text = (Split-Path -Leaf $Game.Exe)
    $exe.AutoSize = $false
    $exe.Size = New-Object Drawing.Size(($w - (UiPx 220)), (UiPx 18))
    $exe.Location = New-Object Drawing.Point((UiPx 74), (UiPx 44))
    $exe.Font = UiFont 8 'regular'
    $exe.ForeColor = UiColor 'muted'
    $exe.BackColor = [Drawing.Color]::Transparent
    $exe.Cursor = [Windows.Forms.Cursors]::Hand
    $card.Controls.Add($exe)

    $meta = New-Object Windows.Forms.Label
    $mode = Get-UiGameModeText $Game
    $last = ''
    try {
        $st = Get-GameLastRun $Game.Id
        if ($st -and $st.LastRun) { $last = ' · 上次 ' + $st.LastRun }
    } catch { }

    $meta.Text = $mode + $last
    $meta.AutoSize = $false
    $meta.Size = New-Object Drawing.Size((UiPx 150), (UiPx 18))
    $meta.Location = New-Object Drawing.Point(($w - (UiPx 310)), (UiPx 20))
    $meta.TextAlign = [Drawing.ContentAlignment]::MiddleRight
    $meta.Font = UiFont 8 'regular'
    $meta.ForeColor = UiColor 'muted'
    $meta.BackColor = [Drawing.Color]::Transparent
    $meta.Cursor = [Windows.Forms.Cursors]::Hand
    $card.Controls.Add($meta)

    $ready = $Game.Exe -and (Test-Path -LiteralPath $Game.Exe)
    $chipBg = if ($ready) { UiColor 'greenBg' } else { UiColor 'amberBg' }
    $chipFg = if ($ready) { UiColor 'green' } else { UiColor 'amber' }
    $chipText = if ($ready) { '● 就绪' } else { '● 缺少 exe' }
    $card | Add-Member NoteProperty ChipInfo @{
        Text = $chipText; X = ($w - (UiPx 140)); Y = (UiPx 46); W = (UiPx 86); H = (UiPx 22)
        Fg = $chipFg; Bg = $chipBg; Font = UiFont 8.5 'bold'
    } -Force
    $card | Add-Member NoteProperty PinInfo @{
        X = ($w - (UiPx 44)); Y = (UiPx 28); W = (UiPx 28); H = (UiPx 28); On = [bool]$Game.Pinned
    } -Force

    foreach ($ctrl in @($icon, $name, $exe, $meta)) {
        $ctrl.Tag = $Game
        $ctrl.Add_Click({
                $script:SelectedId = $this.Tag.Id
                $script:SelectedGame = $this.Tag
                Update-GameList
            })
        $ctrl.Add_DoubleClick({
                if ($this.Tag -and $this.Tag.Exe) { Start-UiGame $this.Tag 'auto' }
            })
    }

    $card.Add_MouseClick({
            param($sender, $e)
            if ($this.PinInfo) {
                $pt = $e.Location
                if ($pt.X -ge $this.PinInfo.X -and $pt.X -le ($this.PinInfo.X + $this.PinInfo.W) -and $pt.Y -ge $this.PinInfo.Y -and $pt.Y -le ($this.PinInfo.Y + $this.PinInfo.H)) {
                    Set-GamePinned $this.Tag (-not $this.Tag.Pinned)
                    if ($this.Tag.Pinned) { Set-UiStatus ('已置顶：' + $this.Tag.Name) 'ok' }
                    else { Set-UiStatus ('已取消置顶：' + $this.Tag.Name) }
                    Update-GameList
                    return
                }
            }
            $script:SelectedId = $this.Tag.Id
            $script:SelectedGame = $this.Tag
            Update-GameList
        })
    $card.Add_DoubleClick({
            if ($this.Tag -and $this.Tag.Exe) { Start-UiGame $this.Tag 'auto' }
        })
    $card.Add_MouseEnter({ $this.Hover = $true; $this.Invalidate() })
    $card.Add_MouseLeave({ $this.Hover = $false; $this.Invalidate() })

    # 右键菜单
    $menu = New-Object Windows.Forms.ContextMenuStrip
    $miStart = $menu.Items.Add('启动')
    $miStart.Tag = $Game
    $miStart.Add_Click({ if ($this.Tag) { Start-UiGame $this.Tag 'auto' } })
    if ($Game.HasLauncher -and $Game.Launcher) {
        $miDirect = $menu.Items.Add('直接启动')
        $miDirect.Tag = $Game
        $miDirect.Add_Click({ if ($this.Tag) { Start-UiGame $this.Tag 'direct' } })
    }
    [void]$menu.Items.Add('-')
    $miLearn = $menu.Items.Add('学习存档位置…')
    $miLearn.Tag = $Game
    $miLearn.Add_Click({ if ($this.Tag) { Show-LearnWindow $this.Tag $script:MainForm; Update-GameList } })
    $miSave = $menu.Items.Add('存档位置…')
    $miSave.Tag = $Game
    $miSave.Add_Click({ if ($this.Tag) { Show-SaveLocationWindow $this.Tag $script:MainForm; Update-GameList } })
    $miPinText = if ($Game.Pinned) { '取消置顶卡片' } else { '置顶卡片' }
    $miPin = $menu.Items.Add($miPinText)
    $miPin.Tag = $Game
    $miPin.Add_Click({
            if ($this.Tag) {
                Set-GamePinned $this.Tag (-not $this.Tag.Pinned)
                Update-GameList
                if ($this.Tag.Pinned) { Set-UiStatus ('已置顶：' + $this.Tag.Name) 'ok' }
                else { Set-UiStatus ('已取消置顶：' + $this.Tag.Name) 'ok' }
            }
        })
    $miIcon = $menu.Items.Add('更换图标…')
    $miIcon.Tag = $Game
    $miIcon.Add_Click({ if ($this.Tag) { Show-ChangeIcon $this.Tag } })
    $miIconReset = $menu.Items.Add('恢复默认图标（从 exe 提取）')
    $miIconReset.Tag = $Game
    $miIconReset.Add_Click({
            if ($this.Tag) {
                $p = Get-GameIconFile $this.Tag
                if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue }
                Update-GameList
            }
        })
    [void]$menu.Items.Add('-')
    $miRestore = $menu.Items.Add('还原到本机…')
    $miRestore.Tag = $Game
    $miRestore.Add_Click({ if ($this.Tag) { Show-RestoreDialog $this.Tag $script:MainForm; Update-GameList } })
    $miUninstall = $menu.Items.Add('卸载游戏…')
    $miUninstall.Tag = $Game
    $miUninstall.Add_Click({ if ($this.Tag) { Show-UninstallDialog $this.Tag $script:MainForm; Update-GameList } })
    $miOpen = $menu.Items.Add('打开游戏文件夹')
    $miOpen.Tag = $Game
    $miOpen.Add_Click({ if ($this.Tag) { Open-UiPath $this.Tag.Dir } })
    $card.ContextMenuStrip = $menu
    foreach ($ctrl in @($icon, $name, $exe, $meta)) { $ctrl.ContextMenuStrip = $menu }

    return $card
}

function Set-GamePinned($Game, [bool]$Value) {
    if (-not $Game -or -not $Game.ProfilePath) { return }
    if (-not (Test-Path -LiteralPath $Game.ProfilePath)) { return }
    $ini = Read-Ini $Game.ProfilePath
    if (-not $ini['game']) { $ini['game'] = [ordered]@{} }
    $v = if ($Value) { '1' } else { '0' }
    $ini['game']['pinned'] = $v
    Write-Ini $ini $Game.ProfilePath
    $Game.Pinned = $Value
}
function Show-ChangeIcon($Game) {
    $dlg = New-Object Windows.Forms.OpenFileDialog
    $dlg.Title = '选择游戏图标'
    $dlg.Filter = '图片 (*.png;*.jpg;*.jpeg;*.bmp;*.ico)|*.png;*.jpg;*.jpeg;*.bmp;*.ico'
    if ($dlg.ShowDialog() -eq 'OK') {
        try {
            $img = [Drawing.Image]::FromFile($dlg.FileName)
            $null = Set-GameIconBitmap $Game $img
            $img.Dispose()
            Update-GameList
            Set-UiStatus ('已更新图标：' + $Game.Name) 'ok'
        } catch {
            Set-UiStatus ('图标导入失败：' + $_.Exception.Message) 'error'
        }
    }
}

function Show-RenameDialog($Game) {
    $form = New-Object Windows.Forms.Form
    $form.Text = '重命名游戏'
    $form.Size = New-Object Drawing.Size((UiPx 440), (UiPx 200))
    $form.StartPosition = [Windows.Forms.FormStartPosition]::CenterParent
    $form.FormBorderStyle = [Windows.Forms.FormBorderStyle]::FixedDialog
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.BackColor = UiColor 'bg'
    $form.ForeColor = UiColor 'text'
    $form.Font = UiFont 9 'regular'

    $cap = New-Object Windows.Forms.Label
    $cap.Text = '显示名称'
    $cap.AutoSize = $true
    $cap.Location = New-Object Drawing.Point((UiPx 24), (UiPx 22))
    $cap.ForeColor = UiColor 'muted'
    $form.Controls.Add($cap)

    $box = New-Object Windows.Forms.TextBox
    $box.Text = $Game.Name
    $box.Location = New-Object Drawing.Point((UiPx 24), (UiPx 48))
    $box.Size = New-Object Drawing.Size((UiPx 388), (UiPx 28))
    $box.BackColor = UiColor 'bg2'
    $box.ForeColor = UiColor 'text'
    $box.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle
    $box.Font = UiFont 10 'regular'
    $form.Controls.Add($box)

    $ok = New-UiButton '保存' (UiPx 232) (UiPx 104) (UiPx 84) (UiPx 34) 'primary'
    $cancel = New-UiGhostButton '取消' (UiPx 328) (UiPx 104) (UiPx 84)
    $ok.Add_Click({
            $newName = $box.Text.Trim()
            if (-not $newName) { return }
            try {
                $path = Join-Path (Join-Path $script:UiRoot 'Launcher\profiles') ($Game.Id + '.ini')
                if (Test-Path -LiteralPath $path) {
                    $ini = Read-Ini $path
                    if (-not $ini['game']) { $ini['game'] = [ordered]@{} }
                    $ini['game']['name'] = $newName
                    Write-Ini $ini $path
                }
                $Game.Name = $newName
                $form.DialogResult = 'OK'
                $form.Close()
            } catch {
                Set-UiStatus ('重命名失败：' + $_.Exception.Message) 'error'
            }
        })
    $form.AcceptButton = $ok
    $form.CancelButton = $cancel
    $form.Controls.Add($ok)
    $form.Controls.Add($cancel)
    [void]$form.ShowDialog($script:MainForm)
    Update-GameList
    Set-UiStatus ('已重命名为「' + $Game.Name + '」') 'ok'
}

function Start-UiGame($Game, [string]$Mode = 'auto') {
    if (-not $Game) { return }
    if ($script:RunProc -and -not $script:RunProc.HasExited) {
        Set-UiStatus '已有游戏在运行，等它结束再启动下一个。' 'warn'
        return
    }
    if ($Mode -eq 'launcher') { $useLauncher = $true }
    elseif ($Mode -eq 'direct') { $useLauncher = $false }
    else { $useLauncher = [bool]$Game.HasLauncher }
    $checkExe = if ($useLauncher) { $Game.Launcher } else { $Game.Exe }
    if (-not $checkExe -or -not (Test-Path -LiteralPath $checkExe)) {
        $what = if ($useLauncher) { '启动器' } else { '游戏' }
        Set-UiStatus ('找不到{0}程序：{1}' -f $what, $Game.Dir) 'error'
        return
    }
    $cfgNow = $global:Config
    if ($cfgNow -and $Game.Mappings) {
        $warnMb = 512
        try { $warnMb = [int]$cfgNow.CopyWarnMB } catch { }
        foreach ($m in @($Game.Mappings)) {
            $mm = $m.Mode
            if (-not $mm -or $mm -eq 'auto') { $mm = $cfgNow.Mode }
            if ($mm -ne 'copy') { continue }
            $storePath = Get-MappingStorePath $Game $m
            $mb = 0
            try { $mb = [int](Get-DirSizeMB $storePath) } catch { }
            if ($mb -ge $warnMb) {
                $msg = ('「{0}」是复制模式，U 盘存档约 {1} MB，启动时要整体复制到本机，退出后再回写，可能比较慢。继续吗？' -f $Game.Name, $mb)
                $ans = [Windows.Forms.MessageBox]::Show($msg, 'AML', [Windows.Forms.MessageBoxButtons]::YesNo, [Windows.Forms.MessageBoxIcon]::Warning)
                if ($ans -ne [Windows.Forms.DialogResult]::Yes) { return }
            }
        }
    }

    $scriptFile = Join-Path $script:UiRoot 'Launcher\Start.ps1'
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell.exe'
    $psi.Arguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -Game "{1}" -NoPause' -f $scriptFile, $Game.Id
    if ($Mode -eq 'direct') { $psi.Arguments += ' -Direct' }
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    try {
        $script:RunProc = [Diagnostics.Process]::Start($psi)
    } catch {
        Set-UiStatus ('启动失败：' + $_.Exception.Message) 'error'
        return
    }
    $script:RunningGame = $Game
    Set-UiStatus ('正在启动 ' + $Game.Name + ' …') 'default'
    Update-DetailPanel
    Set-DetailLayout 'idle' $false
    Set-DetailLayout 'running' $true
    $script:Timer.Start()
}

function Show-MainWindow {
    param([array]$Games, $Config, [string]$Root)

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    if (-not ('PglWin' -as [type])) {
        $nativeDll = Join-Path $Root 'Launcher\cache\PglNative.dll'
        if (Test-Path -LiteralPath $nativeDll) {
            try { Add-Type -Path $nativeDll } catch { }
        }
    }
    if (-not ('PglWin' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class PglWin {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int val, int size);
}
'@
    }
    [void][PglWin]::SetProcessDPIAware()
    $script:Games = @($Games)
    $script:Config = $Config
    if ($Config) { $global:Config = $Config }
    $script:UiRoot = $Root
    $script:RunProc = $null
    $script:RunningGame = $null
    $script:SelectedId = $null
    $script:SelectedGame = $null
    $script:LastLogText = ''

    $cw = UiPx 1080
    $ch = UiPx 720
    $form = New-Object Windows.Forms.Form
    $form.Text = 'AML'
    $form.ClientSize = New-Object Drawing.Size($cw, $ch)
    $form.StartPosition = [Windows.Forms.FormStartPosition]::CenterScreen
    $form.FormBorderStyle = [Windows.Forms.FormBorderStyle]::None
    $form.MinimumSize = New-Object Drawing.Size($cw, $ch)
    $form.MaximumSize = New-Object Drawing.Size($cw, $ch)
    $form.MaximizeBox = $false
    $form.BackColor = UiColor 'bg'
    $form.ForeColor = UiColor 'text'
    $form.Font = UiFont 9 'regular'
    $script:MainForm = $form

    if ('PglWin' -as [type]) {
        try {
            $v = 1
            [void][PglWin]::DwmSetWindowAttribute($form.Handle, 20, [ref]$v, 4)
            [void][PglWin]::DwmSetWindowAttribute($form.Handle, 19, [ref]$v, 4)
        } catch { }
    }

    # ---------------- 外观：壁纸 / 透明度 ----------------
    $script:CardOpacity = 92
    $wpFile = ''
    $wpOpacity = 60
    if ($Config) {
        try { $script:CardOpacity = [int]$Config.PanelOpacity } catch { }
        try { $wpOpacity = [int]$Config.WallpaperOpacity } catch { }
        if ($Config.Wallpaper) { $wpFile = Join-Path $Root ('Launcher\' + $Config.Wallpaper) }
    }
    if ($script:CardOpacity -lt 20) { $script:CardOpacity = 20 }
    if ($script:CardOpacity -gt 100) { $script:CardOpacity = 100 }
    if ($wpOpacity -lt 0) { $wpOpacity = 0 }
    if ($wpOpacity -gt 100) { $wpOpacity = 100 }
    if ($wpFile -and (Test-Path -LiteralPath $wpFile)) {
        try {
            $img = [Drawing.Image]::FromFile($wpFile)
            $bgBmp = New-Object Drawing.Bitmap $cw, $ch
            $bgG = [Drawing.Graphics]::FromImage($bgBmp)
            $bgG.Clear((UiColor 'bg'))
            $bgG.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $ia = New-Object Drawing.Imaging.ImageAttributes
            $cm = New-Object Drawing.Imaging.ColorMatrix
            $cm.Matrix33 = [float]($wpOpacity / 100.0)
            $ia.SetColorMatrix($cm)
            $sc = [Math]::Max(($cw / $img.Width), ($ch / $img.Height))
            $dw = [int]($img.Width * $sc); $dh = [int]($img.Height * $sc)
            $dx = [int](($cw - $dw) / 2); $dy = [int](($ch - $dh) / 2)
            $dst = New-Object Drawing.Rectangle $dx, $dy, $dw, $dh
            $bgG.DrawImage($img, $dst, 0, 0, $img.Width, $img.Height, [Drawing.GraphicsUnit]::Pixel, $ia)
            $scrimH = [int](UiPx 104)
            $scrimRect = New-Object Drawing.Rectangle 0, 0, $cw, $scrimH
            $scrimBrush = New-Object Drawing.Drawing2D.LinearGradientBrush $scrimRect, ([Drawing.Color]::FromArgb(200, (UiColor 'bg'))), ([Drawing.Color]::FromArgb(0, (UiColor 'bg'))), ([float]90.0)
            $bgG.FillRectangle($scrimBrush, $scrimRect)
            $scrimBrush.Dispose()
            $bgG.Dispose(); $img.Dispose(); $ia.Dispose()
            $form.BackgroundImage = $bgBmp
            $form.BackgroundImageLayout = [Windows.Forms.ImageLayout]::None
        } catch { }
    }
    # ---------------- 顶栏 ----------------
    $title = New-Object Windows.Forms.Label
    $title.Text = 'AML'
    $title.AutoSize = $true
    $title.Location = New-Object Drawing.Point((UiPx 24), (UiPx 10))
    $title.Font = UiFont 16 'bold'
    $title.ForeColor = UiColor 'text'
    $title.BackColor = [Drawing.Color]::Transparent
    $form.Controls.Add($title)

    $script:SubLabel = New-Object Windows.Forms.Label
    $script:SubLabel.AutoSize = $true
    $script:SubLabel.Location = New-Object Drawing.Point((UiPx 26), (UiPx 42))
    $script:SubLabel.Font = UiFont 8.5 'regular'
    $script:SubLabel.ForeColor = UiColor 'muted'
    $script:SubLabel.BackColor = [Drawing.Color]::Transparent
    $form.Controls.Add($script:SubLabel)

    $btnRefresh = New-UiGhostButton '刷新' (UiPx 432) (UiPx 88) (UiPx 62)
    $btnAdd = New-UiGhostButton '添加游戏' (UiPx 504) (UiPx 88) (UiPx 90)
    $btnGames = New-UiGhostButton '打开 Games' (UiPx 604) (UiPx 88) (UiPx 92)
    $btnConfig = New-UiGhostButton '设置' (UiPx 706) (UiPx 88) (UiPx 60)
    $script:TopButton = New-UiGhostButton '置顶' (UiPx 774) (UiPx 88) (UiPx 60)

    foreach ($b in @($btnRefresh, $btnAdd, $btnGames, $btnConfig, $script:TopButton)) {
        $form.Controls.Add($b)
    }
    $btnRefresh.Add_Click({ Update-GameList; Set-UiStatus '已刷新游戏列表。' 'ok' })
    $btnAdd.Add_Click({ Show-AddGameWindow $script:MainForm; Update-GameList })
    $btnGames.Add_Click({ Open-UiPath (Join-Path $script:UiRoot 'Games') })
    $btnConfig.Add_Click({ Show-SettingsWindow $script:MainForm })
    $script:TopButton.Add_Click({ Set-UiTopMost (-not $script:MainForm.TopMost) $true })

    # ---------------- 无边框窗口控制 ----------------
    $drag = {
        param($sender, $e)
        if ($e.Button -eq [Windows.Forms.MouseButtons]::Left -and ('PglWin' -as [type])) {
            [PglWin]::DragMove($script:MainForm.Handle)
        }
    }
    $form.Add_MouseDown($drag)
    $title.Add_MouseDown($drag)
    $script:SubLabel.Add_MouseDown($drag)

    $btnMin = New-Object Windows.Forms.Label
    $btnMin.Text = '—'
    $btnMin.Size = New-Object Drawing.Size((UiPx 36), (UiPx 36))
    $btnMin.Location = New-Object Drawing.Point((UiPx 996), (UiPx 22))
    $btnMin.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $btnMin.Font = UiFont 11 'regular'
    $btnMin.ForeColor = UiColor 'muted'
    $btnMin.BackColor = [Drawing.Color]::Transparent
    $btnMin.Cursor = [Windows.Forms.Cursors]::Hand
    $btnMin.Add_Click({ $script:MainForm.WindowState = [Windows.Forms.FormWindowState]::Minimized })
    $btnMin.Add_MouseEnter({ $this.BackColor = UiColor 'panel' })
    $btnMin.Add_MouseLeave({ $this.BackColor = [Drawing.Color]::Transparent })

    $btnClose = New-Object Windows.Forms.Label
    $btnClose.Text = '×'
    $btnClose.Size = New-Object Drawing.Size((UiPx 36), (UiPx 36))
    $btnClose.Location = New-Object Drawing.Point((UiPx 1036), (UiPx 22))
    $btnClose.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $btnClose.Font = UiFont 12 'regular'
    $btnClose.ForeColor = UiColor 'muted'
    $btnClose.BackColor = [Drawing.Color]::Transparent
    $btnClose.Cursor = [Windows.Forms.Cursors]::Hand
    $btnClose.Add_Click({ $script:MainForm.Close() })
    $btnClose.Add_MouseEnter({ $this.BackColor = UiColor 'rose'; $this.ForeColor = [Drawing.Color]::White })
    $btnClose.Add_MouseLeave({ $this.BackColor = [Drawing.Color]::Transparent; $this.ForeColor = UiColor 'muted' })
    $form.Controls.Add($btnMin)
    $form.Controls.Add($btnClose)


    # ---------------- 左侧详情 ----------------
    $leftW = UiPx 380
    $top = UiPx 82
    $bodyH = $ch - $top - (UiPx 44)
    $left = New-Object Windows.Forms.Panel
    $left.Location = New-Object Drawing.Point((UiPx 20), $top)
    $left.Size = New-Object Drawing.Size($leftW, $bodyH)
    $left.BackColor = [Drawing.Color]::Transparent
    $form.Controls.Add($left)
    Set-UiRounded $left (UiPx 14)
    $left.Add_Paint({
            param($s, $e)
            $g = $e.Graphics
            $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $rect = New-Object Drawing.Rectangle 0, 0, ($this.Width - 1), ($this.Height - 1)
            $path = New-UiRoundPath $rect (UiPx 14)
            $a = [int](255 * $script:CardOpacity / 100)
            $br = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb($a, (UiColor 'card')))
            $g.FillPath($br, $path)
            $br.Dispose()
            $path.Dispose()
        })
    $script:DetailPanel = $left

    $script:DetailIcon = New-Object Windows.Forms.PictureBox
    $script:DetailIcon.Size = New-Object Drawing.Size((UiPx 64), (UiPx 64))
    $script:DetailIcon.Location = New-Object Drawing.Point((UiPx 20), (UiPx 20))
    $script:DetailIcon.SizeMode = [Windows.Forms.PictureBoxSizeMode]::Zoom
    $script:DetailIcon.BackColor = [Drawing.Color]::Transparent
    $script:DetailIcon.Cursor = [Windows.Forms.Cursors]::Hand
    $left.Controls.Add($script:DetailIcon)

    $iconMenu = New-Object Windows.Forms.ContextMenuStrip
    $miChange = $iconMenu.Items.Add('更换图标…')
    $miChange.Add_Click({ if ($script:SelectedGame) { Show-ChangeIcon $script:SelectedGame } })
    $miReset = $iconMenu.Items.Add('恢复默认图标（从 exe 提取）')
    $miReset.Add_Click({
            if ($script:SelectedGame) {
                $p = Get-GameIconFile $script:SelectedGame
                if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue }
                Update-GameList
            }
        })
    $script:DetailIcon.ContextMenuStrip = $iconMenu

    $script:DetailName = New-Object Windows.Forms.Label
    $script:DetailName.AutoSize = $true
    $script:DetailName.MinimumSize = New-Object Drawing.Size(0, (UiPx 30))
    $script:DetailName.Location = New-Object Drawing.Point((UiPx 96), (UiPx 24))
    $script:DetailName.Font = UiFont 13 'bold'
    $script:DetailName.ForeColor = UiColor 'text'
    $script:DetailName.BackColor = [Drawing.Color]::Transparent
    $left.Controls.Add($script:DetailName)

    $script:DetailMeta = New-Object Windows.Forms.Label
    $script:DetailMeta.AutoSize = $false
    $script:DetailMeta.Size = New-Object Drawing.Size((UiPx 260), (UiPx 20))
    $script:DetailMeta.Location = New-Object Drawing.Point((UiPx 96), (UiPx 56))
    $script:DetailMeta.Font = UiFont 8.5 'regular'
    $script:DetailMeta.ForeColor = UiColor 'muted'
    $script:DetailMeta.BackColor = [Drawing.Color]::Transparent
    $left.Controls.Add($script:DetailMeta)

    # 铅笔（重命名）
    $pencilBmp = New-Object Drawing.Bitmap 24, 24
    $pg = [Drawing.Graphics]::FromImage($pencilBmp)
    $pg.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $pg.Clear([Drawing.Color]::Transparent)
    $penP = New-Object Drawing.Pen (UiColor 'muted'), 1.8
    $pg.DrawLine($penP, 5, 18, 8, 19)
    $pg.DrawLine($penP, 8, 19, 20, 7)
    $pg.DrawLine($penP, 20, 7, 17, 4)
    $pg.DrawLine($penP, 17, 4, 5, 16)
    $pg.Dispose()
    $penP.Dispose()
    $script:Pencil = New-Object Windows.Forms.PictureBox
    $script:Pencil.Image = $pencilBmp
    $script:Pencil.Size = New-Object Drawing.Size((UiPx 22), (UiPx 22))
    $script:Pencil.Location = New-Object Drawing.Point((UiPx 300), (UiPx 30))
    $script:Pencil.BackColor = [Drawing.Color]::Transparent
    $script:Pencil.Cursor = [Windows.Forms.Cursors]::Hand
    $script:Pencil.Add_MouseEnter({ $this.BackColor = UiColor 'cardHover' })
    $script:Pencil.Add_MouseLeave({ $this.BackColor = [Drawing.Color]::Transparent })
    $script:Pencil.Add_Click({ if ($script:SelectedGame) { Show-RenameDialog $script:SelectedGame } })
    $left.Controls.Add($script:Pencil)
    $script:Pencil.BringToFront()

    $script:DetailLog = New-Object Windows.Forms.TextBox
    $script:DetailLog.Location = New-Object Drawing.Point((UiPx 16), (UiPx 92))
    $script:DetailLog.Size = New-Object Drawing.Size(($leftW - (UiPx 32)), (UiPx 240))
    $script:DetailLog.Multiline = $true
    $script:DetailLog.ReadOnly = $true
    $script:DetailLog.ScrollBars = [Windows.Forms.ScrollBars]::None
    $script:DetailLog.BorderStyle = [Windows.Forms.BorderStyle]::None
    $script:DetailLog.BackColor = UiColor 'panel'
    $script:DetailLog.ForeColor = UiColor 'muted'
    $script:DetailLog.Font = New-Object Drawing.Font('Consolas', 8.2, [Drawing.FontStyle]::Regular, [Drawing.GraphicsUnit]::Point)
    $script:DetailLog.TabStop = $false
    $left.Controls.Add($script:DetailLog)

    $script:DetailEmpty = New-Object Windows.Forms.Label
    $script:DetailEmpty.Text = "从右侧选一个游戏`r`n这里会显示启动器和存档选项"
    $script:DetailEmpty.AutoSize = $false
    $script:DetailEmpty.Size = New-Object Drawing.Size(($leftW - (UiPx 40)), (UiPx 80))
    $script:DetailEmpty.Location = New-Object Drawing.Point((UiPx 20), (UiPx 180))
    $script:DetailEmpty.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $script:DetailEmpty.Font = UiFont 10 'regular'
    $script:DetailEmpty.ForeColor = UiColor 'muted'
    $script:DetailEmpty.BackColor = [Drawing.Color]::Transparent
    $left.Controls.Add($script:DetailEmpty)

    # 按钮：先建好，布局在 Update-DetailPanel 里按有无启动器调整
    $script:DetailButtonsTop = $bodyH - (UiPx 16) - (UiPx 130)
    $btnW = $leftW - (UiPx 32)
    $script:DetailBtnPrimary = New-UiButton '启动游戏' (UiPx 16) $script:DetailButtonsTop $btnW (UiPx 40) 'primary'
    $script:DetailBtnDirect = New-UiButton '直接启动' (UiPx 16) ($script:DetailButtonsTop + (UiPx 48)) (UiPx 166) (UiPx 38) 'primary'
    $script:DetailBtnSave = New-UiButton '打开存档位置' (UiPx 190) ($script:DetailButtonsTop + (UiPx 48)) (UiPx 174) (UiPx 38) 'ghost'
    $script:DetailBtnLearn = New-UiButton '学习存档位置' (UiPx 16) ($script:DetailButtonsTop + (UiPx 94)) $btnW (UiPx 34) 'ghost'
    $script:DetailButtons = @($script:DetailBtnPrimary, $script:DetailBtnDirect, $script:DetailBtnSave, $script:DetailBtnLearn)
    foreach ($b in $script:DetailButtons) { $left.Controls.Add($b) }

    $script:DetailBtnPrimary.Add_Click({
            if (-not $script:SelectedGame) { return }
            $m = if ($script:SelectedGame.HasLauncher) { 'launcher' } else { 'auto' }
            Start-UiGame $script:SelectedGame $m
        })
    $script:DetailBtnDirect.Add_Click({ if ($script:SelectedGame) { Start-UiGame $script:SelectedGame 'direct' } })
    $script:DetailBtnSave.Add_Click({ if ($script:SelectedGame) { Show-SaveLocationWindow $script:SelectedGame $script:MainForm; Update-GameList } })
    $script:DetailBtnLearn.Add_Click({ if ($script:SelectedGame) { Show-LearnWindow $script:SelectedGame $script:MainForm; Update-GameList } })

    # ---------------- 右侧列表 ----------------
    $listX = (UiPx 20) + $leftW + (UiPx 20)
    $listW = $cw - $listX - (UiPx 20)
    $script:ListPanel = New-Object Windows.Forms.FlowLayoutPanel
    $script:ListPanel.Location = New-Object Drawing.Point($listX, ($top + (UiPx 48)))
    $script:ListPanel.Size = New-Object Drawing.Size($listW, ($bodyH - (UiPx 48)))
    $script:ListPanel.BackColor = [Drawing.Color]::Transparent
    $script:ListPanel.FlowDirection = [Windows.Forms.FlowDirection]::TopDown
    $script:ListPanel.WrapContents = $false
    $script:ListPanel.AutoScroll = $true
    $script:ListPanel.Padding = New-Object Windows.Forms.Padding((UiPx 12), (UiPx 8), (UiPx 12), (UiPx 8))
    $form.Controls.Add($script:ListPanel)
    $script:ListPanel.Add_SizeChanged({ Fit-GameCards })

    $script:ListPanel.Add_MouseWheel({
            param($s, $e)
            $script:ListPanel.AutoScrollPosition = New-Object Drawing.Point(0, (-$script:ListPanel.VerticalScroll.Value - (($e.Delta / 120) * 60)))
        })

    # ---------------- 状态栏 ----------------
    $bar = New-Object Windows.Forms.Panel
    $bar.Location = New-Object Drawing.Point(0, ($ch - (UiPx 32)))
    $bar.Size = New-Object Drawing.Size($cw, (UiPx 32))
    $bar.BackColor = [Drawing.Color]::Transparent
    $bar.Add_Paint({
            param($s, $e)
            $g = $e.Graphics
            $a = [int](255 * $script:CardOpacity / 100)
            $br = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb($a, (UiColor 'panel')))
            $g.FillRectangle($br, 0, 0, $this.Width, $this.Height)
            $br.Dispose()
        })
    $form.Controls.Add($bar)

    $script:StatusLabel = New-Object Windows.Forms.Label
    $script:StatusLabel.AutoSize = $false
    $script:StatusLabel.Location = New-Object Drawing.Point((UiPx 24), 0)
    $script:StatusLabel.Size = New-Object Drawing.Size(($cw - (UiPx 620)), (UiPx 32))
    $script:StatusLabel.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
    $script:StatusLabel.Font = UiFont 8.5 'regular'
    $script:StatusLabel.ForeColor = UiColor 'muted'
    $script:StatusLabel.BackColor = [Drawing.Color]::Transparent
    $bar.Controls.Add($script:StatusLabel)

    $barHint = New-Object Windows.Forms.Label
    $barHint.Text = '点卡片选中 · 双击启动 · 右键更多'
    $barHint.AutoSize = $false
    $barHint.Location = New-Object Drawing.Point(($cw - (UiPx 570)), 0)
    $barHint.Size = New-Object Drawing.Size((UiPx 370), (UiPx 32))
    $barHint.TextAlign = [Drawing.ContentAlignment]::MiddleRight
    $barHint.Font = UiFont 8 'regular'
    $barHint.ForeColor = UiColor 'muted'
    $barHint.BackColor = [Drawing.Color]::Transparent
    $bar.Controls.Add($barHint)

    $logLink = New-Object Windows.Forms.Label
    $logLink.Text = '打开日志'
    $logLink.AutoSize = $true
    $logLink.Location = New-Object Drawing.Point(($cw - (UiPx 190)), (UiPx 7))
    $logLink.Font = UiFont 8.5 'regular'
    $logLink.ForeColor = UiColor 'muted'
    $logLink.BackColor = [Drawing.Color]::Transparent
    $logLink.Cursor = [Windows.Forms.Cursors]::Hand
    $logLink.Add_Click({ if ($global:LogFile) { Start-Process notepad.exe $global:LogFile | Out-Null } })
    $bar.Controls.Add($logLink)

    $ver = New-Object Windows.Forms.Label
    $ver.Text = 'v0.18'
    $ver.AutoSize = $true
    $ver.BackColor = [Drawing.Color]::Transparent
    $ver.Location = New-Object Drawing.Point(($cw - (UiPx 64)), (UiPx 7))
    $ver.Font = UiFont 8.5 'regular'
    $ver.ForeColor = UiColor 'muted'
    $bar.Controls.Add($ver)

    # ---------------- 定时器 ----------------
    $script:Timer = New-Object Windows.Forms.Timer
    $script:Timer.Interval = 700
    $script:Timer.Add_Tick({
            $running = $script:RunProc -and -not $script:RunProc.HasExited
            if ($script:RunProc -and $script:RunProc.HasExited) {
                $script:RunProc.Dispose()
                $script:RunProc = $null
                $script:RunningGame = $null
                $script:Timer.Stop()
                Update-GameList
                Set-UiStatus '游戏已结束，存档已收尾。' 'ok'
                Set-DetailLayout 'idle' $true
            } elseif ($running) {
                Update-DetailPanel
                Update-LogView
                $t = Get-UiLogTail 1
                if ($t) { Set-UiStatus $t 'default' }
            }
        })

    $form.Add_KeyDown({
            param($s, $e)
            if ($e.KeyCode -eq 'F5') { Update-GameList; Set-UiStatus '已刷新游戏列表。' 'ok' }
            if ($e.KeyCode -eq 'Escape') { $form.Close() }
        })

    $form.Add_Shown({
        if ('PglWin' -as [type]) {
            try {
                $round = 2
                [void][PglWin]::DwmSetWindowAttribute($form.Handle, 33, [ref]$round, 4)
            } catch { }
        }
        $btnClose.BringToFront()
        $btnMin.BringToFront()
        Update-GameList
        Update-LogView
        Set-DetailLayout 'idle' $false
    })
    $form.Add_FormClosed({
            if ($script:Timer) { $script:Timer.Stop(); $script:Timer.Dispose() }
        })

    if ($Config -and $Config.TopMost) { Set-UiTopMost $true $false }

    [void]$form.ShowDialog()
}
