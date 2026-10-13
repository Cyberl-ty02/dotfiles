@echo off
emacsclientw.exe --eval "t" >nul 2>&1
if not errorlevel 1 (
    emacsclientw.exe --create-frame %*
    exit /b %errorlevel%
)
emacs.exe %*
