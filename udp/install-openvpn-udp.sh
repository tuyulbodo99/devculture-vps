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
  #  OpenVPN UDP Mode Installer
  #  Port: 1194/UDP (OpenVPN standard)
  #  Dual stack: TCP 1194 + UDP 1194
  # ============================================================
  check_root; detect_os

  OVPN_DIR="/etc/openvpn"
  CLIENT_DIR="/root/devculture-vpn"
  EASYRSA_DIR="/etc/openvpn/easy-rsa"

  clear
  green "================================================================"
  green "  DevCulture VPS - OpenVPN UDP Mode"
  green "================================================================"
  echo ""

  yellow "[1/7] Install OpenVPN & EasyRSA..."
  safe_apt update
  safe_apt install openvpn easy-rsa openssl curl

  # EasyRSA path varies by OS version
  EASYRSA_BIN=$(find /usr/share/easy-rsa /usr/lib/easy-rsa -name "easyrsa" 2>/dev/null | head -1)
  [[ -z "$EASYRSA_BIN" ]] && { red "EasyRSA tidak ditemukan!"; exit 1; }

  yellow "[2/7] Setup EasyRSA PKI..."
  if [[ ! -d "$EASYRSA_DIR" ]]; then
    make-cadir "$EASYRSA_DIR" 2>/dev/null || cp -r "$(dirname $EASYRSA_BIN)" "$EASYRSA_DIR" || true
  fi
  cd "$EASYRSA_DIR" || exit 1

  # Pastikan easyrsa binary ada di dir ini
  [[ -f "./easyrsa" ]] || { cp "$EASYRSA_BIN" ./easyrsa; chmod +x ./easyrsa; }

  if [[ ! -d pki ]]; then
    ./easyrsa --batch init-pki >/dev/null 2>&1
    ./easyrsa --batch build-ca nopass >/dev/null 2>&1
    ./easyrsa --batch gen-req server nopass >/dev/null 2>&1
    ./easyrsa --batch sign-req server server >/dev/null 2>&1
    ./easyrsa --batch gen-dh >/dev/null 2>&1
    openvpn --genkey --secret pki/ta.key 2>/dev/null || openvpn --genkey secret pki/ta.key 2>/dev/null
    green "  PKI berhasil dibuat."
  else
    green "  PKI sudah ada, dilewati."
  fi

  yellow "[3/7] Copy certificates..."
  cp pki/ca.crt          "$OVPN_DIR/"   2>/dev/null || true
  cp pki/issued/server.crt "$OVPN_DIR/" 2>/dev/null || true
  cp pki/private/server.key "$OVPN_DIR/" 2>/dev/null || true
  cp pki/dh.pem          "$OVPN_DIR/dh.pem" 2>/dev/null || true
  cp pki/ta.key          "$OVPN_DIR/"   2>/dev/null || true

  yellow "[4/7] Buat OpenVPN UDP server config..."
  NET_IFACE=$(ip -o -4 route show to default 2>/dev/null | awk '{print $5}' | head -1 || echo eth0)
  SERVER_IP=$(curl -s --max-time 5 https://ipv4.icanhazip.com 2>/dev/null || hostname -I | awk '{print $1}')

  cat > "$OVPN_DIR/server-udp.conf" <<EOF
  # DevCulture VPS - OpenVPN UDP Server
  port 1194
  proto udp
  dev tun
  ca ca.crt
  cert server.crt
  key server.key
  dh dh.pem
  tls-auth ta.key 0
  server 10.8.0.0 255.255.255.0
  ifconfig-pool-persist /var/log/openvpn-udp-ipp.txt
  push "redirect-gateway def1 bypass-dhcp"
  push "dhcp-option DNS 8.8.8.8"
  push "dhcp-option DNS 1.1.1.1"
  keepalive 10 120
  cipher AES-256-GCM
  auth SHA256
  comp-lzo no
  max-clients 200
  persist-key
  persist-tun
  status /var/log/openvpn-udp-status.log
  log-append /var/log/openvpn-udp.log
  verb 3
  mute 20
  explicit-exit-notify 1
  EOF

  yellow "[5/7] Enable IP forwarding..."
  sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1
  grep -q "net.ipv4.ip_forward" /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
  sed -i 's/^#net.ipv4.ip_forward/net.ipv4.ip_forward/' /etc/sysctl.conf

  yellow "[6/7] Setup NAT & firewall..."
  iptables -t nat -I POSTROUTING -s 10.8.0.0/24 -o "$NET_IFACE" -j MASQUERADE 2>/dev/null || true
  iptables -I INPUT -p udp --dport 1194 -j ACCEPT 2>/dev/null || true
  iptables -I FORWARD -s 10.8.0.0/24 -j ACCEPT 2>/dev/null || true
  iptables -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
  mkdir -p /etc/iptables
  iptables-save > /etc/iptables/rules.v4 2>/dev/null || true

  yellow "[7/7] Generate client config (.ovpn)..."
  mkdir -p "$CLIENT_DIR"
  CA_CERT=$(cat "$OVPN_DIR/ca.crt" 2>/dev/null || echo "")
  TA_KEY=$(cat  "$OVPN_DIR/ta.key" 2>/dev/null || echo "")

  cat > "$CLIENT_DIR/devculture-udp.ovpn" <<OVPN
  # DevCulture VPS - OpenVPN UDP Client
  client
  dev tun
  proto udp
  remote ${SERVER_IP} 1194
  resolv-retry infinite
  nobind
  persist-key
  persist-tun
  cipher AES-256-GCM
  auth SHA256
  verb 3
  mute 20
  key-direction 1
  <ca>
  ${CA_CERT}
  </ca>
  <tls-auth>
  ${TA_KEY}
  </tls-auth>
  OVPN

  # Start OpenVPN UDP
  systemctl enable openvpn@server-udp 2>/dev/null || true
  systemctl restart openvpn@server-udp 2>/dev/null || systemctl restart openvpn 2>/dev/null || true
  sleep 3

  STATUS=$(systemctl is-active openvpn@server-udp 2>/dev/null || echo "unknown")
  green ""
  green "================================================================"
  green "  [OK] OpenVPN UDP siap!"
  green ""
  green "  Port    : 1194/UDP"
  green "  Server  : $SERVER_IP"
  green "  Status  : $STATUS"
  green "  Config  : $CLIENT_DIR/devculture-udp.ovpn"
  green ""
  green "  Download .ovpn ke HP/PC lalu import ke aplikasi OpenVPN"
  green "================================================================"
  