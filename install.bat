@echo off
setlocal
cd /d "%~dp0"

echo =======================================================
echo   Portable Dev Stack Installer (Nginx, PHP, MariaDB)
echo =======================================================
echo.

:: Cek PowerShell
where powershell >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] PowerShell tidak ditemukan pada sistem ini!
    pause
    exit /b 1
)

:: Tanya password root MariaDB (default: root)
set "DB_PASS=root"
set /p "INPUT_PASS=Masukkan password root MariaDB [default: root]: "
if not "%INPUT_PASS%"=="" set "DB_PASS=%INPUT_PASS%"

echo.
echo Menjalankan proses download dan instalasi...
echo Harap tunggu hingga selesai...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" -MariaDbRootPassword "%DB_PASS%"

if %ERRORLEVEL% equ 0 (
    echo.
    echo =======================================================
    echo   Instalasi Selesai!
    echo   File konfigurasi: .env
    echo   Jalankan: start.bat
    echo   Matikan:  stop.bat
    echo =======================================================
) else (
    echo.
    echo [ERROR] Terjadi kesalahan saat proses instalasi.
)

pause
