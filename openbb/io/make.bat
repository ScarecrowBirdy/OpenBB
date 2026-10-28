@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\build.ps1" -Test %*
exit /b %errorlevel%
