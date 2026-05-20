#!/bin/bash
  # ============================================================
  #   DevCulture VPS - All-in-One VPS Installer
  #   Repo  : https://github.com/tuyulbodo99/devculture-vps
  #   Bot   : @devculturebot
  # ============================================================

  RED='\e[1;31m'
  GREEN='\e[1;32m'
  YELLOW='\e[1;33m'
  CYAN='\e[1;36m'
  NC='\e[0m'

  green()  { echo -e "\\033[32;1m${*}\\033[0m"; }
  red()    { echo -e "\\033[31;1m${*}\\033[0m"; }
  yellow() { echo -e "\\033[33;1m${*}\\033[0m"; }
  cyan()   { echo -e "\\033[36;1m${*}\\033[0m"; }

  BASE_URL="https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main"

  if [[ ${EUID} -ne 0 ]]; then
    red "Skrip ini harus dijalankan sebagai root!"
    exit 1
  fi

  if [[ -e /etc/debian_version ]]; then
    source /etc/os-release
    OS=$ID
  else
    red "OS tidak didukung. Gunakan Debian/Ubuntu."
    exit 1
  fi

  if [[ "$(systemd-detect-virt)" == "openvz" ]]; then
    red "OpenVZ tidak didukung."
    exit 1
  fi

  clear
  echo -e "${CYAN}============================================================${NC}"
  echo -e "${CYAN}        DEVCULTURE VPS - All-in-One Installer               ${NC}"
  echo -e "${CYAN}        https://github.com/tuyulbodo99/devculture-vps       ${NC}"
  echo -e "${CYAN}============================================================${NC}"
  echo ""
  green " [1] Install Full VPS (SSH + Xray + WebSocket + VPN)"
  green " [2] Install Dependencies Only"
  green " [3] Install SSH & WebSocket Only"
  green " [4] Install Xray Only"
  green " [5] Install Telegram Bot Manager"
  green " [6] Setup SSL Auto-Renewal"
  green " [7] Update Scripts"
  green " [0] Exit"
  echo ""
  yellow -n "Pilih menu: "
  read -r CHOICE

  case $CHOICE in
    1)
      cyan "Memulai instalasi penuh..."
      bash <(curl -sSL $BASE_URL/dependencies.sh)
      bash <(curl -sSL $BASE_URL/setup.sh)
      bash <(curl -sSL $BASE_URL/bot/install-bot.sh)
      bash <(curl -sSL $BASE_URL/ssl/ssl-renew.sh) install
      ;;
    2)
      cyan "Menginstall dependencies..."
      bash <(curl -sSL $BASE_URL/dependencies.sh)
      ;;
    3)
      cyan "Menginstall SSH & WebSocket..."
      bash <(curl -sSL $BASE_URL/ssh/ssh-vpn.sh)
      ;;
    4)
      cyan "Menginstall Xray..."
      bash <(curl -sSL $BASE_URL/xray/ins-xray.sh)
      ;;
    5)
      cyan "Menginstall Telegram Bot Manager..."
      bash <(curl -sSL $BASE_URL/bot/install-bot.sh)
      ;;
    6)
      cyan "Setup SSL Auto-Renewal..."
      wget -qO /usr/local/bin/ssl-renew.sh $BASE_URL/ssl/ssl-renew.sh
      chmod +x /usr/local/bin/ssl-renew.sh
      bash /usr/local/bin/ssl-renew.sh install
      ;;
    7)
      cyan "Mengupdate scripts..."
      bash <(curl -sSL $BASE_URL/update/update.sh)
      ;;
    0)
      exit 0
      ;;
    *)
      red "Pilihan tidak valid."
      exit 1
      ;;
  esac
  