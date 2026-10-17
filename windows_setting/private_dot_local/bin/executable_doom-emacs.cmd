@echo off
setlocal
rem Keep native Windows Emacs on its APPDATA-based Doom installation.
set "HOME="
if exist "%ProgramFiles%\Git\cmd\git.exe" set "PATH=%ProgramFiles%\Git\cmd;%PATH%"
emacsclientw.exe --eval "t" >nul 2>&1
if not errorlevel 1 (
    emacsclientw.exe --create-frame %*
    exit /b %errorlevel%
)
call "%~dp0doom.cmd" emacs -- %*
