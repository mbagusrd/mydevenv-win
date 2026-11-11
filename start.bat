@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"
set "ROOT=%~dp0"

:: --silent flag: run all services fully hidden (no console windows, no output)
set "SILENT=0"
if /i "%~1"=="--silent" set "SILENT=1"

if "%SILENT%"=="0" echo [Starting Portable Dev Stack]

:: 0. Parse .env
set "NGINX_ROOT=../../www"
set "DEFAULT_PHP=8.4"
if exist "%ROOT%.env" (
    for /f "usebackq tokens=1,2 delims==" %%A in ("%ROOT%.env") do (
        if "%%A"=="NGINX_WEB_ROOT" set "NGINX_ROOT=%%B"
        if "%%A"=="DEFAULT_PHP_VERSION" set "DEFAULT_PHP=%%B"
    )
)

:: Jika NGINX_ROOT adalah relative path (misal ../../www), ubah ke full absolute path
if "%NGINX_ROOT:~0,2%"==".." (
    pushd "%ROOT%bin\nginx"
    for /f "delims=" %%I in ("%NGINX_ROOT%") do set "FULL_WEBROOT=%%~fI"
    popd
) else (
    set "FULL_WEBROOT=%NGINX_ROOT%"
)

:: Normalize backward slashes to forward slashes for Nginx
set "NGINX_ROOT_FORMATTED=!FULL_WEBROOT:\=/!"
echo root "!NGINX_ROOT_FORMATTED!"; > "%ROOT%bin\nginx\conf\webroot.conf"
if "%SILENT%"=="0" echo Nginx Root: !NGINX_ROOT_FORMATTED!

:: Set Default PHP Port for Port 80
set "PHP_PORT=9084"
if "!DEFAULT_PHP!"=="5.6" set "PHP_PORT=9056"
if "!DEFAULT_PHP!"=="7.4" set "PHP_PORT=9074"
if "!DEFAULT_PHP!"=="8.2" set "PHP_PORT=9082"
if "!DEFAULT_PHP!"=="8.3" set "PHP_PORT=9083"
if "!DEFAULT_PHP!"=="8.4" set "PHP_PORT=9084"
echo fastcgi_pass 127.0.0.1:!PHP_PORT!; > "%ROOT%bin\nginx\conf\default_php.conf"
if "%SILENT%"=="0" echo Default PHP on Port 80: !DEFAULT_PHP! (port !PHP_PORT!)

:: 1. MariaDB...
if "%SILENT%"=="0" echo 1. MariaDB...
call :launch "MariaDB" "%ROOT%bin\mariadb\bin\mysqld.exe" --basedir="%ROOT%bin\mariadb" --datadir="%ROOT%bin\mariadb\data" --console

:: 2. PHP-CGI FastCGI...
if "%SILENT%"=="0" echo 2. PHP-CGI FastCGI...
call :launch "PHP 5.6 CGI" "%ROOT%php\php-5.6\php-cgi.exe" -b 127.0.0.1:9056 -c "%ROOT%php\php-5.6\php.ini"
call :launch "PHP 7.4 CGI" "%ROOT%php\php-7.4\php-cgi.exe" -b 127.0.0.1:9074 -c "%ROOT%php\php-7.4\php.ini"
call :launch "PHP 8.2 CGI" "%ROOT%php\php-8.2\php-cgi.exe" -b 127.0.0.1:9082 -c "%ROOT%php\php-8.2\php.ini"
call :launch "PHP 8.3 CGI" "%ROOT%php\php-8.3\php-cgi.exe" -b 127.0.0.1:9083 -c "%ROOT%php\php-8.3\php.ini"
call :launch "PHP 8.4 CGI" "%ROOT%php\php-8.4\php-cgi.exe" -b 127.0.0.1:9084 -c "%ROOT%php\php-8.4\php.ini"

:: 3. Nginx...
if "%SILENT%"=="0" echo 3. Nginx...
call :launch "Nginx" "%ROOT%bin\nginx\nginx.exe" -p "%ROOT%bin\nginx"

if "%SILENT%"=="1" exit /b 0

echo.
echo Dev environment running!
echo URL:
echo - Default (Port 80): http://localhost (PHP !DEFAULT_PHP!)
echo - PHP 5.6 (Port 8056): http://localhost:8056
echo - PHP 7.4 (Port 8074): http://localhost:8074
echo - PHP 8.2 (Port 8082): http://localhost:8082
echo - PHP 8.3 (Port 8083): http://localhost:8083
echo - PHP 8.4 (Port 8084): http://localhost:8084
echo - MariaDB: 127.0.0.1:3306 (user: root)
echo.
echo Press any key to close this window (services remain active).
pause >nul
exit /b 0

:: launch title exe [args...]  -> hidden in silent mode, minimized window otherwise
:launch
if "%SILENT%"=="1" (
    wscript "%ROOT%run-hidden.vbs" "%~2" %3 %4 %5 %6 %7
) else (
    start "%~1" /min "%~2" %3 %4 %5 %6 %7
)
goto :eof
