#!/bin/bash

# --- VARIBEL YANG PERLU DIKONFIGURASI ---
YOUR_DOMAIN="14.hokageyoutube.my.id"  # Ganti dengan domain Anda
SSH_USERNAME="hokage"                 # Ganti dengan username SSH yang Anda inginkan
SSH_PASSWORD="legend"                 # Ganti dengan password SSH (DIREKOMENDASIKAN MENGGUNAKAN SSH KEY!)
                                     # Jika Anda tidak ingin password di sini, hapus baris ini dan
                                     # ganti perintah useradd dengan "sudo useradd -m -s /bin/bash ${SSH_USERNAME}"
                                     # Lalu tambahkan SSH Key secara manual.

SSH_TUNNEL_PORT=443                  # Port Nginx untuk tunneling SSH (umumnya 443 dengan SSL)
SSH_INTERNAL_PORT=22                 # Port SSH server (default 22)
CERTBOT_EMAIL="faridaumiabi@gmail.com" # Ganti dengan alamat email Anda untuk notifikasi Certbot

# --- FUNGSI LOGGING ---
log_info() {
    echo -e "\e[32m[INFO] $1\e[0m"
}

log_warn() {
    echo -e "\e[33m[WARN] $1\e[0m"
}

log_error() {
    echo -e "\e[31m[ERROR] $1\e[0m"
    exit 1
}

# --- CEK HAK AKSES ROOT ---
if [[ $EUID -ne 0 ]]; then
   log_error "Skrip ini harus dijalankan sebagai root atau dengan sudo."
fi

log_info "Memulai proses setup SSH Tunneling (Uninstall lama, Install baru)..."

# --- BAGIAN 1: UNINSTALL DAN CLEANUP LAMA ---
log_info "--------------------------------------------------------"
log_info "MEMULAI FASE UNINSTALL: Menghapus Nginx dan Certbot lama..."
log_info "--------------------------------------------------------"

# 1. HENTIKAN DAN BUNUH SEMUA PROSES NGINX
log_info "Menghentikan layanan Nginx..."
sudo systemctl stop nginx || true
log_info "Mencari dan membunuh semua proses Nginx yang mungkin 'nyangkut'..."
sudo killall -9 nginx || true
sudo rm -f /run/nginx.pid || true # Hapus file PID yang mungkin tersisa

# 2. HAPUS NGINX SEPENUHNYA
log_info "Menghapus paket Nginx sepenuhnya..."
sudo apt purge nginx nginx-common nginx-core -y || log_warn "Gagal menghapus paket Nginx, mungkin tidak terinstal."
sudo apt autoremove -y || log_warn "Gagal autoremove paket."
sudo apt clean || log_warn "Gagal membersihkan cache apt."

# Hapus sisa-sisa konfigurasi Nginx dan log
log_info "Menghapus sisa-sisa konfigurasi Nginx dan direktori terkait..."
sudo rm -rf /etc/nginx/ || log_warn "Direktori /etc/nginx tidak ditemukan."
sudo rm -rf /var/lib/nginx/ || log_warn "Direktori /var/lib/nginx tidak ditemukan."
sudo rm -rf /var/log/nginx/ || log_warn "Direktori /var/log/nginx tidak ditemukan."

# 3. HENTIKAN DAN HAPUS CERTBOT
log_info "Menghentikan layanan Certbot..."
sudo systemctl stop certbot.timer || true
sudo systemctl stop snap.certbot.renew.timer || true
sudo systemctl stop certbot || true
sudo systemctl stop snap.certbot.certbot.service || true

log_info "Menghapus instalasi Certbot (via snap dan apt)..."
sudo snap remove certbot || true # Hapus jika terinstal via snap
sudo apt purge certbot -y || true # Hapus jika terinstal via apt

# Hapus sisa-sisa Let's Encrypt
log_info "Menghapus sisa-sisa konfigurasi Let's Encrypt..."
sudo rm -rf /etc/letsencrypt/ || log_warn "Direktori /etc/letsencrypt tidak ditemukan."
sudo rm -rf /var/lib/letsencrypt/ || log_warn "Direktori /var/lib/letsencrypt tidak ditemukan."

# 4. VERIFIKASI PORT 443 BEBAS SETELAH PEMBERSIHAN
log_info "Menunggu 5 detik untuk memastikan port dilepaskan..."
sleep 5
log_info "Memverifikasi port $SSH_TUNNEL_PORT bebas setelah pembersihan..."
if sudo netstat -tulnp | grep ":$SSH_TUNNEL_PORT" &>/dev/null; then
    log_error "Port $SSH_TUNNEL_PORT masih digunakan setelah pembersihan. Mungkin ada proses lain yang menggunakannya. Harap reboot VPS secara manual dan coba lagi."
else
    log_info "Port $SSH_TUNNEL_PORT bersih dan siap untuk instalasi baru."
fi

log_info "--------------------------------------------------------"
log_info "FASE UNINSTALL SELESAI. MEMULAI FASE INSTALL..."
log_info "--------------------------------------------------------"

# --- BAGIAN 2: INSTALASI DAN KONFIGURASI BARU ---

# 1. UPDATE SISTEM
log_info "Memperbarui daftar paket sistem..."
sudo apt update || log_error "Gagal memperbarui daftar paket."
log_info "Mengupgrade paket sistem..."
sudo apt upgrade -y || log_error "Gagal mengupgrade paket."

# 2. INSTALASI OPENSSH SERVER
log_info "Memeriksa dan menginstal OpenSSH Server..."
sudo apt install openssh-server -y || log_error "Gagal menginstal OpenSSH Server."
sudo systemctl enable ssh || log_error "Gagal mengaktifkan SSH di startup."
sudo systemctl start ssh || log_error "Gagal memulai SSH."

# 3. INSTALASI NGINX (Penting: Gunakan nginx-full atau nginx-extras untuk modul stream)
log_info "Memeriksa dan menginstal Nginx (paket full/extras untuk modul stream)..."
if sudo apt install nginx-full -y; then
    log_info "Nginx-full berhasil diinstal."
elif sudo apt install nginx-extras -y; then
    log_info "Nginx-extras berhasil diinstal."
else
    log_error "Gagal menginstal Nginx (nginx-full atau nginx-extras). Modul stream mungkin tidak tersedia."
fi

sudo systemctl enable nginx || log_error "Gagal mengaktifkan Nginx di startup."
# Nginx akan dimulai setelah konfigurasi lengkap

# Verifikasi direktori modul Nginx dan keberadaan file .so
log_info "Memverifikasi direktori modul Nginx..."
NGINX_MODULES_PATH="/usr/lib/nginx/modules"
if [ ! -d "$NGINX_MODULES_PATH" ]; then
    log_error "Direktori modul Nginx ($NGINX_MODULES_PATH) tidak ditemukan setelah instalasi Nginx. Instalasi Nginx mungkin rusak."
fi
if [ ! -f "$NGINX_MODULES_PATH/ngx_stream_module.so" ]; then
    log_error "File modul stream (ngx_stream_module.so) tidak ditemukan di $NGINX_MODULES_PATH. Modul stream tidak terinstal dengan benar."
fi
log_info "Direktori modul Nginx dan file modul stream telah diverifikasi."


# 4. INSTALASI CERTBOT (untuk SSL/TLS)
log_info "Memeriksa dan menginstal Certbot untuk SSL/TLS..."
sudo snap install core --classic || log_error "Gagal menginstal snap core."
sudo snap refresh core || log_error "Gagal refresh snap core."
sudo snap install --classic certbot || log_error "Gagal menginstal Certbot snap."
sudo ln -sf /snap/bin/certbot /usr/bin/certbot || log_warn "Gagal membuat symlink Certbot, mungkin sudah ada."

# 5. KONFIGURASI NGINX (Stream dan HTTP)
log_info "Mengkonfigurasi Nginx untuk SSH Tunneling dan HTTP..."

# Buat file konfigurasi Nginx utama
NGINX_CONF_PATH="/etc/nginx/nginx.conf"

# Buat ulang nginx.conf dari template bersih dengan load_module path absolut
sudo cat <<EOF > "$NGINX_CONF_PATH"
user www-data;
worker_processes auto;
pid /run/nginx.pid;
error_log /var/log/nginx/error.log;
include /etc/nginx/modules-enabled/*.conf;

# load_module /usr/lib/nginx/modules/ngx_stream_module.so; # Baris ini dikomentari di skrip
# load_module /usr/lib/nginx/modules/ngx_stream_ssl_module.so; # Baris ini dikomentari di skrip
# load_module /usr/lib/nginx/modules/ngx_stream_ssl_preread_module.so; # Baris ini dikomentari di skrip

events {
    worker_connections 768;
    # multi_accept on;
}

stream {
    map \$ssl_preread_server_name \$name {
        $YOUR_DOMAIN ssh_backend;
        default                       backend_default;
    }

    upstream ssh_backend {
        server 127.0.0.1:$SSH_INTERNAL_PORT;
    }

    upstream backend_default {
        server 127.0.0.1:8080; # Ganti ini jika Anda punya web server di port lain
    }

    server {
        listen $SSH_TUNNEL_PORT ssl;
        listen [::]:$SSH_TUNNEL_PORT ssl;

        ssl_preread on;
        proxy_pass \$name;

        # >>> BARIS INI TELAH DIKOMENTARI DI SCRIPT <<<
        # ssl_certificate /etc/letsencrypt/live/$YOUR_DOMAIN/fullchain.pem;
        # ssl_certificate_key /etc/letsencrypt/live/$YOUR_DOMAIN/privkey.pem;
        # <<< BARIS INI TELAH DIKOMENTARI DI SCRIPT >>>

        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers 'TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_128_GCM_SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA384';
        ssl_prefer_server_ciphers on;
    }
}

http {
    ##
    # Basic Settings
    ##
    sendfile on;
    tcp_nopush on;
    types_hash_max_size 2048;
    # server_tokens off;

    # server_names_hash_bucket_size 64;
    # server_name_in_redirect off;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    ##
    # SSL Settings
    ##
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3; # Dropping SSLv3, ref: POODLE
    ssl_prefer_server_ciphers on;

    ##
    # Logging Settings
    ##
    access_log /var/log/nginx/access.log;

    ##
    # Gzip Settings
    ##
    gzip on;

    # gzip_vary on;
    # gzip_proxied any;
    # gzip_comp_level 6;
    # gzip_buffers 16 8k;
    # gzip_http_version 1.1;
    # gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    ##
    # Virtual Host Configs
    ##
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

# Buat konfigurasi HTTP default baru (untuk port 80)
DEFAULT_HTTP_CONF="/etc/nginx/sites-available/default"
sudo cat <<EOF > "$DEFAULT_HTTP_CONF"
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;

    server_name $YOUR_DOMAIN;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

sudo ln -sf "$DEFAULT_HTTP_CONF" /etc/nginx/sites-enabled/default

# --- 6. DAPATKAN SERTIFIKAT SSL DENGAN CERTBOT ---
log_info "Mendapatkan sertifikat SSL untuk $YOUR_DOMAIN..."
# Hapus direktori live dan archive yang mungkin tersisa dari Certbot sebelumnya (jika tidak terhapus sempurna oleh uninstall)
sudo rm -rf /etc/letsencrypt/live/$YOUR_DOMAIN || true
sudo rm -rf /etc/letsencrypt/archive/$YOUR_DOMAIN || true

# Perbarui izin direktori Let's Encrypt (penting!)
# Ini harus 755 agar www-data bisa mengaksesnya
sudo chmod 755 /etc/letsencrypt/live || log_warn "Gagal mengatur izin untuk /etc/letsencrypt/live. Mungkin direktori tidak ada."
sudo chmod 755 /etc/letsencrypt/archive || log_warn "Gagal mengatur izin untuk /etc/letsencrypt/archive. Mungkin direktori tidak ada."


sudo certbot --nginx -d "$YOUR_DOMAIN" --non-interactive --agree-tos --email "$CERTBOT_EMAIL" || log_error "Gagal mendapatkan sertifikat SSL dari Certbot. Periksa log Certbot: /var/log/letsencrypt/letsencrypt.log"

# Perbaiki izin direktori Let's Encrypt setelah Certbot (ini harus tetap 755)
sudo chmod 755 /etc/letsencrypt/live || log_warn "Gagal mengatur izin ulang untuk /etc/letsencrypt/live."
sudo chmod 755 /etc/letsencrypt/archive || log_warn "Gagal mengatur izin ulang untuk /etc/letsencrypt/archive."

# --- 7. BUAT PENGGUNA SSH BARU (Opsional) ---
log_info "Membuat pengguna SSH baru '$SSH_USERNAME'..."
if id "$SSH_USERNAME" &>/dev/null; then
    log_warn "Pengguna '$SSH_USERNAME' sudah ada, melewati pembuatan pengguna."
else
    sudo useradd -m -s /bin/bash "$SSH_USERNAME" || log_error "Gagal membuat pengguna SSH."
    echo "$SSH_USERNAME:$SSH_PASSWORD" | sudo chpasswd || log_error "Gagal mengatur password pengguna SSH."
    log_info "Pengguna '$SSH_USERNAME' dengan password '$SSH_PASSWORD' berhasil dibuat."
fi

# --- 8. RESTART LAYANAN ---
log_info "Mulai ulang Nginx dan SSH untuk menerapkan perubahan..."
sudo systemctl restart nginx || log_error "Gagal memulai ulang Nginx."
sudo systemctl restart ssh || log_error "Gagal memulai ulang SSH."

log_info "Memverifikasi konfigurasi Nginx terakhir..."
sudo nginx -t || log_error "Nginx konfigurasi error setelah startup. Periksa log!"

log_info "Instalasi dan konfigurasi SSH Tunneling Selesai!"
log_info "Informasi Koneksi:"
log_info "  Domain: $YOUR_DOMAIN"
log_info "  Port Tunneling: $SSH_TUNNEL_PORT"
log_info "  Username SSH: $SSH_USERNAME"
log_info "  Password SSH: $SSH_PASSWORD (Jika diatur via skrip)"
log_info "Pastikan AWS Security Groups mengizinkan traffic masuk ke port $SSH_TUNNEL_PORT (dan 80, 22 jika diperlukan)."
log_info "Sekarang Anda bisa mencoba menghubungkan HTTP Custom/DarkTunnel dengan setting ini."
