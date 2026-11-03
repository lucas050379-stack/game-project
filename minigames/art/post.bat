@echo off
rem Picked candidate -> art\<name>.png   (see ..\tools\post.gd)
rem   post.bat source\block_0_02_s12345.jpg block_0 key
rem   modes: key (remove flat background, crop, 256x256)  fx (brightness -> alpha, 128x128)  plain
set GODOT=%GODOT_BIN%
if "%GODOT%"=="" set GODOT=C:\tools\godot\Godot_v4.7.1-stable_win64_console.exe
cd /d "%~dp0.."
"%GODOT%" --headless --path "%CD%" --script res://tools/post.gd -- "%~f1" %2 %3 %4
