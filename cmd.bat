@echo off
set "ROOT=%~dp0"
echo =======================================================
echo     Dev Environment Shell (PHP, Composer, MariaDB)
echo =======================================================
echo ROOT: %ROOT%

:: Tambahkan root project dan MariaDB client ke PATH sesi ini
set "PATH=%ROOT%;%ROOT%bin\mariadb\bin;%PATH%"

echo.
call php -v
echo.
call composer --version
echo.
echo Shortcut tersedia:
echo - php        (PHP aktif sesuai .env)
echo - php82      (PHP 8.2)
echo - php83      (PHP 8.3)
echo - php84      (PHP 8.4)
echo - composer   (Composer via PHP aktif)
echo - mysql      (MariaDB client CLI)
echo.
cmd /k
