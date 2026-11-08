@echo off
rem U disk game launcher entry
setlocal
set "HERE=%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%HERE%Launcher\Start.ps1" %*
set "RC=%ERRORLEVEL%"
endlocal & exit /b %RC%
