# ui/SettingsWindow.ps1 - 全局设置（深色）
# 依赖：MainWindow.ps1 已 dot-source（UiColor/UiPx/UiFont/New-UiGhostButton/Set-UiRounded/Set-UiStatus）

function Show-SettingsWindow {
    param($Owner)

    $cfg = Read-GlobalConfig

    $form = New-Object Windows.Forms.Form
    $form.Text = '设置'
    $form.FormBorderStyle = [Windows.Forms.FormBorderStyle]::FixedSingle
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.StartPosition = [Windows.Forms.FormStartPosition]::CenterParent
    $form.BackColor = UiColor 'bg'
    $form.ForeColor = UiColor 'text'
    $form.Font = UiFont 9 'regular'
    $form.ClientSize = New-Object Drawing.Size((UiPx 620), (UiPx 546))
    $form.ShowInTaskbar = $false

    $title = New-Object Windows.Forms.Label
    $title.Text = '设置'
    $title.AutoSize = $false
    $title.Size = New-Object Drawing.Size((UiPx 560), (UiPx 34))
    $title.Location = New-Object Drawing.Point((UiPx 30), (UiPx 22))
    $title.Font = New-Object Drawing.Font('Microsoft YaHei UI', 15, [Drawing.FontStyle]::Bold, [Drawing.GraphicsUnit]::Point)
    $title.ForeColor = UiColor 'text'
    $title.BackColor = [Drawing.Color]::Transparent

    $sub = New-Object Windows.Forms.Label
    $sub.Text = '这些是整台 U 盘的全局设置，保存在 Launcher\config.ini。'
    $sub.AutoSize = $false
    $sub.Size = New-Object Drawing.Size((UiPx 560), (UiPx 22))
    $sub.Location = New-Object Drawing.Point((UiPx 30), (UiPx 58))
    $sub.Font = UiFont 8.5 'regular'
    $sub.ForeColor = UiColor 'muted'
    $sub.BackColor = [Drawing.Color]::Transparent

    $form.Controls.Add($title)
    $form.Controls.Add($sub)

    function New-SettingLabel([string]$text, [int]$y, [int]$w) {
        $l = New-Object Windows.Forms.Label
        $l.Text = $text
        $l.AutoSize = $false
        $l.Size = New-Object Drawing.Size((UiPx $w), (UiPx 24))
        $l.Location = New-Object Drawing.Point((UiPx 30), (UiPx $y))
        $l.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
        $l.Font = UiFont 9 'regular'
        $l.ForeColor = UiColor 'text'
        $l.BackColor = [Drawing.Color]::Transparent
        $form.Controls.Add($l)
        return $l
    }

    # 接管模式
    [void](New-SettingLabel '接管模式' 104 120)
    $mode = New-Object Windows.Forms.ComboBox
    $mode.DropDownStyle = [Windows.Forms.ComboBoxStyle]::DropDownList
    $mode.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $mode.BackColor = UiColor 'bg2'
    $mode.ForeColor = UiColor 'text'
    $mode.Font = UiFont 9 'regular'
    $mode.Size = New-Object Drawing.Size((UiPx 300), (UiPx 28))
    $mode.Location = New-Object Drawing.Point((UiPx 160), (UiPx 102))
    [void]$mode.Items.Add([pscustomobject]@{ Text = '自动：优先联接，失败降级复制'; Value = 'auto' })
    [void]$mode.Items.Add([pscustomobject]@{ Text = '只联接：建不了就报错'; Value = 'link' })
    [void]$mode.Items.Add([pscustomobject]@{ Text = '只复制：不建联接，进出各拷一次'; Value = 'copy' })
    $mode.DisplayMember = 'Text'
    $mode.ValueMember = 'Value'
    $idx = 0
    for ($i = 0; $i -lt $mode.Items.Count; $i++) {
        if ($mode.Items[$i].Value -eq $cfg.Mode) { $idx = $i }
    }
    $mode.SelectedIndex = $idx
    $form.Controls.Add($mode)
    $script:SetModeBox = $mode

    # 快照保留
    [void](New-SettingLabel '快照保留份数' 152 120)
    $keep = New-Object Windows.Forms.NumericUpDown
    $keep.Minimum = 1
    $keep.Maximum = 20
    $keep.Value = [decimal][math]::Max(1, [math]::Min(20, $cfg.SnapshotKeep))
    $keep.BackColor = UiColor 'bg2'
    $keep.ForeColor = UiColor 'text'
    $keep.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle
    $keep.Font = UiFont 9 'regular'
    $keep.Size = New-Object Drawing.Size((UiPx 90), (UiPx 26))
    $keep.Location = New-Object Drawing.Point((UiPx 160), (UiPx 151))
    $form.Controls.Add($keep)

    $keepHint = New-Object Windows.Forms.Label
    $keepHint.Text = '每个游戏在 Snapshots\ 下最多留几份，旧的自动清掉。'
    $keepHint.AutoSize = $false
    $keepHint.Size = New-Object Drawing.Size((UiPx 340), (UiPx 22))
    $keepHint.Location = New-Object Drawing.Point((UiPx 262), (UiPx 154))
    $keepHint.Font = UiFont 8.5 'regular'
    $keepHint.ForeColor = UiColor 'muted'
    $keepHint.BackColor = [Drawing.Color]::Transparent
    $form.Controls.Add($keepHint)

    # 快照上限
    [void](New-SettingLabel '快照上限 MB' 196 120)
    $mb = New-Object Windows.Forms.NumericUpDown
    $mb.Minimum = 50
    $mb.Maximum = 4096
    $mb.Increment = 50
    $mb.Value = [decimal][math]::Max(50, [math]::Min(4096, $cfg.MaxSnapshotMB))
    $mb.BackColor = UiColor 'bg2'
    $mb.ForeColor = UiColor 'text'
    $mb.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle
    $mb.Font = UiFont 9 'regular'
    $mb.Size = New-Object Drawing.Size((UiPx 90), (UiPx 26))
    $mb.Location = New-Object Drawing.Point((UiPx 160), (UiPx 195))
    $form.Controls.Add($mb)

    $mbHint = New-Object Windows.Forms.Label
    $mbHint.Text = '单次快照超过这个体积就跳过，避免 U 盘被拖慢。'
    $mbHint.AutoSize = $false
    $mbHint.Size = New-Object Drawing.Size((UiPx 340), (UiPx 22))
    $mbHint.Location = New-Object Drawing.Point((UiPx 262), (UiPx 198))
    $mbHint.Font = UiFont 8.5 'regular'
    $mbHint.ForeColor = UiColor 'muted'
    $mbHint.BackColor = [Drawing.Color]::Transparent
    $form.Controls.Add($mbHint)

    # 排除目录
    [void](New-SettingLabel '排除目录' 240 120)
    $ex = New-Object Windows.Forms.TextBox
    $ex.Text = ($cfg.ExcludeDirs -join ',')
    $ex.BackColor = UiColor 'bg2'
    $ex.ForeColor = UiColor 'text'
    $ex.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle
    $ex.Font = UiFont 9 'regular'
    $ex.Size = New-Object Drawing.Size((UiPx 430), (UiPx 26))
    $ex.Location = New-Object Drawing.Point((UiPx 160), (UiPx 239))
    $form.Controls.Add($ex)

    $exHint = New-Object Windows.Forms.Label
    $exHint.Text = '逗号分隔；任何层级同名目录都会在快照/复制时跳过（缓存、日志等）。'
    $exHint.AutoSize = $false
    $exHint.Size = New-Object Drawing.Size((UiPx 430), (UiPx 22))
    $exHint.Location = New-Object Drawing.Point((UiPx 160), (UiPx 268))
    $exHint.Font = UiFont 8.5 'regular'
    $exHint.ForeColor = UiColor 'muted'
    $exHint.BackColor = [Drawing.Color]::Transparent
    $form.Controls.Add($exHint)


    # ---------------- 外观 ----------------
    [void](New-SettingLabel '背景壁纸' 296 120)
    $wall = New-Object Windows.Forms.TextBox
    $wall.Text = [string]$cfg.Wallpaper
    $wall.BackColor = UiColor 'bg2'
    $wall.ForeColor = UiColor 'text'
    $wall.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle
    $wall.Font = UiFont 9 'regular'
    $wall.Size = New-Object Drawing.Size((UiPx 296), (UiPx 26))
    $wall.Location = New-Object Drawing.Point((UiPx 160), (UiPx 295))
    $form.Controls.Add($wall)
    $wallBrowse = New-UiGhostButton '浏览…' (UiPx 462) (UiPx 292) (UiPx 66)
    $wallBrowse.Add_Click({
            $dlg = New-Object Windows.Forms.OpenFileDialog
            $dlg.Title = '选择背景壁纸'
            $dlg.Filter = '图片|*.jpg;*.jpeg;*.png;*.bmp;*.webp|所有文件|*.*'
            if ($dlg.ShowDialog() -eq [Windows.Forms.DialogResult]::OK) {
                try {
                    $ext = [IO.Path]::GetExtension($dlg.FileName).ToLowerInvariant()
                    if (-not $ext) { $ext = '.png' }
                    $dest = Join-Path $script:UiRoot ('Launcher\wallpaper' + $ext)
                    Copy-Item -LiteralPath $dlg.FileName -Destination $dest -Force
                    $script:SetWallBox.Text = 'wallpaper' + $ext
                } catch {
                    [void][Windows.Forms.MessageBox]::Show('复制壁纸失败：' + $_.Exception.Message, 'AML')
                }
            }
        })
    $form.Controls.Add($wallBrowse)
    $wallClear = New-UiGhostButton '清除' (UiPx 532) (UiPx 292) (UiPx 58)
    $wallClear.Add_Click({ $script:SetWallBox.Text = '' })
    $form.Controls.Add($wallClear)

    [void](New-SettingLabel '壁纸透明度' 336 120)
    $wop = New-Object Windows.Forms.NumericUpDown
    $wop.Minimum = 0
    $wop.Maximum = 100
    $wop.Increment = 5
    $wop.Value = [decimal][math]::Max(0, [math]::Min(100, $cfg.WallpaperOpacity))
    $wop.BackColor = UiColor 'bg2'
    $wop.ForeColor = UiColor 'text'
    $wop.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle
    $wop.Font = UiFont 9 'regular'
    $wop.Size = New-Object Drawing.Size((UiPx 90), (UiPx 26))
    $wop.Location = New-Object Drawing.Point((UiPx 160), (UiPx 335))
    $form.Controls.Add($wop)
    $wopHint = New-Object Windows.Forms.Label
    $wopHint.Text = '0 = 看不见，100 = 原图。'
    $wopHint.AutoSize = $false
    $wopHint.Size = New-Object Drawing.Size((UiPx 300), (UiPx 22))
    $wopHint.Location = New-Object Drawing.Point((UiPx 262), (UiPx 338))
    $wopHint.Font = UiFont 8.5 'regular'
    $wopHint.ForeColor = UiColor 'muted'
    $wopHint.BackColor = [Drawing.Color]::Transparent
    $form.Controls.Add($wopHint)

    [void](New-SettingLabel '卡片透明度' 376 120)
    $cop = New-Object Windows.Forms.NumericUpDown
    $cop.Minimum = 20
    $cop.Maximum = 100
    $cop.Increment = 5
    $cop.Value = [decimal][math]::Max(20, [math]::Min(100, $cfg.PanelOpacity))
    $cop.BackColor = UiColor 'bg2'
    $cop.ForeColor = UiColor 'text'
    $cop.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle
    $cop.Font = UiFont 9 'regular'
    $cop.Size = New-Object Drawing.Size((UiPx 90), (UiPx 26))
    $cop.Location = New-Object Drawing.Point((UiPx 160), (UiPx 375))
    $form.Controls.Add($cop)
    $copHint = New-Object Windows.Forms.Label
    $copHint.Text = '左侧详情卡与右侧游戏卡共用，100 = 不透明。'
    $copHint.AutoSize = $false
    $copHint.Size = New-Object Drawing.Size((UiPx 330), (UiPx 22))
    $copHint.Location = New-Object Drawing.Point((UiPx 262), (UiPx 378))
    $copHint.Font = UiFont 8.5 'regular'
    $copHint.ForeColor = UiColor 'muted'
    $copHint.BackColor = [Drawing.Color]::Transparent
    $form.Controls.Add($copHint)
    $tip = New-Object Windows.Forms.Label
    $tip.Text = '保存后对下一次启动生效；已经建好的联接不会被打断。'
    $tip.AutoSize = $false
    $tip.Size = New-Object Drawing.Size((UiPx 460), (UiPx 22))
    $tip.Location = New-Object Drawing.Point((UiPx 30), (UiPx 424))
    $tip.Font = UiFont 8.5 'regular'
    $tip.ForeColor = UiColor 'amber'
    $tip.BackColor = [Drawing.Color]::Transparent
    $form.Controls.Add($tip)

    $scanNote = New-Object Windows.Forms.Label
    $scanNote.Text = '扫描排除/跳过名单：编辑 Launcher\scan-lists.ini，改完保存，下一次扫描生效。'
    $scanNote.AutoSize = $false
    $scanNote.Size = New-Object Drawing.Size((UiPx 450), (UiPx 22))
    $scanNote.Location = New-Object Drawing.Point((UiPx 30), (UiPx 448))
    $scanNote.Font = UiFont 8.5 'regular'
    $scanNote.ForeColor = UiColor 'muted'
    $scanNote.BackColor = [Drawing.Color]::Transparent
    $form.Controls.Add($scanNote)

    $scanOpen = New-UiGhostButton '打开名单…' (UiPx 492) (UiPx 444) (UiPx 100)
    $scanOpen.Add_Click({
        $f = Join-Path $script:UiRoot 'Launcher\scan-lists.ini'
        if (Test-Path -LiteralPath $f) { Start-Process notepad.exe -ArgumentList ('"' + $f + '"') }
    })
    $form.Controls.Add($scanOpen)
    $cancel = New-UiGhostButton '取消' (UiPx 350) (UiPx 496) (UiPx 90)
    $cancel.Add_Click({ $script:SetForm.Close() })
    $form.Controls.Add($cancel)

    $save = New-Object Windows.Forms.Button
    $save.Text = '保存'
    $save.Size = New-Object Drawing.Size((UiPx 110), (UiPx 36))
    $save.Location = New-Object Drawing.Point((UiPx 456), (UiPx 494))
    $save.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $save.FlatAppearance.BorderSize = 0
    $save.FlatAppearance.MouseOverBackColor = UiColor 'roseHover'
    $save.BackColor = UiColor 'rose'
    $save.ForeColor = [Drawing.Color]::White
    $save.Font = UiFont 9.5 'bold'
    $save.Cursor = [Windows.Forms.Cursors]::Hand
    $save.UseVisualStyleBackColor = $false
    Set-UiRounded $save (UiPx 10)
    $save.Add_Click({
            $modeVal = $script:SetModeBox.SelectedItem.Value
            $keepVal = [int]$script:SetKeepBox.Value
            $mbVal = [int]$script:SetMbBox.Value
            $exVal = ($script:SetExBox.Text -replace '\s+', '').Trim(',')
            $wallVal = $script:SetWallBox.Text.Trim()
            $wopVal = [int]$script:SetWallOpacity.Value
            $copVal = [int]$script:SetCardOpacity.Value
            $topVal = if ($global:Config.TopMost) { '1' } else { '0' }
            $lines = @(
                '; U盘游戏启动器 - 全局配置'
                '[general]'
                '; auto = 优先目录联接，失败自动降级为复制；link = 只用联接；copy = 只用复制'
                ('mode=' + $modeVal)
                '; 每个游戏保留最近几份存档快照'
                ('snapshot_keep=' + $keepVal)
                '; 单次快照体积上限（MB），超过则跳过本次快照'
                ('max_snapshot_mb=' + $mbVal)
                '; 日志保留天数（启动时自动删除更早的 launcher_*.log）'
                ('log_keep_days=' + [int]$global:Config.LogKeepDays)
                '; 每个游戏保留最近几份「接管前备份」'
                ('backup_keep=' + [int]$global:Config.BackupKeep)
                '; 快照/复制时跳过的目录名（缓存、日志之类，任何层级同名目录都会跳过）'
                ('exclude_dirs=' + $exVal)
                '; 窗口置顶（1=是）'
                ('topmost=' + $topVal)
                '; 背景壁纸（相对 Launcher 目录，留空则纯色）'
                ('wallpaper=' + $wallVal)
                '; 壁纸不透明度 0-100'
                ('wallpaper_opacity=' + $wopVal)
                '; 卡片不透明度 0-100（左侧详情卡与游戏卡共用）'
                ('panel_opacity=' + $copVal)
            )
            $path = (Join-Path $script:UiRoot 'Launcher\config.ini')
            $enc = New-Object System.Text.UTF8Encoding($true)
            [IO.File]::WriteAllText($path, (($lines -join "`r`n") + "`r`n"), $enc)
            $global:Config = Read-GlobalConfig
            Set-UiStatus '设置已保存，下一次启动生效。' 'ok'
            $script:SetForm.Close()
        })
    $form.Controls.Add($save)

    $form.AcceptButton = $save
    $form.CancelButton = $cancel

    $script:SetForm = $form
    $script:SetKeepBox = $keep
    $script:SetMbBox = $mb
    $script:SetExBox = $ex
    $script:SetWallBox = $wall
    $script:SetWallOpacity = $wop
    $script:SetCardOpacity = $cop

    if ($Owner -and $Owner.TopMost) { $form.TopMost = $true }
    [void]$form.ShowDialog($Owner)
    $form.Dispose()
}
