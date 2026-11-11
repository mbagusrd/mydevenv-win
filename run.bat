@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"
title MyDevEnv-Win - Control Panel

:main_menu
cls
echo =======================================================
echo          MyDevEnv-Win - Portable Dev Control Panel
echo =======================================================
echo.

:: Cek status service
set "STATUS_NGINX=[OFF]"
set "STATUS_MARIADB=[OFF]"
set "STATUS_PHP=[OFF]"

tasklist /fi "imagename eq nginx.exe" 2>nul | find /i "nginx.exe" >nul && set "STATUS_NGINX=[ON]"
tasklist /fi "imagename eq mysqld.exe" 2>nul | find /i "mysqld.exe" >nul && set "STATUS_MARIADB=[ON]"
tasklist /fi "imagename eq php-cgi.exe" 2>nul | find /i "php-cgi.exe" >nul && set "STATUS_PHP=[ON]"

set "CURRENT_PHP=8.4"
if exist ".env" (
    for /f "usebackq tokens=1,2 delims==" %%A in (".env") do (
        if "%%A"=="DEFAULT_PHP_VERSION" set "CURRENT_PHP=%%B"
    )
)

echo Status Services:
echo   Nginx   : %STATUS_NGINX% (Port 80, 8056, 8074, 8082, 8083, 8084)
echo   MariaDB : %STATUS_MARIADB% (Port 3306)
echo   PHP-CGI : %STATUS_PHP% (Default Port 80: PHP %CURRENT_PHP%)
echo.
echo -------------------------------------------------------
echo  [1] Start All Services (Background)
echo  [2] Stop All Services
echo  [3] Restart All Services
echo  [4] Switch Default PHP Version (Port 80)
echo  [5] Open Dev Terminal (cmd.bat with PATH)
echo  [6] Open Web in Browser (http://localhost)
echo  [7] Install / Re-install Dependencies (install.bat)
echo  [8] Check Status Details
echo  [9] Manage User PATH (Add/Remove from Windows PATH)
echo  [0] Exit
echo -------------------------------------------------------
set "CHOICE="
set /p "CHOICE=Pilih menu [0-9]: "

if "%CHOICE%"=="1" goto :action_start
if "%CHOICE%"=="2" goto :action_stop
if "%CHOICE%"=="3" goto :action_restart
if "%CHOICE%"=="4" goto :submenu_switch_php
if "%CHOICE%"=="5" goto :action_terminal
if "%CHOICE%"=="6" goto :action_browser
if "%CHOICE%"=="7" goto :action_install
if "%CHOICE%"=="8" goto :action_status
if "%CHOICE%"=="9" goto :submenu_path
if "%CHOICE%"=="0" goto :action_exit

echo Pilihan tidak valid.
timeout /t 2 >nul
goto :main_menu

:action_start
echo.
echo Menjalankan services di background...
call start.bat --silent
timeout /t 2 >nul
goto :main_menu

:action_stop
echo.
echo Menghentikan seluruh services...
call stop.bat
timeout /t 1 >nul
goto :main_menu

:action_restart
echo.
echo Me-restart services...
call stop.bat
timeout /t 1 >nul
call start.bat --silent
timeout /t 2 >nul
goto :main_menu

:submenu_switch_php
cls
echo =======================================================
echo              Switch Default PHP Version
echo =======================================================
echo.
echo PHP aktif saat ini pada Port 80: PHP %CURRENT_PHP%
echo.
echo  [1] PHP 5.6 (Port 9056)
echo  [2] PHP 7.4 (Port 9074)
echo  [3] PHP 8.2 (Port 9082)
echo  [4] PHP 8.3 (Port 9083)
echo  [5] PHP 8.4 (Port 9084)
echo  [0] Kembali ke Menu Utama
echo -------------------------------------------------------
set "PHP_CHOICE="
set /p "PHP_CHOICE=Pilih versi [0-5]: "

if "%PHP_CHOICE%"=="0" goto :main_menu

set "NEW_VER="
set "NEW_PORT="
if "%PHP_CHOICE%"=="1" (set "NEW_VER=5.6" & set "NEW_PORT=9056")
if "%PHP_CHOICE%"=="2" (set "NEW_VER=7.4" & set "NEW_PORT=9074")
if "%PHP_CHOICE%"=="3" (set "NEW_VER=8.2" & set "NEW_PORT=9082")
if "%PHP_CHOICE%"=="4" (set "NEW_VER=8.3" & set "NEW_PORT=9083")
if "%PHP_CHOICE%"=="5" (set "NEW_VER=8.4" & set "NEW_PORT=9084")

if "%NEW_VER%"=="" (
    echo Pilihan tidak valid.
    timeout /t 2 >nul
    goto :submenu_switch_php
)

if exist "bin\nginx\conf" (
    echo fastcgi_pass 127.0.0.1:%NEW_PORT%; > "bin\nginx\conf\default_php.conf"
)
powershell -Command "if (Test-Path '.env') { (Get-Content '.env') -replace '^DEFAULT_PHP_VERSION=.*', 'DEFAULT_PHP_VERSION=%NEW_VER%' | Set-Content '.env' }"

tasklist /fi "imagename eq nginx.exe" 2>nul | find /i "nginx.exe" >nul
if %ERRORLEVEL% equ 0 (
    pushd "bin\nginx"
    nginx.exe -p "%~dp0bin\nginx" -s reload
    popd
)

echo.
echo [OK] Default PHP diubah ke PHP %NEW_VER%!
timeout /t 2 >nul
goto :main_menu

:action_terminal
start "" cmd.exe /c "cmd.bat"
goto :main_menu

:action_browser
start http://localhost
goto :main_menu

:action_install
cls
echo =======================================================
echo          Install / Re-install Dependencies
echo =======================================================
echo.
echo Menu ini akan menjalankan installer untuk mengunduh
echo dan mengekstrak komponen jika belum lengkap.
echo.
echo  [1] Lanjutkan Instalasi
echo  [0] Batal / Kembali ke Menu Utama
echo -------------------------------------------------------
set "INS_CHOICE="
set /p "INS_CHOICE=Pilih [0/1]: "
if "%INS_CHOICE%"=="1" (
    call install.bat
    goto :main_menu
)
goto :main_menu

:action_status
cls
echo =======================================================
echo                 Detail Status Process
echo =======================================================
echo.
echo [Process List]
tasklist | findstr /i "nginx mysqld php-cgi"
if %ERRORLEVEL% neq 0 echo Tidak ada process aktif.
echo.
echo [Listening Ports]
netstat -ano | findstr /i "LISTENING" | findstr /r ":80 :8056 :8074 :8082 :8083 :8084 :3306 :9056 :9074 :9082 :9083 :9084"
echo.
pause
goto :main_menu

:submenu_path
cls
echo =======================================================
echo            Manage Windows User PATH
echo =======================================================
echo.
echo Menambahkan folder project dan MariaDB ke User PATH
echo agar 'php', 'composer', dan 'mysql' bisa langsung
echo dipanggil di Command Prompt / PowerShell manapun.
echo.
echo  [1] Tambahkan ke User PATH (Permanent)
echo  [2] Hapus dari User PATH
echo  [0] Kembali ke Menu Utama
echo -------------------------------------------------------
set "PATH_OPT="
set /p "PATH_OPT=Pilih menu [0-2]: "

if "%PATH_OPT%"=="0" goto :main_menu

if "%PATH_OPT%"=="1" (
    powershell -NoProfile -Command ^
        "$root = (Get-Item -Path '%~dp0').FullName.TrimEnd('\');" ^
        "$mysql = Join-Path $root 'bin\mariadb\bin';" ^
        "$old = [Environment]::GetEnvironmentVariable('Path', 'User');" ^
        "$parts = @($old -split ';' | Where-Object { $_ -ne '' -and $_ -ne $root -and $_ -ne $mysql });" ^
        "$new = ($parts + @($root, $mysql)) -join ';';" ^
        "[Environment]::SetEnvironmentVariable('Path', $new, 'User');"
    echo.
    echo [OK] Berhasil ditambahkan ke User PATH!
    echo Catatan: Buka jendela CMD/PowerShell baru agar efek terasa.
    pause
    goto :main_menu
)

if "%PATH_OPT%"=="2" (
    powershell -NoProfile -Command ^
        "$root = (Get-Item -Path '%~dp0').FullName.TrimEnd('\');" ^
        "$mysql = Join-Path $root 'bin\mariadb\bin';" ^
        "$old = [Environment]::GetEnvironmentVariable('Path', 'User');" ^
        "$parts = @($old -split ';' | Where-Object { $_ -ne '' -and $_ -ne $root -and $_ -ne $mysql });" ^
        "$new = $parts -join ';';" ^
        "[Environment]::SetEnvironmentVariable('Path', $new, 'User');"
    echo.
    echo [OK] Berhasil dihapus dari User PATH!
    pause
    goto :main_menu
)

echo Pilihan tidak valid.
timeout /t 2 >nul
goto :submenu_path

:action_exit
exit /b 0
