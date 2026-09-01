@echo off
rem ==== proyamae -- verify the scraped raw data ====
rem Reports any season whose six tables disagree (a whole team silently
rem missing from one table is invisible in the game but corrupts the ratings).
setlocal
cd /d "%~dp0"
set GODOT=%GODOT_BIN%
if "%GODOT%"=="" set GODOT=C:\tools\godot\Godot_v4.7.1-stable_win64_console.exe
if not exist "%GODOT%" echo ERROR: Godot not found. Set GODOT_BIN. & exit /b 1
"%GODOT%" --headless --path "%CD%" --script tools/check.gd
endlocal
