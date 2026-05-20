#!/bin/bash
# =================================================================
#   DevCulture VPS — Service Health Monitor  v3.2.0
#   Dijalankan via cron setiap 5 menit
#   @devculturebot | github.com/tuyulbodo99/devculture-vps
# =================================================================
NOTIFY="/usr/local/bin/dc-notify"
STATE_DIR="/tmp/devculture-monitor"
mkdir -p "$STATE_DIR"

SERVICES=("nginx" "xray" "v2ray" "ws-stunnel" "dropbear" "openvpn@server" "fail2ban")

check_service() {
  local SVC="$1"
  local STATE_FILE="$STATE_DIR/${SVC//\//_}.state"
  local PREV_STATE="ok"
  [ -f "$STATE_FILE" ] && PREV_STATE=$(cat "$STATE_FILE")

  if systemctl is-active --quiet "$SVC" 2>/dev/null; then
    if [ "$PREV_STATE" = "down" ]; then
      # Service recovered
      echo "ok" > "$STATE_FILE"
      "$NOTIFY" "✅ Service <b>${SVC}</b> kembali normal." "ok" 2>/dev/null || true
    else
      echo "ok" > "$STATE_FILE"
    fi
  else
    if systemctl list-units --full -all 2>/dev/null | grep -q "^${SVC}.service"; then
      if [ "$PREV_STATE" = "ok" ]; then
        # Service just went down — try restart first
        systemctl restart "$SVC" 2>/dev/null || true
        sleep 3
        if systemctl is-active --quiet "$SVC" 2>/dev/null; then
          "$NOTIFY" "⚠️ Service <b>${SVC}</b> mati, berhasil di-restart otomatis." "warn" 2>/dev/null || true
          echo "ok" > "$STATE_FILE"
        else
          "$NOTIFY" "🚨 ALERT: Service <b>${SVC}</b> MATI dan gagal di-restart!\nPerlu penanganan manual." "alert" 2>/dev/null || true
          echo "down" > "$STATE_FILE"
        fi
      fi
    fi
  fi
}

check_disk() {
  local USAGE
  USAGE=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
  if [ "$USAGE" -ge 90 ]; then
    local STATE_FILE="$STATE_DIR/disk.state"
    local PREV=$(cat "$STATE_FILE" 2>/dev/null || echo "0")
    if [ "$PREV" != "warned" ]; then
      "$NOTIFY" "🚨 DISK KRITIS: Penggunaan disk ${USAGE}% — VPS bisa mati!\nBersihkan segera: <code>df -h</code>" "alert" 2>/dev/null || true
      echo "warned" > "$STATE_FILE"
    fi
  elif [ "$USAGE" -ge 80 ]; then
    "$NOTIFY" "⚠️ Disk hampir penuh: ${USAGE}% terpakai. Segera bersihkan." "warn" 2>/dev/null || true
  else
    echo "ok" > "$STATE_DIR/disk.state"
  fi
}

check_ram() {
  local FREE_PCT
  FREE_PCT=$(free | awk '/Mem:/{printf "%.0f", $4/$2*100}')
  if [ "$FREE_PCT" -le 5 ]; then
    "$NOTIFY" "🚨 RAM KRITIS: Hanya ${FREE_PCT}% RAM tersisa!\n<code>free -h</code>" "alert" 2>/dev/null || true
  fi
}

# Run all checks
for SVC in "${SERVICES[@]}"; do
  check_service "$SVC"
done
check_disk
check_ram
