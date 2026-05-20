#!/bin/bash
  # DevCulture VPS | github.com/tuyulbodo99/devculture-vps
  set -euo pipefail
  RED='\e[1;31m';GREEN='\e[1;32m';YELLOW='\e[1;33m';CYAN='\e[1;36m';NC='\e[0m'
  green()  { echo -e "\033[32;1m${*}\033[0m"; }
  red()    { echo -e "\033[31;1m${*}\033[0m"; }
  yellow() { echo -e "\033[33;1m${*}\033[0m"; }
  cyan()   { echo -e "\033[36;1m${*}\033[0m"; }

  LOG_FILE="/var/log/devculture-install.log"
  mkdir -p /var/log; exec > >(tee -a "$LOG_FILE") 2>&1
  echo "=== UDP install run: $(date) ==="

  trap_error() { red "ERROR baris $1 (code $2). Log: $LOG_FILE"; exit $2; }
  trap 'trap_error $LINENO $?' ERR

  detect_os() {
    source /etc/os-release 2>/dev/null || { echo "unknown"; exit 1; }
    OS_ID="${ID}"; OS_VER="${VERSION_ID:-0}"
    OS_MAJOR=$(echo "$OS_VER" | cut -d. -f1 | tr -dc '0-9'); [[ "$OS_MAJOR" =~ ^[0-9]+$ ]] || OS_MAJOR=0
  }
  check_root() { [[ ${EUID} -eq 0 ]] || { red "Harus root!"; exit 1; }; }
  wait_apt() {
    local W=0
    while fuser /var/lib/dpkg/lock /var/lib/apt/lists/lock /var/cache/apt/archives/lock >/dev/null 2>&1; do
      [[ $W -eq 0 ]] && yellow "Menunggu apt lock..."
      sleep 3; W=$((W+3)); [[ $W -ge 120 ]] && { red "apt lock timeout!"; exit 1; }
    done
  }
  safe_apt() { wait_apt; DEBIAN_FRONTEND=noninteractive apt-get "$@" -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -o APT::Get::Assume-Yes=true >/dev/null 2>&1 || true; }
  safe_dl() {
    local URL="$1" OUT="$2" i=0
    while [[ $i -lt 3 ]]; do
      wget -qO "$OUT" "$URL" 2>/dev/null && return 0
      curl -fsSL "$URL" -o "$OUT" 2>/dev/null && return 0
      i=$((i+1)); yellow "Retry download $i/3..."; sleep 3
    done
    red "Gagal download: $URL"; return 1
  }
  
  # ============================================================
  #  DevCulture VPS - UDP Support Master Installer
  #  Pilih: UDPGW | Xray mKCP | OpenVPN UDP | Semua
  # ============================================================
  check_root; detect_os

  BASE="https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main/udp"

  clear
  cyan "================================================================"
  cyan "  DevCulture VPS - UDP Support Installer"
  cyan "  OS: $OS_ID $OS_VER"
  cyan "================================================================"
  echo ""
  green " [1] Install UDPGW (BadVPN) - UDP tunnel untuk SSH"
  green " [2] Install Xray mKCP      - UDP transport VLESS/VMess/Trojan"
  green " [3] Install OpenVPN UDP    - VPN mode UDP port 1194"
  green " [4] Install SEMUA (UDP Lengkap)"
  green " [5] Status semua layanan UDP"
  green " [0] Keluar"
  echo ""
  read -rp "Pilih [0-5]: " CHOICE

  run() {
    local TMP=$(mktemp /tmp/dc-udp-XXXXX.sh)
    safe_dl "$BASE/$1" "$TMP" && chmod +x "$TMP" && bash "$TMP"
    rm -f "$TMP"
  }

  show_status() {
    echo ""
    cyan "=== Status Layanan UDP ==="
    for SVC in udpgw xray "openvpn@server-udp"; do
      local STATUS=$(systemctl is-active "$SVC" 2>/dev/null || echo "tidak aktif")
      if [[ "$STATUS" == "active" ]]; then
        green "  [$SVC] aktif"
      else
        yellow "  [$SVC] $STATUS"
      fi
    done
    echo ""
    cyan "=== Port UDP yang Dibuka ==="
    ss -tulnp 2>/dev/null | grep -E "udp|7300|2052|2053|2054|1194" | awk '{print "  " $1 "\t" $5}' || \
      netstat -tulnp 2>/dev/null | grep -E "udp|7300|2052|2053|2054|1194" | awk '{print "  " $1 "\t" $4}' || \
      echo "  (install net-tools untuk lihat port)"
  }

  case "$CHOICE" in
    1) run install-udpgw.sh ;;
    2) run install-mkcp.sh ;;
    3) run install-openvpn-udp.sh ;;
    4)
      yellow ">>> Install UDPGW..."
      run install-udpgw.sh
      yellow ">>> Install Xray mKCP..."
      run install-mkcp.sh
      yellow ">>> Install OpenVPN UDP..."
      run install-openvpn-udp.sh
      green ""
      green "================================================================"
      green "  [OK] Semua komponen UDP berhasil diinstall!"
      show_status
      green "================================================================"
      ;;
    5) show_status ;;
    0) exit 0 ;;
    *) red "Pilihan tidak valid!"; exit 1 ;;
  esac
  