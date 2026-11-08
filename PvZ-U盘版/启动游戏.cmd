@echo off
chcp 936 >nul 2>&1
setlocal EnableExtensions
title PvZ U盘便携版 - 启动游戏

rem =====================================================================
rem  植物大战僵尸 - U 盘便携版启动器
rem
rem  作用：让存档跟着 U 盘走，而不是留在这台电脑的 C 盘里。
rem  原理：把本机的存档目录做成"目录联接"(junction)，实际指向 U 盘上的
rem        save 目录。每次启动都重建一次联接，所以换了盘符也能自己修好。
rem
rem  用法：把本文件放在 PlantsVsZombies.exe 旁边，双击即可。
rem        第一次在某台电脑上运行，会把该电脑的旧存档备份后搬到 U 盘。
rem =====================================================================

set "GAMEDIR=%~dp0"
set "SAVEDIR=%GAMEDIR%save"
set "LOGDIR=%GAMEDIR%logs"
set "EXE="
set "SAVEPATH="

if not exist "%LOGDIR%\" mkdir "%LOGDIR%" >nul 2>&1
call :log "==================== 启动 %DATE% %TIME%"
call :log "程序目录: %GAMEDIR%"

rem ---------- 1. 找游戏主程序 ----------------------------------------
for %%N in (PlantsVsZombies.exe PvZ.exe Game.exe) do (
    if not defined EXE if exist "%GAMEDIR%%%~N" set "EXE=%GAMEDIR%%%~N"
)
if defined EXE goto :have_exe
for %%F in ("%GAMEDIR%*.exe") do if not defined EXE set "EXE=%%~fF"
:have_exe
if not defined EXE (
    call :log "错误: 未找到 exe"
    echo.
    echo  [错误] 这个目录里没有找到游戏 exe。
    echo         请把本文件放在 PlantsVsZombies.exe 旁边。
    echo.
    pause
    exit /b 1
)
call :log "主程序: %EXE%"

rem ---------- 2. 已经是自带存档的绿色版，直接启动 ---------------------
if exist "%GAMEDIR%userdata\" (
    call :log "发现 exe 旁边的 userdata 目录，本副本自带存档，跳过联接"
    goto :start_game
)

rem ---------- 3. 确定本机的存档目录 ----------------------------------
call :find_savepath
call :log "本机存档目录: %SAVEPATH%"

rem ---------- 4. 已有联接（可能指向旧盘符）：拆掉重建 -----------------
fsutil reparsepoint query "%SAVEPATH%" >nul 2>&1
if not errorlevel 1 (
    call :log "发现已有联接，删除后重建"
    rmdir "%SAVEPATH%" >nul 2>&1
    goto :make_link
)

rem ---------- 5. 真实目录：先备份，再搬到 U 盘 -----------------------
if not exist "%SAVEPATH%\" goto :make_link
call :adopt
if errorlevel 1 (
    echo.
    echo  [错误] 旧存档搬迁失败。请确认游戏已完全退出后重试。
    echo         日志: %LOGDIR%\launcher.log
    echo.
    pause
    exit /b 1
)

:make_link
if exist "%SAVEPATH%\" (
    call :log "警告: %SAVEPATH% 仍存在，无法建立联接"
    echo.
    echo  [警告] 无法替换本机存档目录：
    echo         %SAVEPATH%
    echo         游戏仍会写 C 盘，存档不会跟着 U 盘走。
    echo         请关闭游戏，或右键本文件"以管理员身份运行"一次。
    echo.
    goto :start_game
)
if not exist "%SAVEDIR%\" mkdir "%SAVEDIR%" >nul 2>&1
for %%D in ("%SAVEPATH%") do if not exist "%%~dpD" mkdir "%%~dpD" >nul 2>&1
mklink /J "%SAVEPATH%" "%SAVEDIR%" >nul 2>&1
if errorlevel 1 (
    call :log "mklink /J 失败，改用 mklink /D"
    mklink /D "%SAVEPATH%" "%SAVEDIR%" >nul 2>&1
)
fsutil reparsepoint query "%SAVEPATH%" >nul 2>&1
if errorlevel 1 (
    call :log "错误: 建立联接失败"
    echo.
    echo  [错误] 无法创建存档联接。
    echo         挂载点: %SAVEPATH%
    echo         目标  : %SAVEDIR%
    echo         解决办法: 右键本文件 - 以管理员身份运行一次。
    echo         若装了安全软件，可能是它拦截了 mklink。
    echo.
    pause
    exit /b 1
)
call :log "联接已建立: %SAVEPATH% 指向 %SAVEDIR%"
echo  [完成] 本机存档已指向 U 盘：%SAVEDIR%

:start_game
start "" /D "%GAMEDIR%" "%EXE%"
call :log "已启动游戏"
exit /b 0

rem =====================================================================
rem  子程序
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

:adopt
set "STAMP=%COMPUTERNAME%"
if exist "%GAMEDIR%backups_%STAMP%\" set "STAMP=%COMPUTERNAME%_%RANDOM%"
call :log "备份旧存档到 backups_%STAMP%"
robocopy "%SAVEPATH%" "%GAMEDIR%backups_%STAMP%" /E /R:1 /W:1 /NFL /NDL /NJH /NJS >nul
if errorlevel 8 (
    call :log "备份失败"
    exit /b 1
)
if exist "%SAVEDIR%\userdata\" (
    call :log "U 盘已有存档，跳过合并，旧存档仅备份"
    echo  [提示] U 盘上已经有存档，本机这份旧存档没有合并进去。
    echo         需要时从 backups_%STAMP% 手动拷进 save\userdata。
    echo         这样可以避免旧进度把 U 盘上的新进度盖掉。
    rmdir /s /q "%SAVEPATH%" >nul 2>&1
    if exist "%SAVEPATH%\" (
        call :log "旧目录删除失败"
        exit /b 1
    )
    exit /b 0
)
call :log "合并旧存档到 %SAVEDIR%"
robocopy "%SAVEPATH%" "%SAVEDIR%" /E /MOVE /R:1 /W:1 /NFL /NDL /NJH /NJS >nul
if errorlevel 8 (
    call :log "迁移失败"
    exit /b 1
)
rmdir "%SAVEPATH%" >nul 2>&1
if exist "%SAVEPATH%\" (
    call :log "旧目录删除失败"
    exit /b 1
)
echo  [完成] 已把本机旧存档搬到 U 盘，原件备份在 backups_%STAMP%
exit /b 0

:log
if not exist "%LOGDIR%\" exit /b 0
setlocal
set "MSG=%~1"
set "MSG=%MSG:>=＞%"
set "MSG=%MSG:<=＜%"
set "MSG=%MSG:|=｜%"
set "MSG=%MSG:&=＆%"
>>"%LOGDIR%\launcher.log" echo [%DATE% %TIME%] %MSG%
endlocal
exit /b 0
