#!/bin/bash
# =================================================================
#   DevCulture VPS — Update Script  v3.2.0
#   Download semua menu script dari devculture-vps
#   github.com/tuyulbodo99/devculture-vps | @devculturebot
# =================================================================
BASE_URL="https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main"

green()  { echo -e "\033[32;1m${*}\033[0m"; }
yellow() { echo -e "\033[33;1m${*}\033[0m"; }
red()    { echo -e "\033[31;1m${*}\033[0m"; }

safe_dl() {
  local URL="$1" OUT="$2"
  wget -qO "$OUT" "$URL" 2>/dev/null && return 0
  curl -fsSL "$URL" -o "$OUT" 2>/dev/null && return 0
  return 1
}

clear
echo -e "\033[36;1mDevCulture VPS - Update Scripts\033[0m"
echo ""
yellow "[*] Downloading latest scripts..."

mkdir -p /usr/local/sbin /usr/bin

# Download menu scripts ke /usr/local/sbin
declare -A MENUS=(
  ["menu"]="update/menu.sh"
  ["menu-ssh"]="update/menu-ssh.sh"
  ["menu-bot"]="update/menu-bot.sh"
  ["menu-backup"]="update/menu-backup.sh"
  ["menu-dns"]="update/menu-dns.sh"
  ["menu-ip"]="update/menu-ip.sh"
  ["menu-set"]="update/menu-set.sh"
  ["menu-speedtest"]="update/menu-speedtest.sh"
  ["menu-vmess"]="update/menu-vmess.sh"
  ["menu-vless"]="update/menu-vless.sh"
  ["menu-trojan"]="update/menu-trojan.sh"
  ["menu-ss"]="update/menu-ss.sh"
  ["menu-tcp"]="update/menu-tcp.sh"
  ["menu-tor"]="update/menu-tor.sh"
  ["menu-theme"]="update/menu-theme.sh"
  ["menu-bandwith"]="update/menu-bandwith.sh"
  ["autoboot"]="update/autoboot.sh"
  ["info"]="update/info.sh"
  ["mspeed"]="update/menu-speedtest.sh"
  ["mbandwith"]="update/menu-bandwith.sh"
  ["rebootvps"]="corn/rebootvps.sh"
)

for CMD in "${!MENUS[@]}"; do
  SRC="${BASE_URL}/${MENUS[$CMD]}"
  DST="/usr/local/sbin/${CMD}"
  if safe_dl "$SRC" "$DST"; then
    chmod +x "$DST"
    green "  ✔ $CMD"
  else
    yellow "  ⚠ $CMD (skip — tidak ditemukan)"
  fi
done

# Download devculture command panel
if safe_dl "${BASE_URL}/devculture" "/usr/local/bin/devculture"; then
  chmod +x /usr/local/bin/devculture
  green "  ✔ devculture panel"
else
  yellow "  ⚠ devculture panel (skip)"
fi

# Download bbr helper
if safe_dl "${BASE_URL}/ssh/bbr.sh" "/usr/bin/bbr"; then
  chmod +x /usr/bin/bbr
  green "  ✔ bbr"
fi

# Download speedtest
if safe_dl "${BASE_URL}/ssh/speedtest_cli.py" "/usr/bin/speedtest"; then
  chmod +x /usr/bin/speedtest
  green "  ✔ speedtest"
fi

echo ""
green "Update selesai!"
