#!/bin/bash
# =================================================================
#   DevCulture VPS — Premium All-in-One Installer v2.0
#   github.com/tuyulbodo99/devculture-vps | @devculturebot
# =================================================================
set -euo pipefail
mkdir -p /var/log
exec > >(tee -a /var/log/devculture-install.log) 2>&1

LIB_URL="https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main/lib/utils.sh"
TMP_LIB=$(mktemp /tmp/dc-lib-XXXXX.sh)
if wget -qO "$TMP_LIB" "$LIB_URL" 2>/dev/null \
   || curl -fsSL "$LIB_URL" -o "$TMP_LIB" 2>/dev/null; then
  source "$TMP_LIB"; rm -f "$TMP_LIB"
else
  echo "ERROR: Gagal download library. Cek koneksi internet."
  rm -f "$TMP_LIB"; exit 1
fi

setup_trap; check_root; detect_os; check_virt; get_sysinfo

show_banner() {
  clear
  echo -e "${BBLUE}"
  cat << 'LOGO'
  ██████╗ ███████╗██╗   ██╗ ██████╗██╗   ██╗██╗  ████████╗██╗   ██╗██████╗ ███████╗
  ██╔══██╗██╔════╝██║   ██║██╔════╝██║   ██║██║  ╚══██╔══╝██║   ██║██╔══██╗██╔════╝
  ██║  ██║█████╗  ██║   ██║██║     ██║   ██║██║     ██║   ██║   ██║██████╔╝█████╗
  ██║  ██║██╔══╝  ╚██╗ ██╔╝██║     ██║   ██║██║     ██║   ██║   ██║██╔══██╗██╔══╝
  ██████╔╝███████╗ ╚████╔╝ ╚██████╗╚██████╔╝███████╗██║   ╚██████╔╝██║  ██║███████╗
  ╚═════╝ ╚══════╝  ╚═══╝   ╚═════╝ ╚═════╝ ╚══════╝╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝
LOGO
  echo -e "${RESET}"
  echo -e "  ${BCYAN}${BOLD}              Premium VPS Management Suite  v${VERSION}${RESET}"
  echo -e "  ${DIM}              github.com/tuyulbodo99/devculture-vps${RESET}"
  echo ""
}

show_sysinfo() {
  echo -e "${BBLUE}${LINE_TOP}${RESET}"
  box_line "${BOLD}${BYELLOW}  ◈  SYSTEM INFORMATION${RESET}"
  echo -e "${BBLUE}${LINE_SEP}${RESET}"
  box_line "  ${BCYAN}IP Address ${RESET}: ${BWHITE}${SYS_IP}${RESET}"
  box_line "  ${BCYAN}OS         ${RESET}: ${BWHITE}${OS_ID^} ${OS_VER} (${OS_CODENAME})${RESET}"
  box_line "  ${BCYAN}Kernel     ${RESET}: ${BWHITE}${SYS_KERNEL}${RESET}"
  box_line "  ${BCYAN}CPU Cores  ${RESET}: ${BWHITE}${SYS_CPU} core(s)  |  Load: ${SYS_LOAD}${RESET}"
  box_line "  ${BCYAN}RAM        ${RESET}: ${BWHITE}${SYS_RAM}${RESET}"
  box_line "  ${BCYAN}Disk       ${RESET}: ${BWHITE}${SYS_DISK}${RESET}"
  box_line "  ${BCYAN}Uptime     ${RESET}: ${BWHITE}${SYS_UPTIME}${RESET}"
  box_line "  ${BCYAN}Node.js    ${RESET}: ${BWHITE}${NODE_VER}${RESET}"
  echo -e "${BBLUE}${LINE_BOT}${RESET}"
  echo ""
}

show_menu() {
  echo -e "${BBLUE}${LINE_TOP}${RESET}"
  box_line "${BOLD}${BYELLOW}  ◈  DEVCULTURE VPS — MAIN MENU${RESET}"
  echo -e "${BBLUE}${LINE_SEP}${RESET}"
  box_line "  ${BGREEN}[1]${RESET}  Install Full VPS  ${DIM}(SSH + Xray + WS + VPN + Bot)${RESET}"
  box_line "  ${BGREEN}[2]${RESET}  Install Dependencies Only"
  box_line "  ${BGREEN}[3]${RESET}  Install SSH & WebSocket"
  box_line "  ${BGREEN}[4]${RESET}  Install Xray  ${DIM}(VLESS / VMess / Trojan)${RESET}"
  box_line "  ${BGREEN}[5]${RESET}  Install Telegram Bot Manager"
  box_line "  ${BGREEN}[6]${RESET}  Setup SSL Auto-Renewal"
  box_line "  ${BGREEN}[7]${RESET}  Install UDP Support  ${DIM}(UDPGW + mKCP + OpenVPN)${RESET}"
  echo -e "${BBLUE}${LINE_SEP}${RESET}"
  box_line "  ${BYELLOW}[8]${RESET}  Update All Scripts"
  box_line "  ${BYELLOW}[9]${RESET}  Manage SSH Users"
  box_line "  ${BYELLOW}[s]${RESET}  System & Service Status"
  echo -e "${BBLUE}${LINE_SEP}${RESET}"
  box_line "  ${BRED}[u]${RESET}  Uninstall DevCulture VPS"
  box_line "  ${DIM}[0]  Exit${RESET}"
  echo -e "${BBLUE}${LINE_BOT}${RESET}"
  echo ""
  printf "  ${BWHITE}Choice${RESET} ${DIM}›${RESET} "
}

show_status() {
  show_banner
  echo -e "${BBLUE}${LINE_TOP}${RESET}"
  box_line "${BOLD}${BYELLOW}  ◈  SERVICE STATUS${RESET}"
  echo -e "${BBLUE}${LINE_SEP}${RESET}"
  local SVCS=("xray" "devculture-bot" "nginx" "dropbear" "stunnel4"
               "openvpn@server-udp" "udpgw" "fail2ban" "vnstat")
  for S in "${SVCS[@]}"; do
    local ST; ST=$(systemctl is-active "$S" 2>/dev/null || echo "inactive")
    if [[ "$ST" == "active" ]]; then
      box_line "  ${BGREEN}●${RESET}  ${BWHITE}%-24s${RESET}  ${BGREEN}[RUNNING]${RESET}" "$S"
    else
      box_line "  ${BRED}○${RESET}  ${DIM}%-24s  [${ST}]${RESET}" "$S"
    fi
  done
  echo -e "${BBLUE}${LINE_SEP}${RESET}"
  box_line "${BOLD}${BYELLOW}  ◈  OPEN UDP PORTS${RESET}"
  echo -e "${BBLUE}${LINE_SEP}${RESET}"
  local PORTS
  PORTS=$(ss -tulnp 2>/dev/null | awk '/udp/{print "  " $5}' | head -8 \
       || netstat -tulnp 2>/dev/null | awk '/udp/{print "  " $4}' | head -8 \
       || echo "  (install net-tools untuk lihat port)")
  while IFS= read -r line; do box_line "$line"; done <<< "$PORTS"
  echo -e "${BBLUE}${LINE_BOT}${RESET}"
  echo ""
  read -rp "  Tekan Enter untuk kembali..." _
}

run_script() {
  local SCRIPT="$1"
  local TMP; TMP=$(mktemp /tmp/dc-XXXXX.sh)
  info "Mengunduh ${SCRIPT}..."
  safe_dl "${BASE_URL}/${SCRIPT}" "$TMP" || { error "Gagal download ${SCRIPT}"; rm -f "$TMP"; return 1; }
  chmod +x "$TMP"
  bash "$TMP" "$OS_ID" "$OS_VER" || { error "Script gagal: ${SCRIPT}"; rm -f "$TMP"; return 1; }
  rm -f "$TMP"
}

preflight() {
  echo ""; step "Pre-flight checks..."; echo ""
  check_internet; check_disk 300; check_ram 256
  echo ""
}

# ── Main loop ────────────────────────────────────────────────────
while true; do
  show_banner
  show_sysinfo
  show_menu
  read -r CHOICE

  case "$CHOICE" in
    1)
      preflight
      run_script "dependencies.sh"
      run_script "setup.sh"
      run_script "bot/install-bot.sh"
      run_script "udp/install-udp.sh"
      safe_dl "${BASE_URL}/ssl/ssl-renew.sh" /usr/local/bin/ssl-renew.sh
      chmod +x /usr/local/bin/ssl-renew.sh
      bash /usr/local/bin/ssl-renew.sh install
      echo ""; success "Instalasi penuh selesai!"
      ;;
    2) preflight; run_script "dependencies.sh" ;;
    3) preflight; run_script "ssh/ssh-vpn.sh" ;;
    4) preflight; run_script "xray/ins-xray.sh" ;;
    5) preflight; run_script "bot/install-bot.sh" ;;
    6)
      safe_dl "${BASE_URL}/ssl/ssl-renew.sh" /usr/local/bin/ssl-renew.sh
      chmod +x /usr/local/bin/ssl-renew.sh
      bash /usr/local/bin/ssl-renew.sh install
      ;;
    7) preflight; run_script "udp/install-udp.sh" ;;
    8) run_script "update/update.sh" ;;
    9) run_script "ssh/manage-users.sh" ;;
    s|S) show_status; continue ;;
    u|U)
      printf "  ${BRED}Ketik HAPUS untuk konfirmasi:${RESET} "; read -r CONF
      [[ "$CONF" == "HAPUS" ]] && run_script "uninstall.sh" || warn "Dibatalkan."
      ;;
    0)
      echo ""; info "Terima kasih telah menggunakan DevCulture VPS!"; echo ""; exit 0 ;;
    *)
      warn "Pilihan tidak valid.";;
  esac

  echo ""
  read -rp "  Tekan Enter untuk kembali ke menu..." _
done
