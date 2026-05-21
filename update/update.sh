#!/bin/bash
# =================================================================
#   DevCulture VPS — Update All Scripts  v3.2.0
#   github.com/tuyulbodo99/devculture-vps | @devculturebot
# =================================================================
BASE_URL="https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main"

green()  { echo -e "\033[32;1m${*}\033[0m"; }
yellow() { echo -e "\033[33;1m${*}\033[0m"; }

safe_dl() {
  local URL="$1" OUT="$2"
  wget -qO "$OUT" "$URL" 2>/dev/null && return 0
  curl -fsSL "$URL" -o "$OUT" 2>/dev/null && return 0
  return 1
}

echo -e " [INFO] Downloading Update Files..."
sleep 1

for SCRIPT in menu.sh menu-ssh.sh menu-bot.sh menu-backup.sh menu-dns.sh menu-ip.sh \
              menu-set.sh menu-speedtest.sh menu-vmess.sh menu-vless.sh menu-trojan.sh \
              menu-ss.sh menu-tcp.sh menu-tor.sh menu-theme.sh menu-bandwith.sh \
              autoboot.sh info.sh; do
  NAME="${SCRIPT%.sh}"
  if safe_dl "${BASE_URL}/update/${SCRIPT}" "/usr/bin/${NAME}"; then
    chmod +x "/usr/bin/${NAME}"
  fi
done

safe_dl "${BASE_URL}/update/menu.sh"       "/usr/local/sbin/menu" && chmod +x /usr/local/sbin/menu   || true
safe_dl "${BASE_URL}/corn/rebootvps.sh"    "/usr/bin/rebootvps"   && chmod +x /usr/bin/rebootvps     || true
safe_dl "${BASE_URL}/update/info.sh"       "/usr/bin/info"        && chmod +x /usr/bin/info           || true
safe_dl "${BASE_URL}/update/menu-speedtest.sh" "/usr/bin/mspeed"  && chmod +x /usr/bin/mspeed         || true
safe_dl "${BASE_URL}/update/menu-bandwith.sh"  "/usr/bin/mbandwith" && chmod +x /usr/bin/mbandwith   || true

echo -e " [INFO] Update Successfully"
sleep 1
