@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"
set "ROOT=%~dp0"

:: Jalankan secara silent jika dipanggil dengan parameter /silent atau via VBS
if "%1"=="--silent" goto :run_services
if "%1"=="/silent" goto :run_services

:: Jika dijalankan manual tanpa parameter, jalankan via WScript agar 100% background tanpa window
start "" wscript.exe "%ROOT%start-silent.vbs"
exit /b 0

:run_services

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
echo Nginx Root: !NGINX_ROOT_FORMATTED!

:: Set Default PHP Port for Port 80
set "PHP_PORT=9084"
if "!DEFAULT_PHP!"=="5.6" set "PHP_PORT=9056"
if "!DEFAULT_PHP!"=="7.4" set "PHP_PORT=9074"
if "!DEFAULT_PHP!"=="8.2" set "PHP_PORT=9082"
if "!DEFAULT_PHP!"=="8.3" set "PHP_PORT=9083"
if "!DEFAULT_PHP!"=="8.4" set "PHP_PORT=9084"
echo fastcgi_pass 127.0.0.1:!PHP_PORT!; > "%ROOT%bin\nginx\conf\default_php.conf"
echo Default PHP on Port 80: !DEFAULT_PHP! (port !PHP_PORT!)

echo 1. MariaDB...
start "MariaDB" /b "%ROOT%bin\mariadb\bin\mysqld.exe" --basedir="%ROOT%bin\mariadb" --datadir="%ROOT%bin\mariadb\data"

echo 2. PHP-CGI FastCGI...
start "PHP 5.6 CGI" /b "%ROOT%php\php-5.6\php-cgi.exe" -b 127.0.0.1:9056 -c "%ROOT%php\php-5.6\php.ini"
start "PHP 7.4 CGI" /b "%ROOT%php\php-7.4\php-cgi.exe" -b 127.0.0.1:9074 -c "%ROOT%php\php-7.4\php.ini"
start "PHP 8.2 CGI" /b "%ROOT%php\php-8.2\php-cgi.exe" -b 127.0.0.1:9082 -c "%ROOT%php\php-8.2\php.ini"
start "PHP 8.3 CGI" /b "%ROOT%php\php-8.3\php-cgi.exe" -b 127.0.0.1:9083 -c "%ROOT%php\php-8.3\php.ini"
start "PHP 8.4 CGI" /b "%ROOT%php\php-8.4\php-cgi.exe" -b 127.0.0.1:9084 -c "%ROOT%php\php-8.4\php.ini"

echo 3. Nginx...
pushd "%ROOT%bin\nginx"
start "Nginx" /b nginx.exe -p "%ROOT%bin\nginx"
popd

exit /b 0
