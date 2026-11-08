# AML · 移动存储设备游戏存档管理启动器

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Windows](https://img.shields.io/badge/Windows-10%2F11-0078D6.svg)](#)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1-5391FE.svg)](#)

把游戏装进 U 盘或移动硬盘，存档跟着盘走。插到任意一台 Windows 电脑，双击启动器就能玩；游戏照常读写本机存档路径，实际数据始终留在盘里，换电脑、换盘符都不丢。

当前版本：**v0.18.1**（单文件 `AML.exe` + 自定义壁纸/透明度 + 无边框界面；0.18.1 修复旧运行时 DLL 缺 `DragMove` 导致的拖动崩溃）

## 它能做什么

- **存档跟随**：把游戏的存档目录做成目录联接（junction）指向 U 盘 `Data\<游戏>\`，游戏读写存档时实际落在 U 盘。
- **自动/手动定位存档**：学习模式用快照 diff 找存档目录；「存档位置」对话框可逐条查看、修改、添加、删除文件映射和注册表映射。
- **两种模式**：联接优先（实时、快），失败或特殊场景降级为复制（启动时拷到本机，退出回写）。
- **多版本隔离**：同一台机器上多个改版共用同一个存档目录时，每个游戏有独立 store，启动时切换联接。
- **游戏启动器支持**：游戏主程序之外可配置独立启动器；主按钮拉起启动器并按进程树等待，卡片「直接启动」跳过启动器。
- **添加游戏向导**：扫描 exe 自动区分游戏/启动器/工具，可手选；支持 Games 以外的目录。
- **还原/卸载**：把 U 盘存档还原回本机、删除配置；可选删除游戏文件。
- **单文件 exe**：`dist\AML.exe` 内置运行时，首次运行解压到 `Launcher\.runtime\v<版本>`；已有 `启动器\` 文件夹时自动走混合模式。

## 快速开始

1. 把 `AML.exe`（或整个 `启动器\` 文件夹）放到 U 盘根目录。
2. 双击运行，点「添加游戏」选游戏文件夹；或用「学习存档」让它自己找存档位置。
3. 以后换电脑，插上 U 盘双击即可，存档跟着走。

详细说明见 [启动器/使用说明.md](启动器/使用说明.md)，设计与实现细节见 [启动器设计.md](启动器设计.md)。

## 目录

```
启动器/
  Start.ps1 / 启动器.cmd / 启动器.vbs   入口
  Launcher/
    lib/       Common Config Link Sync Snapshot Launch Learn Registry Mappings Restore State Uninstall
    ui/        MainWindow LearnWindow AddGameWindow SettingsWindow SaveLocationWindow RestoreDialog UninstallDialog Menu
    cache/     PglNative.dll（预编译：DWM/图标/Job/DragMove）
    profiles/  每个游戏一个 ini
    scan-lists.ini  扫描排除/跳过/白名单
  build/       LauncherStub.cs + build-exe.ps1（打包单 exe）
  Tests/       回归与各功能测试脚本
  dist/        AML.exe 产物
```

## 开发

- Windows 10/11，PowerShell 5.1；无需 .NET SDK，用系统自带 `csc.exe`。
- 运行：`启动器\启动器.vbs`（无控制台）或 `启动器\启动器.cmd -Console`。
- 构建单 exe：`powershell -ExecutionPolicy Bypass -File 启动器\build\build-exe.ps1 -Version 0.18.0`
- 回归：`powershell -ExecutionPolicy Bypass -File 启动器\Tests\run-regression.ps1`
- 编码约定：`.ps1` / `.ini` 必须 UTF-8 BOM（PS 5.1 否则按 GBK 读中文会报错），`.cmd` 必须无 BOM。编辑后记得补 BOM。

## 已知限制

- 列表滚动条是 WinForms 原生白色，深色主题下不协调（未自绘）。
- 复制模式下 U 盘存档超过 `copy_warn_mb`（默认 512 MB）启动前会提醒。
- 学习模式对已接管的游戏无效（本机目录已是联接）。
- 未做代码签名，SmartScreen 首次运行会提示。

## 版本

- v0.18.1：修复部署旧 `PglNative.dll` 时拖动窗口抛 `[PglWin] 不包含 DragMove` 的崩溃（独立 `PglDrag` + 内联回退 + try/catch）。
- v0.18.0：单文件 exe、壁纸/透明度、无边框窗口、右侧工具栏、空状态引导。
- 更早版本见 Releases。

## 许可证

MIT。见 [LICENSE](LICENSE)。
