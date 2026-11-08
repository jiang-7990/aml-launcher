# SaveLocationWindow.ps1 -- 「存档位置」对话框
# 查看/修改/添加/删除一个游戏的存档映射（写回 profile 的 [mapping.N]）。

function Get-MappingStatusText {
    param($Game, $Map)
    $local = Expand-Vars $Map.Local $Game
    if (Test-Path -LiteralPath $local) {
        if (Test-Junction $local) { return '联接' }
        return '原位置目录'
    }
    return '不存在'
}

function Get-MappingStoreRelText {
    param($Game, $Map)
    return ('Data\' + $Game.Id + '\' + $Map.Store)
}

function New-MappingEditor {
    param($Game, $Map)

    Add-Type -AssemblyName System.Windows.Forms, System.Drawing -ErrorAction SilentlyContinue
    $isFile = ($Map -and $Map.Kind -eq 'file')
    $form = New-Object Windows.Forms.Form
    $form.Text = if ($Map) { '修改存档位置' } else { '添加存档位置' }
    $form.Size = New-Object Drawing.Size(584, 348)
    $form.StartPosition = 'CenterParent'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.BackColor = UiColor 'bg'

    $t = New-Object Windows.Forms.Label
    $t.Text = $form.Text
    $t.Font = UiFont 15 $true
    $t.ForeColor = UiColor 'text'
    $t.AutoSize = $true
    $t.Location = New-Object Drawing.Point(24, 20)
    $form.Controls.Add($t)

    $sub = New-Object Windows.Forms.Label
    $sub.Text = ('游戏：' + $Game.Name + '（' + $Game.Id + '）  ·  ' + $(if ($isFile) { '单文件' } else { '目录' }))
    $sub.Font = UiFont 9
    $sub.ForeColor = UiColor 'muted'
    $sub.AutoSize = $true
    $sub.Location = New-Object Drawing.Point(26, 52)
    $form.Controls.Add($sub)

    $l1 = New-Object Windows.Forms.Label
    $l1.Text = '原位置'
    $l1.Font = UiFont 9
    $l1.ForeColor = UiColor 'muted'
    $l1.AutoSize = $true
    $l1.Location = New-Object Drawing.Point(24, 84)
    $form.Controls.Add($l1)

    $tbLocal = New-Object Windows.Forms.TextBox
    $tbLocal.Font = UiFont 9
    $tbLocal.Location = New-Object Drawing.Point(24, 104)
    $tbLocal.Size = New-Object Drawing.Size(410, 26)
    $tbLocal.BackColor = UiColor 'bg2'
    $tbLocal.ForeColor = UiColor 'text'
    $tbLocal.BorderStyle = 'FixedSingle'
    if ($Map) { $tbLocal.Text = $Map.Local }
    $form.Controls.Add($tbLocal)

    $browse = New-UiGhostButton '浏览…' 444 103 96
    $browse.Location = New-Object Drawing.Point(444, 103)
    $browse.Size = New-Object Drawing.Size(96, 28)
    $form.Controls.Add($browse)
    $browse.Add_Click({
        if ($isFile) {
            $dlg = New-Object Windows.Forms.OpenFileDialog
            $dlg.Title = '选择存档文件'
            $dlg.Filter = '所有文件 (*.*)|*.*'
            if ($dlg.ShowDialog() -eq 'OK') { $tbLocal.Text = $dlg.FileName }
        } else {
            $dlg = New-Object Windows.Forms.FolderBrowserDialog
            $dlg.Description = '选择原位置的存档目录'
            if ($dlg.ShowDialog() -eq 'OK') { $tbLocal.Text = $dlg.SelectedPath }
        }
    })

    $l2 = New-Object Windows.Forms.Label
    $l2.Text = '目标位置目录名'
    $l2.Font = UiFont 9
    $l2.ForeColor = UiColor 'muted'
    $l2.AutoSize = $true
    $l2.Location = New-Object Drawing.Point(24, 140)
    $form.Controls.Add($l2)

    $tbStore = New-Object Windows.Forms.TextBox
    $tbStore.Font = UiFont 9
    $tbStore.Location = New-Object Drawing.Point(24, 160)
    $tbStore.Size = New-Object Drawing.Size(226, 26)
    $tbStore.BackColor = UiColor 'bg2'
    $tbStore.ForeColor = UiColor 'text'
    $tbStore.BorderStyle = 'FixedSingle'
    if ($Map) { $tbStore.Text = $Map.Store }
    $form.Controls.Add($tbStore)

    $storeHint = New-Object Windows.Forms.Label
    $storeHint.Text = ('放在 Data\' + $Game.Id + '\ 下面；只用字母数字和 . _ -')
    $storeHint.Font = UiFont 8.5
    $storeHint.ForeColor = UiColor 'muted'
    $storeHint.AutoSize = $true
    $storeHint.Location = New-Object Drawing.Point(258, 164)
    $form.Controls.Add($storeHint)

    $l3 = New-Object Windows.Forms.Label
    $l3.Text = '这个游戏的模式'
    $l3.Font = UiFont 9
    $l3.ForeColor = UiColor 'muted'
    $l3.AutoSize = $true
    $l3.Location = New-Object Drawing.Point(24, 196)
    $form.Controls.Add($l3)

    $cbMode = New-Object Windows.Forms.ComboBox
    $cbMode.DropDownStyle = 'DropDownList'
    $cbMode.Font = UiFont 9
    $cbMode.Location = New-Object Drawing.Point(24, 216)
    $cbMode.Size = New-Object Drawing.Size(226, 26)
    $cbMode.BackColor = UiColor 'bg2'
    $cbMode.ForeColor = UiColor 'text'
    $cbMode.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $cbMode.Items.AddRange(@('继承全局设置', '只联接', '只复制')) | Out-Null
    $cbMode.SelectedIndex = 0
    if ($Map -and $Map.Mode -eq 'link') { $cbMode.SelectedIndex = 1 }
    if ($Map -and $Map.Mode -eq 'copy') { $cbMode.SelectedIndex = 2 }
    $form.Controls.Add($cbMode)

    $note = New-Object Windows.Forms.Label
    $note.Text = '修改原位置后，旧的联接会被拆掉；数据不会删，仍留在目标位置。'
    $note.Font = UiFont 8.5
    $note.ForeColor = UiColor 'muted'
    $note.AutoSize = $false
    $note.Size = New-Object Drawing.Size(516, 34)
    $note.Location = New-Object Drawing.Point(24, 240)
    $form.Controls.Add($note)

    $ok = New-Object Windows.Forms.Button
    $ok.Text = '保存'
    $ok.Font = UiFont 9 $true
    $ok.Size = New-Object Drawing.Size(112, 34)
    $ok.Location = New-Object Drawing.Point(316, 268)
    $ok.FlatStyle = 'Flat'
    $ok.FlatAppearance.BorderSize = 0
    $ok.BackColor = UiColor 'rose'
    $ok.ForeColor = [Drawing.Color]::White
    $ok.Cursor = [Windows.Forms.Cursors]::Hand
    $form.Controls.Add($ok)
    $script:MapEditorResult = $null

    $cancel = New-UiGhostButton '取消' 440 268 88
    $cancel.Location = New-Object Drawing.Point(440, 268)
    $cancel.Add_Click({ $form.Close() })
    $form.Controls.Add($cancel)

    $ok.Add_Click({
        $local = $tbLocal.Text.Trim()
        $store = $tbStore.Text.Trim()
        if (-not $local) { [void][Windows.Forms.MessageBox]::Show('原位置不能为空。'); return }
        if (-not ($local -match '^%[A-Za-z0-9_]+%' -or [IO.Path]::IsPathRooted($local))) {
            [void][Windows.Forms.MessageBox]::Show('原位置要么是绝对路径（C:\...），要么以 %APPDATA% 这类变量开头。'); return
        }
        if (-not $store) { [void][Windows.Forms.MessageBox]::Show('目标位置目录名不能为空。'); return }
        if ($store -match '[\\/:*?"<>|]' -or $store -match '\.\.') {
            [void][Windows.Forms.MessageBox]::Show('目标位置目录名不能带路径分隔符或 ..。'); return
        }
        $mode = @('auto', 'link', 'copy')[$cbMode.SelectedIndex]
        $script:MapEditorResult = @{ Local = $local; Store = $store; Mode = $mode }
        $form.Close()
    })

    $form.AcceptButton = $ok
    $form.CancelButton = $cancel
    if ($Owner -and $Owner.TopMost) { $form.TopMost = $true }
    [void]$form.ShowDialog($Owner)
    return $script:MapEditorResult
}

function Update-SaveLocationList {
    param($Game, $ListView, $EmptyLabel)
    $ListView.Items.Clear()
    foreach ($m in @($Game.Mappings)) {
        $item = New-Object Windows.Forms.ListViewItem($(if ($m.Kind -eq 'file') { '文件' } else { '目录' }))
        [void]$item.SubItems.Add($m.Local)
        [void]$item.SubItems.Add((Get-MappingStoreRelText $Game $m))
        [void]$item.SubItems.Add((Get-MappingStatusText $Game $m))
        $item.Tag = $m
        [void]$ListView.Items.Add($item)
    }
    $ListView.Visible = ($ListView.Items.Count -gt 0)
    $EmptyLabel.Visible = ($ListView.Items.Count -eq 0)
}

function Show-SaveLocationWindow {
    param($Game, $Owner)

    Add-Type -AssemblyName System.Windows.Forms, System.Drawing -ErrorAction SilentlyContinue
    $form = New-Object Windows.Forms.Form
    $form.Text = '存档位置'
    $form.Size = New-Object Drawing.Size(776, 470)
    $form.StartPosition = 'CenterParent'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.BackColor = UiColor 'bg'
    $form.ForeColor = UiColor 'text'

    $title = New-Object Windows.Forms.Label
    $title.Text = '存档位置'
    $title.Font = UiFont 17 $true
    $title.ForeColor = UiColor 'text'
    $title.AutoSize = $true
    $title.Location = New-Object Drawing.Point(24, 18)
    $form.Controls.Add($title)

    $sub = New-Object Windows.Forms.Label
    $sub.Text = ($Game.Name + '  ·  ' + $Game.Id + '  ·  修改会立即写回 Launcher\profiles\' + $Game.Id + '.ini')
    $sub.Font = UiFont 9
    $sub.ForeColor = UiColor 'muted'
    $sub.AutoSize = $true
    $sub.Location = New-Object Drawing.Point(26, 50)
    $form.Controls.Add($sub)

    $list = New-Object Windows.Forms.ListView
    $list.View = 'Details'
    $list.FullRowSelect = $true
    $list.GridLines = $false
    $list.HeaderStyle = 'Nonclickable'
    $list.Font = UiFont 9
    $list.BackColor = UiColor 'card'
    $list.ForeColor = UiColor 'text'
    $list.BorderStyle = 'FixedSingle'
    $list.Location = New-Object Drawing.Point(24, 82)
    $list.Size = New-Object Drawing.Size(712, 236)
    [void]$list.Columns.Add('类型', 56)
    [void]$list.Columns.Add('原位置', 320)
    [void]$list.Columns.Add('目标位置', 260)
    [void]$list.Columns.Add('状态', 70)
    $form.Controls.Add($list)

    $empty = New-Object Windows.Forms.Label
    $empty.Text = '这个游戏还没有存档映射。可以点「添加…」手动指定，或用卡片上的「学习存档」自动找。'
    $empty.Font = UiFont 9
    $empty.ForeColor = UiColor 'muted'
    $empty.AutoSize = $false
    $empty.Size = New-Object Drawing.Size(712, 40)
    $empty.Location = New-Object Drawing.Point(24, 96)
    $empty.TextAlign = 'MiddleLeft'
    $form.Controls.Add($empty)

    $bOpenLocal = New-UiGhostButton '定位原位置' 24 332 104
    $bOpenLocal.Location = New-Object Drawing.Point(24, 332)
    $form.Controls.Add($bOpenLocal)

    $bOpenStore = New-UiGhostButton '定位目标位置' 136 332 112
    $bOpenStore.Location = New-Object Drawing.Point(128, 332)
    $form.Controls.Add($bOpenStore)

    $bEdit = New-UiGhostButton '修改…' 256 332 84
    $bEdit.Location = New-Object Drawing.Point(256, 332)
    $form.Controls.Add($bEdit)

    $bAdd = New-UiGhostButton '添加…' 348 332 84
    $bAdd.Location = New-Object Drawing.Point(348, 332)
    $form.Controls.Add($bAdd)

    $bDel = New-UiGhostButton '删除' 440 332 72
    $bDel.Location = New-Object Drawing.Point(440, 332)
    $form.Controls.Add($bDel)

    $bClose = New-Object Windows.Forms.Button
    $bClose.Text = '关闭'
    $bClose.Font = UiFont 9 $true
    $bClose.Size = New-Object Drawing.Size(112, 32)
    $bClose.Location = New-Object Drawing.Point(624, 331)
    $bClose.FlatStyle = 'Flat'
    $bClose.FlatAppearance.BorderSize = 0
    $bClose.BackColor = UiColor 'rose'
    $bClose.ForeColor = [Drawing.Color]::White
    $bClose.Cursor = [Windows.Forms.Cursors]::Hand
    $bClose.Add_Click({ $form.Close() })
    $form.Controls.Add($bClose)

    $note = New-Object Windows.Forms.Label
    $note.Text = '提示：改完不用重新学习；下次点「启动」就按新路径接管。旧的联接会被拆掉，数据不会丢（仍在目标位置）。'
    $note.Font = UiFont 8.5
    $note.ForeColor = UiColor 'muted'
    $note.AutoSize = $false
    $note.Size = New-Object Drawing.Size(712, 34)
    $note.Location = New-Object Drawing.Point(24, 378)
    $form.Controls.Add($note)

    $status = New-Object Windows.Forms.Label
    $status.Text = ''
    $status.Font = UiFont 8.5
    $status.ForeColor = UiColor 'green'
    $status.AutoSize = $false
    $status.Size = New-Object Drawing.Size(712, 24)
    $status.Location = New-Object Drawing.Point(24, 420)
    $form.Controls.Add($status)

    Update-SaveLocationList $Game $list $empty

    $selectedMap = {
        if ($list.SelectedItems.Count -eq 0) { return $null }
        return $list.SelectedItems[0].Tag
    }

    $bOpenLocal.Add_Click({
        $m = & $selectedMap
        if (-not $m) { return }
        $p = Expand-Vars $m.Local $Game
        if (Test-Path -LiteralPath $p) { Start-Process explorer.exe $p }
        else { [void][Windows.Forms.MessageBox]::Show('原位置现在不存在：' + $p) }
    })

    $bOpenStore.Add_Click({
        $m = & $selectedMap
        if (-not $m) { return }
        $p = Get-MappingStorePath $Game $m
        if (Test-Path -LiteralPath $p) { Start-Process explorer.exe $p }
        else {
            $base = Join-Path (Join-Path $global:Root 'Data') $Game.Id
            if (Test-Path -LiteralPath $base) { Start-Process explorer.exe $base }
            else { [void][Windows.Forms.MessageBox]::Show('目标位置还没有这个游戏的存档目录：' + $p) }
        }
    })

    $bEdit.Add_Click({
        $m = & $selectedMap
        if (-not $m) { [void][Windows.Forms.MessageBox]::Show('先在列表里选一条。'); return }
        $r = New-MappingEditor $Game $m
        if (-not $r) { return }
        try {
            $notes = @(Update-GameMapping $Game $m.Id $r.Local $r.Store $r.Mode $m.Kind)
            $Game.Mappings = @((Get-GameById $Game.Id).Mappings)
            Update-SaveLocationList $Game $list $empty
            if (Get-Command Update-GameList -ErrorAction SilentlyContinue) { Update-GameList }
            $status.Text = ($notes -join '  ')
            [void][Windows.Forms.MessageBox]::Show((($notes -join "`r`n") + "`r`n`r`n下次启动生效。"), '已保存')
        } catch {
            [void][Windows.Forms.MessageBox]::Show(('保存失败：' + $_.Exception.Message))
        }
    })

    $bAdd.Add_Click({
        $r = New-MappingEditor $Game $null
        if (-not $r) { return }
        try {
            $note2 = Add-GameMapping $Game $r.Local $r.Store $r.Mode 'dir'
            $Game.Mappings = @((Get-GameById $Game.Id).Mappings)
            Update-SaveLocationList $Game $list $empty
            if (Get-Command Update-GameList -ErrorAction SilentlyContinue) { Update-GameList }
            $status.Text = $note2
            [void][Windows.Forms.MessageBox]::Show(($note2 + "`r`n`r`n下次启动时会按新路径接管。"), '已添加')
        } catch {
            [void][Windows.Forms.MessageBox]::Show(('添加失败：' + $_.Exception.Message))
        }
    })

    $bDel.Add_Click({
        $m = & $selectedMap
        if (-not $m) { [void][Windows.Forms.MessageBox]::Show('先在列表里选一条。'); return }
        $ans = [Windows.Forms.MessageBox]::Show(('删除这条映射？' + "`r`n`r`n" + $m.Local + "`r`n`r`n目标位置上的存档副本不会删。"), '确认', 'YesNo', 'Question')
        if ($ans -ne 'Yes') { return }
        try {
            $notes = @(Remove-GameMapping $Game $m.Id)
            $Game.Mappings = @((Get-GameById $Game.Id).Mappings)
            Update-SaveLocationList $Game $list $empty
            if (Get-Command Update-GameList -ErrorAction SilentlyContinue) { Update-GameList }
            $status.Text = ($notes -join '  ')
        } catch {
            [void][Windows.Forms.MessageBox]::Show(('删除失败：' + $_.Exception.Message))
        }
    })

    if ($Owner -and $Owner.TopMost) { $form.TopMost = $true }
    [void]$form.ShowDialog($Owner)
}
