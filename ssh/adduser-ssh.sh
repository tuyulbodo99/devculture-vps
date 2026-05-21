#!/bin/bash
# =================================================================
#   DevCulture VPS — SSH User Manager v2.0.0
#   Multi-Port | UDP | WebSocket | Stunnel | SlowDNS
#   github.com/tuyulbodo99 | @devculturebot
# =================================================================

RESET="\033[0m"; BOLD="\033[1m"; DIM="\033[2m"
BCYAN="\033[1;36m"; BGREEN="\033[1;32m"; BYELLOW="\033[1;33m"
BRED="\033[1;31m"; BPURPLE="\033[1;35m"; BWHITE="\033[1;37m"
BGRAY="\033[1;90m"; BBLUE="\033[1;34m"

LINE="═══════════════════════════════════════════════════════════════"
LINE2="───────────────────────────────────────────────────────────────"

# ── Baca konfigurasi dari log-install.txt ─────────────────────────
read_config() {
  LOG="/root/log-install.txt"
  DOMAIN=$(grep -w "Domain" "$LOG" 2>/dev/null | cut -d: -f2 | xargs || echo "")
  PORT_SSH=$(grep -w "OpenSSH" "$LOG" 2>/dev/null | grep -oP '\d+' | head -1 || echo "22")
  PORT_DROPBEAR=$(grep -w "Dropbear" "$LOG" 2>/dev/null | cut -d: -f2 | sed 's/ //g' | cut -f1 -d"," || echo "109")
  PORT_DROPBEAR2=$(grep -w "Dropbear" "$LOG" 2>/dev/null | cut -d: -f2 | sed 's/ //g' | cut -f2 -d"," || echo "143")
  PORT_SSHWS=$(grep -w "SSH Websocket" "$LOG" 2>/dev/null | cut -d: -f2 | awk '{print $1}' || echo "80")
  PORT_SSHWSSL=$(grep -w "SSH SSL Websocket" "$LOG" 2>/dev/null | cut -d: -f2 | awk '{print $1}' || echo "443")
  PORT_STUNNEL=$(grep -w "Stunnel" "$LOG" 2>/dev/null | grep -oP '\d+' | head -1 || echo "777")
  PORT_UDPGW=$(grep -w "UDPGW" "$LOG" 2>/dev/null | grep -oP '\d+' | head -1 || echo "7300")
  PORT_SLOWDNS=$(grep -w "SlowDNS" "$LOG" 2>/dev/null | grep -oP '\d+' | head -1 || echo "5300")
  PORT_OVPN_TCP=$(grep -w "OpenVPN TCP" "$LOG" 2>/dev/null | grep -oP '\d+' | head -1 || echo "1194")
  PORT_OVPN_UDP=$(grep -w "OpenVPN UDP" "$LOG" 2>/dev/null | grep -oP '\d+' | head -1 || echo "2200")
  MYIP=$(curl -sS --max-time 5 ipv4.icanhazip.com 2>/dev/null \
      || curl -sS --max-time 5 ifconfig.me 2>/dev/null \
      || hostname -I | awk '{print $1}')
  HOST="${DOMAIN:-$MYIP}"
}

validate_user() {
  local u="$1"
  [[ -z "$u" ]] && { echo "Username kosong!"; return 1; }
  [[ ${#u} -lt 3 ]] && { echo "Min 3 karakter!"; return 1; }
  [[ ! "$u" =~ ^[a-zA-Z0-9_-]+$ ]] && { echo "Hanya huruf, angka, _, -"; return 1; }
  id "$u" &>/dev/null && { echo "Username '$u' sudah ada!"; return 1; }
  return 0
}
validate_pass() { [[ -z "$1" || ${#1} -lt 4 ]] && { echo "Password min 4 karakter!"; return 1; }; return 0; }
validate_exp()  { [[ ! "$1" =~ ^[0-9]+$ || "$1" -lt 1 || "$1" -gt 365 ]] && { echo "Hari 1-365!"; return 1; }; return 0; }

calc_expire() { date -d "+${1} days" '+%Y-%m-%d'; }
fmt_days()    {
  local d1; d1=$(date -d "$1" +%s 2>/dev/null) || { echo "$1"; return; }
  local d2; d2=$(date +%s)
  echo "$1 ($(( (d1-d2)/86400 )) hari lagi)"
}

create_ssh_user() {
  useradd -e "$3" -s /bin/false -M "$1" 2>/dev/null \
    || useradd -e "$3" -s /usr/sbin/nologin -M "$1"
  echo "$1:$2" | chpasswd
  grep -q "^$1" /etc/security/limits.conf 2>/dev/null \
    || echo "$1 hard maxlogins 2" >> /etc/security/limits.conf
}

# ════════════════════════════════════════════════════════════════
#   TAMPILKAN INFO AKUN LENGKAP
# ════════════════════════════════════════════════════════════════
show_account() {
  local U="$1" P="$2" EXP="$3"
  local TS; TS=$(date '+%d %B %Y %H:%M:%S WIB')

  clear
  echo ""
  # ── Header Banner ──────────────────────────────────────────────
  echo -e "${BPURPLE}  ╔${LINE}╗${RESET}"
  echo -e "${BPURPLE}  ║${RESET}                                                               ${BPURPLE}║${RESET}"
  echo -e "${BPURPLE}  ║${RESET}  ${BOLD}${BWHITE}  ██████╗  ██████╗    ██╗   ██╗██████╗ ███████╗${RESET}        ${BPURPLE}║${RESET}"
  echo -e "${BPURPLE}  ║${RESET}  ${BOLD}${BWHITE}  ██╔══██╗██╔════╝    ██║   ██║██╔══██╗██╔════╝${RESET}        ${BPURPLE}║${RESET}"
  echo -e "${BPURPLE}  ║${RESET}  ${BOLD}${BWHITE}  ██║  ██║██║         ╚██╗ ██╔╝██████╔╝███████╗${RESET}        ${BPURPLE}║${RESET}"
  echo -e "${BPURPLE}  ║${RESET}  ${BOLD}${BWHITE}  ██║  ██║██║          ╚████╔╝ ██╔═══╝ ╚════██║${RESET}        ${BPURPLE}║${RESET}"
  echo -e "${BPURPLE}  ║${RESET}  ${BOLD}${BWHITE}  ██████╔╝╚██████╗      ╚██╔╝  ██║     ███████║${RESET}        ${BPURPLE}║${RESET}"
  echo -e "${BPURPLE}  ║${RESET}  ${DIM}${BGRAY}  ╚═════╝  ╚═════╝       ╚═╝   ╚═╝     ╚══════╝${RESET}        ${BPURPLE}║${RESET}"
  echo -e "${BPURPLE}  ║${RESET}              ${DIM}github.com/tuyulbodo99 • @devculturebot${RESET}      ${BPURPLE}║${RESET}"
  echo -e "${BPURPLE}  ╚${LINE}╝${RESET}"
  echo ""

  # ── Informasi Akun ─────────────────────────────────────────────
  echo -e "  ${BPURPLE}╔${LINE}╗${RESET}"
  echo -e "  ${BPURPLE}║${RESET}  ${BOLD}${BYELLOW}◈  INFORMASI AKUN SSH${RESET}                                          ${BPURPLE}║${RESET}"
  echo -e "  ${BPURPLE}╠${LINE}╣${RESET}"
  printf "  ${BPURPLE}║${RESET}  ${BCYAN}%-20s${RESET}: ${BWHITE}%-42s${RESET}${BPURPLE}║${RESET}\n" "Username"   "$U"
  printf "  ${BPURPLE}║${RESET}  ${BCYAN}%-20s${RESET}: ${BWHITE}%-42s${RESET}${BPURPLE}║${RESET}\n" "Password"   "$P"
  printf "  ${BPURPLE}║${RESET}  ${BCYAN}%-20s${RESET}: ${BWHITE}%-42s${RESET}${BPURPLE}║${RESET}\n" "Masa Aktif" "$(fmt_days "$EXP")"
  printf "  ${BPURPLE}║${RESET}  ${BCYAN}%-20s${RESET}: ${BWHITE}%-42s${RESET}${BPURPLE}║${RESET}\n" "Dibuat"     "$TS"
  printf "  ${BPURPLE}║${RESET}  ${BCYAN}%-20s${RESET}: ${BWHITE}%-42s${RESET}${BPURPLE}║${RESET}\n" "Host / IP"  "$HOST"
  printf "  ${BPURPLE}║${RESET}  ${BCYAN}%-20s${RESET}: ${BWHITE}%-42s${RESET}${BPURPLE}║${RESET}\n" "Format Akun" "${U}@${P}:${HOST}"
  echo -e "  ${BPURPLE}╚${LINE}╝${RESET}"
  echo ""

  # ── Multi-Port TCP ─────────────────────────────────────────────
  echo -e "  ${BPURPLE}╔${LINE}╗${RESET}"
  echo -e "  ${BPURPLE}║${RESET}  ${BOLD}${BYELLOW}◈  KONEKSI TCP — MULTI PORT${RESET}                                    ${BPURPLE}║${RESET}"
  echo -e "  ${BPURPLE}╠══════════════════════╦═══════╦═══════════════════════════════╣${RESET}"
  printf "  ${BPURPLE}║${RESET}  ${BOLD}%-20s${RESET}  ${BPURPLE}║${RESET}  ${BOLD}%-5s${RESET}  ${BPURPLE}║${RESET}  ${BOLD}%-31s${RESET}${BPURPLE}║${RESET}\n" "Protokol" "Port" "Connection String"
  echo -e "  ${BPURPLE}╠══════════════════════╬═══════╬═══════════════════════════════╣${RESET}"
  printf "  ${BPURPLE}║${RESET}  ${BGREEN}%-20s${RESET}  ${BPURPLE}║${RESET}  ${BWHITE}%-5s${RESET}  ${BPURPLE}║${RESET}  ${BYELLOW}%-31s${RESET}${BPURPLE}║${RESET}\n" \
    "OpenSSH" "$PORT_SSH" "${U}@${P}:${HOST}:${PORT_SSH}"
  printf "  ${BPURPLE}║${RESET}  ${BGREEN}%-20s${RESET}  ${BPURPLE}║${RESET}  ${BWHITE}%-5s${RESET}  ${BPURPLE}║${RESET}  ${BYELLOW}%-31s${RESET}${BPURPLE}║${RESET}\n" \
    "Dropbear" "$PORT_DROPBEAR" "${U}@${P}:${HOST}:${PORT_DROPBEAR}"
  printf "  ${BPURPLE}║${RESET}  ${BGREEN}%-20s${RESET}  ${BPURPLE}║${RESET}  ${BWHITE}%-5s${RESET}  ${BPURPLE}║${RESET}  ${BYELLOW}%-31s${RESET}${BPURPLE}║${RESET}\n" \
    "Dropbear Alt" "$PORT_DROPBEAR2" "${U}@${P}:${HOST}:${PORT_DROPBEAR2}"
  printf "  ${BPURPLE}║${RESET}  ${BGREEN}%-20s${RESET}  ${BPURPLE}║${RESET}  ${BWHITE}%-5s${RESET}  ${BPURPLE}║${RESET}  ${BYELLOW}%-31s${RESET}${BPURPLE}║${RESET}\n" \
    "SSH WebSocket" "$PORT_SSHWS" "${U}@${P}:${HOST}:${PORT_SSHWS}"
  printf "  ${BPURPLE}║${RESET}  ${BGREEN}%-20s${RESET}  ${BPURPLE}║${RESET}  ${BWHITE}%-5s${RESET}  ${BPURPLE}║${RESET}  ${BYELLOW}%-31s${RESET}${BPURPLE}║${RESET}\n" \
    "SSH SSL/WSS" "$PORT_SSHWSSL" "${U}@${P}:${HOST}:${PORT_SSHWSSL}"
  printf "  ${BPURPLE}║${RESET}  ${BGREEN}%-20s${RESET}  ${BPURPLE}║${RESET}  ${BWHITE}%-5s${RESET}  ${BPURPLE}║${RESET}  ${BYELLOW}%-31s${RESET}${BPURPLE}║${RESET}\n" \
    "Stunnel (SSL)" "$PORT_STUNNEL" "${U}@${P}:${HOST}:${PORT_STUNNEL}"
  echo -e "  ${BPURPLE}╚══════════════════════╩═══════╩═══════════════════════════════╝${RESET}"
  echo ""

  # ── Multi-Port UDP ─────────────────────────────────────────────
  echo -e "  ${BPURPLE}╔${LINE}╗${RESET}"
  echo -e "  ${BPURPLE}║${RESET}  ${BOLD}${BYELLOW}◈  KONEKSI UDP — MULTI PORT${RESET}                                    ${BPURPLE}║${RESET}"
  echo -e "  ${BPURPLE}╠══════════════════════╦═══════╦═══════════════════════════════╣${RESET}"
  printf "  ${BPURPLE}║${RESET}  ${BOLD}%-20s${RESET}  ${BPURPLE}║${RESET}  ${BOLD}%-5s${RESET}  ${BPURPLE}║${RESET}  ${BOLD}%-31s${RESET}${BPURPLE}║${RESET}\n" "Protokol" "Port" "Connection String"
  echo -e "  ${BPURPLE}╠══════════════════════╬═══════╬═══════════════════════════════╣${RESET}"
  printf "  ${BPURPLE}║${RESET}  ${BBLUE}%-20s${RESET}  ${BPURPLE}║${RESET}  ${BWHITE}%-5s${RESET}  ${BPURPLE}║${RESET}  ${BYELLOW}%-31s${RESET}${BPURPLE}║${RESET}\n" \
    "UDPGW (BadVPN)" "$PORT_UDPGW" "${U}@${P}:${HOST}:${PORT_UDPGW}"
  printf "  ${BPURPLE}║${RESET}  ${BBLUE}%-20s${RESET}  ${BPURPLE}║${RESET}  ${BWHITE}%-5s${RESET}  ${BPURPLE}║${RESET}  ${BYELLOW}%-31s${RESET}${BPURPLE}║${RESET}\n" \
    "SlowDNS UDP" "$PORT_SLOWDNS" "${U}@${P}:${HOST}:${PORT_SLOWDNS}"
  printf "  ${BPURPLE}║${RESET}  ${BBLUE}%-20s${RESET}  ${BPURPLE}║${RESET}  ${BWHITE}%-5s${RESET}  ${BPURPLE}║${RESET}  ${BYELLOW}%-31s${RESET}${BPURPLE}║${RESET}\n" \
    "OpenVPN UDP" "$PORT_OVPN_UDP" "${U}@${P}:${HOST}:${PORT_OVPN_UDP}"
  printf "  ${BPURPLE}║${RESET}  ${BBLUE}%-20s${RESET}  ${BPURPLE}║${RESET}  ${BWHITE}%-5s${RESET}  ${BPURPLE}║${RESET}  ${BYELLOW}%-31s${RESET}${BPURPLE}║${RESET}\n" \
    "OpenVPN TCP" "$PORT_OVPN_TCP" "${U}@${P}:${HOST}:${PORT_OVPN_TCP}"
  echo -e "  ${BPURPLE}╚══════════════════════╩═══════╩═══════════════════════════════╝${RESET}"
  echo ""

  # ── HTTP Injector / NPay / NetSpark Config ─────────────────────
  echo -e "  ${BPURPLE}╔${LINE}╗${RESET}"
  echo -e "  ${BPURPLE}║${RESET}  ${BOLD}${BYELLOW}◈  HTTP INJECTOR / NETSPARK / NPAY / HTTP CUSTOM${RESET}               ${BPURPLE}║${RESET}"
  echo -e "  ${BPURPLE}╠${LINE}╣${RESET}"
  echo -e "  ${BPURPLE}║${RESET}"
  printf "  ${BPURPLE}║${RESET}  ${BCYAN}%-13s${RESET}: ${BWHITE}%s${RESET}\n" "Proxy Type"   "SSH"
  printf "  ${BPURPLE}║${RESET}  ${BCYAN}%-13s${RESET}: ${BWHITE}%s${RESET}\n" "SSH Host"     "$HOST"
  printf "  ${BPURPLE}║${RESET}  ${BCYAN}%-13s${RESET}: ${BWHITE}%s${RESET}\n" "SSH Port"     "$PORT_SSH"
  printf "  ${BPURPLE}║${RESET}  ${BCYAN}%-13s${RESET}: ${BWHITE}%s${RESET}\n" "SSH User"     "$U"
  printf "  ${BPURPLE}║${RESET}  ${BCYAN}%-13s${RESET}: ${BWHITE}%s${RESET}\n" "SSH Pass"     "$P"
  printf "  ${BPURPLE}║${RESET}  ${BCYAN}%-13s${RESET}: ${BWHITE}%s${RESET}\n" "Remote Proxy" "127.0.0.1:8080"
  printf "  ${BPURPLE}║${RESET}  ${BCYAN}%-13s${RESET}: ${BWHITE}%s${RESET}\n" "Listen Port"  "8989"
  printf "  ${BPURPLE}║${RESET}  ${BCYAN}%-13s${RESET}: ${BWHITE}%s${RESET}\n" "UDPGW"        "${HOST}:${PORT_UDPGW}"
  echo -e "  ${BPURPLE}║${RESET}"
  echo -e "  ${BPURPLE}║${RESET}  ${BOLD}${BGRAY}Payload:${RESET}"
  printf "  ${BPURPLE}║${RESET}  ${BWHITE}GET wss://bug.com/ HTTP/1.1[crlf]${RESET}\n"
  printf "  ${BPURPLE}║${RESET}  ${BWHITE}Host: bug.com[crlf]${RESET}\n"
  printf "  ${BPURPLE}║${RESET}  ${BWHITE}Upgrade: websocket[crlf][crlf]${RESET}\n"
  echo -e "  ${BPURPLE}║${RESET}"
  echo -e "  ${BPURPLE}║${RESET}  ${DIM}Alt Payload 2 (CONNECT):${RESET}"
  printf "  ${BPURPLE}║${RESET}  ${BWHITE}CONNECT ${HOST}:${PORT_SSH} HTTP/1.1[crlf]${RESET}\n"
  printf "  ${BPURPLE}║${RESET}  ${BWHITE}Host: bug.com[crlf][crlf]${RESET}\n"
  echo -e "  ${BPURPLE}║${RESET}"
  echo -e "  ${BPURPLE}║${RESET}  ${DIM}Alt Payload 3 (Upgrade Header):${RESET}"
  printf "  ${BPURPLE}║${RESET}  ${BWHITE}GET / HTTP/1.1[crlf]${RESET}\n"
  printf "  ${BPURPLE}║${RESET}  ${BWHITE}Host: bug.com[crlf]${RESET}\n"
  printf "  ${BPURPLE}║${RESET}  ${BWHITE}Connection: Upgrade[crlf]${RESET}\n"
  printf "  ${BPURPLE}║${RESET}  ${BWHITE}Upgrade: websocket[crlf][crlf]${RESET}\n"
  echo -e "  ${BPURPLE}╚${LINE}╝${RESET}"
  echo ""



  # ── Config KPN Tunnel / OpenTunnel ────────────────────────────
  echo -e "  ${BPURPLE}╔${LINE}╗${RESET}"
  echo -e "  ${BPURPLE}║${RESET}  ${BOLD}${BYELLOW}◈  KPN TUNNEL / OPENTUNNEL / VNPK${RESET}                              ${BPURPLE}║${RESET}"
  echo -e "  ${BPURPLE}╠${LINE}╣${RESET}"
  printf "  ${BPURPLE}║${RESET}  ${BCYAN}%-20s${RESET}: ${BWHITE}%-42s${RESET}${BPURPLE}║${RESET}\n" "Mode"         "SSH + UDP"
  printf "  ${BPURPLE}║${RESET}  ${BCYAN}%-20s${RESET}: ${BWHITE}%-42s${RESET}${BPURPLE}║${RESET}\n" "SSH Server"   "$HOST"
  printf "  ${BPURPLE}║${RESET}  ${BCYAN}%-20s${RESET}: ${BWHITE}%-42s${RESET}${BPURPLE}║${RESET}\n" "SSH Port"     "$PORT_SSH"
  printf "  ${BPURPLE}║${RESET}  ${BCYAN}%-20s${RESET}: ${BWHITE}%-42s${RESET}${BPURPLE}║${RESET}\n" "SSH User"     "$U"
  printf "  ${BPURPLE}║${RESET}  ${BCYAN}%-20s${RESET}: ${BWHITE}%-42s${RESET}${BPURPLE}║${RESET}\n" "SSH Password" "$P"
  printf "  ${BPURPLE}║${RESET}  ${BCYAN}%-20s${RESET}: ${BWHITE}%-42s${RESET}${BPURPLE}║${RESET}\n" "UDPGW Host"   "$HOST"
  printf "  ${BPURPLE}║${RESET}  ${BCYAN}%-20s${RESET}: ${BWHITE}%-42s${RESET}${BPURPLE}║${RESET}\n" "UDPGW Port"   "$PORT_UDPGW"
  echo -e "  ${BPURPLE}║${RESET}"
  echo -e "  ${BPURPLE}║${RESET}  ${DIM}Connection String (copy-paste):${RESET}"
  echo -e "  ${BPURPLE}║${RESET}  ${BWHITE}  ${U}@${P}:${HOST}:${PORT_SSH}:udp:${PORT_UDPGW}${RESET}"
  echo -e "  ${BPURPLE}╚${LINE}╝${RESET}"
  echo ""

  # ── SlowDNS Config ─────────────────────────────────────────────
  echo -e "  ${BPURPLE}╔${LINE}╗${RESET}"
  echo -e "  ${BPURPLE}║${RESET}  ${BOLD}${BYELLOW}◈  SLOWDNS / DNS TUNNEL CONFIG${RESET}                                 ${BPURPLE}║${RESET}"
  echo -e "  ${BPURPLE}╠${LINE}╣${RESET}"
  printf "  ${BPURPLE}║${RESET}  ${BCYAN}%-20s${RESET}: ${BWHITE}%-42s${RESET}${BPURPLE}║${RESET}\n" "SSH Host"     "$HOST"
  printf "  ${BPURPLE}║${RESET}  ${BCYAN}%-20s${RESET}: ${BWHITE}%-42s${RESET}${BPURPLE}║${RESET}\n" "SSH Port"     "$PORT_SSH"
  printf "  ${BPURPLE}║${RESET}  ${BCYAN}%-20s${RESET}: ${BWHITE}%-42s${RESET}${BPURPLE}║${RESET}\n" "DNS Server"   "$HOST"
  printf "  ${BPURPLE}║${RESET}  ${BCYAN}%-20s${RESET}: ${BWHITE}%-42s${RESET}${BPURPLE}║${RESET}\n" "DNS Port"     "$PORT_SLOWDNS (UDP)"
  printf "  ${BPURPLE}║${RESET}  ${BCYAN}%-20s${RESET}: ${BWHITE}%-42s${RESET}${BPURPLE}║${RESET}\n" "Nameserver"   "ns1.devculture.id"
  printf "  ${BPURPLE}║${RESET}  ${BCYAN}%-20s${RESET}: ${BWHITE}%-42s${RESET}${BPURPLE}║${RESET}\n" "Username"     "$U"
  printf "  ${BPURPLE}║${RESET}  ${BCYAN}%-20s${RESET}: ${BWHITE}%-42s${RESET}${BPURPLE}║${RESET}\n" "Password"     "$P"
  echo -e "  ${BPURPLE}║${RESET}"
  echo -e "  ${BPURPLE}║${RESET}  ${DIM}String (SlowDNS format):${RESET}"
  echo -e "  ${BPURPLE}║${RESET}  ${BWHITE}  ${U}@${P}:${HOST}:${PORT_SLOWDNS}:dns:ns1.devculture.id${RESET}"
  echo -e "  ${BPURPLE}╚${LINE}╝${RESET}"
  echo ""

  # ── SSH Terminal Commands ──────────────────────────────────────
  echo -e "  ${BPURPLE}╔${LINE}╗${RESET}"
  echo -e "  ${BPURPLE}║${RESET}  ${BOLD}${BYELLOW}◈  PERINTAH SSH TERMINAL — SEMUA PORT${RESET}                          ${BPURPLE}║${RESET}"
  echo -e "  ${BPURPLE}╠${LINE}╣${RESET}"
  printf "  ${BPURPLE}║${RESET}  ${DIM}%-63s${RESET}${BPURPLE}║${RESET}\n" "# OpenSSH (default):"
  printf "  ${BPURPLE}║${RESET}  ${BWHITE}  %-61s${RESET}${BPURPLE}║${RESET}\n" "ssh ${U}@${HOST} -p ${PORT_SSH}"
  echo -e "  ${BPURPLE}║${RESET}"
  printf "  ${BPURPLE}║${RESET}  ${DIM}%-63s${RESET}${BPURPLE}║${RESET}\n" "# Dropbear port 1:"
  printf "  ${BPURPLE}║${RESET}  ${BWHITE}  %-61s${RESET}${BPURPLE}║${RESET}\n" "ssh ${U}@${HOST} -p ${PORT_DROPBEAR}"
  echo -e "  ${BPURPLE}║${RESET}"
  printf "  ${BPURPLE}║${RESET}  ${DIM}%-63s${RESET}${BPURPLE}║${RESET}\n" "# Dropbear port 2:"
  printf "  ${BPURPLE}║${RESET}  ${BWHITE}  %-61s${RESET}${BPURPLE}║${RESET}\n" "ssh ${U}@${HOST} -p ${PORT_DROPBEAR2}"
  echo -e "  ${BPURPLE}║${RESET}"
  printf "  ${BPURPLE}║${RESET}  ${DIM}%-63s${RESET}${BPURPLE}║${RESET}\n" "# WebSocket HTTP:"
  printf "  ${BPURPLE}║${RESET}  ${BWHITE}  %-61s${RESET}${BPURPLE}║${RESET}\n" "ssh ${U}@${HOST} -p ${PORT_SSHWS}"
  echo -e "  ${BPURPLE}║${RESET}"
  printf "  ${BPURPLE}║${RESET}  ${DIM}%-63s${RESET}${BPURPLE}║${RESET}\n" "# WebSocket HTTPS/SSL:"
  printf "  ${BPURPLE}║${RESET}  ${BWHITE}  %-61s${RESET}${BPURPLE}║${RESET}\n" "ssh ${U}@${HOST} -p ${PORT_SSHWSSL}"
  echo -e "  ${BPURPLE}║${RESET}"
  printf "  ${BPURPLE}║${RESET}  ${DIM}%-63s${RESET}${BPURPLE}║${RESET}\n" "# Via Stunnel SSL:"
  printf "  ${BPURPLE}║${RESET}  ${BWHITE}  %-61s${RESET}${BPURPLE}║${RESET}\n" "ssh ${U}@${HOST} -p ${PORT_STUNNEL}"
  echo -e "  ${BPURPLE}║${RESET}"
  printf "  ${BPURPLE}║${RESET}  ${DIM}%-63s${RESET}${BPURPLE}║${RESET}\n" "# BadVPN UDPGW (di sisi VPS):"
  printf "  ${BPURPLE}║${RESET}  ${BWHITE}  %-61s${RESET}${BPURPLE}║${RESET}\n" "badvpn-udpgw --listen-addr 127.0.0.1:${PORT_UDPGW}"
  echo -e "  ${BPURPLE}╚${LINE}╝${RESET}"
  echo ""

  # ── Status Services ────────────────────────────────────────────
  echo -e "  ${BPURPLE}╔${LINE}╗${RESET}"
  echo -e "  ${BPURPLE}║${RESET}  ${BOLD}${BYELLOW}◈  STATUS LAYANAN${RESET}                                              ${BPURPLE}║${RESET}"
  echo -e "  ${BPURPLE}╠════════════════════╦══════════╦════════════════════════════════╣${RESET}"
  printf "  ${BPURPLE}║${RESET}  ${BOLD}%-18s${RESET}  ${BPURPLE}║${RESET}  ${BOLD}%-8s${RESET}  ${BPURPLE}║${RESET}  ${BOLD}%-30s${RESET}  ${BPURPLE}║${RESET}\n" "Service" "Status" "Port"
  echo -e "  ${BPURPLE}╠════════════════════╬══════════╬════════════════════════════════╣${RESET}"
  local SVC_LIST=(
    "ssh:TCP:$PORT_SSH"
    "dropbear:TCP:${PORT_DROPBEAR},${PORT_DROPBEAR2}"
    "nginx:TCP:80,443"
    "stunnel4:TCP:$PORT_STUNNEL"
    "ws-openssh:TCP:2095"
    "ws-dropbear:TCP:$PORT_SSHWS"
    "badvpn-udpgw:UDP:$PORT_UDPGW"
    "slowdns:UDP:$PORT_SLOWDNS"
  )
  for entry in "${SVC_LIST[@]}"; do
    svc="${entry%%:*}"; rest="${entry#*:}"; proto="${rest%%:*}"; ports="${rest#*:}"
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
      STATUS="${BGREEN}● ACTIVE  ${RESET}"
    else
      STATUS="${BRED}● INACTIVE${RESET}"
    fi
    printf "  ${BPURPLE}║${RESET}  %-18s  ${BPURPLE}║${RESET}  %b  ${BPURPLE}║${RESET}  ${DIM}%-6s${RESET} ${BWHITE}%-24s${RESET}  ${BPURPLE}║${RESET}\n" \
      "$svc" "$STATUS" "$proto" "$ports"
  done
  echo -e "  ${BPURPLE}╚════════════════════╩══════════╩════════════════════════════════╝${RESET}"
  echo ""

  # ── Footer ─────────────────────────────────────────────────────
  echo -e "  ${BPURPLE}╔${LINE}╗${RESET}"
  echo -e "  ${BPURPLE}║${RESET}  ${BGREEN}${BOLD}  ✔  Akun SSH berhasil dibuat!${RESET}                                  ${BPURPLE}║${RESET}"
  printf "  ${BPURPLE}║${RESET}  ${DIM}  Log: /root/dc-ssh-accounts.log %-30s${RESET}${BPURPLE}║${RESET}\n" ""
  echo -e "  ${BPURPLE}╚${LINE}╝${RESET}"
  echo ""

  # Simpan log
  {
    echo "============================================================"
    echo "DATE       : $TS"
    echo "USERNAME   : $U"
    echo "PASSWORD   : $P"
    echo "EXPIRES    : $EXP"
    echo "HOST       : $HOST"
    echo "TCP PORTS  : SSH:$PORT_SSH | DB:$PORT_DROPBEAR,$PORT_DROPBEAR2 | WS:$PORT_SSHWS | WSS:$PORT_SSHWSSL | STN:$PORT_STUNNEL"
    echo "UDP PORTS  : UDPGW:$PORT_UDPGW | SlowDNS:$PORT_SLOWDNS | OVPN-UDP:$PORT_OVPN_UDP"
    echo "STRING     : ${U}@${P}:${HOST}:${PORT_SSH}"
    echo "============================================================"
  } >> /root/dc-ssh-accounts.log 2>/dev/null || true
}

# ── Add user ──────────────────────────────────────────────────────
add_user() {
  read_config; clear; echo ""
  echo -e "  ${BPURPLE}╔══════════════════════════════════════════╗${RESET}"
  echo -e "  ${BPURPLE}║${RESET}  ${BOLD}${BWHITE}BUAT AKUN SSH + MULTI PORT + UDP${RESET}       ${BPURPLE}║${RESET}"
  echo -e "  ${BPURPLE}╚══════════════════════════════════════════╝${RESET}"; echo ""
  while true; do read -rp "  ${BCYAN}Username${RESET}   : " UN; ERR=$(validate_user "$UN" 2>&1) && break || echo -e "  ${BRED}✘ $ERR${RESET}"; done
  while true; do read -rp "  ${BCYAN}Password${RESET}   : " PW; ERR=$(validate_pass "$PW" 2>&1) && break || echo -e "  ${BRED}✘ $ERR${RESET}"; done
  while true; do read -rp "  ${BCYAN}Masa Aktif${RESET} : " DY; ERR=$(validate_exp "$DY" 2>&1) && break || echo -e "  ${BRED}✘ $ERR${RESET}"; done
  EXP=$(calc_expire "$DY"); echo ""
  echo -e "  ${BYELLOW}Membuat akun...${RESET}"
  [[ $EUID -ne 0 ]] && { echo -e "  ${BRED}✘ Butuh root!${RESET}"; exit 1; }
  create_ssh_user "$UN" "$PW" "$EXP"
  show_account "$UN" "$PW" "$EXP"
}

# ── List users ───────────────────────────────────────────────────
list_users() {
  read_config; clear; echo ""
  echo -e "  ${BPURPLE}╔══════╦══════════════════╦════════════╦════════╦══════════════╗${RESET}"
  printf "  ${BPURPLE}║${RESET} ${BOLD}%-4s${RESET} ${BPURPLE}║${RESET} ${BOLD}%-16s${RESET} ${BPURPLE}║${RESET} ${BOLD}%-10s${RESET} ${BPURPLE}║${RESET} ${BOLD}%-6s${RESET} ${BPURPLE}║${RESET} ${BOLD}%-12s${RESET} ${BPURPLE}║${RESET}\n" "No" "Username" "Expired" "Online" "Status"
  echo -e "  ${BPURPLE}╠══════╬══════════════════╬════════════╬════════╬══════════════╣${RESET}"
  local IDX=0 TODAY; TODAY=$(date '+%Y-%m-%d')
  while IFS=: read -r user _ uid _ _ _ shell; do
    [[ "$uid" -lt 1000 ]] && continue
    [[ "$shell" == */nologin || "$shell" == */false ]] || continue
    local exp; exp=$(chage -l "$user" 2>/dev/null | grep "Account expires" | cut -d: -f2 | xargs)
    [[ "$exp" == "never" || -z "$exp" ]] && continue
    local ef; ef=$(date -d "$exp" '+%Y-%m-%d' 2>/dev/null || echo "$exp")
    local on; on=$(who | grep -c "^$user " 2>/dev/null || echo 0)
    IDX=$((IDX+1))
    local C="$BGREEN" S="AKTIF"
    [[ "$ef" < "$TODAY" ]] && C="$BRED" && S="EXPIRED"
    printf "  ${BPURPLE}║${RESET} ${C}%-4s${RESET} ${BPURPLE}║${RESET} ${C}%-16s${RESET} ${BPURPLE}║${RESET} ${C}%-10s${RESET} ${BPURPLE}║${RESET} ${C}%-6s${RESET} ${BPURPLE}║${RESET} ${C}%-12s${RESET} ${BPURPLE}║${RESET}\n" \
      "$IDX" "$user" "$ef" "$on" "$S"
  done < /etc/passwd
  echo -e "  ${BPURPLE}╚══════╩══════════════════╩════════════╩════════╩══════════════╝${RESET}"
  echo -e "  ${DIM}  Total: ${IDX} akun${RESET}"; echo ""
}

delete_user() {
  list_users
  read -rp "  ${BCYAN}Username hapus${RESET}: " D
  [[ -z "$D" ]] && return
  id "$D" &>/dev/null || { echo -e "  ${BRED}✘ '$D' tidak ada!${RESET}"; return; }
  pkill -u "$D" 2>/dev/null || true
  userdel --force "$D" 2>/dev/null
  sed -i "/^$D/d" /etc/security/limits.conf 2>/dev/null || true
  echo -e "  ${BGREEN}✔ '$D' dihapus!${RESET}"
}

extend_user() {
  list_users
  read -rp "  ${BCYAN}Username perpanjang${RESET}: " E
  [[ -z "$E" ]] && return
  id "$E" &>/dev/null || { echo -e "  ${BRED}✘ '$E' tidak ada!${RESET}"; return; }
  read -rp "  ${BCYAN}Tambah hari${RESET}: " ED
  [[ "$ED" =~ ^[0-9]+$ ]] || { echo "Input tidak valid!"; return; }
  local NE; NE=$(date -d "+${ED} days" '+%Y-%m-%d')
  chage -E "$NE" "$E"
  echo -e "  ${BGREEN}✔ '$E' diperpanjang hingga ${BWHITE}${NE}${RESET}"
}

main_menu() {
  while true; do
    clear; echo ""
    echo -e "  ${BPURPLE}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "  ${BPURPLE}║${RESET}  ${BOLD}${BWHITE}DevCulture — SSH Multi-Port + UDP Manager${RESET}              ${BPURPLE}║${RESET}"
    echo -e "  ${BPURPLE}║${RESET}  ${DIM}TCP: SSH | Dropbear | WS | WSS | Stunnel${RESET}                  ${BPURPLE}║${RESET}"
    echo -e "  ${BPURPLE}║${RESET}  ${DIM}UDP: UDPGW | SlowDNS | OpenVPN${RESET}                            ${BPURPLE}║${RESET}"
    echo -e "  ${BPURPLE}╠══════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "  ${BPURPLE}║${RESET}  ${BGREEN}[1]${RESET}  Buat Akun SSH + Multi-Port + UDP                     ${BPURPLE}║${RESET}"
    echo -e "  ${BPURPLE}║${RESET}  ${BCYAN}[2]${RESET}  Lihat Daftar Akun Aktif                              ${BPURPLE}║${RESET}"
    echo -e "  ${BPURPLE}║${RESET}  ${BYELLOW}[3]${RESET}  Perpanjang Masa Aktif Akun                           ${BPURPLE}║${RESET}"
    echo -e "  ${BPURPLE}║${RESET}  ${BRED}[4]${RESET}  Hapus Akun SSH                                       ${BPURPLE}║${RESET}"
    echo -e "  ${BPURPLE}║${RESET}  ${DIM}[0]  Keluar${RESET}                                                 ${BPURPLE}║${RESET}"
    echo -e "  ${BPURPLE}╚══════════════════════════════════════════════════════════════╝${RESET}"; echo ""
    read -rp "  Pilih [0-4]: " CH
    case "$CH" in
      1) add_user    ;;
      2) list_users  ;;
      3) extend_user ;;
      4) delete_user ;;
      0) echo ""; exit 0 ;;
      *) echo -e "  ${BRED}Pilihan tidak valid!${RESET}" ;;
    esac
    [[ "$CH" != "0" ]] && read -rp "  Tekan Enter..." _
  done
}

case "${1:-menu}" in
  add)    add_user    ;;
  list)   list_users  ;;
  delete) delete_user ;;
  extend) extend_user ;;
  demo)
    read_config
    show_account "devculture" "dc@2024" "$(date -d '+30 days' '+%Y-%m-%d')"
    ;;
  menu|*) main_menu ;;
esac
