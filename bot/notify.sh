#!/bin/bash
# =================================================================
#   DevCulture VPS — Telegram Notification Sender
#   Usage: notify.sh "<pesan>" [level: info|warn|alert]
#   @devculturebot | github.com/tuyulbodo99/devculture-vps
# =================================================================
CFG="/etc/devculture/config.json"
BOT_TOKEN=""
ADMIN_ID=""

if [ -f "$CFG" ]; then
  BOT_TOKEN=$(node -e "try{const c=require('$CFG');console.log(c.bot_token||'')}catch(e){}" 2>/dev/null || true)
  ADMIN_ID=$(node -e "try{const c=require('$CFG');console.log(c.admin_id||'')}catch(e){}" 2>/dev/null || true)
fi

[ -z "$BOT_TOKEN" ] && BOT_TOKEN=$(grep -oP '"bot_token"\s*:\s*"\K[^"]+' "$CFG" 2>/dev/null || echo "")
[ -z "$ADMIN_ID"  ] && ADMIN_ID=$(grep -oP '"admin_id"\s*:\s*"\K[^"]+' "$CFG" 2>/dev/null || echo "")

if [ -z "$BOT_TOKEN" ] || [ -z "$ADMIN_ID" ]; then
  echo "[notify] Bot belum dikonfigurasi. Jalankan: devculture → Telegram Bot → Setup Bot"
  exit 0
fi

MSG="${1:-Test notifikasi}"
LEVEL="${2:-info}"
SERVER_IP=$(curl -fsSL --max-time 5 ipv4.icanhazip.com 2>/dev/null || hostname -I | awk '{print $1}')
TIME_NOW=$(date "+%Y-%m-%d %H:%M:%S")

case "$LEVEL" in
  alert) ICON="🚨" ;;
  warn)  ICON="⚠️" ;;
  ok)    ICON="✅" ;;
  *)     ICON="ℹ️" ;;
esac

TEXT="${ICON} <b>DevCulture VPS</b>
━━━━━━━━━━━━━━━━━━━━
${MSG}
━━━━━━━━━━━━━━━━━━━━
🌐 IP     : <code>${SERVER_IP}</code>
🕐 Waktu  : <code>${TIME_NOW}</code>"

curl -s --max-time 10 \
  -d "chat_id=${ADMIN_ID}&parse_mode=HTML&disable_web_page_preview=1&text=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$TEXT" 2>/dev/null || echo "$TEXT" | sed 's/ /%20/g')" \
  "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" > /dev/null 2>&1 || true
