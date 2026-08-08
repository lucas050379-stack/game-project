@echo off
setlocal
rem ==== Headless RTP / probability simulation ====
set GODOT=%GODOT_BIN%
if "%GODOT%"=="" set GODOT=C:\tools\godot\Godot_v4.7.1-stable_win64_console.exe
if not exist "%GODOT%" (
  echo ERROR: Godot not found at "%GODOT%"
  pause
  exit /b 1
)
cd /d "%~dp0"
"%GODOT%" --headless --path "%CD%" --import >nul
"%GODOT%" --headless --path "%CD%" --script res://src/sim.gd
pause
endlocal
