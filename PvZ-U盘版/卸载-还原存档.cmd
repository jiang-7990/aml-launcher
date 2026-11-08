@echo off
chcp 936 >nul 2>&1
setlocal EnableExtensions
title PvZ U盘便携版 - 卸下并还原存档

rem =====================================================================
rem  把本机的存档目录恢复成普通文件夹，并把 U 盘上的存档复制回来。
rem  用途：不想再用 U 盘玩，或者拔了 U 盘想在本机正常玩的时候。
rem  注意：不会动 U 盘上的 save 目录，它仍然是一份完整的备份。
rem =====================================================================

set "GAMEDIR=%~dp0"
set "SAVEDIR=%GAMEDIR%save"
set "SAVEPATH="

call :find_savepath
echo.
echo  本机存档目录: %SAVEPATH%

fsutil reparsepoint query "%SAVEPATH%" >nul 2>&1
if errorlevel 1 (
    echo.
    echo  这个目录不是联接，本机存档本来就在本地，无需还原。
    echo.
    pause
    exit /b 0
)

echo  正在拆除联接 ...
rmdir "%SAVEPATH%" >nul 2>&1
if exist "%SAVEPATH%\" (
    echo.
    echo  [错误] 联拆除失败，请关闭游戏后右键"以管理员身份运行"。
    echo.
    pause
    exit /b 1
)

mkdir "%SAVEPATH%" >nul 2>&1
echo  正在把 U 盘上的存档复制回本机 ...
if exist "%SAVEDIR%\userdata\" (
    robocopy "%SAVEDIR%" "%SAVEPATH%" /E /R:1 /W:1 /NFL /NDL /NJH /NJS >nul
    if errorlevel 8 (
        echo.
        echo  [错误] 复制存档失败，请检查权限后重试。
        echo.
        pause
        exit /b 1
    )
    echo  [完成] 存档已还原到本机，可以直接双击游戏 exe 玩了。
) else (
    echo  [提示] U 盘上没有找到 save\userdata，本机目录已清空。
)

echo.
pause
exit /b 0

rem =====================================================================

:find_savepath
set "SAVEPATH="
for %%P in (
    "%ProgramData%\PopCap Games\PlantsVsZombies"
    "%APPDATA%\PopCap\PlantsVsZombies"
    "%LOCALAPPDATA%\PopCap\PlantsVsZombies"
    "%ProgramData%\PopCap\PlantsVsZombies"
) do (
    if not defined SAVEPATH if exist "%%~P\userdata\" set "SAVEPATH=%%~P"
)
if defined SAVEPATH goto :find_done
for %%P in (
    "%ProgramData%\PopCap Games\PlantsVsZombies"
    "%APPDATA%\PopCap\PlantsVsZombies"
    "%LOCALAPPDATA%\PopCap\PlantsVsZombies"
    "%ProgramData%\PopCap\PlantsVsZombies"
) do (
    if not defined SAVEPATH (
        fsutil reparsepoint query "%%~P" >nul 2>&1
        if not errorlevel 1 set "SAVEPATH=%%~P"
    )
)
if defined SAVEPATH goto :find_done
set "SAVEPATH=%ProgramData%\PopCap Games\PlantsVsZombies"
:find_done
exit /b 0
