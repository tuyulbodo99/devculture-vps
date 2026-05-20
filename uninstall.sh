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

  clear
  red "============================================================"
  red "  DEVCULTURE VPS - Uninstall"
  red "  Ini akan menghapus SEMUA komponen DevCulture VPS!"
  red "============================================================"
  echo ""
  read -rp "Ketik 'HAPUS' untuk konfirmasi: " CONFIRM
  [[ "$CONFIRM" != "HAPUS" ]] && { yellow "Dibatalkan."; exit 0; }
  echo ""

  yellow "[1/10] Menghentikan DevCulture Bot..."
  systemctl stop devculture-bot 2>/dev/null || true
  systemctl disable devculture-bot 2>/dev/null || true
  rm -f /etc/systemd/system/devculture-bot.service
  systemctl daemon-reload

  yellow "[2/10] Menghapus file bot & config..."
  rm -f /usr/local/bin/devculture-bot.js
  rm -f /usr/local/bin/ssl-renew.sh
  rm -rf /etc/devculture
  rm -f /var/log/ssl-renew.log

  yellow "[3/10] Menghapus cron SSL renewal..."
  (crontab -l 2>/dev/null | grep -v ssl-renew) | crontab - 2>/dev/null || true

  yellow "[4/10] Menghentikan Xray..."
  systemctl stop xray 2>/dev/null || true
  systemctl disable xray 2>/dev/null || true
  rm -f /etc/systemd/system/xray.service
  rm -rf /etc/xray /usr/local/bin/xray 2>/dev/null || true

  yellow "[5/10] Menghentikan layanan SSH extra..."
  systemctl stop dropbear 2>/dev/null || true
  systemctl disable dropbear 2>/dev/null || true
  systemctl stop stunnel4 2>/dev/null || true
  systemctl disable stunnel4 2>/dev/null || true

  yellow "[6/10] Menghapus Nginx DevCulture config..."
  rm -f /etc/nginx/sites-enabled/devculture 2>/dev/null || true
  rm -f /etc/nginx/sites-available/devculture 2>/dev/null || true
  systemctl restart nginx 2>/dev/null || true

  yellow "[7/10] Hapus menu scripts..."
  for s in menu menu-ssh menu-bot menu-backup menu-dns menu-ip menu-set \
            menu-speedtest menu-vmess menu-vless menu-trojan menu-ss \
            menu-tcp menu-tor menu-theme menu-bandwith autoboot info; do
    rm -f "/usr/local/sbin/$s" 2>/dev/null || true
  done

  yellow "[8/10] Hapus user SSH yang dibuat bot..."
  if [[ -f /etc/devculture/users.json ]]; then
    while read -r USER; do
      userdel -r "$USER" 2>/dev/null || true
    done < <(grep -oP '"user":\s*"\K[^"]+' /etc/devculture/users.json 2>/dev/null || true)
  fi

  # Trial users
  if [[ -f /etc/devculture/trials.json ]]; then
    while read -r USER; do
      userdel -r "$USER" 2>/dev/null || true
    done < <(grep -oP '"ssh_user":\s*"\K[^"]+' /etc/devculture/trials.json 2>/dev/null || true)
  fi

  yellow "[9/10] Hapus VPN config..."
  systemctl stop openvpn 2>/dev/null || true
  systemctl disable openvpn 2>/dev/null || true
  rm -f /etc/openvpn/server.conf 2>/dev/null || true
  rm -rf /root/openvpn-ca 2>/dev/null || true

  yellow "[10/10] Bersihkan log..."
  rm -f /var/log/devculture-install.log
  systemctl daemon-reload

  echo ""
  green "============================================================"
  green "  [OK] DevCulture VPS berhasil diuninstall!"
  green ""
  green "  Layanan sistem (nginx, ssh, dll) tetap berjalan."
  green "  Untuk reinstall: bash <(curl -sSL"
  green "  https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main/install.sh)"
  green "============================================================"
  