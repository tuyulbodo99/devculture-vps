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
  
  check_root; detect_os
  BASE="https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main"

  clear
  green "================================================================"
  green "  DevCulture Bot Installer"
  green "  OS: $OS_ID $OS_VER ($OS_CODENAME)"
  green "================================================================"

  yellow ">>> Pre-flight checks..."
  check_internet; check_disk 100

  DEBIAN_FRONTEND=noninteractive

  # ---- Ensure Node.js >= 16 ----
  need_node=false
  if command -v node &>/dev/null; then
    NODE_MAJOR=$(node -e "console.log(process.version.split('.')[0].slice(1))" 2>/dev/null || echo 0)
    [[ "$NODE_MAJOR" -lt 16 ]] && need_node=true
  else
    need_node=true
  fi

  if [[ "$need_node" == "true" ]]; then
    wait_apt && safe_apt update
    install_nodejs
  fi

  NODE_BIN=$(get_node_bin)
  [[ -x "$NODE_BIN" ]] || { red "Node.js tidak ditemukan setelah install!"; exit 1; }
  green "  Node: $NODE_BIN ($(node -v 2>/dev/null))"

  mkdir -p /etc/devculture /usr/local/bin

  # ---- Config ----
  if [[ ! -f /etc/devculture/config.json ]]; then
    echo ""
    read -rp "Bot Token Telegram  : " BOT_TOKEN
    [[ -z "$BOT_TOKEN" ]] && { red "Bot token tidak boleh kosong!"; exit 1; }
    read -rp "Chat ID Admin       : " ADMIN_ID
    [[ -z "$ADMIN_ID" ]] && { red "Admin ID tidak boleh kosong!"; exit 1; }
    printf '{"bot_token":"%s","admin_id":"%s"}\n' "$BOT_TOKEN" "$ADMIN_ID" > /etc/devculture/config.json
    echo "$BOT_TOKEN" > /etc/devculture/bot_token
    echo "$ADMIN_ID"  > /etc/devculture/chat_id
    green "  Konfigurasi tersimpan."
  else
    green "  Konfigurasi sudah ada, dilewati."
  fi

  # ---- Download bot ----
  yellow "Downloading bot script..."
  safe_download "$BASE/bot/bot.js" /usr/local/bin/devculture-bot.js || exit 1
  chmod +x /usr/local/bin/devculture-bot.js

  yellow "Downloading SSL renewal script..."
  safe_download "$BASE/ssl/ssl-renew.sh" /usr/local/bin/ssl-renew.sh || true
  chmod +x /usr/local/bin/ssl-renew.sh 2>/dev/null && bash /usr/local/bin/ssl-renew.sh install >/dev/null 2>&1 || true

  # ---- Validate bot script ----
  "$NODE_BIN" --check /usr/local/bin/devculture-bot.js 2>/dev/null || {
    red "  Bot script invalid! Re-downloading..."
    safe_download "$BASE/bot/bot.js" /usr/local/bin/devculture-bot.js || exit 1
  }

  # ---- Systemd service ----
  cat > /etc/systemd/system/devculture-bot.service <<EOF
  [Unit]
  Description=DevCulture VPS Telegram Bot (@devculturebot)
  After=network-online.target
  Wants=network-online.target
  StartLimitIntervalSec=60
  StartLimitBurst=5

  [Service]
  Type=simple
  User=root
  WorkingDirectory=/root
  ExecStart=${NODE_BIN} /usr/local/bin/devculture-bot.js
  Restart=always
  RestartSec=10
  TimeoutStopSec=20
  StandardOutput=journal
  StandardError=journal
  SyslogIdentifier=devculture-bot

  [Install]
  WantedBy=multi-user.target
  EOF

  systemctl daemon-reload
  systemctl enable devculture-bot >/dev/null 2>&1
  systemctl restart devculture-bot
  sleep 4

  if systemctl is-active --quiet devculture-bot; then
    green ""
    green "================================================================"
    green "  [OK] DevCulture Bot aktif!"
    green "  Bot    : @devculturebot"
    green "  Status : systemctl status devculture-bot"
    green "  Log    : journalctl -u devculture-bot -f"
    green "================================================================"
  else
    red "  Bot gagal start. Cek log:"
    journalctl -u devculture-bot -n 15 --no-pager
    exit 1
  fi
  