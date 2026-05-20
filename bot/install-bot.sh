#!/bin/bash
# =================================================================
#   DevCulture VPS — Telegram Bot Installer  v3.2.0
#   @devculturebot | github.com/tuyulbodo99/devculture-vps
# =================================================================
RESET="\033[0m"; BBLUE="\033[1;34m"; BCYAN="\033[1;36m"
BGREEN="\033[1;32m"; BYELLOW="\033[1;33m"; RED="\033[0;31m"; DIM="\033[2m"

BOT_SRC="https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main"
CFG_DIR="/etc/devculture"
BOT_FILE="/usr/local/bin/devculture-bot.js"
SVC_FILE="/etc/systemd/system/devculture-bot.service"

header() {
  clear
  echo -e "  ${BBLUE}╔════════════════════════════════════════════════════╗${RESET}"
  echo -e "  ${BBLUE}║${RESET}  ${BCYAN}DevCulture Telegram Bot — Setup Wizard${RESET}         ${BBLUE}║${RESET}"
  echo -e "  ${BBLUE}║${RESET}  ${DIM}@devculturebot | v3.2.0${RESET}                         ${BBLUE}║${RESET}"
  echo -e "  ${BBLUE}╚════════════════════════════════════════════════════╝${RESET}"
  echo ""
}

check_node() {
  if ! command -v node &>/dev/null; then
    echo -e "  ${BYELLOW}⟳ Menginstall Node.js...${RESET}"
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - &>/dev/null
    apt-get install -y nodejs &>/dev/null
    echo -e "  ${BGREEN}✔ Node.js $(node --version) terinstall${RESET}"
  else
    echo -e "  ${BGREEN}✔ Node.js $(node --version) sudah ada${RESET}"
  fi
}

setup_bot() {
  header
  echo -e "  ${BCYAN}Buat bot Telegram kamu dulu:${RESET}"
  echo -e "  ${DIM}1. Chat @BotFather di Telegram${RESET}"
  echo -e "  ${DIM}2. Ketik /newbot → ikuti langkah${RESET}"
  echo -e "  ${DIM}3. Copy TOKEN yang diberikan${RESET}"
  echo ""

  while true; do
    read -rp "  🤖 Paste BOT TOKEN  : " BOT_TOKEN
    [[ "$BOT_TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]{35,}$ ]] && break
    echo -e "  ${RED}✘ Token tidak valid. Format: 1234567:ABC... (dari @BotFather)${RESET}"
  done

  echo ""
  echo -e "  ${BCYAN}Cari ADMIN ID kamu:${RESET}"
  echo -e "  ${DIM}1. Chat @userinfobot di Telegram${RESET}"
  echo -e "  ${DIM}2. Kirim /start → copy angka Id${RESET}"
  echo ""

  while true; do
    read -rp "  👤 Paste ADMIN ID   : " ADMIN_ID
    [[ "$ADMIN_ID" =~ ^[0-9]+$ ]] && break
    echo -e "  ${RED}✘ Admin ID harus angka${RESET}"
  done

  read -rp "  📛 Username Telegram admin (tanpa @): " ADMIN_USR
  ADMIN_USR=${ADMIN_USR:-admin}

  echo ""
  echo -e "  ${BYELLOW}⟳ Menyiapkan bot...${RESET}"

  # Node.js check
  check_node

  # Create config
  mkdir -p "$CFG_DIR"
  cat > "$CFG_DIR/config.json" << CFGEOF
{
  "bot_token": "${BOT_TOKEN}",
  "admin_id": "${ADMIN_ID}",
  "admin_username": "${ADMIN_USR}",
  "installed_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "version": "3.2.0"
}
CFGEOF
  chmod 600 "$CFG_DIR/config.json"

  # Download bot.js
  curl -fsSL "$BOT_SRC/bot/bot.js" -o "$BOT_FILE" 2>/dev/null || \
    wget -qO "$BOT_FILE" "$BOT_SRC/bot/bot.js" 2>/dev/null
  chmod +x "$BOT_FILE"

  # Download notify helper
  curl -fsSL "$BOT_SRC/bot/notify.sh" -o /usr/local/bin/dc-notify 2>/dev/null || \
    wget -qO /usr/local/bin/dc-notify "$BOT_SRC/bot/notify.sh" 2>/dev/null
  chmod +x /usr/local/bin/dc-notify

  # Download SSH login notifier
  curl -fsSL "$BOT_SRC/bot/ssh-login-notify.sh" -o /usr/local/bin/dc-ssh-notify 2>/dev/null || \
    wget -qO /usr/local/bin/dc-ssh-notify "$BOT_SRC/bot/ssh-login-notify.sh" 2>/dev/null
  chmod +x /usr/local/bin/dc-ssh-notify

  # Download monitor
  curl -fsSL "$BOT_SRC/bot/monitor.sh" -o /usr/local/bin/dc-monitor 2>/dev/null || \
    wget -qO /usr/local/bin/dc-monitor "$BOT_SRC/bot/monitor.sh" 2>/dev/null
  chmod +x /usr/local/bin/dc-monitor

  # Systemd service
  cat > "$SVC_FILE" << SVCEOF
[Unit]
Description=DevCulture Telegram Bot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/usr/local/bin
ExecStart=/usr/bin/node ${BOT_FILE}
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
Environment="NODE_ENV=production"

[Install]
WantedBy=multi-user.target
SVCEOF

  systemctl daemon-reload
  systemctl enable devculture-bot --now &>/dev/null
  sleep 2

  # Cron: monitor setiap 5 menit
  CRON_LINE="*/5 * * * * /usr/local/bin/dc-monitor >> /var/log/dc-monitor.log 2>&1"
  (crontab -l 2>/dev/null | grep -v 'dc-monitor'; echo "$CRON_LINE") | crontab -

  # PAM SSH login notify
  PAM_LINE="session optional pam_exec.so /usr/local/bin/dc-ssh-notify"
  if ! grep -q 'dc-ssh-notify' /etc/pam.d/sshd 2>/dev/null; then
    echo "$PAM_LINE" >> /etc/pam.d/sshd
  fi

  # Test send
  curl -s --max-time 10 \
    -d "chat_id=${ADMIN_ID}&parse_mode=HTML&text=✅+<b>DevCulture+Bot+Aktif!</b>%0A%0ABot+berjalan+normal.+Ketik+/start+untuk+membuka+menu.%0A%0A@devculturebot" \
    "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" > /dev/null 2>&1 || true

  clear
  echo ""
  echo -e "  ${BBLUE}╔════════════════════════════════════════════════════╗${RESET}"
  echo -e "  ${BBLUE}║${RESET}  ${BGREEN}✔  Bot Telegram Berhasil Dikonfigurasi!${RESET}        ${BBLUE}║${RESET}"
  echo -e "  ${BBLUE}╚════════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo -e "  ${BYELLOW}Fitur aktif:${RESET}"
  echo -e "  ${BGREEN}✔${RESET} Bot manager — kirim /start ke bot kamu"
  echo -e "  ${BGREEN}✔${RESET} Monitor service (cron 5 menit)"
  echo -e "  ${BGREEN}✔${RESET} Notifikasi SSH login baru"
  echo -e "  ${BGREEN}✔${RESET} Alert disk & RAM kritis"
  echo -e "  ${BGREEN}✔${RESET} Trial SSH otomatis untuk user publik"
  echo ""
  echo -e "  ${DIM}Cek status: systemctl status devculture-bot${RESET}"
  echo ""
  read -rp "  Tekan ENTER untuk kembali... "
}

stop_bot() {
  systemctl stop devculture-bot 2>/dev/null || true
  echo -e "  ${BGREEN}✔${RESET} Bot dihentikan."
  sleep 1
}

start_bot() {
  if systemctl start devculture-bot 2>/dev/null; then
    echo -e "  ${BGREEN}✔${RESET} Bot dijalankan."
  else
    echo -e "  ${RED}✘ Gagal start bot. Pastikan sudah dikonfigurasi.${RESET}"
  fi
  sleep 1
}

status_bot() {
  echo -e "  ${BYELLOW}Status devculture-bot:${RESET}"
  systemctl status devculture-bot 2>/dev/null | head -20 || echo "  Bot tidak terinstall."
  echo ""
  read -rp "  Tekan ENTER untuk kembali... "
}

uninstall_bot() {
  echo -ne "  ${RED}Yakin hapus bot? (y/N): ${RESET}"
  read -r yn
  [[ "$yn" != "y" ]] && return
  systemctl stop devculture-bot 2>/dev/null || true
  systemctl disable devculture-bot 2>/dev/null || true
  rm -f "$SVC_FILE" "$BOT_FILE" /usr/local/bin/dc-notify /usr/local/bin/dc-ssh-notify /usr/local/bin/dc-monitor
  rm -rf "$CFG_DIR"
  (crontab -l 2>/dev/null | grep -v 'dc-monitor') | crontab -
  # Remove PAM entry
  sed -i '/dc-ssh-notify/d' /etc/pam.d/sshd 2>/dev/null || true
  systemctl daemon-reload
  echo -e "  ${BGREEN}✔${RESET} Bot dihapus."
  sleep 2
}

# --- Main Menu ---
while true; do
  header
  echo -e "  ${BYELLOW}  Menu Telegram Bot:${RESET}"
  echo ""
  echo -e "  [${BCYAN}1${RESET}] Setup / Reconfigure Bot"
  echo -e "  [${BCYAN}2${RESET}] Start Bot"
  echo -e "  [${BCYAN}3${RESET}] Stop Bot"
  echo -e "  [${BCYAN}4${RESET}] Status Bot"
  echo -e "  [${BCYAN}5${RESET}] Uninstall Bot"
  echo -e "  [${BCYAN}0${RESET}] Kembali"
  echo ""
  read -rp "  Pilih [0-5]: " OPT
  case "$OPT" in
    1) setup_bot ;;
    2) start_bot ;;
    3) stop_bot ;;
    4) status_bot ;;
    5) uninstall_bot ;;
    0|"") break ;;
  esac
done
