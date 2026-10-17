@echo off
setlocal
rem Keep native Windows Emacs on its APPDATA-based Doom installation.
set "HOME="
set "LANG=en_US.UTF-8"
set "LC_ALL=en_US.UTF-8"
if exist "%ProgramFiles%\Git\cmd\git.exe" set "PATH=%ProgramFiles%\Git\cmd;%PATH%"
emacsclient.exe --eval "t" >nul 2>&1
if not errorlevel 1 (
    emacsclient.exe --tty %*
    exit /b %errorlevel%
)
emacs.exe --init-directory "%APPDATA%\.emacs.d" -nw %*
