@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo =======================================================
echo           Switch Default PHP Version (Port 80)
echo =======================================================
echo.
echo Pilih versi PHP default untuk http://localhost (Port 80):
echo [1] PHP 5.6 (Port 9056)
echo [2] PHP 7.4 (Port 9074)
echo [3] PHP 8.2 (Port 9082)
echo [4] PHP 8.3 (Port 9083)
echo [5] PHP 8.4 (Port 9084)
echo.

set "CHOICE="
set /p "CHOICE=Masukkan pilihan (1-5): "

set "TARGET_VER="
set "TARGET_PORT="
if "%CHOICE%"=="1" (
    set "TARGET_VER=5.6"
    set "TARGET_PORT=9056"
)
if "%CHOICE%"=="2" (
    set "TARGET_VER=7.4"
    set "TARGET_PORT=9074"
)
if "%CHOICE%"=="3" (
    set "TARGET_VER=8.2"
    set "TARGET_PORT=9082"
)
if "%CHOICE%"=="4" (
    set "TARGET_VER=8.3"
    set "TARGET_PORT=9083"
)
if "%CHOICE%"=="5" (
    set "TARGET_VER=8.4"
    set "TARGET_PORT=9084"
)

if "%TARGET_VER%"=="" (
    echo [ERROR] Pilihan tidak valid!
    pause
    exit /b 1
)

:: Update default_php.conf
if exist "bin\nginx\conf" (
    echo fastcgi_pass 127.0.0.1:%TARGET_PORT%; > "bin\nginx\conf\default_php.conf"
)

:: Update or append DEFAULT_PHP_VERSION in .env
powershell -Command "if (Test-Path '.env') { (Get-Content '.env') -replace '^DEFAULT_PHP_VERSION=.*', 'DEFAULT_PHP_VERSION=%TARGET_VER%' | Set-Content '.env' }"

:: Reload Nginx jika sedang berjalan
tasklist /fi "imagename eq nginx.exe" | find /i "nginx.exe" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo Reloading Nginx configuration...
    pushd "bin\nginx"
    nginx.exe -p "%~dp0bin\nginx" -s reload
    popd
    echo [OK] Nginx reloaded!
)

echo.
echo =======================================================
echo   Default PHP diubah ke PHP %TARGET_VER%!
echo   http://localhost sekarang mengarah ke PHP %TARGET_VER%
echo =======================================================
echo.
pause
