@echo off
setlocal
rem Keep native Windows Emacs on its APPDATA-based Doom installation.
set "HOME="
emacsclientw.exe --eval "t" >nul 2>&1
if not errorlevel 1 (
    emacsclientw.exe --create-frame %*
    exit /b %errorlevel%
)
emacs.exe %*
