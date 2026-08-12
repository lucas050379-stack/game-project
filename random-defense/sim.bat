@echo off
rem ==== Random Defense - headless balance check ====
rem Plays all rounds with an "ideal player" and prints how close each round was.

set GODOT=%GODOT_BIN%
if "%GODOT%"=="" set GODOT=C:\tools\godot\Godot_v4.7.1-stable_win64_console.exe
if not exist "%GODOT%" (
  echo ERROR: Godot not found at "%GODOT%"
  exit /b 1
)

cd /d "%~dp0"
"%GODOT%" --headless --path "%CD%" --script res://tools/sim.gd
