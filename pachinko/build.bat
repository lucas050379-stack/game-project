@echo off
setlocal enabledelayedexpansion
rem ==== Pachinko: Immortal Yi Sun-sin (Godot 4) ====
rem Exports a single self-contained pachinko.exe (PCK embedded).

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
"%GODOT%" --headless --path "%CD%" --export-release "Windows Desktop" "%CD%\dist\pachinko.exe"

if not exist dist\pachinko.exe (
  echo BUILD FAILED
  pause
  exit /b 1
)

echo.
echo OK -^> dist\pachinko.exe
endlocal
