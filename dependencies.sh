#!/bin/bash
  # DevCulture VPS - Dependencies Installer
  # Supports: Ubuntu 16.04/18.04/20.04/22.04/24.04 | Debian 9/10/11/12
  RED='\e[1;31m';GREEN='\e[1;32m';YELLOW='\e[1;33m';NC='\e[0m'
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
  
  
  install_nodejs() {
    local NODE_VER=20
    [[ "$OS_ID" == "ubuntu" && "$OS_MAJOR" -le 16 ]] && NODE_VER=16
    [[ "$OS_ID" == "ubuntu" && "$OS_MAJOR" -eq 18 ]] && NODE_VER=18
    apt-get remove -y nodejs npm >/dev/null 2>&1 || true
    if curl -fsSL "https://deb.nodesource.com/setup_${NODE_VER}.x" | bash - >/dev/null 2>&1; then
      apt-get install -y nodejs >/dev/null 2>&1
    else
      export NVM_DIR="/root/.nvm"
      curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash >/dev/null 2>&1
      source "$NVM_DIR/nvm.sh" 2>/dev/null
      nvm install $NODE_VER >/dev/null 2>&1 && nvm use $NODE_VER >/dev/null 2>&1
      ln -sf "$(nvm which $NODE_VER)" /usr/local/bin/node 2>/dev/null
      ln -sf "$(dirname $(nvm which $NODE_VER))/npm" /usr/local/bin/npm 2>/dev/null
    fi
  }
  
  check_root; detect_os
  export DEBIAN_FRONTEND=noninteractive
  clear
  green "================================================================"
  green "  DevCulture VPS - Installing Dependencies"
  green "  OS: $OS_ID $OS_VER ($OS_CODENAME)"
  green "================================================================"
  sleep 1

  # IPv6 disable
  sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1
  sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1

  # Timezone
  ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
  dpkg-reconfigure -f noninteractive tzdata >/dev/null 2>&1

  yellow "[1/8] Updating packages..."
  apt-get update -y >/dev/null 2>&1
  apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" >/dev/null 2>&1
  apt-get dist-upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" >/dev/null 2>&1

  yellow "[2/8] Removing conflicting packages..."
  apt-get remove --purge -y ufw firewalld exim4 exim4-base exim4-daemon-light >/dev/null 2>&1 || true
  apt-get autoremove -y >/dev/null 2>&1

  yellow "[3/8] Installing core packages..."
  apt-get install -y sudo curl wget git unzip zip screen tmux htop iftop net-tools lsof \
    dnsutils openssl ca-certificates gnupg gnupg2 cron bash-completion \
    build-essential make jq bc sed gawk bzip2 gzip xz-utils rsyslog \
    fail2ban ntpdate chrony neofetch lsb-release >/dev/null 2>&1

  yellow "[4/8] Installing version-specific packages..."
  # apt-transport-https: not needed on Ubuntu 22+ (built-in) but safe to try
  apt-get install -y apt-transport-https software-properties-common >/dev/null 2>&1 || true

  if [[ "$OS_MAJOR" -le 18 && "$OS_ID" == "ubuntu" ]]; then
    apt-get install -y python python-pip python3 python3-pip libssl1.0-dev >/dev/null 2>&1 || \
    apt-get install -y python3 python3-pip libssl-dev >/dev/null 2>&1 || true
  else
    apt-get install -y python3 python3-pip libssl-dev >/dev/null 2>&1 || true
  fi

  # squid: squid3 on 16.04, squid on 18+
  if [[ "$OS_MAJOR" -le 16 && "$OS_ID" == "ubuntu" ]]; then
    apt-get install -y squid3 >/dev/null 2>&1 || apt-get install -y squid >/dev/null 2>&1 || true
  else
    apt-get install -y squid >/dev/null 2>&1 || true
  fi

  yellow "[5/8] Installing network packages..."
  apt-get install -y stunnel4 dropbear openvpn easy-rsa iptables socat >/dev/null 2>&1 || true
  apt-get install -y netcat-openbsd 2>/dev/null || apt-get install -y netcat >/dev/null 2>&1 || true

  # Ensure netstat is available
  command -v netstat &>/dev/null || apt-get install -y net-tools >/dev/null 2>&1 || true

  yellow "[6/8] Installing Node.js..."
  install_nodejs
  green "  Node.js: $(node -v 2>/dev/null || echo 'check manually')"

  yellow "[7/8] Installing vnstat..."
  apt-get install -y vnstat >/dev/null 2>&1 || true
  VNSTAT_MAJOR=$(vnstat --version 2>/dev/null | grep -oP '\d+' | head -1)
  if [[ "${VNSTAT_MAJOR:-0}" -ge 2 ]]; then
    systemctl enable vnstat >/dev/null 2>&1 && systemctl start vnstat >/dev/null 2>&1
  else
    NET=$(ip -o -4 route show to default 2>/dev/null | awk '{print $5}' | head -1)
    [[ -z "$NET" ]] && NET="eth0"
    vnstat -u -i "$NET" >/dev/null 2>&1 || true
    sed -i "s/Interface \"eth0\"/Interface \"$NET\"/g" /etc/vnstat.conf 2>/dev/null
    systemctl enable vnstat >/dev/null 2>&1 && systemctl restart vnstat >/dev/null 2>&1
  fi

  yellow "[8/8] Installing additional libraries..."
  apt-get install -y libnss3-dev libnspr4-dev libpam0g-dev libcap-ng-utils \
    libselinux1-dev flex bison libnss3-tools libevent-dev \
    libsqlite3-dev xl2tpd pptpd >/dev/null 2>&1 || true
  apt-get install -y libcurl4-nss-dev >/dev/null 2>&1 || apt-get install -y libcurl4-openssl-dev >/dev/null 2>&1 || true

  systemctl enable cron >/dev/null 2>&1 && systemctl start cron >/dev/null 2>&1 || true

  green ""
  green "================================================================"
  green "  Dependencies selesai! OS: $OS_ID $OS_VER | Node: $(node -v 2>/dev/null)"
  green "================================================================"
  sleep 2
  