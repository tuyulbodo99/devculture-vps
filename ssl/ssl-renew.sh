#!/bin/bash
# =================================================================
#   DevCulture VPS — Premium SSL Auto-Renewal v2.0
#   github.com/tuyulbodo99/devculture-vps | @devculturebot
# =================================================================
set -euo pipefail
mkdir -p /var/log

LIB_URL="https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main/lib/utils.sh"
TMP_LIB=$(mktemp /tmp/dc-lib-XXXXX.sh)
wget -qO "$TMP_LIB" "$LIB_URL" 2>/dev/null || curl -fsSL "$LIB_URL" -o "$TMP_LIB" 2>/dev/null
source "$TMP_LIB"; rm -f "$TMP_LIB"

check_root

DOMAIN=$(cat /etc/xray/domain 2>/dev/null || cat /root/domain 2>/dev/null || echo "")
BOT_FILE="/etc/devculture/bot_token"
CID_FILE="/etc/devculture/chat_id"

send_tg() {
  [[ -f "$BOT_FILE" && -f "$CID_FILE" ]] || return 0
  curl -sS --max-time 10 -X POST \
    "https://api.telegram.org/bot$(cat $BOT_FILE)/sendMessage" \
    -d chat_id="$(cat $CID_FILE)" \
    -d text="$1" -d parse_mode="HTML" >/dev/null 2>&1 || true
}

install_certbot() {
  command -v certbot &>/dev/null && return 0
  detect_os; safe_apt update || true
  if [[ "$OS_ID" == "ubuntu" && "$OS_MAJOR" -ge 20 ]] \
     || [[ "$OS_ID" == "debian" && "$OS_MAJOR" -ge 11 ]]; then
    command -v snap &>/dev/null \
      && snap install --classic certbot >/dev/null 2>&1 \
      && ln -sf /snap/bin/certbot /usr/bin/certbot 2>/dev/null \
      || safe_apt install certbot || true
  elif [[ "$OS_ID" == "ubuntu" && "$OS_MAJOR" -ge 18 ]]; then
    safe_apt install software-properties-common || true
    add-apt-repository universe -y >/dev/null 2>&1 || true
    safe_apt install certbot || true
  else
    safe_apt install certbot \
      || { safe_dl "https://dl.eff.org/certbot-auto" /usr/local/bin/certbot \
           && chmod +x /usr/local/bin/certbot; } || true
  fi
}

renew_acme() {
  [[ -f /root/.acme.sh/acme.sh && -n "$DOMAIN" ]] || return 1
  /root/.acme.sh/acme.sh --renew -d "$DOMAIN" --force >/dev/null 2>&1 || return 1
  /root/.acme.sh/acme.sh --install-cert -d "$DOMAIN" \
    --cert-file /etc/xray/cert.crt --key-file /etc/xray/cert.key \
    --reloadcmd "systemctl restart xray nginx haproxy 2>/dev/null; true" >/dev/null 2>&1
  success "Renewed via acme.sh"; return 0
}

renew_certbot() {
  install_certbot; command -v certbot &>/dev/null || return 1
  systemctl stop nginx haproxy 2>/dev/null || true; sleep 2
  certbot renew --standalone --non-interactive --agree-tos 2>&1; local RET=$?
  systemctl start nginx haproxy 2>/dev/null || true
  if [[ $RET -eq 0 && -n "$DOMAIN" ]]; then
    local D="/etc/letsencrypt/live/$DOMAIN"
    [[ -d "$D" ]] && {
      cp "$D/fullchain.pem" /etc/xray/cert.crt 2>/dev/null || true
      cp "$D/privkey.pem"   /etc/xray/cert.key 2>/dev/null || true
      chmod 644 /etc/xray/cert.crt /etc/xray/cert.key 2>/dev/null || true
    }
    systemctl restart xray 2>/dev/null || true
    success "Renewed via certbot"; return 0
  fi
  return 1
}

get_cert_file() {
  [[ -f /etc/xray/cert.crt ]] && echo /etc/xray/cert.crt && return
  [[ -n "$DOMAIN" && -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]] \
    && echo "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" && return
  [[ -n "$DOMAIN" && -f "/root/.acme.sh/$DOMAIN/$DOMAIN.cer" ]] \
    && echo "/root/.acme.sh/$DOMAIN/$DOMAIN.cer" && return
  echo ""
}

check_expiry() {
  local CERT; CERT=$(get_cert_file)
  if [[ -z "$CERT" ]]; then warn "Sertifikat SSL tidak ditemukan."; return 0; fi

  local EXP; EXP=$(openssl x509 -enddate -noout -in "$CERT" 2>/dev/null | cut -d= -f2 || echo "")
  [[ -z "$EXP" ]] && { warn "Tidak bisa membaca tanggal expiry."; return 0; }
  local EXP_EPOCH; EXP_EPOCH=$(date -d "$EXP" +%s 2>/dev/null || echo 0)
  local DAYS=$(( (EXP_EPOCH - $(date +%s)) / 86400 ))

  echo ""
  echo -e "${BBLUE}${LINE_TOP}${RESET}"
  box_line "${BOLD}${BYELLOW}  ◈  SSL CERTIFICATE STATUS${RESET}"
  echo -e "${BBLUE}${LINE_SEP}${RESET}"
  box_line "  ${BCYAN}Domain  ${RESET}: ${BWHITE}${DOMAIN:-N/A}${RESET}"
  box_line "  ${BCYAN}File    ${RESET}: ${BWHITE}${CERT}${RESET}"
  box_line "  ${BCYAN}Expiry  ${RESET}: ${BWHITE}${EXP}${RESET}"
  if [[ "$DAYS" -le 7 ]]; then
    box_line "  ${BCYAN}Status  ${RESET}: ${BRED}${DAYS} hari — KRITIS! Segera diperbarui${RESET}"
  elif [[ "$DAYS" -le 30 ]]; then
    box_line "  ${BCYAN}Status  ${RESET}: ${BYELLOW}${DAYS} hari — Hampir expired${RESET}"
  else
    box_line "  ${BCYAN}Status  ${RESET}: ${BGREEN}${DAYS} hari — Valid & aman${RESET}"
  fi
  echo -e "${BBLUE}${LINE_BOT}${RESET}"
  echo ""

  if [[ "$DAYS" -le 30 ]]; then
    warn "SSL hampir expired ($DAYS hari). Memperbarui..."
    send_tg "⚠️ <b>SSL Warning</b>
Domain: <code>$DOMAIN</code>
Sisa: <b>${DAYS} hari</b>
Status: Renewal dimulai..."
    if renew_acme || renew_certbot; then
      success "SSL berhasil diperbarui!"
      send_tg "✅ <b>SSL Renewed</b>
Domain: <code>$DOMAIN</code>
Status: Berhasil diperbarui!"
    else
      warn "Renewal gagal, akan dicoba lagi besok."
      send_tg "❌ <b>SSL Renewal Gagal</b>
Domain: <code>$DOMAIN</code>
Sisa: ${DAYS} hari — Cek server!"
    fi
  else
    success "SSL masih valid — tidak perlu renewal."
  fi
}

install_self() {
  cp "$0" /usr/local/bin/ssl-renew.sh && chmod +x /usr/local/bin/ssl-renew.sh
  (crontab -l 2>/dev/null | grep -v ssl-renew
   echo "0 3 * * * /bin/bash /usr/local/bin/ssl-renew.sh check >> /var/log/ssl-renew.log 2>&1"
  ) | crontab -
  echo ""
  echo -e "${BBLUE}${LINE_TOP}${RESET}"
  box_line "${BOLD}${BGREEN}  ✔  SSL AUTO-RENEWAL TERPASANG${RESET}"
  echo -e "${BBLUE}${LINE_SEP}${RESET}"
  box_line "  ${BCYAN}Script  ${RESET}: /usr/local/bin/ssl-renew.sh"
  box_line "  ${BCYAN}Cron    ${RESET}: Setiap hari jam 03:00 WIB"
  box_line "  ${BCYAN}Log     ${RESET}: /var/log/ssl-renew.log"
  box_line "  ${BCYAN}Notify  ${RESET}: Via Telegram @devculturebot"
  echo -e "${BBLUE}${LINE_BOT}${RESET}"
  echo ""
}

case "${1:-check}" in
  install) install_self ;;
  check)   check_expiry ;;
  renew)   renew_acme || renew_certbot || warn "Tidak ada method renewal tersedia." ;;
  status)  check_expiry ;;
  *)       check_expiry ;;
esac
