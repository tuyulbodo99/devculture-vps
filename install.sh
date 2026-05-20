#!/bin/bash
  # DevCulture VPS - All-in-One VPS Installer
  # Supports: Ubuntu 16.04/18.04/20.04/22.04/24.04 | Debian 9/10/11/12
  # Repo: https://github.com/tuyulbodo99/devculture-vps
  RED='\e[1;31m';GREEN='\e[1;32m';YELLOW='\e[1;33m';CYAN='\e[1;36m';NC='\e[0m'
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
  
  BASE="https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main"
  check_root; detect_os; check_virt
  clear
  echo -e "${CYAN}============================================================${NC}"
  echo -e "${CYAN}  DEVCULTURE VPS | $OS_ID $OS_VER ($OS_CODENAME)${NC}"
  echo -e "${CYAN}  github.com/tuyulbodo99/devculture-vps${NC}"
  echo -e "${CYAN}============================================================${NC}"
  echo ""
  green " [1] Install Full VPS (SSH + Xray + WebSocket + VPN)"
  green " [2] Install Dependencies Only"
  green " [3] Install SSH & WebSocket Only"
  green " [4] Install Xray Only"
  green " [5] Install Telegram Bot"
  green " [6] Setup SSL Auto-Renewal"
  green " [7] Update Scripts"
  green " [0] Exit"
  echo ""
  read -rp "$(yellow "Pilih menu: ")" CHOICE
  run() { bash <(curl -fsSL "$BASE/$1") "$OS_ID" "$OS_VER"; }
  case "$CHOICE" in
    1) run dependencies.sh; run setup.sh; run bot/install-bot.sh
       wget -qO /usr/local/bin/ssl-renew.sh "$BASE/ssl/ssl-renew.sh"
       chmod +x /usr/local/bin/ssl-renew.sh && bash /usr/local/bin/ssl-renew.sh install ;;
    2) run dependencies.sh ;;
    3) run ssh/ssh-vpn.sh ;;
    4) run xray/ins-xray.sh ;;
    5) run bot/install-bot.sh ;;
    6) wget -qO /usr/local/bin/ssl-renew.sh "$BASE/ssl/ssl-renew.sh"
       chmod +x /usr/local/bin/ssl-renew.sh && bash /usr/local/bin/ssl-renew.sh install ;;
    7) run update/update.sh ;;
    0) exit 0 ;;
    *) red "Pilihan tidak valid."; exit 1 ;;
  esac
  