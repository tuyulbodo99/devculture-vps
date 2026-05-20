#!/bin/bash
# =================================================================
#   DevCulture VPS — Premium Bot Installer v2.0
#   github.com/tuyulbodo99/devculture-vps | @devculturebot
# =================================================================
set -euo pipefail
mkdir -p /var/log; exec > >(tee -a /var/log/devculture-install.log) 2>&1

LIB_URL="https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main/lib/utils.sh"
TMP_LIB=$(mktemp /tmp/dc-lib-XXXXX.sh)
wget -qO "$TMP_LIB" "$LIB_URL" 2>/dev/null || curl -fsSL "$LIB_URL" -o "$TMP_LIB" 2>/dev/null
source "$TMP_LIB"; rm -f "$TMP_LIB"

setup_trap; check_root; detect_os

clear
echo -e "${BBLUE}${LINE_TOP}${RESET}"
box_line "${BOLD}${BYELLOW}  ◈  DEVCULTURE BOT — INSTALLER${RESET}"
box_line "  ${DIM}Telegram  : @devculturebot${RESET}"
box_line "  ${DIM}OS        : ${OS_ID^} ${OS_VER} (${OS_CODENAME})${RESET}"
echo -e "${BBLUE}${LINE_BOT}${RESET}"
echo ""

step "Memeriksa koneksi internet..."; check_internet; echo ""

step "Memastikan Node.js >= 16 tersedia..."
NEED_NODE=false
if command -v node &>/dev/null; then
  NMAJ=$(node -e "console.log(process.version.split('.')[0].slice(1))" 2>/dev/null || echo 0)
  [[ "$NMAJ" -lt 16 ]] && NEED_NODE=true
else
  NEED_NODE=true
fi
if [[ "$NEED_NODE" == "true" ]]; then
  safe_apt update; install_nodejs
fi
NODE_BIN=$(get_node_bin)
[[ -x "$NODE_BIN" ]] || { error "Node.js tidak ditemukan!"; exit 1; }
success "Node.js: $NODE_BIN ($(node -v 2>/dev/null))"
echo ""

mkdir -p /etc/devculture /usr/local/bin

# ── Config input ─────────────────────────────────────────────────
if [[ ! -f /etc/devculture/config.json ]]; then
  echo -e "${BBLUE}${LINE_TOP}${RESET}"
  box_line "${BOLD}${BYELLOW}  ◈  KONFIGURASI TELEGRAM BOT${RESET}"
  echo -e "${BBLUE}${LINE_SEP}${RESET}"
  box_line "  Dapatkan token dari @BotFather"
  box_line "  Dapatkan Chat ID dari @userinfobot"
  echo -e "${BBLUE}${LINE_BOT}${RESET}"
  echo ""
  printf "  ${BCYAN}Bot Token   ${RESET}› "; read -r BOT_TOKEN
  [[ -z "$BOT_TOKEN" ]] && { error "Token tidak boleh kosong!"; exit 1; }
  printf "  ${BCYAN}Admin Chat ID ${RESET}› "; read -r ADMIN_ID
  [[ -z "$ADMIN_ID" ]] && { error "Admin ID tidak boleh kosong!"; exit 1; }
  printf '{"bot_token":"%s","admin_id":"%s"}\n' "$BOT_TOKEN" "$ADMIN_ID" > /etc/devculture/config.json
  echo "$BOT_TOKEN" > /etc/devculture/bot_token
  echo "$ADMIN_ID"  > /etc/devculture/chat_id
  success "Konfigurasi tersimpan di /etc/devculture/"
else
  success "Konfigurasi ditemukan, melewati input."
fi
echo ""

step "Mengunduh script bot..."
start_spin "Mengunduh devculture-bot.js..."
safe_dl "${BASE_URL}/bot/bot.js" /usr/local/bin/devculture-bot.js
chmod +x /usr/local/bin/devculture-bot.js
spin_ok "Bot script diunduh"

start_spin "Mengunduh ssl-renew.sh..."
safe_dl "${BASE_URL}/ssl/ssl-renew.sh" /usr/local/bin/ssl-renew.sh || true
chmod +x /usr/local/bin/ssl-renew.sh 2>/dev/null || true
bash /usr/local/bin/ssl-renew.sh install >/dev/null 2>&1 || true
spin_ok "SSL renewal terpasang"

start_spin "Validasi bot script..."
"$NODE_BIN" --check /usr/local/bin/devculture-bot.js 2>/dev/null || {
  spin_fail "Script rusak, re-download..."
  safe_dl "${BASE_URL}/bot/bot.js" /usr/local/bin/devculture-bot.js
}
spin_ok "Bot script valid"
echo ""

step "Membuat systemd service..."
cat > /etc/systemd/system/devculture-bot.service << SVCEOF
[Unit]
Description=DevCulture VPS Telegram Bot (@devculturebot)
Documentation=https://github.com/tuyulbodo99/devculture-vps
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
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable devculture-bot >/dev/null 2>&1

start_spin "Memulai bot service..."
systemctl restart devculture-bot
sleep 4; stop_spin

if systemctl is-active --quiet devculture-bot; then
  echo ""
  echo -e "${BBLUE}${LINE_TOP}${RESET}"
  box_line "${BOLD}${BGREEN}  ✔  DEVCULTURE BOT AKTIF!${RESET}"
  echo -e "${BBLUE}${LINE_SEP}${RESET}"
  box_line "  ${BCYAN}Bot      ${RESET}: @devculturebot"
  box_line "  ${BCYAN}Status   ${RESET}: $(systemctl is-active devculture-bot)"
  box_line "  ${BCYAN}Node     ${RESET}: ${NODE_BIN}"
  box_line "  ${BCYAN}Config   ${RESET}: /etc/devculture/config.json"
  echo -e "${BBLUE}${LINE_SEP}${RESET}"
  box_line "  ${DIM}Status  : systemctl status devculture-bot${RESET}"
  box_line "  ${DIM}Log     : journalctl -u devculture-bot -f${RESET}"
  box_line "  ${DIM}Restart : systemctl restart devculture-bot${RESET}"
  echo -e "${BBLUE}${LINE_BOT}${RESET}"
else
  echo ""
  error "Bot gagal start! Cek log di bawah:"
  journalctl -u devculture-bot -n 20 --no-pager
  exit 1
fi
echo ""
