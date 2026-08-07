@echo off
rem Multi-game LOVE2D launcher for Windows.
rem ROM verification and private import happen inside the launcher.
title Pokemon Red Blue Yellow Crystal - LOVE2D port
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\bootstrap.ps1"
if errorlevel 1 (
  echo.
  echo Something went wrong - see the messages above.
  pause
)
