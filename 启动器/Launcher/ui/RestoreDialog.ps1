# ui/RestoreDialog.ps1 - 「还原到本机」确认与执行
# 依赖：MainWindow.ps1 已 dot-source；lib\Restore.ps1 已加载

function Show-RestoreDialog {
    param($Game, $Owner)

    if (-not $Game) { return }
    if ($script:RunProc -and $script:RunningGame -and $script:RunningGame.Id -eq $Game.Id) {
        [void][Windows.Forms.MessageBox]::Show('这个游戏正在运行，退出后再还原。', '还原到本机', 'OK', 'Warning')
        return
    }
    if ((@($Game.Mappings).Count -eq 0) -and (@($Game.RegistryMappings).Count -eq 0)) {
        [void][Windows.Forms.MessageBox]::Show('这个游戏没有配置存档映射，无需还原。', '还原到本机', 'OK', 'Information')
        return
    }

    $form = New-Object Windows.Forms.Form
    $form.Text = '还原到本机'
    $form.FormBorderStyle = [Windows.Forms.FormBorderStyle]::FixedSingle
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.StartPosition = [Windows.Forms.FormStartPosition]::CenterParent
    $form.BackColor = UiColor 'bg'
    $form.ForeColor = UiColor 'text'
    $form.Font = UiFont 9 'regular'
    $form.ClientSize = New-Object Drawing.Size((UiPx 640), (UiPx 360))
    $form.ShowInTaskbar = $false

    $title = New-Object Windows.Forms.Label
    $title.Text = '还原到本机'
    $title.AutoSize = $false
    $title.Size = New-Object Drawing.Size((UiPx 580), (UiPx 34))
    $title.Location = New-Object Drawing.Point((UiPx 30), (UiPx 24))
    $title.Font = New-Object Drawing.Font('Microsoft YaHei UI', 15, [Drawing.FontStyle]::Bold, [Drawing.GraphicsUnit]::Point)
    $title.ForeColor = UiColor 'text'
    $title.BackColor = [Drawing.Color]::Transparent

    $sub = New-Object Windows.Forms.Label
    $sub.Text = $Game.Name + '  ·  ' + $Game.Id
    $sub.AutoSize = $false
    $sub.Size = New-Object Drawing.Size((UiPx 580), (UiPx 22))
    $sub.Location = New-Object Drawing.Point((UiPx 30), (UiPx 62))
    $sub.Font = UiFont 8.5 'regular'
    $sub.ForeColor = UiColor 'muted'
    $sub.BackColor = [Drawing.Color]::Transparent

    $body = New-Object Windows.Forms.Label
    $body.Text = "把 U 盘上的存档复制回本机，然后拆掉目录联接。`r`n`r`n之后这个游戏就像普通安装一样，存档写在本机；再点「启动」会重新接管、跟随 U 盘。`r`n`r`n本机已有同名目录时会先备份到 Backups\。"
    $body.AutoSize = $false
    $body.Size = New-Object Drawing.Size((UiPx 580), (UiPx 120))
    $body.Location = New-Object Drawing.Point((UiPx 30), (UiPx 94))
    $body.Font = UiFont 9 'regular'
    $body.ForeColor = UiColor 'muted'
    $body.BackColor = [Drawing.Color]::Transparent

    $chk = New-Object Windows.Forms.CheckBox
    $chk.Text = '同时删除 U 盘上的存档副本（还原后不再跟随 U 盘）'
    $chk.AutoSize = $false
    $chk.Size = New-Object Drawing.Size((UiPx 580), (UiPx 26))
    $chk.Location = New-Object Drawing.Point((UiPx 30), (UiPx 226))
    $chk.Font = UiFont 9 'regular'
    $chk.ForeColor = UiColor 'amber'
    $chk.BackColor = [Drawing.Color]::Transparent
    $chk.FlatStyle = [Windows.Forms.FlatStyle]::Flat

    $cancel = New-UiGhostButton '取消' (UiPx 350) (UiPx 296) (UiPx 90)
    $cancel.Add_Click({ $script:RestoreForm.Close() })
    $form.Controls.Add($cancel)

    $ok = New-Object Windows.Forms.Button
    $ok.Text = '还原'
    $ok.Size = New-Object Drawing.Size((UiPx 110), (UiPx 36))
    $ok.Location = New-Object Drawing.Point((UiPx 472), (UiPx 294))
    $ok.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $ok.FlatAppearance.BorderSize = 0
    $ok.FlatAppearance.MouseOverBackColor = UiColor 'roseHover'
    $ok.BackColor = UiColor 'rose'
    $ok.ForeColor = [Drawing.Color]::White
    $ok.Font = UiFont 9.5 'bold'
    $ok.Cursor = [Windows.Forms.Cursors]::Hand
    $ok.UseVisualStyleBackColor = $false
    Set-UiRounded $ok (UiPx 10)
    $ok.Add_Click({
            $script:RestoreBtn.Enabled = $false
            $script:RestoreBtn.Text = '还原中…'
            $script:RestoreForm.Cursor = [Windows.Forms.Cursors]::WaitCursor
            $game = $script:RestoreGame
            try {
                $notes = Restore-GameToLocal $game -DeleteStore:$script:RestoreChk.Checked
                Update-GameList
                $msg = (@($notes) -join "`r`n")
                if (-not $msg) { $msg = '完成。' }
                [void][Windows.Forms.MessageBox]::Show($msg, '还原完成', 'OK', 'Information')
                Set-UiStatus ($game.Name + ' 已还原到本机。') 'ok'
                $script:RestoreForm.Close()
            } catch {
                [void][Windows.Forms.MessageBox]::Show(('还原失败：' + $_.Exception.Message), '还原到本机', 'OK', 'Error')
            } finally {
                if ($script:RestoreForm -and -not $script:RestoreForm.IsDisposed) {
                    $script:RestoreForm.Cursor = [Windows.Forms.Cursors]::Default
                }
            }
        })
    $form.Controls.Add($ok)

    $form.Controls.Add($title)
    $form.Controls.Add($sub)
    $form.Controls.Add($body)
    $form.Controls.Add($chk)

    $form.AcceptButton = $ok
    $form.CancelButton = $cancel

    $script:RestoreForm = $form
    $script:RestoreChk = $chk
    $script:RestoreBtn = $ok
    $script:RestoreGame = $Game

    if ($Owner -and $Owner.TopMost) { $form.TopMost = $true }
    [void]$form.ShowDialog($Owner)
    $form.Dispose()
}
