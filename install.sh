#!/bin/bash
  # ============================================================
  #  DevCulture VPS - All-in-One Installer
  #  Supports: Ubuntu 16/18/20/22/24 | Debian 9/10/11/12
  #  Repo: https://github.com/tuyulbodo99/devculture-vps
  # ============================================================
  set -euo pipefail
  RED='\e[1;31m';GREEN='\e[1;32m';YELLOW='\e[1;33m';CYAN='\e[1;36m';NC='\e[0m'
  green()  { echo -e "\033[32;1m${*}\033[0m"; }
  red()    { echo -e "\033[31;1m${*}\033[0m"; }
  yellow() { echo -e "\033[33;1m${*}\033[0m"; }
  cyan()   { echo -e "\033[36;1m${*}\033[0m"; }

  LOG_FILE="/var/log/devculture-install.log"
  mkdir -p /var/log; exec > >(tee -a "$LOG_FILE") 2>&1
  trap 'red "ERROR baris $LINENO"; exit 1' ERR

  detect_os() {
    source /etc/os-release 2>/dev/null || true
    OS_ID="${ID:-unknown}"; OS_VER="${VERSION_ID:-0}"
    OS_CODENAME="${VERSION_CODENAME:-$(lsb_release -cs 2>/dev/null || echo -)}"
    OS_MAJOR=$(echo "$OS_VER" | cut -d. -f1 | tr -dc '0-9'); [[ "$OS_MAJOR" =~ ^[0-9]+$ ]] || OS_MAJOR=0
  }
  check_root()   { [[ ${EUID} -eq 0 ]] || { red "Harus root!"; exit 1; }; }
  check_virt()   { [[ "$(systemd-detect-virt 2>/dev/null)" == "openvz" ]] && red "OpenVZ tidak didukung." && exit 1; return 0; }
  check_internet() {
    yellow "Cek internet..."
    ping -c1 -W3 8.8.8.8 >/dev/null 2>&1 || curl -s --max-time 5 https://google.com >/dev/null 2>&1 || { red "Tidak ada internet!"; exit 1; }
    green "  [OK] Internet terhubung"
  }
  check_disk()   { local F=$(df -m / | awk 'NR==2{print $4}'); [[ $F -lt 300 ]] && { red "Disk kurang: ${F}MB"; exit 1; }; green "  [OK] Disk: ${F}MB"; }

  safe_dl() {
    local URL="$1" OUT="$2" i=0
    while [[ $i -lt 3 ]]; do
      wget -qO "$OUT" "$URL" 2>/dev/null && return 0
      curl -fsSL "$URL" -o "$OUT" 2>/dev/null && return 0
      i=$((i+1)); sleep 3
    done; return 1
  }

  BASE="https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main"
  check_root; detect_os; check_virt

  clear
  echo -e "${CYAN}============================================================${NC}"
  echo -e "${CYAN}  DEVCULTURE VPS | $OS_ID $OS_VER ($OS_CODENAME)${NC}"
  echo -e "${CYAN}  github.com/tuyulbodo99/devculture-vps${NC}"
  echo -e "${CYAN}============================================================${NC}"
  echo ""
  yellow ">>> Pre-flight checks..."
  check_internet; check_disk
  echo ""
  green " [1]  Install Full VPS (SSH + Xray + WS + VPN)"
  green " [2]  Install Dependencies Only"
  green " [3]  Install SSH & WebSocket Only"
  green " [4]  Install Xray Only"
  green " [5]  Install Telegram Bot"
  green " [6]  Setup SSL Auto-Renewal"
  green " [7]  Install UDP Support (UDPGW + mKCP + OpenVPN UDP)"
  green " [8]  Update Scripts"
  green " [9]  Uninstall DevCulture VPS"
  green " [0]  Exit"
  echo ""
  read -rp "Pilih menu [0-9]: " CHOICE

  run() {
    local TMP=$(mktemp /tmp/dc-XXXXX.sh)
    safe_dl "$BASE/$1" "$TMP" && chmod +x "$TMP" && bash "$TMP" || { red "$1 gagal!"; rm -f "$TMP"; exit 1; }
    rm -f "$TMP"
  }

  case "$CHOICE" in
    1)
      run "dependencies.sh"
      run "setup.sh"
      run "bot/install-bot.sh"
      run "udp/install-udp.sh"
      safe_dl "$BASE/ssl/ssl-renew.sh" /usr/local/bin/ssl-renew.sh && chmod +x /usr/local/bin/ssl-renew.sh && bash /usr/local/bin/ssl-renew.sh install
      ;;
    2) run "dependencies.sh" ;;
    3) run "ssh/ssh-vpn.sh" ;;
    4) run "xray/ins-xray.sh" ;;
    5) run "bot/install-bot.sh" ;;
    6) safe_dl "$BASE/ssl/ssl-renew.sh" /usr/local/bin/ssl-renew.sh && chmod +x /usr/local/bin/ssl-renew.sh && bash /usr/local/bin/ssl-renew.sh install ;;
    7) run "udp/install-udp.sh" ;;
    8) run "update/update.sh" ;;
    9) safe_dl "$BASE/uninstall.sh" /tmp/dc-uninstall.sh && chmod +x /tmp/dc-uninstall.sh && bash /tmp/dc-uninstall.sh ;;
    0) exit 0 ;;
    *) red "Pilihan tidak valid!"; exit 1 ;;
  esac

  green ""
  green "============================================================"
  green "  Selesai! Log: $LOG_FILE"
  green "============================================================"
  