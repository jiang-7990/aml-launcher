@echo off
setlocal EnableExtensions
title PvZ portable save launcher

rem =====================================================================
rem  Plants vs. Zombies - portable save launcher
rem
rem  WHAT IT DOES
rem   The real save folder lives on THIS drive:  <script dir>\save
rem   The path the game writes to is turned into a directory junction
rem   that points at it.  The junction is rebuilt on every start, so a
rem   changed drive letter (E: -> F: ...) is repaired automatically.
rem
rem  HOW TO USE
rem   1. put this .cmd next to PlantsVsZombies.exe
rem   2. close the game, double-click this file
rem   3. always start the game through it (or a shortcut to it)
rem
rem  EDIT the two settings below if your copy is different.
rem =====================================================================

set "EXENAME=PlantsVsZombies.exe"
set "SAVEPATH=%ProgramData%\PopCap Games\PlantsVsZombies"

set "GAMEDIR=%~dp0"
set "SAVEDIR=%GAMEDIR%save"
set "BACKUPDIR=%~dp0save-backups"

rem ---- 0. use whichever known save folder this copy really writes to ---
call :detect

rem ---- 1. junction already there?  drop it (it may use a stale letter) --
fsutil reparsepoint query "%SAVEPATH%" >nul 2>&1
if not errorlevel 1 (
    rmdir "%SAVEPATH%" >nul 2>&1
    goto :make_link
)

rem ---- 2. a real folder on this PC: back it up, then merge onto drive --
if not exist "%SAVEPATH%\" goto :make_link
call :adopt

:make_link
if exist "%SAVEPATH%\" (
    echo  [WARN] "%SAVEPATH%" could not be replaced.
    echo         Close the game / open a console as administrator, run again.
    goto :start_game
)
if not exist "%SAVEDIR%\" mkdir "%SAVEDIR%" >nul 2>&1
for %%D in ("%SAVEPATH%") do if not exist "%%~dpD" mkdir "%%~dpD" >nul 2>&1
mklink /J "%SAVEPATH%" "%SAVEDIR%" >nul
if errorlevel 1 (
    echo.
    echo  [ERROR] Could not create the junction:
    echo          "%SAVEPATH%"
    echo      -^>  "%SAVEDIR%"
    echo.
    echo  Fix: right-click this file, "Run as administrator" once.
    echo.
    pause
    exit /b 1
)

:start_game
if not exist "%GAMEDIR%%EXENAME%" (
    echo.
    echo  [ERROR] "%EXENAME%" not found next to this file.
    echo          Edit EXENAME= at the top of the script.
    echo.
    pause
    exit /b 1
)
start "" "%GAMEDIR%%EXENAME%"
exit /b 0

rem =====================================================================
:detect
rem keep SAVEPATH if it already holds save data, else try known locations
if exist "%SAVEPATH%\userdata\" exit /b 0
for %%P in (
    "%ProgramData%\PopCap Games\PlantsVsZombies"
    "%APPDATA%\PopCap\PlantsVsZombies"
    "%LOCALAPPDATA%\PopCap\PlantsVsZombies"
    "%ProgramData%\PopCap\PlantsVsZombies"
) do (
    if exist "%%~P\userdata\" (
        set "SAVEPATH=%%~P"
        exit /b 0
    )
)
exit /b 0

rem =====================================================================
:adopt
set "STAMP=%COMPUTERNAME%"
if exist "%BACKUPDIR%_%STAMP%" set "STAMP=%COMPUTERNAME%_%RANDOM%"
echo  [setup] Backing up "%SAVEPATH%"
robocopy "%SAVEPATH%" "%BACKUPDIR%_%STAMP%" /E /NFL /NDL /NJH /NJS >nul
echo  [setup] Merging it into "%SAVEDIR%"
robocopy "%SAVEPATH%" "%SAVEDIR%" /E /MOVE /NFL /NDL /NJH /NJS >nul
rmdir "%SAVEPATH%" >nul 2>&1
exit /b 0
