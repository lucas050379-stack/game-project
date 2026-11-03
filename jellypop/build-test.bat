@echo off
rem ==== Jellypop - test build: every stage unlocked, separate save (save_test.cfg) ====
rem   dist\web-test\ + dist\jellypop-test.exe
rem Same steps as build.bat, only the presets differ ("Web Test" / "Windows Test", feature tag testbuild).
call "%~dp0build.bat" test
