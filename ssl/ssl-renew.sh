#!/bin/bash
  # DevCulture VPS - SSL Auto Renewal
  # Supports: Ubuntu 16.04/18.04/20.04/22.04/24.04 | Debian 9/10/11/12
  RED='\e[1;31m';GREEN='\e[1;32m';YELLOW='\e[1;33m';NC='\e[0m'
  log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
  log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
  log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
  
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
  
  check_root

  DOMAIN=$(cat /etc/xray/domain 2>/dev/null || cat /root/domain 2>/dev/null || echo "")
  BOT_FILE="/etc/devculture/bot_token"; CID_FILE="/etc/devculture/chat_id"

  send_tg() {
    [[ -f "$BOT_FILE" && -f "$CID_FILE" ]] || return
    curl -sS -X POST "https://api.telegram.org/bot$(cat $BOT_FILE)/sendMessage" \
      -d chat_id="$(cat $CID_FILE)" -d text="$1" -d parse_mode="HTML" >/dev/null 2>&1
  }

  install_certbot() {
    command -v certbot &>/dev/null && return
    detect_os
    apt-get update -y >/dev/null 2>&1
    if [[ "$OS_ID" == "ubuntu" && "$OS_MAJOR" -ge 20 ]] || [[ "$OS_ID" == "debian" && "$OS_MAJOR" -ge 11 ]]; then
      # Ubuntu 20+ / Debian 11+: snap preferred
      if command -v snap &>/dev/null; then
        snap install --classic certbot >/dev/null 2>&1 && ln -sf /snap/bin/certbot /usr/bin/certbot 2>/dev/null
      else
        apt-get install -y certbot >/dev/null 2>&1
      fi
    elif [[ "$OS_ID" == "ubuntu" && "$OS_MAJOR" -ge 18 ]]; then
      apt-get install -y software-properties-common >/dev/null 2>&1
      add-apt-repository universe -y >/dev/null 2>&1
      apt-get install -y certbot >/dev/null 2>&1
    else
      # Ubuntu 16 / Debian 9-10
      apt-get install -y certbot >/dev/null 2>&1 || \
      (wget -qO /usr/local/bin/certbot "https://dl.eff.org/certbot-auto" && chmod +x /usr/local/bin/certbot)
    fi
  }

  renew_acme() {
    [[ -f /root/.acme.sh/acme.sh ]] || return 1
    log_info "Renewal via acme.sh..."
    /root/.acme.sh/acme.sh --renew -d "$DOMAIN" --force >/dev/null 2>&1 || return 1
    /root/.acme.sh/acme.sh --install-cert -d "$DOMAIN" \
      --cert-file /etc/xray/cert.crt --key-file /etc/xray/cert.key \
      --reloadcmd "systemctl restart xray nginx haproxy 2>/dev/null; true" >/dev/null 2>&1
    log_info "Renewed via acme.sh"; return 0
  }

  renew_certbot() {
    install_certbot
    command -v certbot &>/dev/null || return 1
    systemctl stop nginx haproxy 2>/dev/null; sleep 2
    certbot renew --standalone --non-interactive --agree-tos 2>&1; local RET=$?
    systemctl start nginx haproxy 2>/dev/null
    if [[ $RET -eq 0 && -n "$DOMAIN" ]]; then
      local D="/etc/letsencrypt/live/$DOMAIN"
      [[ -d "$D" ]] && cp "$D/fullchain.pem" /etc/xray/cert.crt 2>/dev/null && \
        cp "$D/privkey.pem" /etc/xray/cert.key 2>/dev/null && chmod 644 /etc/xray/cert.crt /etc/xray/cert.key 2>/dev/null
      systemctl restart xray 2>/dev/null; log_info "Renewed via certbot"; return 0
    fi
    return 1
  }

  get_cert_file() {
    [[ -f /etc/xray/cert.crt ]] && echo /etc/xray/cert.crt && return
    [[ -n "$DOMAIN" && -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]] && echo "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" && return
    [[ -f "/root/.acme.sh/$DOMAIN/$DOMAIN.cer" ]] && echo "/root/.acme.sh/$DOMAIN/$DOMAIN.cer"
  }

  check_expiry() {
    local CERT=$(get_cert_file)
    [[ -z "$CERT" ]] && log_warn "Sertifikat tidak ditemukan." && return
    local EXP=$(openssl x509 -enddate -noout -in "$CERT" 2>/dev/null | cut -d= -f2)
    local DAYS=$(( ($(date -d "$EXP" +%s 2>/dev/null) - $(date +%s)) / 86400 ))
    log_info "Domain: $DOMAIN | Sisa: $DAYS hari"
    if [[ "$DAYS" -le 30 ]]; then
      log_warn "SSL hampir expired ($DAYS hari). Memperbarui..."
      send_tg "SSL Warning: $DOMAIN sisa ${DAYS} hari, memulai renewal..."
      renew_acme || renew_certbot || { log_error "SSL renewal gagal!"; send_tg "SSL Renewal Gagal: $DOMAIN"; return 1; }
      send_tg "SSL Renewed: $DOMAIN berhasil diperbarui!"
    else
      log_info "SSL masih valid."
    fi
  }

  install_self() {
    cp "$0" /usr/local/bin/ssl-renew.sh && chmod +x /usr/local/bin/ssl-renew.sh
    (crontab -l 2>/dev/null | grep -v ssl-renew; echo "0 3 * * * /bin/bash /usr/local/bin/ssl-renew.sh check >> /var/log/ssl-renew.log 2>&1") | crontab -
    log_info "ssl-renew.sh terinstall + cron aktif (jam 3 pagi)"
  }

  case "${1:-check}" in
    install) install_self ;;
    check)   check_expiry ;;
    renew)   renew_acme || renew_certbot ;;
    *) check_expiry ;;
  esac
  