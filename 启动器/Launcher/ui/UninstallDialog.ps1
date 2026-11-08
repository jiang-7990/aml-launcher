# ui/UninstallDialog.ps1 - 「卸载游戏」确认与执行
# 依赖：MainWindow.ps1 已 dot-source；lib\Uninstall.ps1、lib\Restore.ps1 已加载

function Show-UninstallDialog {
    param($Game, $Owner)

    if (-not $Game) { return }
    if ($script:RunProc -and $script:RunningGame -and $script:RunningGame.Id -eq $Game.Id) {
        [void][Windows.Forms.MessageBox]::Show('这个游戏正在运行，退出后再卸载。', '卸载游戏', 'OK', 'Warning')
        return
    }

    $form = New-Object Windows.Forms.Form
    $form.Text = '卸载游戏'
    $form.FormBorderStyle = [Windows.Forms.FormBorderStyle]::FixedSingle
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.StartPosition = [Windows.Forms.FormStartPosition]::CenterParent
    $form.BackColor = UiColor 'bg'
    $form.ForeColor = UiColor 'text'
    $form.Font = UiFont 9 'regular'
    $form.ClientSize = New-Object Drawing.Size((UiPx 640), (UiPx 400))
    $form.ShowInTaskbar = $false

    $title = New-Object Windows.Forms.Label
    $title.Text = '卸载游戏'
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
    $body.Text = "把游戏从启动器列表里移除，并删除它的 profile 配置。`r`n`r`n默认先把 U 盘存档还原到本机、再删 U 盘副本；游戏文件默认保留在 Games\ 下，可手动删。"
    $body.AutoSize = $false
    $body.Size = New-Object Drawing.Size((UiPx 580), (UiPx 100))
    $body.Location = New-Object Drawing.Point((UiPx 30), (UiPx 94))
    $body.Font = UiFont 9 'regular'
    $body.ForeColor = UiColor 'muted'
    $body.BackColor = [Drawing.Color]::Transparent

    $chkRestore = New-Object Windows.Forms.CheckBox
    $chkRestore.Text = '先把 U 盘存档还原到本机（并删除 U 盘副本）'
    $chkRestore.AutoSize = $false
    $chkRestore.Size = New-Object Drawing.Size((UiPx 580), (UiPx 26))
    $chkRestore.Location = New-Object Drawing.Point((UiPx 30), (UiPx 204))
    $chkRestore.Font = UiFont 9 'regular'
    $chkRestore.ForeColor = UiColor 'text'
    $chkRestore.BackColor = [Drawing.Color]::Transparent
    $chkRestore.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $chkRestore.Checked = $true

    $chkFiles = New-Object Windows.Forms.CheckBox
    $chkFiles.Text = '同时删除 Games\ 下的游戏文件（不可恢复）'
    $chkFiles.AutoSize = $false
    $chkFiles.Size = New-Object Drawing.Size((UiPx 580), (UiPx 26))
    $chkFiles.Location = New-Object Drawing.Point((UiPx 30), (UiPx 236))
    $chkFiles.Font = UiFont 9 'regular'
    $chkFiles.ForeColor = UiColor 'amber'
    $chkFiles.BackColor = [Drawing.Color]::Transparent
    $chkFiles.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $chkFiles.Checked = $false

    $cancel = New-UiGhostButton '取消' (UiPx 350) (UiPx 336) (UiPx 90)
    $cancel.Add_Click({ $script:UninstallForm.Close() })
    $form.Controls.Add($cancel)

    $ok = New-Object Windows.Forms.Button
    $ok.Text = '卸载'
    $ok.Size = New-Object Drawing.Size((UiPx 110), (UiPx 36))
    $ok.Location = New-Object Drawing.Point((UiPx 472), (UiPx 334))
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
            $script:UninstallBtn.Enabled = $false
            $script:UninstallBtn.Text = '处理中…'
            $script:UninstallForm.Cursor = [Windows.Forms.Cursors]::WaitCursor
            $game = $script:UninstallGame
            try {
                $notes = Uninstall-Game $game -Restore:$script:UninstallChkRestore.Checked -DeleteFiles:$script:UninstallChkFiles.Checked
                Update-GameList
                $msg = (@($notes) -join "`r`n")
                if (-not $msg) { $msg = '完成。' }
                [void][Windows.Forms.MessageBox]::Show($msg, '卸载完成', 'OK', 'Information')
                Set-UiStatus ($game.Name + ' 已从启动器移除。') 'ok'
                $script:UninstallForm.Close()
            } catch {
                [void][Windows.Forms.MessageBox]::Show(('卸载失败：' + $_.Exception.Message), '卸载游戏', 'OK', 'Error')
            } finally {
                if ($script:UninstallForm -and -not $script:UninstallForm.IsDisposed) {
                    $script:UninstallForm.Cursor = [Windows.Forms.Cursors]::Default
                }
            }
        })
    $form.Controls.Add($ok)

    $form.Controls.Add($title)
    $form.Controls.Add($sub)
    $form.Controls.Add($body)
    $form.Controls.Add($chkRestore)
    $form.Controls.Add($chkFiles)

    $form.AcceptButton = $ok
    $form.CancelButton = $cancel

    $script:UninstallForm = $form
    $script:UninstallChkRestore = $chkRestore
    $script:UninstallChkFiles = $chkFiles
    $script:UninstallBtn = $ok
    $script:UninstallGame = $Game

    if ($Owner -and $Owner.TopMost) { $form.TopMost = $true }
    [void]$form.ShowDialog($Owner)
    $form.Dispose()
}
