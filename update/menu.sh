#!/bin/bash
# =================================================================
#   DevCulture VPS — Main Menu  v3.2.0
#   @devculturebot | github.com/tuyulbodo99/devculture-vps
# =================================================================
# FIX: hapus check_license dan PERMISSION (fungsi tidak terdefinisi)
# FIX: updatews sekarang download dari devculture-vps bukan tuyulbodo99/original
# FIX: Exp dan variabel ijin/original dihapus
# =================================================================
set -euo pipefail

BASE_URL="https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main"

export RED='\033[0;31m'
export GREEN='\033[0;32m'
export NC='\033[0m'
YELLOW='\033[0;33m'
COLOR1='\033[1;36m'
COLBG1='\033[1;37m'

[[ "${EUID}" -ne 0 ]] && { echo -e "${RED}Harus root!${NC}"; exit 1; }

# Service status
svc_status_inline() {
  local SVC="$1"
  if systemctl is-active --quiet "$SVC" 2>/dev/null; then
    echo -e "${GREEN}ON${NC}"
  else
    echo -e "${RED}OFF${NC}"
  fi
}

status_ws=$(svc_status_inline ws-stunnel)
status_nginx=$(svc_status_inline nginx)
status_xray=$(svc_status_inline xray)

# Info sistem
IPVPS=$(curl -s --max-time 5 ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}')
ISP=$(curl -s --max-time 5 ipinfo.io/org 2>/dev/null | cut -d' ' -f2- || echo "N/A")
CITY=$(curl -s --max-time 5 ipinfo.io/city 2>/dev/null || echo "N/A")
uram=$(free -m | awk '/Mem:/{print $3}')
tram=$(free -m | awk '/Mem:/{print $2}')

function add-host(){
  clear
  echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
  echo -e "$COLOR1│${NC} ${COLBG1}               • ADD VPS HOST •                ${NC} $COLOR1│$NC"
  echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
  echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
  read -rp "  New Host Name : " -e host
  echo ""
  if [[ -z "$host" ]]; then
    echo -e "  [INFO] Type Your Domain/sub domain"
    echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
    echo ""
    read -n 1 -s -r -p "  Press any key to back on menu"
    menu
  else
    echo "$host" > /etc/xray/domain
    echo "IP=$host" > /var/lib/devculturevpn-pro/ipvps.conf 2>/dev/null || true
    echo ""
    echo "  [INFO] Dont forget to renew cert"
    echo ""
    echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
    echo ""
    read -n 1 -s -r -p "  Press any key to Renew Cert"
    crtxray 2>/dev/null || true
  fi
}

function updatews(){
  clear
  echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
  echo -e "$COLOR1│${NC} ${COLBG1}            • UPDATE SCRIPT VPS •              ${NC} $COLOR1│$NC"
  echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
  echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
  echo -e "$COLOR1│${NC}  $COLOR1[INFO]${NC} Check for Script updates..."
  sleep 1

  # FIX: download dari devculture-vps bukan tuyulbodo99/original
  TMP_UP=$(mktemp /tmp/dc-update-XXXXX.sh)
  wget -qO "$TMP_UP" "${BASE_URL}/update/update.sh" 2>/dev/null || \
    curl -fsSL "${BASE_URL}/update/update.sh" -o "$TMP_UP" 2>/dev/null
  chmod +x "$TMP_UP"
  bash "$TMP_UP" && rm -f "$TMP_UP"

  echo -e "$COLOR1│${NC}  $COLOR1[INFO]${NC} Successfully Up To Date!"
  echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
  echo -e "$COLOR1┌────────────────────── BY ───────────────────────┐${NC}"
  echo -e "$COLOR1│${NC}              • DevCulture •                $COLOR1│$NC"
  echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
  echo ""
  read -n 1 -s -r -p "  Press any key to back on menu"
  menu
}

function menu(){
  clear
  echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
  echo -e "$COLOR1│${NC} ${COLBG1}               • VPS PANEL MENU •              ${NC} $COLOR1│$NC"
  echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
  echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
  uphours=$(uptime -p 2>/dev/null | awk '{print $2,$3}' | cut -d, -f1 || echo "N/A")
  upminutes=$(uptime -p 2>/dev/null | awk '{print $4,$5}' | cut -d, -f1 || echo "")
  DOMAIN=$(cat /etc/xray/domain 2>/dev/null || echo "N/A")

  echo -e "$COLOR1│$NC Memory Usage   : $uram / $tram MB"
  echo -e "$COLOR1│$NC ISP & City     : $ISP & $CITY"
  echo -e "$COLOR1│$NC Current Domain : $DOMAIN"
  echo -e "$COLOR1│$NC IP-VPS         : ${COLOR1}$IPVPS${NC}"
  echo -e "$COLOR1│$NC Uptime         : $uphours $upminutes"
  echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
  echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
  echo -e "$COLOR1│$NC [ SSH WS : ${status_ws} ]  [ XRAY : ${status_xray} ]   [ NGINX : ${status_nginx} ] $COLOR1│$NC"
  echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
  echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
  echo -e "  ${COLOR1}[01]${NC} • SSHWS   [${YELLOW}Menu${NC}]   ${COLOR1}[07]${NC} • THEME    [${YELLOW}Menu${NC}]  $COLOR1│$NC"
  echo -e "  ${COLOR1}[02]${NC} • VMESS   [${YELLOW}Menu${NC}]   ${COLOR1}[08]${NC} • BACKUP   [${YELLOW}Menu${NC}]  $COLOR1│$NC"
  echo -e "  ${COLOR1}[03]${NC} • VLESS   [${YELLOW}Menu${NC}]   ${COLOR1}[09]${NC} • ADD HOST/DOMAIN  $COLOR1│$NC"
  echo -e "  ${COLOR1}[04]${NC} • TROJAN  [${YELLOW}Menu${NC}]   ${COLOR1}[10]${NC} • RENEW CERT       $COLOR1│$NC"
  echo -e "  ${COLOR1}[05]${NC} • SS WS   [${YELLOW}Menu${NC}]   ${COLOR1}[11]${NC} • SETTINGS [${YELLOW}Menu${NC}]  $COLOR1│$NC"
  echo -e "  ${COLOR1}[06]${NC} • SET DNS [${YELLOW}Menu${NC}]   ${COLOR1}[12]${NC} • INFO     [${YELLOW}Menu${NC}]  $COLOR1│$NC"
  echo -e "  ${COLOR1}[13]${NC} • REG IP  [${YELLOW}Menu${NC}]   ${COLOR1}[14]${NC} • SET BOT  [${YELLOW}Menu${NC}]  $COLOR1│$NC"
  echo -e "  ${COLOR1}[00]${NC} • UPDATE SCRIPT                               $COLOR1│$NC"
  echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
  echo -e "$COLOR1┌────────────────────── BY ───────────────────────┐${NC}"
  echo -e "$COLOR1│${NC}              • DevCulture •            $COLOR1│$NC"
  echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
  echo ""
  echo -ne " Select menu : "; read -r opt
  case $opt in
    01|1) clear; menu-ssh 2>/dev/null || echo "menu-ssh tidak ditemukan" ;;
    02|2) clear; menu-vmess 2>/dev/null || echo "menu-vmess tidak ditemukan" ;;
    03|3) clear; menu-vless 2>/dev/null || echo "menu-vless tidak ditemukan" ;;
    04|4) clear; menu-trojan 2>/dev/null || echo "menu-trojan tidak ditemukan" ;;
    05|5) clear; menu-ss 2>/dev/null || echo "menu-ss tidak ditemukan" ;;
    06|6) clear; menu-dns 2>/dev/null || echo "menu-dns tidak ditemukan" ;;
    07|7) clear; menu-theme 2>/dev/null || echo "menu-theme tidak ditemukan" ;;
    08|8) clear; menu-backup 2>/dev/null || echo "menu-backup tidak ditemukan" ;;
    09|9) clear; add-host ;;
    10) clear; crtxray 2>/dev/null || echo "crtxray tidak ditemukan" ;;
    11) clear; menu-set 2>/dev/null || echo "menu-set tidak ditemukan" ;;
    12) clear; info 2>/dev/null || devculture status ;;
    13) clear; menu-ip 2>/dev/null || echo "menu-ip tidak ditemukan" ;;
    14) clear; menu-bot 2>/dev/null || echo "menu-bot tidak ditemukan" ;;
    00|0) clear; updatews ;;
    *) clear; menu ;;
  esac
}

menu
