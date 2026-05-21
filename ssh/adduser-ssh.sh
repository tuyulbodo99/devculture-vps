#!/bin/bash
# =================================================================
#   DevCulture VPS — SSH User Manager v1.0.0
#   Buat & kelola akun SSH + WebSocket lengkap
#   github.com/tuyulbodo99 | @devculturebot
# =================================================================

RESET="\033[0m"; BOLD="\033[1m"; DIM="\033[2m"
BCYAN="\033[1;36m"; BGREEN="\033[1;32m"; BYELLOW="\033[1;33m"
BRED="\033[1;31m"; BPURPLE="\033[1;35m"; BWHITE="\033[1;37m"
BGRAY="\033[1;90m"

# ── Baca konfigurasi dari log-install.txt ─────────────────────────
read_config() {
  LOG="/root/log-install.txt"
  DOMAIN=$(grep -w "Domain" "$LOG" 2>/dev/null | cut -d: -f2 | xargs || echo "")
  PORT_SSH=$(grep -w "OpenSSH" "$LOG" 2>/dev/null | grep -oP '\d+' | head -1 || echo "22")
  PORT_DROPBEAR=$(grep -w "Dropbear" "$LOG" 2>/dev/null | cut -d: -f2 | sed 's/ //g' | cut -f1 -d"," || echo "109")
  PORT_DROPBEAR2=$(grep -w "Dropbear" "$LOG" 2>/dev/null | cut -d: -f2 | sed 's/ //g' | cut -f2 -d"," || echo "143")
  PORT_SSHWS=$(grep -w "SSH Websocket" "$LOG" 2>/dev/null | cut -d: -f2 | awk '{print $1}' || echo "80")
  PORT_SSHWSSL=$(grep -w "SSH SSL Websocket" "$LOG" 2>/dev/null | cut -d: -f2 | awk '{print $1}' || echo "443")
  PORT_STUNNEL=$(grep -w "Stunnel" "$LOG" 2>/dev/null | grep -oP '\d+' | head -1 || echo "777")
  MYIP=$(curl -sS --max-time 5 ipv4.icanhazip.com 2>/dev/null \
      || curl -sS --max-time 5 ifconfig.me 2>/dev/null \
      || hostname -I | awk '{print $1}')
  # Gunakan IP jika tidak ada domain
  HOST="${DOMAIN:-$MYIP}"
}

# ── Validasi input ────────────────────────────────────────────────
validate_user() {
  local user="$1"
  if [[ -z "$user" ]]; then echo "Username tidak boleh kosong!"; return 1; fi
  if [[ ${#user} -lt 3 ]]; then echo "Username minimal 3 karakter!"; return 1; fi
  if ! [[ "$user" =~ ^[a-zA-Z0-9_-]+$ ]]; then echo "Username hanya boleh huruf, angka, _, -"; return 1; fi
  if id "$user" &>/dev/null; then echo "Username '$user' sudah ada!"; return 1; fi
  return 0
}

validate_pass() {
  local pass="$1"
  if [[ -z "$pass" ]]; then echo "Password tidak boleh kosong!"; return 1; fi
  if [[ ${#pass} -lt 4 ]]; then echo "Password minimal 4 karakter!"; return 1; fi
  return 0
}

validate_exp() {
  local days="$1"
  if ! [[ "$days" =~ ^[0-9]+$ ]] || [[ "$days" -lt 1 ]] || [[ "$days" -gt 365 ]]; then
    echo "Masa aktif harus antara 1-365 hari!"; return 1
  fi
  return 0
}

# ── Hitung tanggal expire ─────────────────────────────────────────
calc_expire() {
  local days="$1"
  date -d "+${days} days" '+%Y-%m-%d'
}

# ── Buat akun SSH ─────────────────────────────────────────────────
create_ssh_user() {
  local username="$1" password="$2" exp_date="$3"

  # Buat user system tanpa login shell interaktif (bisa SSH tapi tidak bisa exec)
  useradd -e "$exp_date" -s /bin/false -M "$username" 2>/dev/null \
    || useradd -e "$exp_date" -s /usr/sbin/nologin -M "$username"

  # Set password
  echo "$username:$password" | chpasswd

  # Batas max login bersamaan = 2 (anti multi-login)
  if ! grep -q "^$username" /etc/security/limits.conf 2>/dev/null; then
    echo "$username hard maxlogins 2" >> /etc/security/limits.conf
  fi
}

# ── Generate payload WebSocket ────────────────────────────────────
gen_ws_payload() {
  echo "GET wss://bug.com/ HTTP/1.1[crlf]Host: bug.com[crlf]Upgrade: websocket[crlf][crlf]"
}

# ── Format waktu dari detik ───────────────────────────────────────
fmt_exp() {
  local exp_date="$1"
  local today; today=$(date '+%Y-%m-%d')
  local diff; diff=$(( ( $(date -d "$exp_date" +%s) - $(date -d "$today" +%s) ) / 86400 ))
  echo "${exp_date} (${diff} hari)"
}

# ── Tampilkan hasil akun SSH + WebSocket lengkap ──────────────────
show_account() {
  local username="$1" password="$2" exp_date="$3"
  local timestamp; timestamp=$(date '+%d %B %Y %H:%M:%S WIB')

  clear
  echo ""
  echo -e "${BPURPLE}  ╔══════════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${BPURPLE}  ║${RESET}                                                              ${BPURPLE}║${RESET}"
  echo -e "${BPURPLE}  ║${RESET}   ${BOLD}${BWHITE}██████╗  ██████╗    ██╗   ██╗██████╗ ███████╗${RESET}          ${BPURPLE}║${RESET}"
  echo -e "${BPURPLE}  ║${RESET}   ${BOLD}${BWHITE}██╔══██╗██╔════╝    ██║   ██║██╔══██╗██╔════╝${RESET}          ${BPURPLE}║${RESET}"
  echo -e "${BPURPLE}  ║${RESET}   ${BOLD}${BWHITE}██║  ██║██║         ╚██╗ ██╔╝██████╔╝███████╗${RESET}          ${BPURPLE}║${RESET}"
  echo -e "${BPURPLE}  ║${RESET}   ${BOLD}${BWHITE}██║  ██║██║          ╚████╔╝ ██╔═══╝ ╚════██║${RESET}          ${BPURPLE}║${RESET}"
  echo -e "${BPURPLE}  ║${RESET}   ${BOLD}${BWHITE}██████╔╝╚██████╗      ╚██╔╝  ██║     ███████║${RESET}          ${BPURPLE}║${RESET}"
  echo -e "${BPURPLE}  ║${RESET}   ${DIM}${BGRAY}╚═════╝  ╚═════╝       ╚═╝   ╚═╝     ╚══════╝${RESET}          ${BPURPLE}║${RESET}"
  echo -e "${BPURPLE}  ║${RESET}                 ${DIM}github.com/tuyulbodo99 • @devculturebot${RESET}    ${BPURPLE}║${RESET}"
  echo -e "${BPURPLE}  ╚══════════════════════════════════════════════════════════════╝${RESET}"
  echo ""

  # ── Info Akun ──────────────────────────────────────────────────
  echo -e "  ${BPURPLE}┌─────────────────────────────────────────────────────────────┐${RESET}"
  echo -e "  ${BPURPLE}│${RESET}  ${BOLD}${BYELLOW}◈  INFORMASI AKUN SSH${RESET}                                     ${BPURPLE}│${RESET}"
  echo -e "  ${BPURPLE}├─────────────────────────────────────────────────────────────┤${RESET}"
  printf "  ${BPURPLE}│${RESET}  ${BCYAN}%-18s${RESET}: ${BWHITE}%s${RESET}\n" "Username" "$username"
  printf "  ${BPURPLE}│${RESET}  ${BCYAN}%-18s${RESET}: ${BWHITE}%s${RESET}\n" "Password" "$password"
  printf "  ${BPURPLE}│${RESET}  ${BCYAN}%-18s${RESET}: ${BWHITE}%s${RESET}\n" "Masa Aktif" "$(fmt_exp "$exp_date")"
  printf "  ${BPURPLE}│${RESET}  ${BCYAN}%-18s${RESET}: ${BWHITE}%s${RESET}\n" "Dibuat" "$timestamp"
  printf "  ${BPURPLE}│${RESET}  ${BCYAN}%-18s${RESET}: ${BWHITE}%s${RESET}\n" "Host / IP" "$HOST"
  echo -e "  ${BPURPLE}└─────────────────────────────────────────────────────────────┘${RESET}"
  echo ""

  # ── Detail Koneksi ─────────────────────────────────────────────
  echo -e "  ${BPURPLE}┌─────────────────────────────────────────────────────────────┐${RESET}"
  echo -e "  ${BPURPLE}│${RESET}  ${BOLD}${BYELLOW}◈  DETAIL KONEKSI${RESET}                                         ${BPURPLE}│${RESET}"
  echo -e "  ${BPURPLE}├──────────────────────────────────┬──────────────────────────┤${RESET}"
  printf "  ${BPURPLE}│${RESET}  ${BGRAY}%-30s${RESET}  ${BPURPLE}│${RESET}  %-24s${RESET}  ${BPURPLE}│${RESET}\n" "Protokol" "Port"
  echo -e "  ${BPURPLE}├──────────────────────────────────┼──────────────────────────┤${RESET}"
  printf "  ${BPURPLE}│${RESET}  ${BGREEN}%-30s${RESET}  ${BPURPLE}│${RESET}  ${BWHITE}%-24s${RESET}  ${BPURPLE}│${RESET}\n" "OpenSSH" "$PORT_SSH"
  printf "  ${BPURPLE}│${RESET}  ${BGREEN}%-30s${RESET}  ${BPURPLE}│${RESET}  ${BWHITE}%-24s${RESET}  ${BPURPLE}│${RESET}\n" "Dropbear" "${PORT_DROPBEAR}, ${PORT_DROPBEAR2}"
  printf "  ${BPURPLE}│${RESET}  ${BGREEN}%-30s${RESET}  ${BPURPLE}│${RESET}  ${BWHITE}%-24s${RESET}  ${BPURPLE}│${RESET}\n" "SSH WebSocket" "$PORT_SSHWS"
  printf "  ${BPURPLE}│${RESET}  ${BGREEN}%-30s${RESET}  ${BPURPLE}│${RESET}  ${BWHITE}%-24s${RESET}  ${BPURPLE}│${RESET}\n" "SSH SSL WebSocket (HTTPS)" "$PORT_SSHWSSL"
  printf "  ${BPURPLE}│${RESET}  ${BGREEN}%-30s${RESET}  ${BPURPLE}│${RESET}  ${BWHITE}%-24s${RESET}  ${BPURPLE}│${RESET}\n" "Stunnel (SSL Tunnel)" "$PORT_STUNNEL"
  echo -e "  ${BPURPLE}└──────────────────────────────────┴──────────────────────────┘${RESET}"
  echo ""

  # ── Config WebSocket ───────────────────────────────────────────
  echo -e "  ${BPURPLE}┌─────────────────────────────────────────────────────────────┐${RESET}"
  echo -e "  ${BPURPLE}│${RESET}  ${BOLD}${BYELLOW}◈  KONFIGURASI HTTP CUSTOM (WebSocket Payload)${RESET}            ${BPURPLE}│${RESET}"
  echo -e "  ${BPURPLE}├─────────────────────────────────────────────────────────────┤${RESET}"
  printf "  ${BPURPLE}│${RESET}  ${BCYAN}%-18s${RESET}: ${BWHITE}%s${RESET}\n" "Server Host" "$HOST"
  printf "  ${BPURPLE}│${RESET}  ${BCYAN}%-18s${RESET}: ${BWHITE}%s${RESET}\n" "Server Port" "$PORT_SSHWS (HTTP/WS)"
  printf "  ${BPURPLE}│${RESET}  ${BCYAN}%-18s${RESET}: ${BWHITE}%s${RESET}\n" "Port SSL" "$PORT_SSHWSSL (HTTPS/WSS)"
  printf "  ${BPURPLE}│${RESET}  ${BCYAN}%-18s${RESET}: ${BWHITE}%s${RESET}\n" "Username" "$username"
  printf "  ${BPURPLE}│${RESET}  ${BCYAN}%-18s${RESET}: ${BWHITE}%s${RESET}\n" "Password" "$password"
  printf "  ${BPURPLE}│${RESET}  ${BCYAN}%-18s${RESET}: ${BWHITE}%s${RESET}\n" "Proxy Host" "bug.com"
  printf "  ${BPURPLE}│${RESET}  ${BCYAN}%-18s${RESET}: ${BWHITE}%s${RESET}\n" "Inject Method" "HTTP Custom"
  printf "  ${BPURPLE}│${RESET}  ${BCYAN}%-18s${RESET}: ${BWHITE}%s${RESET}\n" "SNI / Bug Host" "bug.com"
  echo -e "  ${BPURPLE}│${RESET}"
  echo -e "  ${BPURPLE}│${RESET}  ${BOLD}${BGRAY}Payload (HTTP Injector / HTTP Custom):${RESET}"
  echo -e "  ${BPURPLE}│${RESET}  ${BWHITE}  GET wss://bug.com/ HTTP/1.1[crlf]${RESET}"
  echo -e "  ${BPURPLE}│${RESET}  ${BWHITE}  Host: bug.com[crlf]${RESET}"
  echo -e "  ${BPURPLE}│${RESET}  ${BWHITE}  Upgrade: websocket[crlf][crlf]${RESET}"
  echo -e "  ${BPURPLE}└─────────────────────────────────────────────────────────────┘${RESET}"
  echo ""

  # ── Format Config HTTP Injector ───────────────────────────────
  echo -e "  ${BPURPLE}┌─────────────────────────────────────────────────────────────┐${RESET}"
  echo -e "  ${BPURPLE}│${RESET}  ${BOLD}${BYELLOW}◈  CONFIG HTTP INJECTOR / NETSPARK / NPAY${RESET}                 ${BPURPLE}│${RESET}"
  echo -e "  ${BPURPLE}├─────────────────────────────────────────────────────────────┤${RESET}"
  printf "  ${BPURPLE}│${RESET}  ${BCYAN}%-18s${RESET}: ${BWHITE}%s${RESET}\n" "Proxy Type" "SSH"
  printf "  ${BPURPLE}│${RESET}  ${BCYAN}%-18s${RESET}: ${BWHITE}%s${RESET}\n" "SSH Host" "$HOST"
  printf "  ${BPURPLE}│${RESET}  ${BCYAN}%-18s${RESET}: ${BWHITE}%s${RESET}\n" "SSH Port" "$PORT_SSH"
  printf "  ${BPURPLE}│${RESET}  ${BCYAN}%-18s${RESET}: ${BWHITE}%s${RESET}\n" "SSH User" "$username"
  printf "  ${BPURPLE}│${RESET}  ${BCYAN}%-18s${RESET}: ${BWHITE}%s${RESET}\n" "SSH Pass" "$password"
  printf "  ${BPURPLE}│${RESET}  ${BCYAN}%-18s${RESET}: ${BWHITE}%s${RESET}\n" "Remote Proxy" "127.0.0.1:8080"
  printf "  ${BPURPLE}│${RESET}  ${BCYAN}%-18s${RESET}: ${BWHITE}%s${RESET}\n" "Listen Port" "8989"
  echo -e "  ${BPURPLE}└─────────────────────────────────────────────────────────────┘${RESET}"
  echo ""

  # ── SSH Command ───────────────────────────────────────────────
  echo -e "  ${BPURPLE}┌─────────────────────────────────────────────────────────────┐${RESET}"
  echo -e "  ${BPURPLE}│${RESET}  ${BOLD}${BYELLOW}◈  PERINTAH SSH (Terminal)${RESET}                                ${BPURPLE}│${RESET}"
  echo -e "  ${BPURPLE}├─────────────────────────────────────────────────────────────┤${RESET}"
  echo -e "  ${BPURPLE}│${RESET}  ${DIM}# Koneksi langsung:${RESET}"
  echo -e "  ${BPURPLE}│${RESET}  ${BWHITE}  ssh ${username}@${HOST} -p ${PORT_SSH}${RESET}"
  echo -e "  ${BPURPLE}│${RESET}"
  echo -e "  ${BPURPLE}│${RESET}  ${DIM}# Via WebSocket tunnel (HTTP):${RESET}"
  echo -e "  ${BPURPLE}│${RESET}  ${BWHITE}  ssh ${username}@${HOST} -p ${PORT_SSHWS}${RESET}"
  echo -e "  ${BPURPLE}│${RESET}"
  echo -e "  ${BPURPLE}│${RESET}  ${DIM}# Via WebSocket SSL (HTTPS):${RESET}"
  echo -e "  ${BPURPLE}│${RESET}  ${BWHITE}  ssh ${username}@${HOST} -p ${PORT_SSHWSSL}${RESET}"
  echo -e "  ${BPURPLE}└─────────────────────────────────────────────────────────────┘${RESET}"
  echo ""

  # ── Status services ───────────────────────────────────────────
  echo -e "  ${BPURPLE}┌─────────────────────────────────────────────────────────────┐${RESET}"
  echo -e "  ${BPURPLE}│${RESET}  ${BOLD}${BYELLOW}◈  STATUS LAYANAN${RESET}                                         ${BPURPLE}│${RESET}"
  echo -e "  ${BPURPLE}├─────────────────────────────────────────────────────────────┤${RESET}"
  local services=("ssh" "dropbear" "nginx" "stunnel4" "ws-openssh" "ws-dropbear")
  for svc in "${services[@]}"; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
      printf "  ${BPURPLE}│${RESET}  ${BGREEN}● ACTIVE${RESET}  %-20s\n" "$svc"
    else
      printf "  ${BPURPLE}│${RESET}  ${BRED}● INACTIVE${RESET} %-20s\n" "$svc"
    fi
  done
  echo -e "  ${BPURPLE}└─────────────────────────────────────────────────────────────┘${RESET}"
  echo ""

  echo -e "  ${BPURPLE}══════════════════════════════════════════════════════════════${RESET}"
  echo -e "  ${BGREEN}${BOLD}  ✔  Akun berhasil dibuat!${RESET}  ${DIM}@devculturebot | tuyulbodo99${RESET}"
  echo -e "  ${BPURPLE}══════════════════════════════════════════════════════════════${RESET}"
  echo ""

  # Simpan ke file log
  local logfile="/root/dc-ssh-accounts.log"
  {
    echo "============================================================"
    echo "DATE     : $timestamp"
    echo "USERNAME : $username"
    echo "PASSWORD : $password"
    echo "EXPIRES  : $exp_date"
    echo "HOST     : $HOST"
    echo "SSH PORT : $PORT_SSH | WS: $PORT_SSHWS | WSS: $PORT_SSHWSSL"
    echo "============================================================"
  } >> "$logfile"
  echo -e "  ${DIM}  Log disimpan: $logfile${RESET}"
  echo ""
}

# ── Menu tambah akun ──────────────────────────────────────────────
add_user() {
  read_config
  clear
  echo ""
  echo -e "  ${BPURPLE}╔══════════════════════════════════════════╗${RESET}"
  echo -e "  ${BPURPLE}║${RESET}  ${BOLD}${BWHITE}BUAT AKUN SSH + WEBSOCKET BARU${RESET}          ${BPURPLE}║${RESET}"
  echo -e "  ${BPURPLE}╚══════════════════════════════════════════╝${RESET}"
  echo ""

  # Input username
  while true; do
    read -rp "  ${BCYAN}Username${RESET}      : " USERNAME
    ERR=$(validate_user "$USERNAME" 2>&1) && break || echo -e "  ${BRED}✘ $ERR${RESET}"
  done

  # Input password
  while true; do
    read -rp "  ${BCYAN}Password${RESET}      : " PASSWORD
    ERR=$(validate_pass "$PASSWORD" 2>&1) && break || echo -e "  ${BRED}✘ $ERR${RESET}"
  done

  # Input masa aktif
  while true; do
    read -rp "  ${BCYAN}Masa aktif${RESET}    : " DAYS
    ERR=$(validate_exp "$DAYS" 2>&1) && break || echo -e "  ${BRED}✘ $ERR${RESET}"
  done

  EXPIRE=$(calc_expire "$DAYS")
  echo ""
  echo -e "  ${BYELLOW}Membuat akun...${RESET}"

  # Cek apakah root
  if [[ $EUID -ne 0 ]]; then
    echo -e "  ${BRED}✘ Butuh root untuk membuat akun SSH!${RESET}"
    echo -e "  ${DIM}  Jalankan: sudo bash adduser-ssh.sh${RESET}"
    exit 1
  fi

  create_ssh_user "$USERNAME" "$PASSWORD" "$EXPIRE"
  show_account "$USERNAME" "$PASSWORD" "$EXPIRE"
}

# ── Lihat daftar akun ─────────────────────────────────────────────
list_users() {
  read_config
  clear
  echo ""
  echo -e "  ${BPURPLE}┌─────────────────────────────────────────────────────────────┐${RESET}"
  echo -e "  ${BPURPLE}│${RESET}  ${BOLD}${BWHITE}DAFTAR AKUN SSH AKTIF${RESET}                                     ${BPURPLE}│${RESET}"
  echo -e "  ${BPURPLE}├────┬──────────────┬────────────┬────────┬──────────────────┤${RESET}"
  printf "  ${BPURPLE}│${RESET} ${BOLD}%-2s${RESET} ${BPURPLE}│${RESET} ${BOLD}%-12s${RESET} ${BPURPLE}│${RESET} ${BOLD}%-10s${RESET} ${BPURPLE}│${RESET} ${BOLD}%-6s${RESET} ${BPURPLE}│${RESET} ${BOLD}%-16s${RESET} ${BPURPLE}│${RESET}\n" \
    "No" "Username" "Expired" "Online" "Status"
  echo -e "  ${BPURPLE}├────┼──────────────┼────────────┼────────┼──────────────────┤${RESET}"

  local TODAY; TODAY=$(date '+%Y-%m-%d')
  local IDX=0
  while IFS=: read -r user _ uid gid _ home shell; do
    [[ "$uid" -lt 1000 ]] && continue
    [[ "$shell" == */nologin ]] || [[ "$shell" == */false ]] || continue
    local exp; exp=$(chage -l "$user" 2>/dev/null | grep "Account expires" | cut -d: -f2 | xargs)
    [[ "$exp" == "never" || -z "$exp" ]] && continue
    local exp_fmt; exp_fmt=$(date -d "$exp" '+%Y-%m-%d' 2>/dev/null || echo "$exp")
    local online; online=$(who | grep -c "^$user " || echo "0")
    IDX=$((IDX+1))
    local color="$BGREEN"
    local status="AKTIF"
    if [[ "$exp_fmt" < "$TODAY" ]]; then color="$BRED"; status="EXPIRED"; fi
    printf "  ${BPURPLE}│${RESET} ${color}%-2s${RESET} ${BPURPLE}│${RESET} ${color}%-12s${RESET} ${BPURPLE}│${RESET} ${color}%-10s${RESET} ${BPURPLE}│${RESET} ${color}%-6s${RESET} ${BPURPLE}│${RESET} ${color}%-16s${RESET} ${BPURPLE}│${RESET}\n" \
      "$IDX" "$user" "$exp_fmt" "$online" "$status"
  done < /etc/passwd
  echo -e "  ${BPURPLE}└────┴──────────────┴────────────┴────────┴──────────────────┘${RESET}"
  echo -e "  ${DIM}  Total: ${IDX} akun${RESET}"
  echo ""
}

# ── Hapus akun ────────────────────────────────────────────────────
delete_user() {
  list_users
  read -rp "  ${BCYAN}Username yang akan dihapus${RESET}: " DEL_USER
  [[ -z "$DEL_USER" ]] && { echo "Dibatalkan."; return; }
  if ! id "$DEL_USER" &>/dev/null; then
    echo -e "  ${BRED}✘ User '$DEL_USER' tidak ditemukan!${RESET}"; return
  fi
  # Kill semua sesi aktif
  pkill -u "$DEL_USER" 2>/dev/null || true
  userdel --force "$DEL_USER" 2>/dev/null
  sed -i "/^$DEL_USER/d" /etc/security/limits.conf 2>/dev/null || true
  echo -e "  ${BGREEN}✔ Akun '$DEL_USER' berhasil dihapus!${RESET}"
}

# ── Perpanjang akun ───────────────────────────────────────────────
extend_user() {
  list_users
  read -rp "  ${BCYAN}Username yang diperpanjang${RESET}: " EXT_USER
  [[ -z "$EXT_USER" ]] && { echo "Dibatalkan."; return; }
  if ! id "$EXT_USER" &>/dev/null; then
    echo -e "  ${BRED}✘ User '$EXT_USER' tidak ditemukan!${RESET}"; return
  fi
  read -rp "  ${BCYAN}Tambah berapa hari${RESET}: " EXT_DAYS
  if ! [[ "$EXT_DAYS" =~ ^[0-9]+$ ]]; then echo "Input tidak valid!"; return; fi
  local NEW_EXP; NEW_EXP=$(date -d "+${EXT_DAYS} days" '+%Y-%m-%d')
  chage -E "$NEW_EXP" "$EXT_USER"
  echo -e "  ${BGREEN}✔ Akun '$EXT_USER' diperpanjang hingga ${BWHITE}${NEW_EXP}${RESET}"
}

# ── Menu utama ────────────────────────────────────────────────────
main_menu() {
  while true; do
    clear
    echo ""
    echo -e "  ${BPURPLE}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "  ${BPURPLE}║${RESET}  ${BOLD}${BWHITE}DevCulture — SSH + WebSocket User Manager${RESET}               ${BPURPLE}║${RESET}"
    echo -e "  ${BPURPLE}║${RESET}  ${DIM}github.com/tuyulbodo99 • @devculturebot${RESET}                  ${BPURPLE}║${RESET}"
    echo -e "  ${BPURPLE}╠══════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "  ${BPURPLE}║${RESET}  ${BGREEN}[1]${RESET}  Buat Akun SSH + WebSocket Baru                        ${BPURPLE}║${RESET}"
    echo -e "  ${BPURPLE}║${RESET}  ${BCYAN}[2]${RESET}  Lihat Daftar Akun Aktif                               ${BPURPLE}║${RESET}"
    echo -e "  ${BPURPLE}║${RESET}  ${BYELLOW}[3]${RESET}  Perpanjang Masa Aktif Akun                            ${BPURPLE}║${RESET}"
    echo -e "  ${BPURPLE}║${RESET}  ${BRED}[4]${RESET}  Hapus Akun SSH                                        ${BPURPLE}║${RESET}"
    echo -e "  ${BPURPLE}║${RESET}  ${DIM}[0]  Keluar${RESET}                                                  ${BPURPLE}║${RESET}"
    echo -e "  ${BPURPLE}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    read -rp "  Pilih [0-4]: " CHOICE
    case "$CHOICE" in
      1) add_user   ;;
      2) list_users ;;
      3) extend_user;;
      4) delete_user;;
      0) echo ""; exit 0 ;;
      *) echo -e "  ${BRED}Pilihan tidak valid!${RESET}" ;;
    esac
    [[ "$CHOICE" != "0" ]] && read -rp "  Tekan Enter..." _
  done
}

# ── Entry point ───────────────────────────────────────────────────
case "${1:-menu}" in
  add)    add_user    ;;
  list)   list_users  ;;
  delete) delete_user ;;
  extend) extend_user ;;
  demo)
    # Mode demo — tampilkan sample output tanpa buat user beneran
    read_config
    show_account "devculture" "dc@2024" "$(date -d '+30 days' '+%Y-%m-%d')"
    ;;
  menu|*) main_menu ;;
esac
