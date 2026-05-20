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
  #  Xray mKCP (UDP transport) Configurator
  #  Ports: VLESS mKCP: 2052 | VMess mKCP: 2053 | Trojan mKCP: 2054
  #  Seed: DevCulture
  # ============================================================
  check_root; detect_os

  XRAY_CONFIG="/etc/xray/config.json"
  DOMAIN_FILE="/etc/xray/domain"
  TMP_CONF="/tmp/xray-mkcp.json"

  clear
  green "================================================================"
  green "  DevCulture VPS - Xray mKCP (UDP) Configurator"
  green "================================================================"
  echo ""

  [[ -f "$XRAY_CONFIG" ]] || { red "Xray belum terinstall! Install Xray dulu."; exit 1; }
  [[ -f "$DOMAIN_FILE" ]] || { red "Domain belum dikonfigurasi!"; exit 1; }
  DOMAIN=$(cat "$DOMAIN_FILE")

  # Backup existing config
  cp "$XRAY_CONFIG" "$XRAY_CONFIG.bak.$(date +%Y%m%d%H%M%S)"
  yellow "Backup config disimpan."

  yellow "[1/3] Generate mKCP inbounds..."

  # Baca config existing, tambah mKCP inbounds
  python3 - <<'PYEOF'
  import json, sys

  with open("/etc/xray/config.json") as f:
      cfg = json.load(f)

  # Pastikan ada inbounds
  cfg.setdefault("inbounds", [])

  # Hapus existing mKCP entries (update-safe)
  cfg["inbounds"] = [x for x in cfg["inbounds"]
                     if not (x.get("streamSettings",{}).get("network") == "mkcp")]

  mkcp_base = {
      "network": "mkcp",
      "kcpSettings": {
          "mtu": 1350,
          "tti": 50,
          "uplinkCapacity": 100,
          "downlinkCapacity": 100,
          "congestion": False,
          "readBufferSize": 2,
          "writeBufferSize": 2,
          "seed": "DevCulture",
          "header": {"type": "none"}
      }
  }

  new_inbounds = [
      # VLESS mKCP
      {
          "listen": "0.0.0.0", "port": 2052, "protocol": "vless",
          "settings": {
              "clients": [],
              "decryption": "none"
          },
          "streamSettings": {**mkcp_base, "security": "none"},
          "tag": "vless-mkcp",
          "sniffing": {"enabled": True, "destOverride": ["http","tls"]}
      },
      # VMess mKCP
      {
          "listen": "0.0.0.0", "port": 2053, "protocol": "vmess",
          "settings": {"clients": []},
          "streamSettings": {**mkcp_base, "security": "none"},
          "tag": "vmess-mkcp",
          "sniffing": {"enabled": True, "destOverride": ["http","tls"]}
      },
      # Trojan mKCP
      {
          "listen": "0.0.0.0", "port": 2054, "protocol": "trojan",
          "settings": {"clients": []},
          "streamSettings": {**mkcp_base, "security": "none"},
          "tag": "trojan-mkcp",
          "sniffing": {"enabled": True, "destOverride": ["http","tls"]}
      }
  ]

  cfg["inbounds"].extend(new_inbounds)

  # Pastikan routing ada
  cfg.setdefault("routing", {"rules": []})

  with open("/etc/xray/config.json", "w") as f:
      json.dump(cfg, f, indent=2)

  print("mKCP inbounds berhasil ditambahkan.")
  PYEOF

  yellow "[2/3] Buka port mKCP di firewall..."
  for PORT in 2052 2053 2054; do
    iptables -I INPUT -p udp --dport "$PORT" -j ACCEPT 2>/dev/null || true
    iptables -I INPUT -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null || true
  done

  yellow "[3/3] Restart Xray..."
  systemctl restart xray 2>/dev/null || xray run -c "$XRAY_CONFIG" &
  sleep 2

  if systemctl is-active --quiet xray 2>/dev/null || pgrep xray >/dev/null 2>&1; then
    green ""
    green "================================================================"
    green "  [OK] Xray mKCP aktif!"
    green ""
    green "  Protocol  | Port | Transport"
    green "  ----------+------+----------"
    green "  VLESS     | 2052 | mKCP/UDP"
    green "  VMess     | 2053 | mKCP/UDP"
    green "  Trojan    | 2054 | mKCP/UDP"
    green ""
    green "  Seed: DevCulture"
    green "  Domain: $DOMAIN"
    green "================================================================"
  else
    red "Xray gagal start setelah konfigurasi mKCP!"
    red "Restore backup: cp $XRAY_CONFIG.bak.* $XRAY_CONFIG && systemctl restart xray"
    exit 1
  fi
  