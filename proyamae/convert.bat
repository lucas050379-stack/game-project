@echo off
rem ==== proyamae -- raw KBO records to card stats ====
rem   convert.bat            all fetched years
rem   convert.bat 2003       one season
rem   convert.bat 2000 2010  a range
setlocal
cd /d "%~dp0"
set GODOT=%GODOT_BIN%
if "%GODOT%"=="" set GODOT=C:\tools\godot\Godot_v4.7.1-stable_win64_console.exe
if not exist "%GODOT%" echo ERROR: Godot not found. Set GODOT_BIN. & exit /b 1
"%GODOT%" --headless --path "%CD%" --script tools/convert.gd -- %1 %2
endlocal
