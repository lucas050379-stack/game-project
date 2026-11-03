@echo off
rem Cloudflare Workers AI -> art\source\<name>_NN_s<seed>.jpg   (see gen.ps1)
rem   gen.bat block_0
rem   gen.bat block_0 -Count 8
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0gen.ps1" -Name %*
