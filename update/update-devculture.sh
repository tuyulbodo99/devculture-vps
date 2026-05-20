#!/bin/bash
  # DevCulture VPS - Update Script
  BASE_URL="https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main"

  clear
  echo -e "\033[36;1mDevCulture VPS - Update\033[0m"
  echo ""
  echo "Downloading latest scripts..."

  # Update menu scripts
  for script in menu.sh menu-ssh.sh menu-bot.sh menu-backup.sh menu-dns.sh menu-ip.sh menu-set.sh menu-speedtest.sh menu-vmess.sh menu-vless.sh menu-trojan.sh menu-ss.sh menu-tcp.sh menu-tor.sh menu-theme.sh menu-bandwith.sh; do
    wget -qO "/usr/local/sbin/${script%.sh}" "$BASE_URL/update/$script" 2>/dev/null
    chmod +x "/usr/local/sbin/${script%.sh}" 2>/dev/null
  done

  # Update autoboot
  wget -qO "/usr/local/sbin/autoboot" "$BASE_URL/update/autoboot.sh" 2>/dev/null
  chmod +x /usr/local/sbin/autoboot 2>/dev/null

  echo -e "\033[32;1mUpdate selesai!\033[0m"
  