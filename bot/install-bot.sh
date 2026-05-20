#!/bin/bash
  # ============================================================
  #   DevCulture VPS - Install Telegram Bot
  #   Bot: @devculturebot
  # ============================================================

  RED='\e[1;31m'
  GREEN='\e[1;32m'
  YELLOW='\e[1;33m'
  CYAN='\e[1;36m'
  NC='\e[0m'

  log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
  log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

  if [[ ${EUID} -ne 0 ]]; then log_error "Harus dijalankan sebagai root!"; fi

  clear
  echo -e "${CYAN}============================================================${NC}"
  echo -e "${CYAN}     DevCulture VPS - Telegram Bot Installer${NC}"
  echo -e "${CYAN}============================================================${NC}"
  echo ""

  # Install Node.js if not present
  if ! command -v node &>/dev/null; then
    log_info "Menginstall Node.js..."
    curl -sSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
  fi

  # Setup config dir
  mkdir -p /etc/devculture
  mkdir -p /usr/local/bin

  echo -n "Masukkan Bot Token Telegram: "
  read -r BOT_TOKEN
  echo -n "Masukkan Telegram Chat ID Admin Anda: "
  read -r ADMIN_ID

  cat > /etc/devculture/config.json <<EOF
  {
    "bot_token": "${BOT_TOKEN}",
    "admin_id": "${ADMIN_ID}"
  }
  EOF

  # Save for SSL notifications
  echo "$BOT_TOKEN" > /etc/devculture/bot_token
  echo "$ADMIN_ID"  > /etc/devculture/chat_id

  # Download bot
  log_info "Mendownload bot script..."
  wget -qO /usr/local/bin/devculture-bot.js "https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main/bot/bot.js"
  chmod +x /usr/local/bin/devculture-bot.js

  # Download SSL renewal
  wget -qO /usr/local/bin/ssl-renew.sh "https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main/ssl/ssl-renew.sh"
  chmod +x /usr/local/bin/ssl-renew.sh

  # Install SSL cron
  bash /usr/local/bin/ssl-renew.sh install

  # Create systemd service
  cat > /etc/systemd/system/devculture-bot.service <<EOF
  [Unit]
  Description=DevCulture VPS Telegram Bot
  After=network.target

  [Service]
  Type=simple
  ExecStart=/usr/bin/node /usr/local/bin/devculture-bot.js
  Restart=always
  RestartSec=5
  StandardOutput=journal
  StandardError=journal

  [Install]
  WantedBy=multi-user.target
  EOF

  systemctl daemon-reload
  systemctl enable devculture-bot
  systemctl start devculture-bot

  sleep 2
  if systemctl is-active --quiet devculture-bot; then
    echo ""
    log_info "✅ DevCulture Bot berhasil diinstall dan berjalan!"
    log_info "Bot: @devculturebot"
    log_info "Cek status: systemctl status devculture-bot"
    log_info "Lihat log : journalctl -u devculture-bot -f"
  else
    log_error "Bot gagal distart. Cek: journalctl -u devculture-bot -f"
  fi
  