@echo off
rem Runs jellypop from source in a desktop window (fastest way to check a change).
rem   run.bat -- --auto                 bot plays by itself
rem   run.bat -- --auto --time=12       short game, to see the result screen
rem   run.bat -- --sp-demo              board with one of each special block
rem   run.bat -- --input-test           drag with real mouse events, exit code 1 on failure
rem   run.bat -- --auto --shot=out.png --shot-at=6
set GODOT=%GODOT_BIN%
if "%GODOT%"=="" set GODOT=C:\tools\godot\Godot_v4.7.1-stable_win64_console.exe
cd /d "%~dp0"
"%GODOT%" --path "%CD%" %*
