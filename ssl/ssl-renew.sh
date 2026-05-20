#!/bin/bash
  # ============================================================
  #   DevCulture VPS - SSL Auto Renewal
  #   Repo: https://github.com/tuyulbodo99/devculture-vps
  # ============================================================

  RED='\e[1;31m'
  GREEN='\e[1;32m'
  YELLOW='\e[1;33m'
  CYAN='\e[1;36m'
  NC='\e[0m'

  log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
  log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
  log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

  if [[ ${EUID} -ne 0 ]]; then
    log_error "Harus dijalankan sebagai root!"
    exit 1
  fi

  DOMAIN=$(cat /etc/xray/domain 2>/dev/null || cat /root/domain 2>/dev/null || echo "")
  CERT_DIR="/etc/letsencrypt/live/$DOMAIN"
  ACME_CERT="/root/.acme.sh/$DOMAIN/$DOMAIN.cer"
  BOT_TOKEN_FILE="/etc/devculture/bot_token"
  CHAT_ID_FILE="/etc/devculture/chat_id"

  send_telegram() {
    local MSG="$1"
    if [[ -f "$BOT_TOKEN_FILE" && -f "$CHAT_ID_FILE" ]]; then
      local BOT=$(cat $BOT_TOKEN_FILE)
      local CID=$(cat $CHAT_ID_FILE)
      curl -sS -X POST "https://api.telegram.org/bot$BOT/sendMessage" \
        -d chat_id="$CID" \
        -d text="$MSG" \
        -d parse_mode="HTML" >/dev/null 2>&1
    fi
  }

  renew_acme() {
    log_info "Mencoba renewal via acme.sh..."
    if [[ -f /root/.acme.sh/acme.sh ]]; then
      /root/.acme.sh/acme.sh --renew -d $DOMAIN --force
      if [[ $? -eq 0 ]]; then
        /root/.acme.sh/acme.sh --install-cert -d $DOMAIN \
          --cert-file /etc/xray/cert.crt \
          --key-file  /etc/xray/cert.key \
          --reloadcmd "systemctl restart xray nginx 2>/dev/null; systemctl restart haproxy 2>/dev/null"
        log_info "SSL berhasil diperbarui via acme.sh"
        send_telegram "✅ <b>SSL Renewed</b>%0ADomain: <code>$DOMAIN</code>%0AMethod: acme.sh%0AStatus: Sukses"
        return 0
      fi
    fi
    return 1
  }

  renew_certbot() {
    log_info "Mencoba renewal via certbot..."
    if command -v certbot &>/dev/null; then
      systemctl stop nginx haproxy 2>/dev/null
      sleep 2
      certbot renew --standalone --non-interactive --agree-tos 2>&1
      if [[ $? -eq 0 ]]; then
        # Copy cert ke xray dir
        if [[ -n "$DOMAIN" && -d "$CERT_DIR" ]]; then
          cp "$CERT_DIR/fullchain.pem" /etc/xray/cert.crt 2>/dev/null
          cp "$CERT_DIR/privkey.pem"   /etc/xray/cert.key 2>/dev/null
          chmod 644 /etc/xray/cert.crt /etc/xray/cert.key 2>/dev/null
        fi
        systemctl start nginx haproxy 2>/dev/null
        systemctl restart xray 2>/dev/null
        log_info "SSL berhasil diperbarui via certbot"
        send_telegram "✅ <b>SSL Renewed</b>%0ADomain: <code>$DOMAIN</code>%0AMethod: certbot%0AStatus: Sukses"
        return 0
      fi
      systemctl start nginx haproxy 2>/dev/null
    fi
    return 1
  }

  check_expiry() {
    local CERT_FILE=""
    [[ -f /etc/xray/cert.crt ]] && CERT_FILE="/etc/xray/cert.crt"
    [[ -z "$CERT_FILE" && -f "$CERT_DIR/fullchain.pem" ]] && CERT_FILE="$CERT_DIR/fullchain.pem"
    [[ -z "$CERT_FILE" && -f "$ACME_CERT" ]] && CERT_FILE="$ACME_CERT"

    if [[ -z "$CERT_FILE" ]]; then
      log_warn "File sertifikat tidak ditemukan."
      return 1
    fi

    EXPIRY_DATE=$(openssl x509 -enddate -noout -in "$CERT_FILE" 2>/dev/null | cut -d= -f2)
    EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s 2>/dev/null)
    NOW_EPOCH=$(date +%s)
    DAYS_LEFT=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))

    log_info "Sertifikat untuk $DOMAIN: $DAYS_LEFT hari tersisa"

    if [[ "$DAYS_LEFT" -le 30 ]]; then
      log_warn "Sertifikat hampir expired ($DAYS_LEFT hari). Memperbarui..."
      send_telegram "⚠️ <b>SSL Warning</b>%0ADomain: <code>$DOMAIN</code>%0ASisa: ${DAYS_LEFT} hari%0AMemulai renewal..."
      renew_acme || renew_certbot || {
        log_error "Gagal memperbarui SSL!"
        send_telegram "❌ <b>SSL Renewal Gagal</b>%0ADomain: <code>$DOMAIN</code>%0ASisa: ${DAYS_LEFT} hari"
      }
    else
      log_info "Sertifikat masih valid, tidak perlu renewal."
    fi
  }

  install_cron() {
    log_info "Memasang cron job SSL auto-renewal (setiap hari jam 3 pagi)..."
    CRON_JOB="0 3 * * * /bin/bash /usr/local/bin/ssl-renew.sh >> /var/log/ssl-renew.log 2>&1"
    (crontab -l 2>/dev/null | grep -v "ssl-renew"; echo "$CRON_JOB") | crontab -
    log_info "Cron job terpasang."
  }

  # Install this script
  install_self() {
    cp "$0" /usr/local/bin/ssl-renew.sh
    chmod +x /usr/local/bin/ssl-renew.sh
    install_cron
    log_info "ssl-renew.sh terinstall di /usr/local/bin/"
  }

  case "${1:-check}" in
    install) install_self ;;
    check)   check_expiry ;;
    renew)   renew_acme || renew_certbot ;;
    cron)    install_cron ;;
    *)       check_expiry ;;
  esac
  