@echo off
setlocal enabledelayedexpansion
rem ==== Beatfall (Godot 4) ====
rem Exports dist\beatfall.exe and copies the songs folder next to it.
rem Songs are NOT packed into the exe - they are read from disk at runtime
rem so you can add new ones without rebuilding.

set GODOT=%GODOT_BIN%
if "%GODOT%"=="" set GODOT=C:\tools\godot\Godot_v4.7.1-stable_win64_console.exe
if not exist "%GODOT%" (
  echo ERROR: Godot not found at "%GODOT%"
  echo Set GODOT_BIN to the Godot console executable, or install it there.
  pause
  exit /b 1
)

cd /d "%~dp0"
if not exist dist mkdir dist

echo Importing resources...
"%GODOT%" --headless --path "%CD%" --import

echo Exporting...
"%GODOT%" --headless --path "%CD%" --export-release "Windows Desktop" "%CD%\dist\beatfall.exe"

if not exist dist\beatfall.exe (
  echo BUILD FAILED
  pause
  exit /b 1
)

echo Copying songs...
if not exist dist\songs mkdir dist\songs
xcopy /e /i /y /q songs dist\songs >nul

echo.
echo Done: dist\beatfall.exe
echo Songs live in dist\songs - add more with import.bat, no rebuild needed.
