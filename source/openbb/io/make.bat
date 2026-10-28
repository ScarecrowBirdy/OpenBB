@echo off
call "%~dp0..\..\..\make.bat" -Test %*
exit /b %errorlevel%
