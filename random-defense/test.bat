@echo off
rem ==== Random Defense - craft logic tests ====
rem Headless checks for the crafting rules (see tools\test_craft.gd).

set GODOT=%GODOT_BIN%
if "%GODOT%"=="" set GODOT=C:\tools\godot\Godot_v4.7.1-stable_win64_console.exe
if not exist "%GODOT%" (
  echo ERROR: Godot not found at "%GODOT%"
  exit /b 1
)

cd /d "%~dp0"
"%GODOT%" --headless --path "%CD%" --script res://tools/test_craft.gd
