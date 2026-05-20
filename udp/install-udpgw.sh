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
  #  UDPGW (BadVPN) Installer
  #  Port default: 7300
  #  Fungsi: SSH UDP tunneling, game bypass, DNS UDP
  # ============================================================
  check_root; detect_os

  UDPGW_PORT=7300
  UDPGW_BIN="/usr/bin/badvpn-udpgw"

  clear
  green "================================================================"
  green "  DevCulture VPS - UDPGW (BadVPN) Installer"
  green "  OS: $OS_ID $OS_VER | Port: $UDPGW_PORT"
  green "================================================================"
  echo ""

  yellow "[1/5] Install build dependencies..."
  safe_apt update
  safe_apt install cmake make gcc g++ git libssl-dev

  yellow "[2/5] Download BadVPN source..."
  rm -rf /tmp/badvpn
  if ! git clone --depth=1 https://github.com/ambrop72/badvpn.git /tmp/badvpn 2>/dev/null; then
    # Fallback: download pre-compiled binary
    yellow "  Git gagal, coba download binary..."
    ARCH=$(uname -m)
    if [[ "$ARCH" == "x86_64" ]]; then
      safe_dl "https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main/bin/badvpn-udpgw-amd64" "$UDPGW_BIN"
    elif [[ "$ARCH" == "aarch64" ]]; then
      safe_dl "https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main/bin/badvpn-udpgw-arm64" "$UDPGW_BIN"
    else
      red "Arsitektur $ARCH tidak didukung binary pre-compiled."
      exit 1
    fi
    chmod +x "$UDPGW_BIN"
    green "  Binary pre-compiled digunakan."
  else
    yellow "[3/5] Compile BadVPN..."
    mkdir -p /tmp/badvpn/build
    cd /tmp/badvpn/build
    cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 >/dev/null 2>&1
    make -j$(nproc) >/dev/null 2>&1
    cp udpgw/badvpn-udpgw "$UDPGW_BIN"
    chmod +x "$UDPGW_BIN"
    cd /root
    rm -rf /tmp/badvpn
    green "  Compile selesai."
  fi

  [[ -x "$UDPGW_BIN" ]] || { red "Binary UDPGW tidak ditemukan!"; exit 1; }

  yellow "[4/5] Buat systemd service..."
  cat > /etc/systemd/system/udpgw.service <<EOF
  [Unit]
  Description=BadVPN UDP Gateway (UDPGW)
  After=network.target

  [Service]
  Type=simple
  User=nobody
  ExecStart=${UDPGW_BIN} --listen-addr 127.0.0.1:${UDPGW_PORT} --max-clients 1000 --max-connections-for-client 100
  Restart=always
  RestartSec=5
  LimitNOFILE=65536

  [Install]
  WantedBy=multi-user.target
  EOF

  systemctl daemon-reload
  systemctl enable udpgw
  systemctl restart udpgw
  sleep 2

  yellow "[5/5] Konfigurasi firewall UDPGW..."
  iptables -I INPUT -p tcp --dport $UDPGW_PORT -j ACCEPT 2>/dev/null || true
  iptables -I INPUT -p udp --dport $UDPGW_PORT -j ACCEPT 2>/dev/null || true

  # Simpan iptables agar persistent
  if command -v iptables-save &>/dev/null; then
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
  fi

  if systemctl is-active --quiet udpgw; then
    green ""
    green "================================================================"
    green "  [OK] UDPGW aktif di 127.0.0.1:$UDPGW_PORT"
    green ""
    green "  Cara pakai di HTTP Custom/HTTP Injector:"
    green "  Payload UDPGW: --udp-gw-remote-server-addr 127.0.0.1:$UDPGW_PORT"
    green ""
    green "  Status : systemctl status udpgw"
    green "  Log    : journalctl -u udpgw -f"
    green "================================================================"
  else
    red "UDPGW gagal start! Cek: journalctl -u udpgw -n 20"
    exit 1
  fi
  