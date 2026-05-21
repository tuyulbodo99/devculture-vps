#!/bin/bash
# =================================================================
#   healthcheck.sh — DevCulture VPS Service Health Checker
#   Verifikasi semua service VPS berjalan setelah instalasi
#   Penggunaan: bash healthcheck.sh
# =================================================================

PASS=0; FAIL=0; WARN=0

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
PURPLE='\033[0;35m'

check_service() {
  local NAME="$1" SVC="$2"
  if systemctl is-active --quiet "$SVC" 2>/dev/null; then
    printf "  ${GREEN}●${NC} %-28s ${GREEN}[RUNNING]${NC}\n" "$NAME"
    ((PASS++))
  else
    printf "  ${RED}●${NC} %-28s ${RED}[STOPPED]${NC}\n" "$NAME"
    ((FAIL++))
  fi
}

check_port() {
  local NAME="$1" PORT="$2" PROTO="${3:-tcp}"
  if ss -lntup 2>/dev/null | grep -qE ":${PORT}[[:space:]]"; then
    printf "  ${GREEN}●${NC} %-28s ${GREEN}[PORT $PORT OPEN]${NC}\n" "$NAME"
    ((PASS++))
  else
    printf "  ${YELLOW}●${NC} %-28s ${YELLOW}[PORT $PORT CLOSED]${NC}\n" "$NAME"
    ((WARN++))
  fi
}

check_cmd() {
  local NAME="$1" CMD="$2"
  if command -v "$CMD" &>/dev/null; then
    local VER
    VER=$("$CMD" --version 2>&1 | head -1 | cut -c1-40)
    printf "  ${GREEN}●${NC} %-28s ${GREEN}[OK]${NC} %s\n" "$NAME" "$VER"
    ((PASS++))
  else
    printf "  ${RED}●${NC} %-28s ${RED}[NOT FOUND]${NC}\n" "$NAME"
    ((FAIL++))
  fi
}

check_file() {
  local NAME="$1" FILE="$2"
  if [[ -f "$FILE" ]]; then
    printf "  ${GREEN}●${NC} %-28s ${GREEN}[EXISTS]${NC}\n" "$NAME"
    ((PASS++))
  else
    printf "  ${YELLOW}●${NC} %-28s ${YELLOW}[MISSING] $FILE${NC}\n" "$NAME"
    ((WARN++))
  fi
}

check_url() {
  local NAME="$1" URL="$2"
  local CODE
  CODE=$(curl -o /dev/null -sfm 5 -w "%{http_code}" "$URL" 2>/dev/null || echo "ERR")
  if [[ "$CODE" =~ ^(200|301|302|403)$ ]]; then
    printf "  ${GREEN}●${NC} %-28s ${GREEN}[HTTP $CODE]${NC}\n" "$NAME"
    ((PASS++))
  else
    printf "  ${RED}●${NC} %-28s ${RED}[HTTP $CODE — GAGAL]${NC}\n" "$NAME"
    ((FAIL++))
  fi
}

clear
echo -e "${PURPLE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║${NC}       ${BOLD}DevCulture VPS — Health Check${NC}                  ${PURPLE}║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

IP=$(curl -s --max-time 5 ipv4.icanhazip.com 2>/dev/null || hostname -I | awk '{print $1}')
UPTIME=$(uptime -p 2>/dev/null | sed 's/up //')
OS=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2 || uname -r)
CPU=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print 100-$8}' | cut -d. -f1 || echo "N/A")
MEM=$(free -h 2>/dev/null | awk 'NR==2{printf "%s / %s", $3, $2}')

echo -e "  ${CYAN}IP VPS   :${NC} $IP"
echo -e "  ${CYAN}OS       :${NC} $OS"
echo -e "  ${CYAN}Uptime   :${NC} $UPTIME"
echo -e "  ${CYAN}CPU      :${NC} ${CPU}%"
echo -e "  ${CYAN}RAM      :${NC} $MEM"
echo ""

echo -e "${PURPLE}── SERVICES ─────────────────────────────────────────────${NC}"
check_service "SSH (OpenSSH)"         ssh
check_service "Dropbear"              dropbear
check_service "Nginx (WebSocket Proxy)" nginx
check_service "Stunnel4 (SSL Tunnel)" stunnel4
check_service "Xray"                  xray
check_service "UDP-Custom (UDPGW)"    udp-custom
check_service "Cron"                  cron
echo ""

echo -e "${PURPLE}── PORTS ────────────────────────────────────────────────${NC}"
check_port "OpenSSH"              22
check_port "Dropbear"            109
check_port "Dropbear Alt"        143
check_port "SSH WebSocket"        80
check_port "SSH SSL WebSocket"   443
check_port "Stunnel"             777
check_port "UDPGW"             7300
echo ""

echo -e "${PURPLE}── BINARIES ─────────────────────────────────────────────${NC}"
check_cmd  "Nginx"    nginx
check_cmd  "Xray"     xray
check_cmd  "Python3"  python3
check_cmd  "Curl"     curl
check_cmd  "Wget"     wget
echo ""

echo -e "${PURPLE}── CONFIG FILES ──────────────────────────────────────────${NC}"
check_file "Nginx config"           /etc/nginx/nginx.conf
check_file "Xray config"            /usr/local/etc/xray/config.json
check_file "Stunnel config"         /etc/stunnel/stunnel.conf
check_file "Dropbear config"        /etc/default/dropbear
check_file "WebSocket service"      /etc/systemd/system/ws-stunnel.service
echo ""

echo -e "${PURPLE}── NGINX STATUS ──────────────────────────────────────────${NC}"
if command -v nginx &>/dev/null; then
  nginx -t 2>&1 | while read -r line; do
    if echo "$line" | grep -q "ok\|successful"; then
      printf "  ${GREEN}●${NC} %s\n" "$line"
    elif echo "$line" | grep -q "error\|fail"; then
      printf "  ${RED}●${NC} %s\n" "$line"
      ((FAIL++))
    else
      printf "  ${CYAN}●${NC} %s\n" "$line"
    fi
  done
else
  printf "  ${RED}●${NC} nginx tidak terinstall\n"
  ((FAIL++))
fi
echo ""

echo -e "${PURPLE}── CONNECTIVITY ──────────────────────────────────────────${NC}"
check_url "GitHub (raw)"   "https://raw.githubusercontent.com"
check_url "Google DNS"     "https://dns.google"
check_url "Xray CDN"       "https://github.com/XTLS/Xray-core/releases"
echo ""

echo -e "${PURPLE}═══════════════════════════════════════════════════════════${NC}"
TOTAL=$((PASS + FAIL + WARN))
if [[ $FAIL -eq 0 && $WARN -eq 0 ]]; then
  echo -e "  ${GREEN}${BOLD}✔ SEMUA OK — VPS SIAP DIGUNAKAN${NC}"
elif [[ $FAIL -eq 0 ]]; then
  echo -e "  ${YELLOW}${BOLD}⚠ $PASS/$TOTAL OK · $WARN peringatan (cek detail di atas)${NC}"
else
  echo -e "  ${RED}${BOLD}✘ $FAIL GAGAL · $WARN peringatan · $PASS/$TOTAL OK${NC}"
  echo ""
  echo -e "  ${CYAN}Tips perbaikan cepat:${NC}"
  echo -e "  • nginx error  → ${YELLOW}nginx -t${NC} lalu ${YELLOW}systemctl restart nginx${NC}"
  echo -e "  • xray stop    → ${YELLOW}systemctl restart xray${NC}"
  echo -e "  • stunnel stop → ${YELLOW}systemctl restart stunnel4${NC}"
  echo -e "  • udpgw stop   → ${YELLOW}systemctl restart udp-custom${NC}"
fi
echo -e "${PURPLE}═══════════════════════════════════════════════════════════${NC}"
