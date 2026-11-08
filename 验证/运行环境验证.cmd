@echo off
setlocal
chcp 936 >nul
cd /d "%~dp0"

echo ============================================
echo   U 盘游戏启动器 - 环境验证
echo ============================================
echo.
echo 请先插好 U 盘。脚本会自动找 U 盘；找不到时可这样指定：
echo    运行环境验证.cmd -UsbRoot F:\
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0环境验证.ps1" %*

echo.
echo 验证结束。报告在脚本同目录的 验证报告_*.md。
pause