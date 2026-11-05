@echo off
setlocal
set "ROOT=%~dp0"
set "PHP_EXE=%ROOT%php\php-7.4\php.exe"
if not exist "%PHP_EXE%" (
    echo [ERROR] PHP 7.4 tidak ditemukan di %PHP_EXE% >&2
    exit /b 1
)
"%PHP_EXE%" %*
exit /b %ERRORLEVEL%
