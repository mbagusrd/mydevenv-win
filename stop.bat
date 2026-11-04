@echo off
cd /d "%~dp0"

taskkill /f /im nginx.exe >nul 2>&1
taskkill /f /im php-cgi.exe >nul 2>&1
taskkill /f /im mysqld.exe >nul 2>&1

exit /b 0
