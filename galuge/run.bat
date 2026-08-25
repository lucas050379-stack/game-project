@echo off
rem Runs galuge from source without exporting.
set GODOT=%GODOT_BIN%
if "%GODOT%"=="" set GODOT=C:\tools\godot\Godot_v4.7.1-stable_win64_console.exe
cd /d "%~dp0"
"%GODOT%" --path "%CD%" %*