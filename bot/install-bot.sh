#!/bin/bash
  # DevCulture VPS - Telegram Bot Installer
  # Supports: Ubuntu 16.04/18.04/20.04/22.04/24.04 | Debian 9/10/11/12
  RED='\e[1;31m';GREEN='\e[1;32m';YELLOW='\e[1;33m';NC='\e[0m'
  green()  { echo -e "\033[32;1m${*}\033[0m"; }
  red()    { echo -e "\033[31;1m${*}\033[0m"; }
  yellow() { echo -e "\033[33;1m${*}\033[0m"; }
  
  detect_os() {
    if [[ -f /etc/os-release ]]; then
      source /etc/os-release
      OS_ID="${ID}"; OS_VER="${VERSION_ID}"
      OS_CODENAME="${VERSION_CODENAME:-$(lsb_release -cs 2>/dev/null)}"
    elif [[ -f /etc/debian_version ]]; then
      OS_ID="debian"; OS_VER=$(cat /etc/debian_version); OS_CODENAME="unknown"
    else
      red "OS tidak didukung. Script ini hanya untuk Ubuntu/Debian."; exit 1
    fi
    OS_MAJOR=$(echo $OS_VER | cut -d. -f1)
    case "$OS_ID" in
      ubuntu|debian) ;;
      *) red "OS tidak didukung: $OS_ID"; exit 1 ;;
    esac
  }
  check_root()  { [[ ${EUID} -ne 0 ]] && red "Harus dijalankan sebagai root!" && exit 1; }
  check_virt()  { [[ "$(systemd-detect-virt 2>/dev/null)" == "openvz" ]] && red "OpenVZ tidak didukung." && exit 1; }
  
  
  install_nodejs() {
    local NODE_VER=20
    [[ "$OS_ID" == "ubuntu" && "$OS_MAJOR" -le 16 ]] && NODE_VER=16
    [[ "$OS_ID" == "ubuntu" && "$OS_MAJOR" -eq 18 ]] && NODE_VER=18
    apt-get remove -y nodejs npm >/dev/null 2>&1 || true
    if curl -fsSL "https://deb.nodesource.com/setup_${NODE_VER}.x" | bash - >/dev/null 2>&1; then
      apt-get install -y nodejs >/dev/null 2>&1
    else
      export NVM_DIR="/root/.nvm"
      curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash >/dev/null 2>&1
      source "$NVM_DIR/nvm.sh" 2>/dev/null
      nvm install $NODE_VER >/dev/null 2>&1 && nvm use $NODE_VER >/dev/null 2>&1
      ln -sf "$(nvm which $NODE_VER)" /usr/local/bin/node 2>/dev/null
      ln -sf "$(dirname $(nvm which $NODE_VER))/npm" /usr/local/bin/npm 2>/dev/null
    fi
  }
  
  check_root; detect_os
  export DEBIAN_FRONTEND=noninteractive
  clear
  green "================================================================"
  green "  DevCulture Bot Installer | $OS_ID $OS_VER"
  green "================================================================"
  echo ""

  # Ensure Node.js
  if ! command -v node &>/dev/null || [[ $(node -e "console.log(process.version.split('.')[0].slice(1))" 2>/dev/null) -lt 16 ]]; then
    yellow "Menginstall Node.js..."
    apt-get update -y >/dev/null 2>&1
    install_nodejs
  fi

  NODE_BIN=$(command -v node 2>/dev/null)
  if [[ -z "$NODE_BIN" ]]; then
    source /root/.nvm/nvm.sh 2>/dev/null
    NODE_BIN=$(command -v node 2>/dev/null)
    [[ -z "$NODE_BIN" ]] && red "Node.js tidak ditemukan!" && exit 1
  fi
  green "Node path: $NODE_BIN ($(node -v))"

  mkdir -p /etc/devculture /usr/local/bin

  if [[ ! -f /etc/devculture/config.json ]]; then
    read -rp "Bot Token Telegram: " BOT_TOKEN
    read -rp "Chat ID Admin     : " ADMIN_ID
    printf '{"bot_token":"%s","admin_id":"%s"}\n' "$BOT_TOKEN" "$ADMIN_ID" > /etc/devculture/config.json
    echo "$BOT_TOKEN" > /etc/devculture/bot_token
    echo "$ADMIN_ID"  > /etc/devculture/chat_id
    green "Konfigurasi tersimpan."
  else
    green "Konfigurasi sudah ada."
  fi

  yellow "Downloading bot..."
  wget -qO /usr/local/bin/devculture-bot.js "https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main/bot/bot.js"
  wget -qO /usr/local/bin/ssl-renew.sh      "https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main/ssl/ssl-renew.sh"
  chmod +x /usr/local/bin/devculture-bot.js /usr/local/bin/ssl-renew.sh
  bash /usr/local/bin/ssl-renew.sh install >/dev/null 2>&1

  cat > /etc/systemd/system/devculture-bot.service <<EOF
  [Unit]
  Description=DevCulture VPS Telegram Bot
  After=network-online.target
  Wants=network-online.target

  [Service]
  Type=simple
  User=root
  WorkingDirectory=/root
  ExecStart=${NODE_BIN} /usr/local/bin/devculture-bot.js
  Restart=always
  RestartSec=10
  StandardOutput=journal
  StandardError=journal

  [Install]
  WantedBy=multi-user.target
  EOF

  systemctl daemon-reload
  systemctl enable devculture-bot >/dev/null 2>&1
  systemctl restart devculture-bot
  sleep 3

  if systemctl is-active --quiet devculture-bot; then
    green ""
    green "================================================================"
    green "  [OK] Bot aktif! | @devculturebot"
    green "  Status: systemctl status devculture-bot"
    green "  Log   : journalctl -u devculture-bot -f"
    green "================================================================"
  else
    red "Bot gagal start. Log: journalctl -u devculture-bot -n 30"
  fi
  