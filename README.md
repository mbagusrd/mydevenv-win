# MyDevEnv2 - Portable Windows Web Dev Stack

Portable local development stack untuk Windows tanpa Docker atau WSL. Menyediakan Nginx, multi-versi PHP (8.2, 8.3, 8.4) aman CVE patch terbaru, MariaDB, dan Composer dalam satu paket mandiri yang bisa dipindahkan antar drive/folder tanpa merusak konfigurasi.

---

## Fitur Utama

- **100% Portable**: Menggunakan path relatif (`%~dp0`), bebas dipindahkan ke drive lain (`D:`, `E:`, atau Flashdisk USB).
- **Multi-PHP FastCGI**:
  - PHP 8.2 (`8.2.35` NTS x64) pada FastCGI port `9082`
  - PHP 8.3 (`8.3.36` NTS x64) pada FastCGI port `9083`
  - PHP 8.4 (`8.4.27` NTS x64) pada FastCGI port `9084`
- **Dynamic Port 80**: Versi default pada port 80 dapat diubah on-the-fly (`switch-php.bat`).
- **Nginx Web Server**: Termasuk routing URL rewriting untuk framework modern (Laravel/CI).
- **MariaDB Portable**: Data tersimpan di folder lokal `bin/mariadb/data`.
- **Composer CLI Ready**: Disediakan wrapper `composer.bat` dan `php.bat`.
- **Silent Background Execution**: `start.bat` berjalan di background tanpa membuka jendela konsol.
- **Offline Repair / Re-install**: File instalasi disimpan di `archives/` agar tidak perlu download ulang jika setup diulang.

---

## Persyaratan Sistem

- Windows 10 / 11 (64-bit)
- PowerShell 5.1+ (bawaan Windows)
- Koneksi internet (hanya saat pertama kali instalasi untuk mengunduh binary)

---

## Cara Instalasi

1. Clone repositori ini:
   ```bash
   git clone https://github.com/mbagusrd/mydevenv2.git
   cd mydevenv2
   ```
2. Jalankan installer:
   - Double click `install.bat`, atau
   - Jalankan dari terminal:
     ```cmd
     install.bat
     ```
3. Masukkan password root MariaDB saat diminta (default: `root`).
4. Script akan mengunduh paket binary ke folder `archives/` dan melakukan ekstraksi serta konfigurasi otomatis.

---

## Penggunaan

### 1. Menjalankan Service
Double click `start.bat`.
Semua service (Nginx, MariaDB, dan ketiga versi PHP) akan berjalan secara silent di background.

Akses URL di browser:
- **Default PHP (Port 80)**: `http://localhost/`
- **Dedicated PHP 8.2**: `http://localhost:8082/`
- **Dedicated PHP 8.3**: `http://localhost:8083/`
- **Dedicated PHP 8.4**: `http://localhost:8084/`
- **MariaDB Host**: `127.0.0.1:3306` (user: `root`)

### 2. Menghentikan Service
Double click `stop.bat`. Semua service latar belakang akan dihentikan seketika.

### 3. Mengganti Versi PHP Default (Port 80)
Double click `switch-php.bat`, lalu pilih:
- `1` untuk PHP 8.2
- `2` untuk PHP 8.3
- `3` untuk PHP 8.4

Nginx akan otomatis di-reload tanpa perlu restart server.

### 4. Mengubah Document Root Nginx
Buka file `.env` di root folder, lalu ubah variabel `NGINX_WEB_ROOT`:
```env
# Contoh path relatif (default www/)
NGINX_WEB_ROOT=../../www

# Contoh mengarah ke public project Laravel
NGINX_WEB_ROOT=../../www/my-laravel-project/public

# Contoh path absolut drive Windows
NGINX_WEB_ROOT=D:/Projects/my-app/public
```
Setelah mengubah `.env`, jalankan kembali `start.bat`.

---

## Perintah Command Line (CLI)

Disediakan wrapper script untuk memudahkan eksekusi CLI:

| Perintah | Deskripsi |
|---|---|
| `cmd.bat` | Membuka command prompt dengan PATH lokal aktif (`php`, `composer`, `mysql`) |
| `php -v` | Menjalankan PHP versi default (sesuai `.env`) |
| `php82 -v` | Menjalankan PHP 8.2 secara spesifik |
| `php83 -v` | Menjalankan PHP 8.3 secara spesifik |
| `php84 -v` | Menjalankan PHP 8.4 secara spesifik |
| `composer <command>` | Menjalankan Composer dengan PHP default |

---

## Struktur Direktori

```text
mydevenv2/
├── archives/          # Cache file zip installer & binary download
├── bin/
│   ├── mariadb/       # Runtime MariaDB & database data/
│   ├── nginx/         # Runtime Nginx & konfigurasi conf/
│   └── composer.phar  # Binary Composer
├── php/
│   ├── php-8.2/       # Runtime PHP 8.2 NTS
│   ├── php-8.3/       # Runtime PHP 8.3 NTS
│   └── php-8.4/       # Runtime PHP 8.4 NTS
├── www/               # Default folder web root
├── .env               # Konfigurasi aktif (root folder, versi default, db pass)
├── .env.example       # Template konfigurasi
├── cmd.bat            # CLI environment launcher
├── composer.bat       # Wrapper Composer CLI
├── install.bat        # Installer 1-klik
├── php.bat            # Wrapper PHP CLI (default)
├── php82.bat          # Wrapper PHP 8.2 CLI
├── php83.bat          # Wrapper PHP 8.3 CLI
├── php84.bat          # Wrapper PHP 8.4 CLI
├── setup.ps1          # Core PowerShell setup engine
├── start.bat          # Launcher background service
├── stop.bat           # Killer background service
└── switch-php.bat     # Interactive PHP version switcher
```

---

## Lisensi
MIT License.
