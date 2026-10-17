@echo off
setlocal
rem Keep native Windows Emacs on its APPDATA-based Doom installation.
set "HOME="
if exist "%ProgramFiles%\Git\cmd\git.exe" set "PATH=%ProgramFiles%\Git\cmd;%PATH%"
emacsclient.exe --eval "t" >nul 2>&1
if not errorlevel 1 (
    emacsclient.exe --tty %*
    exit /b %errorlevel%
)
call "%~dp0doom.cmd" emacs -- -nw %*
