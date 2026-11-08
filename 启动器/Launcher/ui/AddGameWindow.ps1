# AddGameWindow.ps1 - 添加游戏向导（深色）
# 流程：选文件夹 → 扫描 exe → 选游戏进程（可选启动器）→ 写 profile。

function Get-AddGameExeList {
    param([string]$Dir, [switch]$IncludeTools)
    $out = New-Object System.Collections.ArrayList
    if (-not $Dir) { return $out }
    if (-not (Test-Path -LiteralPath $Dir)) { return $out }
    $skipDirs = @('uninstall', 'redist', 'redistributable', 'vcredist', 'directx', 'dxsetup', 'dotnet',
        'support', 'crashreport', 'crashreporter', 'launcherhelper', 'tools', 'installer', '_commonredist')
    $toolRe = '(?i)(unins|uninstall|\bsetup\b|setup_|_setup|installer|\binstall\b|updat|patch|crash|report|redist|vcredist|dxsetup|dotnet|directx|helper|benchmark|config\b|setting|readme|license|eula|createdump|unitycrashhandler|prereqsetup|ofprereqsetup|oalinst|physx|dxwebsetup|vc_redist|service|extension|webcore|webview|webengine|webhelper|browser|cef|electron|crashpad|useless|shareplay|7z|7za|7zr|winrar|unrar|winzip|bandizip|peazip|haozip|_be\.exe$)'
    $launcherRe = '(?i)(launcher|(?<![A-Za-z])play|(?<![A-Za-z])start|boot|login|gamestart|connect|\bupc\b)'
    # 合并扫描名单（Launcher\scan-lists.ini）与旧配置里的自定义项
    try {
        $lists = Get-ScanLists
        if ($lists.SkipDirs.Count) { $skipDirs = @($skipDirs + @($lists.SkipDirs)) }
        if ($lists.Include.Count) { $include = @($lists.Include) }
        if ($lists.Exclude.Count) {
            $extra = (($lists.Exclude | ForEach-Object { [regex]::Escape($_) }) -join '|')
            $toolRe = $toolRe.TrimEnd(')') + '|' + $extra + ')'
        }
        $cfg = Read-GlobalConfig
        if ($cfg.ScanSkipDirs) { $skipDirs = @($skipDirs + @($cfg.ScanSkipDirs | ForEach-Object { $_.ToLowerInvariant() })) }
        if ($cfg.ScanExclude) {
            $extra = (($cfg.ScanExclude | ForEach-Object { [regex]::Escape($_) }) -join '|')
            $toolRe = $toolRe.TrimEnd(')') + '|' + $extra + ')'
        }
    } catch { }
    $stack = New-Object System.Collections.Stack
    $stack.Push(@($Dir, 0))
    while ($stack.Count -gt 0) {
        $cur = $stack.Pop()
        $path = [string]$cur[0]
        $depth = [int]$cur[1]
        $files = @()
        try { $files = @(Get-ChildItem -LiteralPath $path -File -Filter '*.exe' -ErrorAction Stop) } catch { $files = @() }
        foreach ($f in $files) {
            $rel = $f.FullName.Substring($Dir.TrimEnd('\').Length).TrimStart('\')
            $forceGame = $false
            foreach ($inc in $include) {
                if ($inc -and ($rel -match [regex]::Escape($inc))) { $forceGame = $true; break }
            }
            $isTool = ($rel -match $toolRe) -and -not $forceGame
            if ($isTool -and -not $IncludeTools) { continue }
            $kind = 'game'
            if ($forceGame) { $kind = 'game' }
            elseif ($isTool) { $kind = 'tool' }
            elseif ($f.Name -match $launcherRe) { $kind = 'launcher' }
            $label = $rel
            if ($kind -eq 'launcher') { $label = '(启动器) ' + $rel }
            elseif ($kind -eq 'tool') { $label = '(工具) ' + $rel }
            else { $label = '(游戏) ' + $rel }
            [void]$out.Add([pscustomobject]@{ Full = $f.FullName; Rel = $rel; Size = $f.Length; Name = $f.Name; Kind = $kind; Label = $label })
        }
        if ($depth -ge 2) { continue }
        $dirs = @()
        try { $dirs = @(Get-ChildItem -LiteralPath $path -Directory -ErrorAction Stop) } catch { $dirs = @() }
        foreach ($d in $dirs) {
            if (($d.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
            if ($skipDirs -contains $d.Name.ToLowerInvariant()) { continue }
            $stack.Push(@($d.FullName, ($depth + 1)))
        }
    }
    return $out
}

function New-AddGameId([string]$Name) {
    $id = $Name.Trim()
    $id = $id -replace '[\\/:*?"<>|]', ''
    $id = $id -replace '\s+', ''
    if (-not $id) { $id = 'game' }
    if ($id.Length -gt 40) { $id = $id.Substring(0, 40) }
    return $id
}

function Pick-AddGameExe([string]$Kind) {
    if (-not $script:AddForm) { return }
    $dlg = New-Object Windows.Forms.OpenFileDialog
    $dlg.Title = if ($Kind -eq 'launcher') { '选择启动器程序' } else { '选择游戏主程序' }
    $dlg.Filter = 'exe 文件 (*.exe)|*.exe|所有文件 (*.*)|*.*'
    $dlg.CheckFileExists = $true
    $combo = if ($Kind -eq 'launcher') { $script:AddLauncherCombo } else { $script:AddGameCombo }
    if ($dlg.ShowDialog($script:AddForm) -ne 'OK') {
        if ($script:AddPickPrev -ge 0 -and $script:AddPickPrev -lt $combo.Items.Count) { $combo.SelectedIndex = $script:AddPickPrev }
        else { $combo.SelectedIndex = -1 }
        return
    }
    $f = Get-Item -LiteralPath $dlg.FileName -ErrorAction SilentlyContinue
    if (-not $f) { return }
    $dir = $script:AddDirBox.Text.Trim().TrimEnd('\')
    $rel = $f.FullName
    if ($dir -and $f.FullName.StartsWith($dir + '\', [StringComparison]::OrdinalIgnoreCase)) {
        $rel = $f.FullName.Substring($dir.Length + 1)
    }
    $prefix = if ($Kind -eq 'launcher') { '(自选启动器) ' } else { '(自选游戏) ' }
    $item = [pscustomobject]@{ Full = $f.FullName; Rel = $rel; Size = $f.Length; Name = $f.Name; Kind = $Kind; Label = ($prefix + $f.Name) }
    $combo = if ($Kind -eq 'launcher') { $script:AddLauncherCombo } else { $script:AddGameCombo }
    if ($combo.Items.Count -lt 1) { [void]$combo.Items.Add($item) }
    else { [void]$combo.Items.Insert($combo.Items.Count - 1, $item) }
    $combo.SelectedItem = $item
    if ($Kind -eq 'launcher') {
        $script:AddLauncherChk.Checked = $true
        $script:AddLauncherCombo.Enabled = $true
    }
    $script:AddStatus.ForeColor = UiColor 'ok'
    $script:AddStatus.Text = ('已选：' + $f.Name)
}
function Show-AddGameWindow($Owner) {
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing -ErrorAction SilentlyContinue

    $form = New-Object Windows.Forms.Form
    $form.Text = '添加游戏'
    $form.ClientSize = New-Object Drawing.Size(780, 560)
    $form.StartPosition = 'CenterParent'
    $form.FormBorderStyle = [Windows.Forms.FormBorderStyle]::FixedSingle
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ShowInTaskbar = $false
    $form.BackColor = UiColor 'bg'
    $form.ForeColor = UiColor 'text'
    $form.Font = UiFont 9 'regular'

    $title = New-Object Windows.Forms.Label
    $title.Text = '添加游戏'
    $title.AutoSize = $false
    $title.Size = New-Object Drawing.Size((UiPx 400), (UiPx 34))
    $title.Location = New-Object Drawing.Point((UiPx 28), (UiPx 18))
    $title.Font = UiFont 16 'bold'
    $title.ForeColor = UiColor 'text'
    $title.BackColor = [Drawing.Color]::Transparent

    $sub = New-Object Windows.Forms.Label
    $sub.Text = '选游戏文件夹 → 指定游戏进程 → 有启动器就再选启动器进程'
    $sub.AutoSize = $false
    $sub.Size = New-Object Drawing.Size((UiPx 700), (UiPx 22))
    $sub.Location = New-Object Drawing.Point((UiPx 30), (UiPx 56))
    $sub.Font = UiFont 9 'regular'
    $sub.ForeColor = UiColor 'muted'
    $sub.BackColor = [Drawing.Color]::Transparent

    $lblDir = New-Object Windows.Forms.Label
    $lblDir.Text = '游戏文件夹'
    $lblDir.AutoSize = $false
    $lblDir.Size = New-Object Drawing.Size((UiPx 80), (UiPx 24))
    $lblDir.Location = New-Object Drawing.Point((UiPx 28), (UiPx 104))
    $lblDir.ForeColor = UiColor 'muted'
    $lblDir.BackColor = [Drawing.Color]::Transparent

    $dirBox = New-Object Windows.Forms.TextBox
    $dirBox.Location = New-Object Drawing.Point((UiPx 110), (UiPx 100))
    $dirBox.Size = New-Object Drawing.Size((UiPx 468), (UiPx 30))
    $dirBox.BackColor = UiColor 'panel'
    $dirBox.ForeColor = UiColor 'text'
    $dirBox.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle
    $dirBox.Font = UiFont 9 'regular'
    $script:AddDirBox = $dirBox

    $btnBrowse = New-UiGhostButton '浏览…' (UiPx 588) (UiPx 98) (UiPx 84)
    $btnBrowse.Add_Click({
            $dlg = New-Object Windows.Forms.FolderBrowserDialog
            $dlg.Description = '选择游戏文件夹'
            $dlg.ShowNewFolderButton = $false
            if ($dlg.ShowDialog() -eq 'OK') {
                $script:AddDirBox.Text = $dlg.SelectedPath
                if (-not $script:AddNameBox.Text) {
                    $leaf = Split-Path -Leaf $dlg.SelectedPath
                    if ($leaf) { $script:AddNameBox.Text = $leaf }
                }
            }
        })

    $btnScan = New-UiGhostButton '扫描' (UiPx 680) (UiPx 98) (UiPx 72)
    $btnScan.Add_Click({ Invoke-AddGameScan })

    $lblExe = New-Object Windows.Forms.Label
    $lblExe.Text = '游戏进程'
    $lblExe.AutoSize = $false
    $lblExe.Size = New-Object Drawing.Size((UiPx 80), (UiPx 24))
    $lblExe.Location = New-Object Drawing.Point((UiPx 28), (UiPx 152))
    $lblExe.ForeColor = UiColor 'muted'
    $lblExe.BackColor = [Drawing.Color]::Transparent

    $cbExe = New-Object Windows.Forms.ComboBox
    $cbExe.Location = New-Object Drawing.Point((UiPx 110), (UiPx 148))
    $cbExe.Size = New-Object Drawing.Size((UiPx 642), (UiPx 28))
    $cbExe.DropDownStyle = [Windows.Forms.ComboBoxStyle]::DropDownList
    $cbExe.DisplayMember = 'Label'
    $cbExe.BackColor = UiColor 'panel'
    $cbExe.ForeColor = UiColor 'text'
    $cbExe.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $script:AddGameCombo = $cbExe

    $chkLauncher = New-Object Windows.Forms.CheckBox
    $chkLauncher.Text = '这个游戏有独立的启动器（可选，缺省无）'
    $chkLauncher.AutoSize = $false
    $chkLauncher.Size = New-Object Drawing.Size((UiPx 480), (UiPx 26))
    $chkLauncher.Location = New-Object Drawing.Point((UiPx 110), (UiPx 192))
    $chkLauncher.ForeColor = UiColor 'text'
    $chkLauncher.BackColor = [Drawing.Color]::Transparent
    $script:AddLauncherChk = $chkLauncher

    $cbLauncher = New-Object Windows.Forms.ComboBox
    $cbLauncher.Location = New-Object Drawing.Point((UiPx 110), (UiPx 220))
    $cbLauncher.Size = New-Object Drawing.Size((UiPx 642), (UiPx 28))
    $cbLauncher.DropDownStyle = [Windows.Forms.ComboBoxStyle]::DropDownList
    $cbLauncher.DisplayMember = 'Label'
    $cbLauncher.BackColor = UiColor 'panel'
    $cbLauncher.ForeColor = UiColor 'text'
    $cbLauncher.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $cbLauncher.Enabled = $false
    $script:AddLauncherCombo = $cbLauncher

    $browse0 = [pscustomobject]@{ Full = ''; Rel = ''; Size = 0; Name = ''; Kind = 'browse'; Label = '（自己选择 exe 文件…）' }
    [void]$cbExe.Items.Add($browse0)
    [void]$cbLauncher.Items.Add($browse0)
    $cbExe.SelectedIndex = -1
    $cbLauncher.SelectedIndex = -1

    $chkTools = New-Object Windows.Forms.CheckBox
    $chkTools.Text = '显示工具/卸载类 exe'
    $chkTools.AutoSize = $false
    $chkTools.Size = New-Object Drawing.Size((UiPx 220), (UiPx 26))
    $chkTools.Location = New-Object Drawing.Point((UiPx 600), (UiPx 192))
    $chkTools.ForeColor = UiColor 'muted'
    $chkTools.BackColor = [Drawing.Color]::Transparent
    $chkTools.Font = UiFont 8.5 'regular'
    $script:AddShowTools = $chkTools
    $chkTools.Add_CheckedChanged({ if ($script:AddDirBox.Text.Trim()) { Invoke-AddGameScan } })

    $chkLauncher.Add_CheckedChanged({
            $script:AddLauncherCombo.Enabled = $script:AddLauncherChk.Checked
            if ($script:AddLauncherChk.Checked -and $script:AddLauncherCombo.Items.Count -gt 0 -and $script:AddLauncherCombo.SelectedIndex -lt 0) {
                $idx = -1
                for ($i = 0; $i -lt $script:AddLauncherCombo.Items.Count; $i++) {
                    if ($script:AddLauncherCombo.Items[$i].Kind -eq 'launcher') { $idx = $i; break }
                }
                if ($idx -lt 0) { $idx = 0 }
                $script:AddLauncherCombo.SelectedIndex = $idx
            }
        })

    $script:AddLastGameIdx = -1
    $script:AddLastLauncherIdx = -1

    $cbExe.Add_SelectedIndexChanged({
            $cb = $script:AddGameCombo
            $it = $cb.SelectedItem
            if (-not $it) { return }
            if ($it.Kind -ne 'browse') { $script:AddLastGameIdx = $cb.SelectedIndex; return }
            $script:AddPickPrev = $script:AddLastGameIdx
            $cb.BeginInvoke([Windows.Forms.MethodInvoker]{ Pick-AddGameExe 'game' }) | Out-Null
        })
    $cbLauncher.Add_SelectedIndexChanged({
            $cb = $script:AddLauncherCombo
            $it = $cb.SelectedItem
            if (-not $it) { return }
            if ($it.Kind -ne 'browse') { $script:AddLastLauncherIdx = $cb.SelectedIndex; return }
            $script:AddPickPrev = $script:AddLastLauncherIdx
            $cb.BeginInvoke([Windows.Forms.MethodInvoker]{ Pick-AddGameExe 'launcher' }) | Out-Null
        })

    $lblName = New-Object Windows.Forms.Label
    $lblName.Text = '显示名称'
    $lblName.AutoSize = $false
    $lblName.Size = New-Object Drawing.Size((UiPx 80), (UiPx 24))
    $lblName.Location = New-Object Drawing.Point((UiPx 28), (UiPx 262))
    $lblName.ForeColor = UiColor 'muted'
    $lblName.BackColor = [Drawing.Color]::Transparent

    $nameBox = New-Object Windows.Forms.TextBox
    $nameBox.Location = New-Object Drawing.Point((UiPx 110), (UiPx 258))
    $nameBox.Size = New-Object Drawing.Size((UiPx 300), (UiPx 30))
    $nameBox.BackColor = UiColor 'panel'
    $nameBox.ForeColor = UiColor 'text'
    $nameBox.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle
    $nameBox.Font = UiFont 9 'regular'
    $script:AddNameBox = $nameBox

    $lblId = New-Object Windows.Forms.Label
    $lblId.Text = '标识：'
    $lblId.AutoSize = $false
    $lblId.Size = New-Object Drawing.Size((UiPx 320), (UiPx 24))
    $lblId.Location = New-Object Drawing.Point((UiPx 426), (UiPx 262))
    $lblId.ForeColor = UiColor 'muted'
    $lblId.BackColor = [Drawing.Color]::Transparent
    $script:AddIdLabel = $lblId

    $nameBox.Add_TextChanged({
            $id = New-AddGameId $script:AddNameBox.Text
            $script:AddIdLabel.Text = '标识：' + $id
        })

    $status = New-Object Windows.Forms.Label
    $status.Text = ''
    $status.AutoSize = $false
    $status.Size = New-Object Drawing.Size((UiPx 720), (UiPx 24))
    $status.Location = New-Object Drawing.Point((UiPx 28), (UiPx 300))
    $status.ForeColor = UiColor 'muted'
    $status.BackColor = [Drawing.Color]::Transparent
    $script:AddStatus = $status

    $hint1 = New-Object Windows.Forms.Label
    $hint1.Text = '扫描文件夹下三层内的 .exe；自动隐藏卸载/安装/更新/崩溃上报等工具，只留游戏本体和启动器。'
    $hint1.AutoSize = $false
    $hint1.Size = New-Object Drawing.Size((UiPx 720), (UiPx 22))
    $hint1.Location = New-Object Drawing.Point((UiPx 28), (UiPx 334))
    $hint1.ForeColor = UiColor 'muted'
    $hint1.BackColor = [Drawing.Color]::Transparent

    $hint2 = New-Object Windows.Forms.Label
    $hint2.Text = '填了启动器时：主按钮「启动」会先拉启动器（按进程树等待），卡片上的「直接开始」则跳过启动器直接起游戏。'
    $hint2.AutoSize = $false
    $hint2.Size = New-Object Drawing.Size((UiPx 720), (UiPx 22))
    $hint2.Location = New-Object Drawing.Point((UiPx 28), (UiPx 358))
    $hint2.ForeColor = UiColor 'muted'
    $hint2.BackColor = [Drawing.Color]::Transparent

    $btnCancel = New-UiGhostButton '取消' (UiPx 520) (UiPx 470) (UiPx 90)
    $btnCancel.Add_Click({ $form.Close() })

    $btnCreate = New-Object Windows.Forms.Button
    $btnCreate.Text = '创建游戏'
    $btnCreate.Location = New-Object Drawing.Point((UiPx 620), (UiPx 470))
    $btnCreate.Size = New-Object Drawing.Size((UiPx 130), (UiPx 36))
    $btnCreate.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $btnCreate.FlatAppearance.BorderSize = 0
    $btnCreate.BackColor = UiColor 'rose'
    $btnCreate.ForeColor = [Drawing.Color]::White
    $btnCreate.Font = UiFont 10 'bold'
    $btnCreate.Cursor = [Windows.Forms.Cursors]::Hand
    Set-UiRounded $btnCreate (UiPx 10)
    $script:AddCreateBtn = $btnCreate

    $btnCreate.Add_Click({ Invoke-AddGameCreate })

    $form.Controls.Add($title)
    $form.Controls.Add($sub)
    $form.Controls.Add($lblDir)
    $form.Controls.Add($dirBox)
    $form.Controls.Add($btnBrowse)
    $form.Controls.Add($btnScan)
    $form.Controls.Add($lblExe)
    $form.Controls.Add($cbExe)
    $form.Controls.Add($chkLauncher)
    $form.Controls.Add($chkTools)
    $form.Controls.Add($cbLauncher)
    $form.Controls.Add($lblName)
    $form.Controls.Add($nameBox)
    $form.Controls.Add($lblId)
    $form.Controls.Add($status)
    $form.Controls.Add($hint1)
    $form.Controls.Add($hint2)
    $form.Controls.Add($btnCancel)
    $form.Controls.Add($btnCreate)

    $form.AcceptButton = $btnCreate
    $form.CancelButton = $btnCancel

    $script:AddForm = $form
    $script:AddOwner = $Owner
    if ($Owner -and $Owner.TopMost) { $form.TopMost = $true }
    [void]$form.ShowDialog($Owner)
}

function Invoke-AddGameScan {
    if (-not $script:AddForm) { return }
    $dir = $script:AddDirBox.Text.Trim().TrimEnd('\')
    if (-not $dir) {
        $script:AddStatus.ForeColor = UiColor 'amber'
        $script:AddStatus.Text = '先填游戏文件夹。'
        return
    }
    if (-not (Test-Path -LiteralPath $dir)) {
        $script:AddStatus.ForeColor = UiColor 'red'
        $script:AddStatus.Text = '游戏文件夹不存在：' + $dir
        return
    }
    $exes = @(Get-AddGameExeList $dir -IncludeTools:$script:AddShowTools.Checked)
    $script:AddGameCombo.Items.Clear()
    $script:AddLauncherCombo.Items.Clear()
    $browseItem = [pscustomobject]@{ Full = ''; Rel = ''; Size = 0; Name = ''; Kind = 'browse'; Label = '（自己选择 exe 文件…）' }
    [void]$script:AddGameCombo.Items.Add($browseItem)
    [void]$script:AddLauncherCombo.Items.Add($browseItem)
    if ($exes.Count -eq 0) {
        $script:AddGameCombo.SelectedIndex = -1
        $script:AddLauncherCombo.SelectedIndex = -1
        $script:AddStatus.ForeColor = UiColor 'amber'
        $script:AddStatus.Text = '这个文件夹里没找到可用的 .exe；可以点「扫描」重试，或在「游戏进程」下拉里选「自己选择 exe 文件…」。'
        return
    }
    $sorted = @($exes | Sort-Object -Property @{ Expression = { switch ($_.Kind) { 'game' { 0 } 'launcher' { 1 } default { 2 } } } }, @{ Expression = { $_.Size }; Descending = $true })
    foreach ($x in $sorted) {
        [void]$script:AddGameCombo.Items.Insert($script:AddGameCombo.Items.Count - 1, $x)
        [void]$script:AddLauncherCombo.Items.Insert($script:AddLauncherCombo.Items.Count - 1, $x)
    }
    $gameIdx = 0
    for ($i = 0; $i -lt $sorted.Count; $i++) {
        if ($sorted[$i].Kind -eq 'game') { $gameIdx = $i; break }
    }
    $script:AddGameCombo.SelectedIndex = $gameIdx
    $script:AddLauncherCombo.SelectedIndex = -1
    if (-not $script:AddNameBox.Text) {
        $leaf = Split-Path -Leaf $dir
        if ($leaf) { $script:AddNameBox.Text = $leaf }
    }
    $script:AddStatus.ForeColor = UiColor 'ok'
    $script:AddStatus.Text = ('找到 ' + $exes.Count + ' 个 exe。')
}

function Invoke-AddGameCreate {
    if (-not $script:AddForm) { return }
    $dir = $script:AddDirBox.Text.Trim().TrimEnd('\')
    if (-not $dir -or -not (Test-Path -LiteralPath $dir)) {
        $script:AddStatus.ForeColor = UiColor 'red'
        $script:AddStatus.Text = '游戏文件夹不存在。'
        return
    }
    $root = $global:Root.TrimEnd('\')
    if ($dir -eq $root -or $dir -like ($root + '\Launcher*') -or $dir -like ($root + '\Data*')) {
        $script:AddStatus.ForeColor = UiColor 'red'
        $script:AddStatus.Text = '不能把启动器自身或 Data 目录当成游戏目录。'
        return
    }
    $sel = $script:AddGameCombo.SelectedItem
    if (-not $sel) {
        $script:AddStatus.ForeColor = UiColor 'amber'
        $script:AddStatus.Text = '先点「扫描」并选一个游戏进程。'
        return
    }
    if ($sel.Kind -eq 'browse') {
        $script:AddStatus.ForeColor = UiColor 'amber'
        $script:AddStatus.Text = '请在下拉里选一个 exe，或选「自己选择 exe 文件…」。'
        return
    }
    if ($sel.Kind -eq 'tool') {
        $r0 = [Windows.Forms.MessageBox]::Show(('「' + $sel.Rel + '」看起来是工具/卸载程序，确定把它当游戏主程序吗？'), '添加游戏', 'YesNo', 'Warning')
        if ($r0 -ne 'Yes') { return }
    }
    $name = $script:AddNameBox.Text.Trim()
    if (-not $name) {
        $script:AddStatus.ForeColor = UiColor 'amber'
        $script:AddStatus.Text = '填一个显示名称。'
        return
    }
    $id = New-AddGameId $name
    $prof = Join-Path $global:Root ('Launcher\profiles\' + $id + '.ini')
    if (Test-Path -LiteralPath $prof) {
        $r = [Windows.Forms.MessageBox]::Show(('标识「' + $id + '」已经有配置，覆盖它吗？'), '添加游戏', 'YesNo', 'Question')
        if ($r -ne 'Yes') { return }
    }
    $launcherRel = ''
    if ($script:AddLauncherChk.Checked -and $script:AddLauncherCombo.SelectedItem) {
        $launcherRel = $script:AddLauncherCombo.SelectedItem.Rel
    }
    $gameEntry = [ordered]@{
        name          = $name
        exe           = $sel.Rel
        launcher      = $launcherRel
        launcher_args = ''
        wait          = 'process'
    }
    if ($dir -like ($root + '\*')) {
        $gameEntry['dir'] = $dir.Substring($root.Length).TrimStart('\')
    } else {
        $gameEntry['dir'] = $dir
    }
    $ini = [ordered]@{ game = $gameEntry }
    Write-Ini $ini $prof
    if (Get-Command Update-GameList -ErrorAction SilentlyContinue) { Update-GameList }
    if (Get-Command Set-UiStatus -ErrorAction SilentlyContinue) { Set-UiStatus ('已添加 ' + $name + '。') 'ok' }
    $script:AddForm.Close()
    $ans = [Windows.Forms.MessageBox]::Show(('已添加「' + $name + '」。现在学习它的存档位置吗？'), '添加游戏', 'YesNo', 'Question')
    if ($ans -eq 'Yes') {
        $g = Get-GameById $id
        if ($g) { Show-LearnWindow $g $script:AddOwner }
    }
}
