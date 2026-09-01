@echo off
rem Runs the headless self-check (chart sanity + auto-charting accuracy).
rem Pass "sweep" to grid-search the onset thresholds instead.
set GODOT=%GODOT_BIN%
if "%GODOT%"=="" set GODOT=C:\tools\godot\Godot_v4.7.1-stable_win64_console.exe
cd /d "%~dp0"
set CMD=%1
if "%CMD%"=="" set CMD=check
"%GODOT%" --headless --path "%CD%" --script src/tool.gd -- %CMD%
