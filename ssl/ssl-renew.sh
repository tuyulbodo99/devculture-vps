#!/bin/bash
  # ============================================================
  #  DevCulture VPS | github.com/tuyulbodo99/devculture-vps
  #  Support: Ubuntu 16/18/20/22/24 | Debian 9/10/11/12
  # ============================================================
  set -euo pipefail

  RED='\e[1;31m';GREEN='\e[1;32m';YELLOW='\e[1;33m';CYAN='\e[1;36m';NC='\e[0m'
  green()  { echo -e "\033[32;1m${*}\033[0m"; }
  red()    { echo -e "\033[31;1m${*}\033[0m"; }
  yellow() { echo -e "\033[33;1m${*}\033[0m"; }
  cyan()   { echo -e "\033[36;1m${*}\033[0m"; }
  bold()   { echo -e "\033[1m${*}\033[0m"; }

  LOG_FILE="/var/log/devculture-install.log"
  mkdir -p /var/log
  exec > >(tee -a "$LOG_FILE") 2>&1
  echo "=== DevCulture run: $(date) ==="

  # ---- Trap errors ----
  trap_error() {
    local LINE=$1 CODE=$2
    red ""
    red "====================================================="
    red "  ERROR pada baris $LINE (exit code: $CODE)"
    red "  Log lengkap: $LOG_FILE"
    red "====================================================="
    red "  Solusi umum:"
    red "  1. Pastikan koneksi internet stabil"
    red "  2. Jalankan: apt-get update -y && apt-get upgrade -y"
    red "  3. Coba jalankan script lagi"
    red "====================================================="
    exit $CODE
  }
  trap 'trap_error $LINENO $?' ERR

  # ---- Helper functions ----
  detect_os() {
    if [[ -f /etc/os-release ]]; then
      source /etc/os-release
      OS_ID="${ID}"; OS_VER="${VERSION_ID:-0}"
      OS_CODENAME="${VERSION_CODENAME:-$(lsb_release -cs 2>/dev/null || echo unknown)}"
    elif [[ -f /etc/debian_version ]]; then
      OS_ID="debian"; OS_VER=$(cat /etc/debian_version); OS_CODENAME="unknown"
    else
      red "OS tidak didukung. Gunakan Ubuntu atau Debian."; exit 1
    fi
    OS_MAJOR=$(echo "$OS_VER" | cut -d. -f1 | tr -dc '0-9')
    [[ "$OS_MAJOR" =~ ^[0-9]+$ ]] || OS_MAJOR=0
    case "$OS_ID" in ubuntu|debian) ;; *) red "OS tidak didukung: $OS_ID"; exit 1 ;; esac
  }

  check_root() { [[ ${EUID} -eq 0 ]] || { red "Harus dijalankan sebagai root!"; exit 1; }; }

  check_virt() {
    local v=$(systemd-detect-virt 2>/dev/null || echo "none")
    [[ "$v" == "openvz" ]] && red "OpenVZ tidak didukung." && exit 1
    return 0
  }

  check_internet() {
    yellow "Memeriksa koneksi internet..."
    local HOSTS=("8.8.8.8" "1.1.1.1" "google.com")
    for h in "${HOSTS[@]}"; do
      if ping -c1 -W3 "$h" >/dev/null 2>&1 || curl -s --max-time 5 "https://$h" >/dev/null 2>&1; then
        green "  [OK] Internet terhubung"
        return 0
      fi
    done
    red "  Tidak ada koneksi internet! Periksa jaringan VPS."
    exit 1
  }

  check_disk() {
    local MIN_MB=${1:-500}
    local FREE_MB=$(df -m / | awk 'NR==2 {print $4}')
    if [[ "$FREE_MB" -lt "$MIN_MB" ]]; then
      red "Disk tidak cukup! Free: ${FREE_MB}MB, dibutuhkan: ${MIN_MB}MB"; exit 1
    fi
    green "  [OK] Disk: ${FREE_MB}MB tersedia"
  }

  check_ram() {
    local MIN_MB=${1:-256}
    local FREE_MB=$(free -m | awk '/^Mem:/{print $2}')
    if [[ "$FREE_MB" -lt "$MIN_MB" ]]; then
      yellow "  [WARN] RAM hanya ${FREE_MB}MB, disarankan minimal ${MIN_MB}MB"
    else
      green "  [OK] RAM: ${FREE_MB}MB"
    fi
  }

  # ---- Wait for apt lock (anti-conflict) ----
  wait_apt() {
    local WAIT=0 MAX=120
    while fuser /var/lib/dpkg/lock /var/lib/apt/lists/lock /var/cache/apt/archives/lock >/dev/null 2>&1; do
      [[ $WAIT -eq 0 ]] && yellow "Menunggu proses apt lain selesai..."
      sleep 3; WAIT=$((WAIT+3))
      [[ $WAIT -ge $MAX ]] && { red "Timeout menunggu apt lock! Coba: rm -f /var/lib/dpkg/lock*"; exit 1; }
    done
  }

  safe_apt() {
    wait_apt
    DEBIAN_FRONTEND=noninteractive apt-get "$@" \
      -o Dpkg::Options::="--force-confdef" \
      -o Dpkg::Options::="--force-confold" \
      -o APT::Get::Assume-Yes=true \
      -o APT::Get::allow-downgrades=true >/dev/null 2>&1 || true
  }

  # ---- Download with retry ----
  safe_download() {
    local URL="$1" OUT="$2" MAX=3 i=0
    while [[ $i -lt $MAX ]]; do
      wget -qO "$OUT" "$URL" 2>/dev/null && return 0
      curl -fsSL "$URL" -o "$OUT" 2>/dev/null && return 0
      i=$((i+1)); yellow "  Download retry $i/$MAX..."; sleep 3
    done
    red "  Gagal download: $URL"; return 1
  }

  # ---- Node.js installer (version-aware + nvm fallback) ----
  install_nodejs() {
    local NODE_VER=20
    [[ "$OS_ID" == "ubuntu" && "$OS_MAJOR" -le 16 ]] && NODE_VER=16
    [[ "$OS_ID" == "ubuntu" && "$OS_MAJOR" -eq 18 ]] && NODE_VER=18

    yellow "  Menginstall Node.js $NODE_VER..."
    safe_apt remove nodejs npm 2>/dev/null || true

    # Method 1: NodeSource
    if curl -fsSL "https://deb.nodesource.com/setup_${NODE_VER}.x" | bash - >/dev/null 2>&1; then
      safe_apt install nodejs
      command -v node &>/dev/null && { green "  Node.js $(node -v) via NodeSource"; return 0; }
    fi

    # Method 2: nvm fallback
    yellow "  NodeSource gagal, mencoba nvm..."
    export NVM_DIR="/root/.nvm"
    safe_download "https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh" /tmp/nvm-install.sh
    bash /tmp/nvm-install.sh >/dev/null 2>&1 || true
    [[ -f "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
    nvm install "$NODE_VER" >/dev/null 2>&1 && nvm use "$NODE_VER" >/dev/null 2>&1 || true
    local NVM_NODE=$(nvm which "$NODE_VER" 2>/dev/null || echo "")
    if [[ -n "$NVM_NODE" && -x "$NVM_NODE" ]]; then
      ln -sf "$NVM_NODE" /usr/local/bin/node 2>/dev/null
      ln -sf "$(dirname $NVM_NODE)/npm" /usr/local/bin/npm 2>/dev/null
      green "  Node.js $(node -v) via nvm"
      return 0
    fi

    # Method 3: distro package
    yellow "  nvm gagal, mencoba apt..."
    safe_apt install nodejs
    command -v node &>/dev/null && { green "  Node.js $(node -v) via apt"; return 0; }
    red "  Gagal menginstall Node.js!"; return 1
  }

  get_node_bin() {
    local N=$(command -v node 2>/dev/null)
    [[ -z "$N" ]] && source /root/.nvm/nvm.sh 2>/dev/null && N=$(command -v node 2>/dev/null)
    [[ -z "$N" ]] && N="/usr/local/bin/node"
    echo "$N"
  }
  
  check_root

  DOMAIN=$(cat /etc/xray/domain 2>/dev/null || cat /root/domain 2>/dev/null || echo "")
  BOT_FILE="/etc/devculture/bot_token"; CID_FILE="/etc/devculture/chat_id"

  send_tg() {
    [[ -f "$BOT_FILE" && -f "$CID_FILE" ]] || return 0
    curl -sS --max-time 10 -X POST "https://api.telegram.org/bot$(cat $BOT_FILE)/sendMessage" \
      -d chat_id="$(cat $CID_FILE)" -d text="$1" -d parse_mode="HTML" >/dev/null 2>&1 || true
  }

  install_certbot() {
    command -v certbot &>/dev/null && return 0
    detect_os
    wait_apt && safe_apt update || true

    if [[ "$OS_ID" == "ubuntu" && "$OS_MAJOR" -ge 20 ]] || [[ "$OS_ID" == "debian" && "$OS_MAJOR" -ge 11 ]]; then
      if command -v snap &>/dev/null; then
        snap install --classic certbot >/dev/null 2>&1 && ln -sf /snap/bin/certbot /usr/bin/certbot 2>/dev/null || true
      else
        safe_apt install certbot || true
      fi
    elif [[ "$OS_ID" == "ubuntu" && "$OS_MAJOR" -ge 18 ]]; then
      safe_apt install software-properties-common || true
      add-apt-repository universe -y >/dev/null 2>&1 || true
      safe_apt install certbot || true
    else
      safe_apt install certbot || safe_download "https://dl.eff.org/certbot-auto" /usr/local/bin/certbot && chmod +x /usr/local/bin/certbot || true
    fi
  }

  renew_acme() {
    [[ -f /root/.acme.sh/acme.sh ]] || return 1
    [[ -n "$DOMAIN" ]] || return 1
    /root/.acme.sh/acme.sh --renew -d "$DOMAIN" --force >/dev/null 2>&1 || return 1
    /root/.acme.sh/acme.sh --install-cert -d "$DOMAIN" \
      --cert-file /etc/xray/cert.crt --key-file /etc/xray/cert.key \
      --reloadcmd "systemctl restart xray nginx haproxy 2>/dev/null; true" >/dev/null 2>&1
    green "[SSL] Renewed via acme.sh"; return 0
  }

  renew_certbot() {
    install_certbot
    command -v certbot &>/dev/null || return 1
    systemctl stop nginx haproxy 2>/dev/null || true; sleep 2
    certbot renew --standalone --non-interactive --agree-tos 2>&1; local RET=$?
    systemctl start nginx haproxy 2>/dev/null || true
    if [[ $RET -eq 0 && -n "$DOMAIN" ]]; then
      local D="/etc/letsencrypt/live/$DOMAIN"
      if [[ -d "$D" ]]; then
        cp "$D/fullchain.pem" /etc/xray/cert.crt 2>/dev/null || true
        cp "$D/privkey.pem"   /etc/xray/cert.key 2>/dev/null || true
        chmod 644 /etc/xray/cert.crt /etc/xray/cert.key 2>/dev/null || true
      fi
      systemctl restart xray 2>/dev/null || true
      green "[SSL] Renewed via certbot"; return 0
    fi
    return 1
  }

  get_cert_file() {
    [[ -f /etc/xray/cert.crt ]] && { echo /etc/xray/cert.crt; return; }
    [[ -n "$DOMAIN" && -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]] && { echo "/etc/letsencrypt/live/$DOMAIN/fullchain.pem"; return; }
    [[ -n "$DOMAIN" && -f "/root/.acme.sh/$DOMAIN/$DOMAIN.cer" ]] && { echo "/root/.acme.sh/$DOMAIN/$DOMAIN.cer"; return; }
    echo ""
  }

  check_expiry() {
    local CERT=$(get_cert_file)
    if [[ -z "$CERT" ]]; then yellow "[SSL] Sertifikat tidak ditemukan."; return 0; fi
    local EXP=$(openssl x509 -enddate -noout -in "$CERT" 2>/dev/null | cut -d= -f2 || echo "")
    [[ -z "$EXP" ]] && { yellow "[SSL] Tidak bisa baca tanggal expiry."; return 0; }
    local EXP_EPOCH=$(date -d "$EXP" +%s 2>/dev/null || echo 0)
    local DAYS=$(( (EXP_EPOCH - $(date +%s)) / 86400 ))
    green "[SSL] Domain: $DOMAIN | Sisa: $DAYS hari"
    if [[ "$DAYS" -le 30 ]]; then
      yellow "[SSL] Hampir expired! Memperbarui..."
      send_tg "⚠️ SSL Warning: $DOMAIN sisa ${DAYS} hari — renewal dimulai..."
      if renew_acme || renew_certbot; then
        send_tg "✅ SSL Renewed: $DOMAIN berhasil diperbarui!"
      else
        yellow "[SSL] Renewal gagal, akan dicoba lagi besok."
        send_tg "❌ SSL Renewal Gagal: $DOMAIN (${DAYS} hari tersisa)"
      fi
    else
      green "[SSL] Masih valid, tidak perlu renewal."
    fi
  }

  install_self() {
    cp "$0" /usr/local/bin/ssl-renew.sh && chmod +x /usr/local/bin/ssl-renew.sh
    (crontab -l 2>/dev/null | grep -v ssl-renew; echo "0 3 * * * /bin/bash /usr/local/bin/ssl-renew.sh check >> /var/log/ssl-renew.log 2>&1") | crontab -
    green "[SSL] ssl-renew.sh terinstall + cron aktif (jam 3 pagi setiap hari)"
  }

  case "${1:-check}" in
    install) install_self ;;
    check)   check_expiry ;;
    renew)   renew_acme || renew_certbot || yellow "[SSL] Tidak ada method renewal yang tersedia." ;;
    *) check_expiry ;;
  esac
  