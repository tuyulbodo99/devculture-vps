#!/bin/bash
# =================================================================
#   DevCulture VPS — Premium Dependencies Installer v2.0
#   github.com/tuyulbodo99/devculture-vps | @devculturebot
# =================================================================
set -euo pipefail
mkdir -p /var/log; exec > >(tee -a /var/log/devculture-install.log) 2>&1

LIB_URL="https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main/lib/utils.sh"
TMP_LIB=$(mktemp /tmp/dc-lib-XXXXX.sh)
wget -qO "$TMP_LIB" "$LIB_URL" 2>/dev/null || curl -fsSL "$LIB_URL" -o "$TMP_LIB" 2>/dev/null
source "$TMP_LIB"; rm -f "$TMP_LIB"

setup_trap; check_root; detect_os

clear
echo -e "${BBLUE}${LINE_TOP}${RESET}"
box_line "${BOLD}${BYELLOW}  ◈  DEVCULTURE VPS — DEPENDENCIES INSTALLER${RESET}"
box_line "  ${DIM}${OS_ID^} ${OS_VER} (${OS_CODENAME})${RESET}"
echo -e "${BBLUE}${LINE_BOT}${RESET}"
echo ""

TOTAL=8; CUR=0
pstep() {
  CUR=$1; progress_bar $CUR $TOTAL "$2"; sleep 0.1
}
pdone() { progress_done; success "$1"; }

export DEBIAN_FRONTEND=noninteractive

# Fix dpkg state
dpkg --configure -a >/dev/null 2>&1 || true
apt-get -f install -y >/dev/null 2>&1 || true

# IPv6 disable
sysctl -w net.ipv6.conf.all.disable_ipv6=1    >/dev/null 2>&1 || true
sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1 || true
grep -q "disable_ipv6" /etc/sysctl.conf || {
  printf "net.ipv6.conf.all.disable_ipv6=1\nnet.ipv6.conf.default.disable_ipv6=1\n" >> /etc/sysctl.conf
}

# Timezone
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
DEBIAN_FRONTEND=noninteractive dpkg-reconfigure tzdata >/dev/null 2>&1 || true

step "Memulai instalasi dependencies..."; echo ""

pstep 1 "Update & upgrade packages..."
safe_apt update
apt-get upgrade -y \
  -o Dpkg::Options::="--force-confdef" \
  -o Dpkg::Options::="--force-confold" >/dev/null 2>&1 || true
pdone "Packages updated"

pstep 2 "Removing conflicting packages..."
safe_apt remove --purge ufw firewalld exim4 exim4-base exim4-daemon-light || true
safe_apt autoremove || true
pdone "Conflicting packages removed"

pstep 3 "Installing core packages..."
safe_apt install sudo curl wget git unzip zip screen tmux htop iftop \
  net-tools lsof dnsutils openssl ca-certificates gnupg gnupg2 cron \
  bash-completion build-essential make jq bc sed gawk bzip2 gzip \
  xz-utils rsyslog fail2ban ntpdate chrony neofetch lsb-release
pdone "Core packages installed"

pstep 4 "Installing version-specific packages..."
safe_apt install software-properties-common || true
safe_apt install apt-transport-https || true
[[ "$OS_MAJOR" -le 18 && "$OS_ID" == "ubuntu" ]] && { safe_apt install python python-pip || true; }
safe_apt install python3 python3-pip || true
if [[ "$OS_MAJOR" -le 16 && "$OS_ID" == "ubuntu" ]]; then
  safe_apt install squid3 || safe_apt install squid || true
else
  safe_apt install squid || true
fi
safe_apt install libssl-dev || true
pdone "Version-specific packages installed"

pstep 5 "Installing network & VPN packages..."
safe_apt install stunnel4 dropbear openvpn easy-rsa iptables socat || true
safe_apt install netcat-openbsd || safe_apt install netcat || true
command -v netstat &>/dev/null || safe_apt install net-tools || true
pdone "Network packages installed"

pstep 6 "Installing Node.js..."
install_nodejs
pdone "Node.js $(node -v 2>/dev/null) installed"

pstep 7 "Installing vnstat bandwidth monitor..."
safe_apt install vnstat || true
if command -v vnstat &>/dev/null; then
  VMAJ=$(vnstat --version 2>/dev/null | grep -oP '\d+' | head -1 || echo 0)
  if [[ "${VMAJ:-0}" -ge 2 ]]; then
    systemctl enable vnstat >/dev/null 2>&1 && systemctl start vnstat >/dev/null 2>&1 || true
  else
    NET=$(ip -o -4 route show to default 2>/dev/null | awk '{print $5}' | head -1 || echo eth0)
    vnstat -u -i "${NET:-eth0}" >/dev/null 2>&1 || true
    systemctl enable vnstat >/dev/null 2>&1 && systemctl restart vnstat >/dev/null 2>&1 || true
  fi
fi
pdone "vnstat installed"

pstep 8 "Installing extra libraries..."
safe_apt install libnss3-dev libnspr4-dev libpam0g-dev libcap-ng-utils \
  libselinux1-dev flex bison libnss3-tools libevent-dev libsqlite3-dev \
  xl2tpd pptpd || true
safe_apt install libcurl4-nss-dev || safe_apt install libcurl4-openssl-dev || true
systemctl enable cron >/dev/null 2>&1 && systemctl start cron >/dev/null 2>&1 || true
pdone "Extra libraries installed"

echo ""
echo -e "${BBLUE}${LINE_TOP}${RESET}"
box_line "${BOLD}${BGREEN}  ✔  DEPENDENCIES BERHASIL DIINSTALL${RESET}"
echo -e "${BBLUE}${LINE_SEP}${RESET}"
box_line "  ${BCYAN}OS     ${RESET}: ${OS_ID^} ${OS_VER} (${OS_CODENAME})"
box_line "  ${BCYAN}Node   ${RESET}: $(node -v 2>/dev/null || echo N/A)"
box_line "  ${BCYAN}Log    ${RESET}: /var/log/devculture-install.log"
echo -e "${BBLUE}${LINE_BOT}${RESET}"
echo ""
sleep 2
