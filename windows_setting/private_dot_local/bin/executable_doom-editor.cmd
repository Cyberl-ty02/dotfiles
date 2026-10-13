@echo off
emacsclient.exe --eval "t" >nul 2>&1
if not errorlevel 1 (
    emacsclient.exe --tty %*
    exit /b %errorlevel%
)
emacs.exe -nw %*
