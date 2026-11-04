@echo off
setlocal
set "ROOT=%~dp0"
set "PHP_EXE=%ROOT%php\php-8.3\php.exe"
if not exist "%PHP_EXE%" (
    echo [ERROR] PHP 8.3 tidak ditemukan di %PHP_EXE% >&2
    exit /b 1
)
"%PHP_EXE%" %*
exit /b %ERRORLEVEL%
