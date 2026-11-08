# ui/LearnWindow.ps1 - 学习存档位置对话框
# 依赖：MainWindow.ps1 的 UiColor/UiFont/UiPx/Set-UiRounded/New-UiGhostButton
#        lib\Learn.ps1、lib\Launch.ps1（Job Object）

$script:LearnProc = $null
$script:LearnJob = [IntPtr]::Zero
$script:LearnZero = 0
$script:LearnGame = $null
$script:LearnCandidates = @()

function Set-LearnStatus([string]$text, [string]$kind = 'default') {
    if (-not $script:LearnStatus) { return }
    $script:LearnStatus.Text = $text
    switch ($kind) {
        'error' { $script:LearnStatus.ForeColor = UiColor 'red' }
        'warn'  { $script:LearnStatus.ForeColor = UiColor 'amber' }
        'ok'    { $script:LearnStatus.ForeColor = UiColor 'green' }
        default { $script:LearnStatus.ForeColor = UiColor 'muted' }
    }
    [Windows.Forms.Application]::DoEvents()
}

function Set-LearnPrimary($btn, [bool]$enabled) {
    if (-not $btn) { return }
    $btn.Enabled = $enabled
    if ($enabled) {
        $btn.BackColor = UiColor 'rose'
        $btn.ForeColor = [Drawing.Color]::White
        $btn.FlatAppearance.MouseOverBackColor = UiColor 'roseHover'
        $btn.Cursor = [Windows.Forms.Cursors]::Hand
    } else {
        $btn.BackColor = UiColor 'bg2'
        $btn.ForeColor = UiColor 'muted'
        $btn.FlatAppearance.MouseOverBackColor = UiColor 'bg2'
        $btn.Cursor = [Windows.Forms.Cursors]::Default
    }
}

function Complete-LearnRun {
    $script:LearnTimer.Stop()
    if ($script:LearnJob -ne [IntPtr]::Zero) {
        [PglJob]::Close($script:LearnJob)
        $script:LearnJob = [IntPtr]::Zero
    }
    $script:LearnProc = $null

    Set-LearnStatus '游戏已退出，正在拍第二次快照…'
    $after = New-LearnSnapshot $script:LearnGame 'after'
    $regAfter = New-LearnRegSnapshot $script:LearnGame 'after'
    Set-LearnStatus '正在对比文件和注册表差异…'
    $cands = @(Compare-LearnSnapshots $script:LearnBefore $after $script:LearnGame)
    if ($script:LearnRegBefore) {
        $cands += @(Compare-LearnRegSnapshots $script:LearnRegBefore $regAfter $script:LearnGame)
    }
    $script:LearnCandidates = $cands

    $script:LearnList.Items.Clear()
    foreach ($c in $cands) {
        if ($c.Kind -eq 'registry') {
            $text = '注册表 {0}    · {1} 个值 · 得分 {2}' -f $c.Local, $c.Files, $c.Score
        } else {
            $text = '{0}    · {1} 文件 / {2} MB · 得分 {3}' -f $c.Local, $c.Files, $c.SizeMB, $c.Score
        }
        [void]$script:LearnList.Items.Add($text)
    }
    if ($cands.Count -gt 0) {
        $script:LearnList.SetItemChecked(0, $true)
        Set-LearnPrimary $script:LearnSave $true
        Set-LearnStatus ('分析完成：发现 {0} 个候选位置（目录或注册表），勾选要跟随 U 盘走的，再点「保存」。' -f $cands.Count) 'ok'
    } else {
        Set-LearnPrimary $script:LearnSave $false
        Set-LearnStatus '没有发现新增或变大的文件，也没有发现变化的注册表键。可能存档在已排除的目录、或游戏还没写盘。' 'warn'
    }
    Set-LearnPrimary $script:LearnStart $true
    $script:LearnStart.Text = '重新学习'
    $script:LearnForm.Cursor = [Windows.Forms.Cursors]::Default
    [Windows.Forms.Application]::DoEvents()
}

function Start-LearnRun {
    if ($script:LearnProc -and -not $script:LearnProc.HasExited) {
        Set-LearnStatus '游戏还在运行，先等它退出。' 'warn'
        return
    }
    $useLauncher = $false
    if ($script:LearnChoiceLauncher -and $script:LearnChoiceLauncher.Checked) { $useLauncher = $true }
    $targetExe = if ($useLauncher) { $script:LearnGame.Launcher } else { $script:LearnGame.Exe }
    if (-not $targetExe -or -not (Test-Path -LiteralPath $targetExe)) {
        $what = if ($useLauncher) { '启动器' } else { '游戏程序' }
        Set-LearnStatus ('找不到' + $what + '：' + $script:LearnGame.Dir) 'error'
        return
    }

    $script:LearnList.Items.Clear()
    Set-LearnPrimary $script:LearnSave $false
    Set-LearnPrimary $script:LearnStart $false
    $script:LearnStart.Text = '学习进行中…'
    $script:LearnForm.Cursor = [Windows.Forms.Cursors]::WaitCursor

    Set-LearnStatus '正在拍第一次快照（扫描常用存档目录和 HKCU 注册表，可能要十几秒）…'
    try {
        $script:LearnBefore = New-LearnSnapshot $script:LearnGame 'before'
        $script:LearnRegBefore = New-LearnRegSnapshot $script:LearnGame 'before'
    } catch {
        Set-LearnStatus ('快照失败：' + $_.Exception.Message) 'error'
        Set-LearnPrimary $script:LearnStart $true
        $script:LearnStart.Text = '重新学习'
        $script:LearnForm.Cursor = [Windows.Forms.Cursors]::Default
        return
    }

    Set-LearnStatus ('正在启动' + $(if ($useLauncher) { '启动器' } else { '游戏' }) + '…')
    try {
        $spArgs = @{
            FilePath         = $targetExe
            WorkingDirectory = $(if ($useLauncher) { Split-Path -Parent $targetExe } else { $script:LearnGame.WorkDir })
            PassThru         = $true
        }
        $runArgs = if ($useLauncher) { $script:LearnGame.LauncherArgs } else { $script:LearnGame.Args }
        if ($runArgs) { $spArgs['ArgumentList'] = $runArgs }
        $proc = Start-Process @spArgs
    } catch {
        Set-LearnStatus ('启动失败：' + $_.Exception.Message) 'error'
        Set-LearnPrimary $script:LearnStart $true
        $script:LearnStart.Text = '重新学习'
        $script:LearnForm.Cursor = [Windows.Forms.Cursors]::Default
        return
    }

    $script:LearnProc = $proc
    $script:LearnZero = 0
    $script:LearnJob = [IntPtr]::Zero
    try {
        Initialize-JobApi
        $script:LearnJob = New-GameJob -Proc $proc
    } catch { }

    $script:LearnForm.Cursor = [Windows.Forms.Cursors]::Default
    Set-LearnStatus ('游戏已启动（PID {0}）。玩到能存一次档，然后退出游戏，这里会自动分析。' -f $proc.Id) 'ok'
    $script:LearnTimer.Start()
}

function Show-LearnWindow {
    param($Game, $Owner)

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $script:LearnGame = $Game
    $script:LearnCandidates = @()
    $script:LearnRegBefore = $null
    $script:LearnProc = $null
    $script:LearnJob = [IntPtr]::Zero
    $script:LearnChoiceDirect = $null
    $script:LearnChoiceLauncher = $null

    $form = New-Object Windows.Forms.Form
    $form.Text = '学习存档位置'
    $form.FormBorderStyle = [Windows.Forms.FormBorderStyle]::FixedSingle
    $form.MaximizeBox = $false
    $form.StartPosition = [Windows.Forms.FormStartPosition]::CenterParent
    $form.BackColor = UiColor 'bg'
    $form.ForeColor = UiColor 'text'
    $form.Font = UiFont 9 'regular'
    $form.KeyPreview = $true
    $form.ClientSize = New-Object Drawing.Size((UiPx 780), (UiPx 640))
    $script:LearnForm = $form

    $header = New-Object Windows.Forms.Panel
    $header.Location = New-Object Drawing.Point(0, 0)
    $header.Size = New-Object Drawing.Size((UiPx 780), (UiPx 84))
    $header.Add_Paint({
            param($s, $e)
            $g = $e.Graphics
            $rect = New-Object Drawing.Rectangle 0, 0, $s.Width, $s.Height
            $brush = New-Object Drawing.Drawing2D.LinearGradientBrush($rect, (UiColor 'bg2'), (UiColor 'bg'), 90.0)
            $g.FillRectangle($brush, $rect)
            $brush.Dispose()
        })

    $title = New-Object Windows.Forms.Label
    $title.Text = '学习存档位置'
    $title.AutoSize = $false
    $title.Size = New-Object Drawing.Size((UiPx 440), (UiPx 28))
    $title.Location = New-Object Drawing.Point((UiPx 28), (UiPx 16))
    $title.Font = UiFont 15 'bold'
    $title.ForeColor = UiColor 'text'
    $title.BackColor = [Drawing.Color]::Transparent

    $sub = New-Object Windows.Forms.Label
    $sub.Text = $Game.Name + '  ·  ' + $Game.Id
    $sub.AutoSize = $false
    $sub.AutoEllipsis = $true
    $sub.Size = New-Object Drawing.Size((UiPx 700), (UiPx 20))
    $sub.Location = New-Object Drawing.Point((UiPx 30), (UiPx 48))
    $sub.Font = UiFont 9 'regular'
    $sub.ForeColor = UiColor 'muted'
    $sub.BackColor = [Drawing.Color]::Transparent

    $header.Controls.Add($title)
    $header.Controls.Add($sub)

    $desc = New-Object Windows.Forms.Label
    $desc.Text = '流程：拍快照 → 启动游戏玩到能存一次档 → 退出游戏 → 自动分析新增文件 → 勾选存档目录并保存。'
    $desc.AutoSize = $false
    $desc.Size = New-Object Drawing.Size((UiPx 724), (UiPx 22))
    $desc.Location = New-Object Drawing.Point((UiPx 28), (UiPx 96))
    $desc.Font = UiFont 9 'regular'
    $desc.ForeColor = UiColor 'muted'
    $desc.BackColor = [Drawing.Color]::Transparent

    $script:LearnStatus = New-Object Windows.Forms.Label
    $script:LearnStatus.Text = '点「开始学习」拍第一次快照，然后启动游戏。'
    $script:LearnStatus.AutoSize = $false
    $script:LearnStatus.Size = New-Object Drawing.Size((UiPx 724), (UiPx 22))
    $script:LearnStatus.Location = New-Object Drawing.Point((UiPx 28), (UiPx 126))
    $script:LearnStatus.Font = UiFont 9 'regular'
    $script:LearnStatus.ForeColor = UiColor 'muted'
    $script:LearnStatus.BackColor = [Drawing.Color]::Transparent

    $listY = 156
    $listH = 330
    if ($Game.HasLauncher -and $Game.Launcher -and (Test-Path -LiteralPath $Game.Launcher)) {
        $listY = 190
        $listH = 296

        $lblMode = New-Object Windows.Forms.Label
        $lblMode.Text = '启动方式：'
        $lblMode.AutoSize = $false
        $lblMode.Size = New-Object Drawing.Size((UiPx 82), (UiPx 24))
        $lblMode.Location = New-Object Drawing.Point((UiPx 28), (UiPx 154))
        $lblMode.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
        $lblMode.Font = UiFont 9 'regular'
        $lblMode.ForeColor = UiColor 'muted'
        $lblMode.BackColor = [Drawing.Color]::Transparent
        $form.Controls.Add($lblMode)

        $script:LearnChoiceDirect = New-Object Windows.Forms.RadioButton
        $script:LearnChoiceDirect.Text = '直接启动游戏'
        $script:LearnChoiceDirect.AutoSize = $false
        $script:LearnChoiceDirect.Size = New-Object Drawing.Size((UiPx 130), (UiPx 24))
        $script:LearnChoiceDirect.Location = New-Object Drawing.Point((UiPx 110), (UiPx 154))
        $script:LearnChoiceDirect.Checked = $true
        $script:LearnChoiceDirect.Font = UiFont 9 'regular'
        $script:LearnChoiceDirect.ForeColor = UiColor 'text'
        $script:LearnChoiceDirect.BackColor = [Drawing.Color]::Transparent
        $form.Controls.Add($script:LearnChoiceDirect)

        $script:LearnChoiceLauncher = New-Object Windows.Forms.RadioButton
        $script:LearnChoiceLauncher.Text = '经启动器'
        $script:LearnChoiceLauncher.AutoSize = $false
        $script:LearnChoiceLauncher.Size = New-Object Drawing.Size((UiPx 120), (UiPx 24))
        $script:LearnChoiceLauncher.Location = New-Object Drawing.Point((UiPx 246), (UiPx 154))
        $script:LearnChoiceLauncher.Font = UiFont 9 'regular'
        $script:LearnChoiceLauncher.ForeColor = UiColor 'text'
        $script:LearnChoiceLauncher.BackColor = [Drawing.Color]::Transparent
        $form.Controls.Add($script:LearnChoiceLauncher)
    }

    $script:LearnList = New-Object Windows.Forms.CheckedListBox
    $script:LearnList.Location = New-Object Drawing.Point((UiPx 28), (UiPx $listY))
    $script:LearnList.Size = New-Object Drawing.Size((UiPx 724), (UiPx $listH))
    $script:LearnList.BackColor = UiColor 'bg2'
    $script:LearnList.ForeColor = UiColor 'text'
    $script:LearnList.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle
    $script:LearnList.Font = UiFont 9 'regular'
    $script:LearnList.CheckOnClick = $true
    $script:LearnList.IntegralHeight = $false

    $info = New-Object Windows.Forms.Label
    $info.Text = '只统计新增或变大的文件；日志、缓存、临时目录、浏览器数据已跳过。注册表学习暂未开放。'
    $info.AutoSize = $false
    $info.Size = New-Object Drawing.Size((UiPx 724), (UiPx 22))
    $info.Location = New-Object Drawing.Point((UiPx 28), (UiPx 496))
    $info.Font = UiFont 8.5 'regular'
    $info.ForeColor = UiColor 'muted'
    $info.BackColor = [Drawing.Color]::Transparent

    $script:LearnStart = New-Object Windows.Forms.Button
    $script:LearnStart.Text = '开始学习'
    $script:LearnStart.Size = New-Object Drawing.Size((UiPx 150), (UiPx 40))
    $script:LearnStart.Location = New-Object Drawing.Point((UiPx 28), (UiPx 556))
    $script:LearnStart.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $script:LearnStart.FlatAppearance.BorderSize = 0
    $script:LearnStart.FlatAppearance.MouseOverBackColor = UiColor 'roseHover'
    $script:LearnStart.BackColor = UiColor 'rose'
    $script:LearnStart.ForeColor = [Drawing.Color]::White
    $script:LearnStart.Font = UiFont 10 'bold'
    $script:LearnStart.Cursor = [Windows.Forms.Cursors]::Hand
    $script:LearnStart.UseVisualStyleBackColor = $false
    $script:LearnStart.Add_Click({ Start-LearnRun })
    Set-UiRounded $script:LearnStart (UiPx 10)

    $script:LearnSave = New-Object Windows.Forms.Button
    $script:LearnSave.Text = '保存并关闭'
    $script:LearnSave.Size = New-Object Drawing.Size((UiPx 150), (UiPx 40))
    $script:LearnSave.Location = New-Object Drawing.Point((UiPx 420), (UiPx 556))
    $script:LearnSave.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $script:LearnSave.FlatAppearance.BorderSize = 0
    $script:LearnSave.FlatAppearance.MouseOverBackColor = UiColor 'roseHover'
    $script:LearnSave.BackColor = UiColor 'rose'
    $script:LearnSave.ForeColor = [Drawing.Color]::White
    $script:LearnSave.Font = UiFont 10 'bold'
    $script:LearnSave.Cursor = [Windows.Forms.Cursors]::Hand
    $script:LearnSave.UseVisualStyleBackColor = $false
    Set-LearnPrimary $script:LearnSave $false
    $script:LearnSave.Add_Click({
            $picked = @()
            foreach ($i in $script:LearnList.CheckedIndices) {
                $idx = [int]$i
                if ($idx -ge 0 -and $idx -lt $script:LearnCandidates.Count) {
                    $picked += $script:LearnCandidates[$idx]
                }
            }
            if ($picked.Count -eq 0) {
                Set-LearnStatus '先勾选至少一个目录。' 'warn'
                return
            }
            # 去掉被另一个勾选目录包含的子目录，避免重复映射
            $picked = @($picked | Sort-Object { $_.Dir.Length })
            $final = @()
            foreach ($c in $picked) {
                $nested = $false
                foreach ($p in $final) {
                    if ($c.Dir.StartsWith($p.Dir.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
                        $nested = $true
                        break
                    }
                }
                if (-not $nested) { $final += $c }
            }
            try {
                $n = Save-LearnMappings $script:LearnGame $final
                [void][Windows.Forms.MessageBox]::Show(('已写入 {0} 条存档映射。下次点「启动」就会接管这些目录。' -f $n), '学习完成')
                $script:LearnForm.DialogResult = [Windows.Forms.DialogResult]::OK
                $script:LearnForm.Close()
            } catch {
                Set-LearnStatus ('保存失败：' + $_.Exception.Message) 'error'
            }
        })
    Set-UiRounded $script:LearnSave (UiPx 10)
    Set-LearnPrimary $script:LearnSave $false

    $cancel = New-UiGhostButton '取消' (UiPx 640) (UiPx 560) (UiPx 112)
    $cancel.Size = New-Object Drawing.Size((UiPx 112), (UiPx 32))
    $cancel.Add_Click({
            if ($script:LearnTimer) { $script:LearnTimer.Stop() }
            if ($script:LearnJob -ne [IntPtr]::Zero) { [PglJob]::Close($script:LearnJob); $script:LearnJob = [IntPtr]::Zero }
            $script:LearnForm.Close()
        })

    $form.Controls.Add($header)
    $form.Controls.Add($desc)
    $form.Controls.Add($script:LearnStatus)
    $form.Controls.Add($script:LearnList)
    $form.Controls.Add($info)
    $form.Controls.Add($script:LearnStart)
    $form.Controls.Add($script:LearnSave)
    $form.Controls.Add($cancel)

    $script:LearnTimer = New-Object Windows.Forms.Timer
    $script:LearnTimer.Interval = 1000
    $script:LearnTimer.Add_Tick({
            if (-not $script:LearnProc) { $script:LearnTimer.Stop(); return }
            $active = -1
            if ($script:LearnJob -ne [IntPtr]::Zero) {
                $active = [PglJob]::Active($script:LearnJob)
            } else {
                if ($script:LearnProc.HasExited) { $active = 0 } else { $active = 1 }
            }
            if ($active -le 0) {
                $script:LearnZero++
                if ($script:LearnZero -ge 2) { Complete-LearnRun }
            } else {
                $script:LearnZero = 0
            }
        })

    $form.Add_KeyDown({
            if ($e.KeyCode -eq [Windows.Forms.Keys]::Escape) { $this.Close() }
        })

    $form.Add_FormClosed({
            if ($script:LearnTimer) { $script:LearnTimer.Stop() }
            if ($script:LearnJob -ne [IntPtr]::Zero) {
                [PglJob]::Close($script:LearnJob)
                $script:LearnJob = [IntPtr]::Zero
            }
            $script:LearnProc = $null
        })

    if ($Owner) { if ($Owner -and $Owner.TopMost) { $form.TopMost = $true }
    [void]$form.ShowDialog($Owner) } else { [void]$form.ShowDialog() }
}
