@echo off
rem ==== Jellypop self check (headless) ====
rem   check.bat          board logic + stages (bot 12 runs each)
rem   check.bat stages   stages only, 60 runs each
rem   check.bat tune     suggest move limits per stage
set GODOT=%GODOT_BIN%
if "%GODOT%"=="" set GODOT=C:\tools\godot\Godot_v4.7.1-stable_win64_console.exe
cd /d "%~dp0"
"%GODOT%" --headless --path "%CD%" --import >nul 2>&1
"%GODOT%" --headless --path "%CD%" --script res://tools/check.gd -- %*
exit /b %ERRORLEVEL%
