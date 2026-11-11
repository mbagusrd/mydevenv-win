@echo off
echo [Stopping Portable Dev Stack]

taskkill /f /im nginx.exe >nul 2>&1
taskkill /f /im php-cgi.exe >nul 2>&1
taskkill /f /im mysqld.exe >nul 2>&1

echo All services stopped.
pause
