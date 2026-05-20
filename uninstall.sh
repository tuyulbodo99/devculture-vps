#!/bin/bash
# =================================================================
#   DevCulture VPS — Premium Uninstaller v2.0
#   github.com/tuyulbodo99/devculture-vps | @devculturebot
# =================================================================
set -euo pipefail
mkdir -p /var/log; exec > >(tee -a /var/log/devculture-install.log) 2>&1

LIB_URL="https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main/lib/utils.sh"
TMP_LIB=$(mktemp /tmp/dc-lib-XXXXX.sh)
wget -qO "$TMP_LIB" "$LIB_URL" 2>/dev/null || curl -fsSL "$LIB_URL" -o "$TMP_LIB" 2>/dev/null
source "$TMP_LIB"; rm -f "$TMP_LIB"

check_root

clear
echo -e "${BRED}${LINE_TOP}${RESET}"
box_line "${BOLD}${BRED}  ⚠  DEVCULTURE VPS — UNINSTALLER v${VERSION}${RESET}"
echo -e "${BRED}${LINE_SEP}${RESET}"
box_line "  Semua komponen DevCulture VPS akan dihapus permanen."
box_line "  Layanan sistem (nginx, sshd, dll) tidak akan terpengaruh."
box_line ""
box_line "  ${BYELLOW}Data yang akan dihapus:${RESET}"
box_line "  ${DIM}Bot, Xray, UDPGW, OpenVPN, SSL cron, SSH users${RESET}"
echo -e "${BRED}${LINE_BOT}${RESET}"
echo ""
printf "  ${BYELLOW}Ketik ${BRED}HAPUS${BYELLOW} untuk konfirmasi${RESET} › "
read -r CONFIRM
[[ "$CONFIRM" != "HAPUS" ]] && { warn "Dibatalkan oleh user."; exit 0; }
echo ""

TOTAL=10; step "Memulai proses uninstall..."; echo ""

pstep() { progress_bar $1 $TOTAL "$2"; sleep 0.2; }
pdone()  { progress_done; success "$1"; }

pstep 1 "Menghentikan DevCulture Bot..."
systemctl stop devculture-bot 2>/dev/null || true
systemctl disable devculture-bot 2>/dev/null || true
rm -f /etc/systemd/system/devculture-bot.service
systemctl daemon-reload 2>/dev/null || true
pdone "Bot service dihapus"

pstep 2 "Menghapus file bot & konfigurasi..."
rm -f /usr/local/bin/devculture-bot.js /usr/local/bin/ssl-renew.sh
rm -rf /etc/devculture
pdone "File bot & config dihapus"

pstep 3 "Menghapus cron SSL renewal..."
(crontab -l 2>/dev/null | grep -v ssl-renew) | crontab - 2>/dev/null || true
rm -f /var/log/ssl-renew.log
pdone "SSL cron dihapus"

pstep 4 "Menghentikan & menghapus Xray..."
systemctl stop xray 2>/dev/null || true
systemctl disable xray 2>/dev/null || true
rm -f /etc/systemd/system/xray.service
rm -rf /etc/xray /usr/local/bin/xray 2>/dev/null || true
systemctl daemon-reload 2>/dev/null || true
pdone "Xray dihapus"

pstep 5 "Menghentikan SSH extra services..."
for S in dropbear stunnel4; do
  systemctl stop "$S" 2>/dev/null || true
  systemctl disable "$S" 2>/dev/null || true
done
pdone "Dropbear & Stunnel dihentikan"

pstep 6 "Menghapus konfigurasi Nginx DevCulture..."
rm -f /etc/nginx/sites-enabled/devculture /etc/nginx/sites-available/devculture 2>/dev/null || true
systemctl reload nginx 2>/dev/null || true
pdone "Nginx config dihapus"

pstep 7 "Menghapus CLI menu scripts..."
for s in menu menu-ssh menu-bot menu-backup menu-dns menu-ip menu-set \
         menu-speedtest menu-vmess menu-vless menu-trojan menu-ss \
         menu-tcp menu-tor menu-theme menu-bandwith autoboot info; do
  rm -f "/usr/local/sbin/$s" 2>/dev/null || true
done
pdone "Menu scripts dihapus"

pstep 8 "Menghapus user SSH yang dibuat bot..."
for JSON in /etc/devculture/users.json /etc/devculture/trials.json; do
  [[ -f "$JSON" ]] || continue
  while IFS= read -r U; do
    userdel -r "$U" 2>/dev/null || true
  done < <(grep -oP '"(ssh_user|user)":\s*"\K[^"]+' "$JSON" 2>/dev/null || true)
done
pdone "User SSH dihapus"

pstep 9 "Menghapus UDP services..."
systemctl stop udpgw 2>/dev/null || true
systemctl disable udpgw 2>/dev/null || true
rm -f /etc/systemd/system/udpgw.service /usr/bin/badvpn-udpgw 2>/dev/null || true
systemctl stop "openvpn@server-udp" 2>/dev/null || true
rm -f /etc/openvpn/server-udp.conf 2>/dev/null || true
rm -rf /root/devculture-vpn 2>/dev/null || true
systemctl daemon-reload 2>/dev/null || true
pdone "UDP services dihapus"

pstep 10 "Membersihkan log..."
rm -f /var/log/devculture-install.log
pdone "Log dibersihkan"

echo ""
echo -e "${BBLUE}${LINE_TOP}${RESET}"
box_line "${BOLD}${BGREEN}  ✔  UNINSTALL SELESAI${RESET}"
echo -e "${BBLUE}${LINE_SEP}${RESET}"
box_line "  DevCulture VPS telah berhasil dihapus dari sistem."
box_line ""
box_line "  ${DIM}Untuk install ulang:${RESET}"
box_line "  ${BCYAN}bash <(curl -sSL${RESET}"
box_line "  ${BCYAN}    https://github.com/tuyulbodo99/devculture-vps/raw/main/install.sh)${RESET}"
echo -e "${BBLUE}${LINE_BOT}${RESET}"
echo ""
