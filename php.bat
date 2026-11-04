@echo off
setlocal enabledelayedexpansion
set "ROOT=%~dp0"

:: Ambil default PHP dari .env
set "DEFAULT_PHP=8.4"
if exist "%ROOT%.env" (
    for /f "usebackq tokens=1,2 delims==" %%A in ("%ROOT%.env") do (
        if "%%A"=="DEFAULT_PHP_VERSION" set "DEFAULT_PHP=%%B"
    )
)

set "PHP_EXE=%ROOT%php\php-%DEFAULT_PHP%\php.exe"
if not exist "%PHP_EXE%" (
    echo [ERROR] PHP executable tidak ditemukan di: %PHP_EXE% >&2
    exit /b 1
)

"%PHP_EXE%" %*
exit /b %ERRORLEVEL%
