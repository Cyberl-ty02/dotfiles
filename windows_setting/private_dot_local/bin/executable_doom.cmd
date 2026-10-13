@echo off
setlocal
set "DOOMCLI=%APPDATA%\.emacs.d\bin\doom.ps1"
if not exist "%DOOMCLI%" (
    echo Doom CLI not found: %DOOMCLI% 1>&2
    exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%DOOMCLI%" %*
