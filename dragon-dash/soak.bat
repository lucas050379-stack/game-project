@echo off
rem Headless autopilot soak. Prints one line per run:
rem   distance / kills / clear% / effective dps / power / gold
rem
rem   soak.bat            about 6 minutes of game time
rem   soak.bat 36000      frame count (60 = 1 second)
rem   soak.bat 21600 3000 start each run at 3000 m
set GODOT=%GODOT_BIN%
if "%GODOT%"=="" set GODOT=C:\tools\godot\Godot_v4.7.1-stable_win64_console.exe
cd /d "%~dp0"
set FRAMES=%1
if "%FRAMES%"=="" set FRAMES=21600
set SKIP=%2
if "%SKIP%"=="" set SKIP=0
"%GODOT%" --headless --path "%CD%" --fixed-fps 60 --quit-after %FRAMES% -- --autoplay --skip=%SKIP%
