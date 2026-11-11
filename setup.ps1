param(
    [string]$MariaDbRootPassword = "root"
)

$ErrorActionPreference = "Stop"
$BaseDir = $PSScriptRoot

Write-Host "=== Setting up Portable Dev Environment in $BaseDir ===" -ForegroundColor Cyan

$binDir = Join-Path $BaseDir "bin"
$phpDir = Join-Path $BaseDir "php"
$nginxDir = Join-Path $binDir "nginx"
$mariadbDir = Join-Path $binDir "mariadb"
$wwwDir = Join-Path $BaseDir "www"
$logsDir = Join-Path $BaseDir "logs"
$tmpDir = Join-Path $BaseDir "tmp"
$archivesDir = Join-Path $BaseDir "archives"

@($binDir, $phpDir, $wwwDir, $logsDir, $tmpDir, $archivesDir) | ForEach-Object {
    if (-not (Test-Path $_)) { New-Item -ItemType Directory -Path $_ -Force | Out-Null }
}

function Install-VcRuntime {
    param([string]$DllName, [string]$Url, [string]$ArchiveName, [string]$Label)
    $sysDll = Join-Path $env:SystemRoot "System32\$DllName"
    if (Test-Path $sysDll) {
        Write-Host "$Label already installed, skipping." -ForegroundColor Green
        return
    }
    $installer = Join-Path $archivesDir $ArchiveName
    if (-not (Test-Path $installer)) {
        Write-Host "Downloading $Label runtime..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $Url -OutFile $installer
    } else {
        Write-Host "Runtime installer $ArchiveName exists in archives/, reusing." -ForegroundColor Green
    }
    Write-Host "Installing $Label runtime (silent)..." -ForegroundColor Yellow
    Start-Process -FilePath $installer -ArgumentList "/install", "/q", "/norestart" -Wait
}

# 0. Visual C++ Runtimes (dibutuhkan binary PHP)
#    VC++ 2012 (VC11)  -> PHP 5.6 (msvcr110.dll)
Install-VcRuntime -DllName "msvcr110.dll" `
    -Url "https://download.microsoft.com/download/9/C/D/9CD480DC-0301-41B0-AAAB-FE9AC1F60237/VSU4/vcredist_x64.exe" `
    -ArchiveName "vcredist2012_x64.exe" -Label "Visual C++ 2012 x64"
#    VC++ 2015-2022 (unified) -> PHP 7.4 (VC15/2017), 8.2 & 8.3 (VS16/2019), 8.4 (VS17/2022)
$hasVcr140 = (Test-Path (Join-Path $env:SystemRoot "System32\vcruntime140.dll")) -and `
    (Test-Path (Join-Path $env:SystemRoot "System32\vcruntime140_1.dll"))
if (-not $hasVcr140) {
    Install-VcRuntime -DllName "vcruntime140.dll" `
        -Url "https://aka.ms/vs/17/release/VC_redist.x64.exe" `
        -ArchiveName "vcredist2015-2022_x64.exe" -Label "Visual C++ 2015-2022 x64"
} else {
    Write-Host "Visual C++ 2015-2022 x64 already installed, skipping." -ForegroundColor Green
}
#    Verifikasi hasil instalasi
foreach ($dll in @("msvcr110.dll", "vcruntime140.dll", "vcruntime140_1.dll")) {
    if (-not (Test-Path (Join-Path $env:SystemRoot "System32\$dll"))) {
        Write-Host "[WARNING] $dll tidak ditemukan di System32. Kemungkinan install.bat dijalankan tanpa hak Administrator. Jalankan ulang sebagai Administrator." -ForegroundColor Red
    }
}

function Download-And-Extract {
    param([string]$Url, [string]$DestDir, [string]$ZipName)
    $zipPath = Join-Path $archivesDir $ZipName
    if (-not (Test-Path $zipPath)) {
        Write-Host "Downloading $ZipName from $Url..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $Url -OutFile $zipPath
    } else {
        Write-Host "Archive $ZipName already exists in archives/, reusing." -ForegroundColor Green
    }
    if (-not (Test-Path $DestDir)) {
        Write-Host "Extracting to $DestDir..." -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
        Expand-Archive -Path $zipPath -DestinationPath $DestDir -Force
    } else {
        Write-Host "$DestDir already exists, skipping extract." -ForegroundColor Green
    }
}

# 1. Download Nginx
$nginxZip = "nginx-1.26.2.zip"
$nginxExtract = Join-Path $tmpDir "nginx_extract"
if (-not (Test-Path (Join-Path $nginxDir "nginx.exe"))) {
    $zipPath = Join-Path $archivesDir $nginxZip
    if (-not (Test-Path $zipPath)) {
        Write-Host "Downloading Nginx..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri "https://nginx.org/download/$nginxZip" -OutFile $zipPath
    } else {
        Write-Host "Archive $nginxZip exists in archives/, reusing." -ForegroundColor Green
    }
    Expand-Archive -Path $zipPath -DestinationPath $nginxExtract -Force
    $innerDir = Get-ChildItem -Path $nginxExtract -Directory | Select-Object -First 1
    Move-Item -Path $innerDir.FullName -Destination $nginxDir -Force
    Remove-Item -Path $nginxExtract -Recurse -Force
}

# 2. Download PHP versions (NTS x64) - Versi patch terbaru aman CVE/php2shell
$phpVersions = @{
    "5.6" = @{
        "url" = "https://windows.php.net/downloads/releases/archives/php-5.6.40-nts-Win32-VC11-x64.zip"
        "dir" = Join-Path $phpDir "php-5.6"
        "port" = 9056
    }
    "7.4" = @{
        "url" = "https://windows.php.net/downloads/releases/archives/php-7.4.33-nts-Win32-vc15-x64.zip"
        "dir" = Join-Path $phpDir "php-7.4"
        "port" = 9074
    }
    "8.2" = @{
        "url" = "https://downloads.php.net/~windows/releases/archives/php-8.2.35-nts-Win32-vs16-x64.zip"
        "dir" = Join-Path $phpDir "php-8.2"
        "port" = 9082
    }
    "8.3" = @{
        "url" = "https://downloads.php.net/~windows/releases/archives/php-8.3.36-nts-Win32-vs16-x64.zip"
        "dir" = Join-Path $phpDir "php-8.3"
        "port" = 9083
    }
    "8.4" = @{
        "url" = "https://downloads.php.net/~windows/releases/archives/php-8.4.27-nts-Win32-vs17-x64.zip"
        "dir" = Join-Path $phpDir "php-8.4"
        "port" = 9084
    }
}

foreach ($ver in $phpVersions.Keys) {
    $info = $phpVersions[$ver]
    Download-And-Extract -Url $info.url -DestDir $info.dir -ZipName "php-$ver.zip"

    # Configure php.ini
    $iniFile = Join-Path $info.dir "php.ini"
    $iniDev = Join-Path $info.dir "php.ini-development"
    if ((-not (Test-Path $iniFile)) -and (Test-Path $iniDev)) {
        Copy-Item -Path $iniDev -Destination $iniFile
        $content = Get-Content $iniFile
        $content = $content -replace ';extension_dir = "ext"', 'extension_dir = "ext"'
        $content = $content -replace '; extension_dir = "ext"', 'extension_dir = "ext"'
        $content = $content -replace ';extension=curl', 'extension=curl'
        $content = $content -replace ';extension=fileinfo', 'extension=fileinfo'
        $content = $content -replace ';extension=mbstring', 'extension=mbstring'
        $content = $content -replace ';extension=mysqli', 'extension=mysqli'
        $content = $content -replace ';extension=openssl', 'extension=openssl'
        $content = $content -replace ';extension=pdo_mysql', 'extension=pdo_mysql'
        $content = $content -replace ';extension=intl', 'extension=intl'
        $content = $content -replace ';extension=gd', 'extension=gd'
        $content = $content -replace ';extension=zip', 'extension=zip'
        $content = $content -replace ';extension=exif', 'extension=exif'
        $content = $content -replace ';extension=pdo_sqlite', 'extension=pdo_sqlite'
        $content = $content -replace ';extension=sqlite3', 'extension=sqlite3'
        $content = $content -replace ';extension=gd2', 'extension=gd2'
        $content = $content -replace ';extension=php_curl\.dll', 'extension=php_curl.dll'
        $content = $content -replace ';extension=php_fileinfo\.dll', 'extension=php_fileinfo.dll'
        $content = $content -replace ';extension=php_mbstring\.dll', 'extension=php_mbstring.dll'
        $content = $content -replace ';extension=php_mysql\.dll', 'extension=php_mysql.dll'
        $content = $content -replace ';extension=php_mysqli\.dll', 'extension=php_mysqli.dll'
        $content = $content -replace ';extension=php_openssl\.dll', 'extension=php_openssl.dll'
        $content = $content -replace ';extension=php_pdo_mysql\.dll', 'extension=php_pdo_mysql.dll'
        $content = $content -replace ';extension=php_intl\.dll', 'extension=php_intl.dll'
        $content = $content -replace ';extension=php_gd2\.dll', 'extension=php_gd2.dll'
        $content = $content -replace ';extension=php_exif\.dll', 'extension=php_exif.dll'
        $content = $content -replace ';extension=php_pdo_sqlite\.dll', 'extension=php_pdo_sqlite.dll'
        $content = $content -replace ';extension=php_sqlite3\.dll', 'extension=php_sqlite3.dll'
        $content = $content -replace ';date.timezone =', 'date.timezone = Asia/Jakarta'
        Set-Content -Path $iniFile -Value $content
        Write-Host "php.ini configured for PHP $ver" -ForegroundColor Green
    }
}

# 3. Download MariaDB (Portable ZIP)
$mariadbZip = "mariadb-11.4.5-winx64.zip"
$mariadbExtract = Join-Path $tmpDir "mariadb_extract"
if (-not (Test-Path (Join-Path $mariadbDir "bin\mysqld.exe"))) {
    $zipPath = Join-Path $archivesDir $mariadbZip
    if (-not (Test-Path $zipPath)) {
        Write-Host "Downloading MariaDB..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri "https://archive.mariadb.org/mariadb-11.4.5/winx64-packages/$mariadbZip" -OutFile $zipPath
    } else {
        Write-Host "Archive $mariadbZip exists in archives/, reusing." -ForegroundColor Green
    }
    Expand-Archive -Path $zipPath -DestinationPath $mariadbExtract -Force
    $innerDir = Get-ChildItem -Path $mariadbExtract -Directory | Select-Object -First 1
    Move-Item -Path $innerDir.FullName -Destination $mariadbDir -Force
    Remove-Item -Path $mariadbExtract -Recurse -Force

    # Initialize MariaDB Data directory
    Write-Host "Initializing MariaDB database..." -ForegroundColor Yellow
    $mysqlInstallDb = Join-Path $mariadbDir "bin\mysql_install_db.exe"
    & $mysqlInstallDb --datadir="$mariadbDir\data" --password="$MariaDbRootPassword"
}

# 3b. Download Composer.phar
$composerPhar = Join-Path $binDir "composer.phar"
$composerArchive = Join-Path $archivesDir "composer.phar"
if (-not (Test-Path $composerPhar)) {
    if (-not (Test-Path $composerArchive)) {
        Write-Host "Downloading Composer..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri "https://getcomposer.org/composer.phar" -OutFile $composerArchive
    }
    Copy-Item -Path $composerArchive -Destination $composerPhar -Force
}

# 4. Nginx Portable Configuration
$nginxConf = Join-Path $nginxDir "conf\nginx.conf"
$nginxConfBackup = Join-Path $nginxDir "conf\nginx.conf.bak"
if (-not (Test-Path $nginxConfBackup)) {
    Copy-Item -Path $nginxConf -Destination $nginxConfBackup
}

# Create .env default if not exists
$envFile = Join-Path $BaseDir ".env"
$envExampleFile = Join-Path $BaseDir ".env.example"
$envDefault = @"
# Nginx Document Root (relatif terhadap bin/nginx misal ../../www atau absolut path)
NGINX_WEB_ROOT=../../www
# Default PHP version untuk Port 80 (pilihan: 5.6 / 7.4 / 8.2 / 8.3 / 8.4)
DEFAULT_PHP_VERSION=8.4
MARIADB_ROOT_PASSWORD=$MariaDbRootPassword
"@

if (-not (Test-Path $envExampleFile)) {
    Set-Content -Path $envExampleFile -Value $envDefault
}
if (-not (Test-Path $envFile)) {
    Set-Content -Path $envFile -Value $envDefault
}

$nginxConfigText = @"
worker_processes  1;
events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;

    include       conf.d/*.conf;

    # Default Server (Port 80) - target FastCGI dinamis via default_php.conf
    server {
        listen       80;
        server_name  localhost;
        include      webroot.conf;
        index        index.php index.html;

        location / {
            # Generic Laravel projects support (e.g. /order-appsnew/public/...)
            location ~ ^/(?<app>[^/]+)/public/ {
                try_files `$uri `$uri/ /`$app/public/index.php?`$query_string;

                location ~ \.php$ {
                    include        default_php.conf;
                    fastcgi_index  index.php;
                    fastcgi_param  SCRIPT_FILENAME  `$document_root`$fastcgi_script_name;
                    include        fastcgi_params;
                }
            }

            # Nested project routing (CodeIgniter / legacy MVC with index.php/path)
            location ~ ^/(?<app>[^/]+)(?<path_info>/.*)?$ {
                try_files `$uri `$uri/ /`$app/index.php`$path_info;

                location ~ ^/(?<app_name>[^/]+)(?<php_script>.+\.php)(?<sub_path_info>.*)$ {
                    include        default_php.conf;
                    fastcgi_param  SCRIPT_FILENAME  `$document_root`$fastcgi_script_name;
                    fastcgi_param  PATH_INFO        `$sub_path_info;
                    fastcgi_param  SCRIPT_NAME      /`$app_name`$php_script;
                    include        fastcgi_params;
                }
            }

            try_files `$uri `$uri/ /index.php?`$query_string;
        }

        location ~ ^(?<php_script>.+\.php)(?<path_info>.*)$ {
            include        default_php.conf;
            fastcgi_param  SCRIPT_FILENAME  `$document_root`$fastcgi_script_name;
            fastcgi_param  PATH_INFO        `$path_info;
            fastcgi_param  SCRIPT_NAME      `$php_script;
            include        fastcgi_params;
        }
    }

    # PHP 5.6 Dedicated (Port 8056)
    server {
        listen       8056;
        server_name  localhost;
        include      webroot.conf;
        index        index.php index.html;

        location / {
            # Generic Laravel projects support (e.g. /order-appsnew/public/...)
            location ~ ^/(?<app>[^/]+)/public/ {
                try_files `$uri `$uri/ /`$app/public/index.php?`$query_string;

                location ~ \.php$ {
                    fastcgi_pass   127.0.0.1:9056;
                    fastcgi_index  index.php;
                    fastcgi_param  SCRIPT_FILENAME  `$document_root`$fastcgi_script_name;
                    include        fastcgi_params;
                }
            }

            # Nested project routing (CodeIgniter / legacy MVC with index.php/path)
            location ~ ^/(?<app>[^/]+)(?<path_info>/.*)?$ {
                try_files `$uri `$uri/ /`$app/index.php`$path_info;

                location ~ ^/(?<app_name>[^/]+)(?<php_script>.+\.php)(?<sub_path_info>.*)$ {
                    fastcgi_pass   127.0.0.1:9056;
                    fastcgi_param  SCRIPT_FILENAME  `$document_root`$fastcgi_script_name;
                    fastcgi_param  PATH_INFO        `$sub_path_info;
                    fastcgi_param  SCRIPT_NAME      /`$app_name`$php_script;
                    include        fastcgi_params;
                }
            }

            try_files `$uri `$uri/ /index.php?`$query_string;
        }

        location ~ ^(?<php_script>.+\.php)(?<path_info>.*)$ {
            fastcgi_pass   127.0.0.1:9056;
            fastcgi_param  SCRIPT_FILENAME  `$document_root`$fastcgi_script_name;
            fastcgi_param  PATH_INFO        `$path_info;
            fastcgi_param  SCRIPT_NAME      `$php_script;
            include        fastcgi_params;
        }
    }

    # PHP 7.4 Dedicated (Port 8074)
    server {
        listen       8074;
        server_name  localhost;
        include      webroot.conf;
        index        index.php index.html;

        location / {
            # Generic Laravel projects support (e.g. /order-appsnew/public/...)
            location ~ ^/(?<app>[^/]+)/public/ {
                try_files `$uri `$uri/ /`$app/public/index.php?`$query_string;

                location ~ \.php$ {
                    fastcgi_pass   127.0.0.1:9074;
                    fastcgi_index  index.php;
                    fastcgi_param  SCRIPT_FILENAME  `$document_root`$fastcgi_script_name;
                    include        fastcgi_params;
                }
            }

            # Nested project routing (CodeIgniter / legacy MVC with index.php/path)
            location ~ ^/(?<app>[^/]+)(?<path_info>/.*)?$ {
                try_files `$uri `$uri/ /`$app/index.php`$path_info;

                location ~ ^/(?<app_name>[^/]+)(?<php_script>.+\.php)(?<sub_path_info>.*)$ {
                    fastcgi_pass   127.0.0.1:9074;
                    fastcgi_param  SCRIPT_FILENAME  `$document_root`$fastcgi_script_name;
                    fastcgi_param  PATH_INFO        `$sub_path_info;
                    fastcgi_param  SCRIPT_NAME      /`$app_name`$php_script;
                    include        fastcgi_params;
                }
            }

            try_files `$uri `$uri/ /index.php?`$query_string;
        }

        location ~ ^(?<php_script>.+\.php)(?<path_info>.*)$ {
            fastcgi_pass   127.0.0.1:9074;
            fastcgi_param  SCRIPT_FILENAME  `$document_root`$fastcgi_script_name;
            fastcgi_param  PATH_INFO        `$path_info;
            fastcgi_param  SCRIPT_NAME      `$php_script;
            include        fastcgi_params;
        }
    }

    # PHP 8.2 Dedicated (Port 8082)
    server {
        listen       8082;
        server_name  localhost;
        include      webroot.conf;
        index        index.php index.html;

        location / {
            # Generic Laravel projects support (e.g. /order-appsnew/public/...)
            location ~ ^/(?<app>[^/]+)/public/ {
                try_files `$uri `$uri/ /`$app/public/index.php?`$query_string;

                location ~ \.php$ {
                    fastcgi_pass   127.0.0.1:9082;
                    fastcgi_index  index.php;
                    fastcgi_param  SCRIPT_FILENAME  `$document_root`$fastcgi_script_name;
                    include        fastcgi_params;
                }
            }

            # Nested project routing (CodeIgniter / legacy MVC with index.php/path)
            location ~ ^/(?<app>[^/]+)(?<path_info>/.*)?$ {
                try_files `$uri `$uri/ /`$app/index.php`$path_info;

                location ~ ^/(?<app_name>[^/]+)(?<php_script>.+\.php)(?<sub_path_info>.*)$ {
                    fastcgi_pass   127.0.0.1:9082;
                    fastcgi_param  SCRIPT_FILENAME  `$document_root`$fastcgi_script_name;
                    fastcgi_param  PATH_INFO        `$sub_path_info;
                    fastcgi_param  SCRIPT_NAME      /`$app_name`$php_script;
                    include        fastcgi_params;
                }
            }

            try_files `$uri `$uri/ /index.php?`$query_string;
        }

        location ~ ^(?<php_script>.+\.php)(?<path_info>.*)$ {
            fastcgi_pass   127.0.0.1:9082;
            fastcgi_param  SCRIPT_FILENAME  `$document_root`$fastcgi_script_name;
            fastcgi_param  PATH_INFO        `$path_info;
            fastcgi_param  SCRIPT_NAME      `$php_script;
            include        fastcgi_params;
        }
    }

    # PHP 8.3 Dedicated (Port 8083)
    server {
        listen       8083;
        server_name  localhost;
        include      webroot.conf;
        index        index.php index.html;

        location / {
            # Generic Laravel projects support (e.g. /order-appsnew/public/...)
            location ~ ^/(?<app>[^/]+)/public/ {
                try_files `$uri `$uri/ /`$app/public/index.php?`$query_string;

                location ~ \.php$ {
                    fastcgi_pass   127.0.0.1:9083;
                    fastcgi_index  index.php;
                    fastcgi_param  SCRIPT_FILENAME  `$document_root`$fastcgi_script_name;
                    include        fastcgi_params;
                }
            }

            # Nested project routing (CodeIgniter / legacy MVC with index.php/path)
            location ~ ^/(?<app>[^/]+)(?<path_info>/.*)?$ {
                try_files `$uri `$uri/ /`$app/index.php`$path_info;

                location ~ ^/(?<app_name>[^/]+)(?<php_script>.+\.php)(?<sub_path_info>.*)$ {
                    fastcgi_pass   127.0.0.1:9083;
                    fastcgi_param  SCRIPT_FILENAME  `$document_root`$fastcgi_script_name;
                    fastcgi_param  PATH_INFO        `$sub_path_info;
                    fastcgi_param  SCRIPT_NAME      /`$app_name`$php_script;
                    include        fastcgi_params;
                }
            }

            try_files `$uri `$uri/ /index.php?`$query_string;
        }

        location ~ ^(?<php_script>.+\.php)(?<path_info>.*)$ {
            fastcgi_pass   127.0.0.1:9083;
            fastcgi_param  SCRIPT_FILENAME  `$document_root`$fastcgi_script_name;
            fastcgi_param  PATH_INFO        `$path_info;
            fastcgi_param  SCRIPT_NAME      `$php_script;
            include        fastcgi_params;
        }
    }

    # PHP 8.4 Dedicated (Port 8084)
    server {
        listen       8084;
        server_name  localhost;
        include      webroot.conf;
        index        index.php index.html;

        location / {
            # Generic Laravel projects support (e.g. /order-appsnew/public/...)
            location ~ ^/(?<app>[^/]+)/public/ {
                try_files `$uri `$uri/ /`$app/public/index.php?`$query_string;

                location ~ \.php$ {
                    fastcgi_pass   127.0.0.1:9084;
                    fastcgi_index  index.php;
                    fastcgi_param  SCRIPT_FILENAME  `$document_root`$fastcgi_script_name;
                    include        fastcgi_params;
                }
            }

            # Nested project routing (CodeIgniter / legacy MVC with index.php/path)
            location ~ ^/(?<app>[^/]+)(?<path_info>/.*)?$ {
                try_files `$uri `$uri/ /`$app/index.php`$path_info;

                location ~ ^/(?<app_name>[^/]+)(?<php_script>.+\.php)(?<sub_path_info>.*)$ {
                    fastcgi_pass   127.0.0.1:9084;
                    fastcgi_param  SCRIPT_FILENAME  `$document_root`$fastcgi_script_name;
                    fastcgi_param  PATH_INFO        `$sub_path_info;
                    fastcgi_param  SCRIPT_NAME      /`$app_name`$php_script;
                    include        fastcgi_params;
                }
            }

            try_files `$uri `$uri/ /index.php?`$query_string;
        }

        location ~ ^(?<php_script>.+\.php)(?<path_info>.*)$ {
            fastcgi_pass   127.0.0.1:9084;
            fastcgi_param  SCRIPT_FILENAME  `$document_root`$fastcgi_script_name;
            fastcgi_param  PATH_INFO        `$path_info;
            fastcgi_param  SCRIPT_NAME      `$php_script;
            include        fastcgi_params;
        }
    }
}
"@
Set-Content -Path $nginxConf -Value $nginxConfigText

# Folder conf.d untuk custom virtual hosts
$confDDir = Join-Path $nginxDir "conf\conf.d"
if (-not (Test-Path $confDDir)) { New-Item -ItemType Directory -Path $confDDir -Force | Out-Null }

# Initial webroot.conf & default_php.conf
$webrootConf = Join-Path $nginxDir "conf\webroot.conf"
Set-Content -Path $webrootConf -Value "root ../../www;"
$defaultPhpConf = Join-Path $nginxDir "conf\default_php.conf"
Set-Content -Path $defaultPhpConf -Value "fastcgi_pass 127.0.0.1:9084;"

# 5. Sample index.php
$indexPhp = Join-Path $wwwDir "index.php"
if (-not (Test-Path $indexPhp)) {
    $indexContent = @'
<!DOCTYPE html>
<html>
<head><title>Dev Environment</title></head>
<body style="font-family: sans-serif; padding: 2rem;">
    <h2>Dev Environment Active</h2>
    <p>Current PHP Version: <b><?php echo phpversion(); ?></b></p>
    <ul>
        <li><a href="http://localhost:8056">Port 8056 (PHP 5.6)</a></li>
        <li><a href="http://localhost:8074">Port 8074 (PHP 7.4)</a></li>
        <li><a href="http://localhost:8082">Port 8082 (PHP 8.2)</a></li>
        <li><a href="http://localhost:8083">Port 8083 (PHP 8.3)</a></li>
        <li><a href="http://localhost:8084">Port 8084 (PHP 8.4)</a></li>
    </ul>
    <hr>
    <?php phpinfo(); ?>
</body>
</html>
'@
    Set-Content -Path $indexPhp -Value $indexContent
}

# 6. Start & Stop scripts
$runHiddenScript = Join-Path $BaseDir "run-hidden.vbs"
$runHiddenContent = @'
' Run an executable completely hidden (no console window).
' Usage: wscript run-hidden.vbs "C:\path\app.exe" [arg1] [arg2] ...
Set sh = CreateObject("WScript.Shell")
If WScript.Arguments.Count = 0 Then WScript.Quit
exe = Chr(34) & WScript.Arguments(0) & Chr(34)
args = ""
For i = 1 To WScript.Arguments.Count - 1
    args = args & " " & WScript.Arguments(i)
Next
sh.Run exe & args, 0, False
'@
Set-Content -Path $runHiddenScript -Value $runHiddenContent

$startScript = Join-Path $BaseDir "start.bat"
$startBatContent = @"
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
"@
Set-Content -Path $startScript -Value $startBatContent

$stopScript = Join-Path $BaseDir "stop.bat"
$stopBatContent = @"
@echo off
echo [Stopping Portable Dev Stack]

taskkill /f /im nginx.exe >nul 2>&1
taskkill /f /im php-cgi.exe >nul 2>&1
taskkill /f /im mysqld.exe >nul 2>&1

echo All services stopped.
pause
"@
Set-Content -Path $stopScript -Value $stopBatContent

# Clean temp directory
if (Test-Path $tmpDir) { Remove-Item -Path $tmpDir -Recurse -Force }

Write-Host "`n=== Setup Selesai (Portable Ready) ===" -ForegroundColor Green
Write-Host "Folder project bisa dipindah drive / USB flashdisk tanpa rekonfigurasi path."
Write-Host "Jalankan: .\start.bat"
Write-Host "Matikan:  .\stop.bat"
