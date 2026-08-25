@echo off
setlocal enabledelayedexpansion
rem ==== Dragon Dash (Godot 4) ====
rem   dist\dragon-dash.apk        Android (debug-signed)
rem   dist\dragon-dash.exe        Windows  (for checking on PC)
rem   dist\dragon-dash-test.exe   Windows  test build (feature tag "testmode")
rem
rem Usage:  build.bat            everything
rem         build.bat apk        Android only
rem         build.bat win        Windows only

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

set WHAT=%1
if "%WHAT%"=="" set WHAT=all

echo Importing resources...
"%GODOT%" --headless --path "%CD%" --import

if "%WHAT%"=="win" goto :windows

rem ---- Android ----
rem Godot reads the SDK / JDK / debug keystore from its EDITOR SETTINGS, not from
rem environment variables. See README section "APK" for the three paths.
echo.
echo Exporting Android APK...
"%GODOT%" --headless --path "%CD%" --export-debug "Android" "%CD%\dist\dragon-dash.apk"
if not exist dist\dragon-dash.apk (
  echo.
  echo BUILD FAILED ^(apk^)
  echo   Check Godot editor settings:
  echo     export/android/android_sdk_path
  echo     export/android/java_sdk_path
  echo     export/android/debug_keystore
  pause
  exit /b 1
)
if "%WHAT%"=="apk" goto :done

:windows
echo.
echo Exporting Windows build...
"%GODOT%" --headless --path "%CD%" --export-release "Windows Desktop" "%CD%\dist\dragon-dash.exe"
echo Exporting Windows test build...
"%GODOT%" --headless --path "%CD%" --export-release "Windows Desktop Test" "%CD%\dist\dragon-dash-test.exe"
if not exist dist\dragon-dash.exe (
  echo BUILD FAILED ^(windows^)
  pause
  exit /b 1
)

:done
echo.
if exist dist\dragon-dash.apk echo OK -^> dist\dragon-dash.apk        Android
if exist dist\dragon-dash.exe echo OK -^> dist\dragon-dash.exe        Windows
if exist dist\dragon-dash-test.exe echo OK -^> dist\dragon-dash-test.exe   Windows test
endlocal
