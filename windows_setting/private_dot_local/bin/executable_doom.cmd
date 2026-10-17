@echo off
setlocal
rem Git Bash exports HOME, which makes native Windows Emacs ignore APPDATA.
set "HOME="
rem Do not depend on the parent process having refreshed its machine PATH.
if exist "%ProgramFiles%\Git\cmd\git.exe" set "PATH=%ProgramFiles%\Git\cmd;%PATH%"
set "DOOMCLI=%APPDATA%\.emacs.d\bin\doom.ps1"
if not exist "%DOOMCLI%" (
    echo Doom CLI not found: %DOOMCLI% 1>&2
    exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%DOOMCLI%" %*
