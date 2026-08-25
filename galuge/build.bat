@echo off
setlocal enabledelayedexpansion
rem ==== Galuge (Godot 4) ====
rem Exports two single-file executables:
rem   dist\galuge.exe       normal build
rem   dist\galuge-test.exe  test build (round select, feature tag "testmode")

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

echo Exporting normal build...
"%GODOT%" --headless --path "%CD%" --export-release "Windows Desktop" "%CD%\dist\galuge.exe"

echo Exporting test build...
"%GODOT%" --headless --path "%CD%" --export-release "Windows Desktop Test" "%CD%\dist\galuge-test.exe"

if not exist dist\galuge.exe (
  echo BUILD FAILED ^(normal^)
  pause
  exit /b 1
)
if not exist dist\galuge-test.exe (
  echo BUILD FAILED ^(test^)
  pause
  exit /b 1
)

echo.
echo OK -^> dist\galuge.exe        normal
echo OK -^> dist\galuge-test.exe   test ^(round select^)
endlocal