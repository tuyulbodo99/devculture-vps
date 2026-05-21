#!/bin/bash
# =================================================================
#   DevCulture VPS — Full Setup Script  v3.2.0
#   github.com/tuyulbodo99/devculture-vps | @devculturebot
# =================================================================
set -euo pipefail
mkdir -p /var/log; exec > >(tee -a /var/log/devculture-install.log) 2>&1

LIB_URL="https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main/lib/utils.sh"
TMP_LIB=$(mktemp /tmp/dc-lib-XXXXX.sh)
wget -qO "$TMP_LIB" "$LIB_URL" 2>/dev/null || curl -fsSL "$LIB_URL" -o "$TMP_LIB" 2>/dev/null
source "$TMP_LIB"; rm -f "$TMP_LIB"

setup_trap; check_root; detect_os

BASE_URL="https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main"

clear
red='\e[1;31m'; green='\e[0;32m'; yell='\e[1;33m'; tyblue='\e[1;36m'; NC='\e[0m'
yellow() { echo -e "\\033[33;1m${*}\\033[0m"; }
tyblue() { echo -e "\\033[36;1m${*}\\033[0m"; }
green()  { echo -e "\\033[32;1m${*}\\033[0m"; }
red()    { echo -e "\\033[31;1m${*}\\033[0m"; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "You need to run this script as root"; exit 1
fi
if [[ "$(systemd-detect-virt 2>/dev/null || echo none)" == "openvz" ]]; then
  echo "OpenVZ is not supported"; exit 1
fi

localip=$(hostname -I | cut -d\  -f1)
hst=$(hostname)
dart=$(grep -w "$(hostname)" /etc/hosts | awk '{print $2}' || true)
if [[ "$hst" != "$dart" ]]; then
  echo "$localip $(hostname)" >> /etc/hosts
fi

mkdir -p /etc/xray

secs_to_human() {
  echo "Installation time : $(( ${1} / 3600 )) hours $(( (${1} / 60) % 60 )) minutes $(( ${1} % 60 )) seconds"
}
start=$(date +%s)

ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
sysctl -w net.ipv6.conf.all.disable_ipv6=1     >/dev/null 2>&1 || true
sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1 || true

cat > /root/.profile << 'PROFILE'
# ~/.profile
if [ "$BASH" ]; then
  if [ -f ~/.bashrc ]; then . ~/.bashrc; fi
fi
mesg n 2>/dev/null || true
clear
PROFILE
chmod 644 /root/.profile

info "Preparing installation..."
apt-get install -y git curl wget >/dev/null 2>&1

mkdir -p /etc/devculturevpnn
mkdir -p /etc/devculturevpn/theme
mkdir -p /var/lib/devculturevpn-pro

if [[ -f "/etc/xray/domain" ]]; then
  echo ""
  warn "Script sudah pernah diinstall sebelumnya."
  echo -ne "  Lanjutkan install ulang? (y/n)? "
  read -r answer
  if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
    rm -f /root/setup.sh 2>/dev/null; exit 0
  fi
  clear
fi

echo ""
yellow "Masukkan domain untuk vmess/vless/trojan"
echo ""
read -rp "  Input domain: " -e pp
if [[ -z "$pp" ]]; then
  red "Domain tidak boleh kosong!"; exit 1
fi
echo "$pp" > /root/domain
echo "$pp" > /root/scdomain
echo "$pp" > /etc/xray/domain
echo "$pp" > /etc/xray/scdomain
echo "IP=$pp" > /var/lib/devculturevpn-pro/ipvps.conf

# Setup tema
for theme in red blue green yellow magenta cyan; do
  mkdir -p /etc/devculturevpn/theme
done
cat > /etc/devculturevpn/theme/color.conf << 'EOF'
blue
EOF

# Install dependencies
info "Install SSH & OpenVPN..."
TMP=$(mktemp /tmp/dc-XXXXX.sh)
safe_dl "${BASE_URL}/ssh/ssh-vpn.sh" "$TMP" && chmod +x "$TMP" && bash "$TMP"
rm -f "$TMP"

# Install Xray
info "Install Xray..."
TMP=$(mktemp /tmp/dc-XXXXX.sh)
safe_dl "${BASE_URL}/xray/ins-xray.sh" "$TMP" && chmod +x "$TMP" && bash "$TMP"
rm -f "$TMP"
clear

# Install WebSocket
info "Install WebSocket..."
TMP=$(mktemp /tmp/dc-XXXXX.sh)
safe_dl "${BASE_URL}/websocket/insshws.sh" "$TMP" && chmod +x "$TMP" && bash "$TMP"
rm -f "$TMP"
clear

# Download & run update menu
info "Download Extra Menu..."
TMP=$(mktemp /tmp/dc-XXXXX.sh)
safe_dl "${BASE_URL}/update/update-devculture.sh" "$TMP" && chmod +x "$TMP" && bash "$TMP"
rm -f "$TMP"
clear

cat > /root/.profile << 'PROFILE'
# ~/.profile
if [ "$BASH" ]; then
  if [ -f ~/.bashrc ]; then . ~/.bashrc; fi
fi
mesg n 2>/dev/null || true
clear
menu
PROFILE
chmod 644 /root/.profile

rm -f /root/log-install.txt 2>/dev/null
[[ ! -f "/etc/log-create-user.log" ]] && echo "Log All Account" > /etc/log-create-user.log

# Ambil waktu reboot
aureb=7
gg="AM"
curl -sS ifconfig.me > /etc/myipvps 2>/dev/null || hostname -I | awk '{print $1}' > /etc/myipvps

echo ""
echo "====================-[DevCulture]-===================="
echo ""
echo "   >>> Service & Port"
echo "   - OpenSSH                 : 22, 200, 500, 40000, 51443, 58080"
echo "   - SSH SSL Websocket       : 443"
echo "   - Stunnel4                : 447, 777"
echo "   - Dropbear                : 109, 143"
echo "   - Badvpn                  : 7100-7900"
echo "   - Nginx                   : 81"
echo "   - XRAY Vmess TLS          : 443"
echo "   - XRAY Vmess None TLS     : 80"
echo "   - XRAY Vless TLS          : 443"
echo "   - XRAY Vless None TLS     : 80"
echo "   - Trojan GRPC             : 443"
echo "   - Trojan WS               : 443"
echo ""
echo "   >>> Server Information"
echo "   - Timezone                : Asia/Jakarta (GMT +7)"
echo "   - Fail2Ban                : [ON]"
echo "   - IPtables                : [ON]"
echo "   - Auto-Reboot             : [ON] jam ${aureb}:00 ${gg} GMT+7"
echo "   - IPv6                    : [OFF]"
echo ""
echo "   >>> About"
echo "   - Script By               : DevCulture VPN STORE"
echo "   - Contact                 : wa.me/087726917005"
echo "=============-[DevCulture]-==============="
echo ""
rm -f /root/setup.sh 2>/dev/null
secs_to_human "$(($(date +%s) - ${start}))"
echo ""
echo -ne "  Reboot sekarang? (y/n)? "
read -r answer
if [[ "$answer" == "y" || "$answer" == "Y" ]]; then reboot; fi
