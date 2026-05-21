#!/bin/bash
# =================================================================
#   DevCulture VPS — Central Sync & Auto-Update System v1.0.0
#   Menghubungkan & menyinkronkan semua komponen DevCulture
#   github.com/tuyulbodo99 | @devculturebot
# =================================================================
set -euo pipefail

RESET="\033[0m"; BOLD="\033[1m"; DIM="\033[2m"
BBLUE="\033[1;34m"; BCYAN="\033[1;36m"; BGREEN="\033[1;32m"
BYELLOW="\033[1;33m"; BRED="\033[1;31m"; BPURPLE="\033[1;35m"
BWHITE="\033[1;37m"

DC_VERSION="1.0.0"
BASE="https://raw.githubusercontent.com/tuyulbodo99"
LOG="/var/log/devculture-sync.log"
SYNC_DIR="/etc/devculture/sync"
LOCK="/tmp/dc-sync.lock"

# ── Daftar komponen yang disinkronkan ────────────────────────────
COMP_NAMES=(
  "devculture-panel"
  "dc-notify"
  "dc-monitor"
  "ssl-renew"
  "vpn-menu-update"
  "hokage-menu"
  "hokage-update"
)
COMP_URLS=(
  "${BASE}/devculture-vps/main/devculture"
  "${BASE}/devculture-vps/main/bot/notify.sh"
  "${BASE}/devculture-vps/main/bot/monitor.sh"
  "${BASE}/devculture-vps/main/ssl/ssl-renew.sh"
  "${BASE}/vpnscript/main/update.sh"
  "${BASE}/hokagescript/main/update/menu.sh"
  "${BASE}/hokagescript/main/update/update.sh"
)
COMP_DSTS=(
  "/usr/local/bin/devculture"
  "/usr/local/bin/dc-notify"
  "/usr/local/bin/dc-monitor"
  "/usr/local/bin/ssl-renew.sh"
  "/tmp/dc-vpn-update.sh"
  "/usr/local/sbin/menu"
  "/usr/local/bin/dc-update"
)

mkdir -p "$SYNC_DIR" 2>/dev/null || true

# ── Cek lock ─────────────────────────────────────────────────────
if [[ -f "$LOCK" ]]; then
  echo -e "${BRED}[ERROR]${RESET} Sync sedang berjalan (lock: $LOCK). Keluar."
  exit 1
fi
touch "$LOCK"
trap "rm -f $LOCK" EXIT

# ── Banner ────────────────────────────────────────────────────────
banner() {
  clear
  echo -e "${BPURPLE}"
  echo "  ██████╗ ███████╗██╗   ██╗ ██████╗██╗   ██╗██╗  ████████╗██╗   ██╗██████╗ ███████╗"
  echo "  ██╔══██╗██╔════╝██║   ██║██╔════╝██║   ██║██║  ╚══██╔══╝██║   ██║██╔══██╗██╔════╝"
  echo "  ██║  ██║█████╗  ██║   ██║██║     ██║   ██║██║     ██║   ██║   ██║██████╔╝█████╗  "
  echo "  ██║  ██║██╔══╝  ╚██╗ ██╔╝██║     ██║   ██║██║     ██║   ██║   ██║██╔══██╗██╔══╝  "
  echo "  ██████╔╝███████╗ ╚████╔╝ ╚██████╗╚██████╔╝███████╗██║   ╚██████╔╝██║  ██║███████╗"
  echo "  ╚═════╝ ╚══════╝  ╚═══╝   ╚═════╝ ╚═════╝ ╚══════╝╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝"
  echo -e "${RESET}"
  echo -e "  ${BPURPLE}${BOLD}  Central Sync System  v${DC_VERSION}${RESET}  ${DIM}│  github.com/tuyulbodo99${RESET}"
  echo ""
}

# ── Helpers ───────────────────────────────────────────────────────
info()    { echo -e "  ${BCYAN}[INFO]${RESET}    $*"; }
success() { echo -e "  ${BGREEN}[OK]${RESET}      $*"; }
warn()    { echo -e "  ${BYELLOW}[WARN]${RESET}    $*"; }
error()   { echo -e "  ${BRED}[ERROR]${RESET}   $*"; }
step()    { echo -e "  ${BPURPLE}[SYNC]${RESET}    $*"; }

safe_dl() {
  local url="$1" dst="$2"
  curl -fsSL --max-time 30 "$url" -o "$dst" 2>/dev/null \
    || wget -qO "$dst" "$url" 2>/dev/null \
    || return 1
}

check_internet() {
  curl -fsSL --max-time 5 https://google.com >/dev/null 2>&1 \
    || { error "Tidak ada koneksi internet!"; exit 1; }
}

# ── Sync satu komponen ────────────────────────────────────────────
sync_component() {
  local name="$1" url="$2" dst="$3"
  local tmp; tmp=$(mktemp /tmp/dc-sync-XXXXX)
  step "Syncing: ${BWHITE}${name}${RESET}"
  if safe_dl "$url" "$tmp"; then
    chmod +x "$tmp"
    mkdir -p "$(dirname "$dst")"
    mv "$tmp" "$dst"
    echo "$(date '+%Y-%m-%d %H:%M:%S') SYNCED $name -> $dst" >> "$SYNC_DIR/sync.log"
    success "$name diperbarui → ${DIM}$dst${RESET}"
  else
    warn "$name gagal diunduh, skip."
    rm -f "$tmp"
  fi
}

# ── Sync database ijin ────────────────────────────────────────────
sync_permissions() {
  step "Memperbarui database ijin dari tuyulbodo99/ijin..."
  local tmp; tmp=$(mktemp /tmp/dc-ijin-XXXXX)
  local IJIN_URL="${BASE}/ijin/main/youtube"
  if safe_dl "$IJIN_URL" "$tmp"; then
    mkdir -p /etc/devculture
    mv "$tmp" /etc/devculture/ijin.db
    success "Database ijin berhasil diperbarui"
  else
    warn "Gagal memperbarui database ijin"
    rm -f "$tmp"
  fi
}

# ── Validasi ijin VPS ini ─────────────────────────────────────────
check_permission() {
  step "Validasi ijin VPS ini..."
  local MYIP; MYIP=$(curl -sS ipv4.icanhazip.com 2>/dev/null || hostname -I | awk '{print $1}')
  local IJIN_URL="${BASE}/ijin/main/youtube"
  local IZIN; IZIN=$(curl -sS "$IJIN_URL" 2>/dev/null | awk '{print $4}' | grep -w "$MYIP" || true)
  if [[ "$MYIP" == "$IZIN" ]]; then
    success "VPS terotorisasi: ${BWHITE}${MYIP}${RESET}"
    return 0
  else
    warn "VPS tidak terdaftar di ijin: ${BYELLOW}${MYIP}${RESET}"
    info "Hubungi admin untuk mendaftarkan VPS Anda"
    return 1
  fi
}

# ── Install cron auto-sync harian ────────────────────────────────
install_cron() {
  local CRON_FILE="/etc/cron.d/devculture-sync"
  if [[ ! -f "$CRON_FILE" ]]; then
    cat > "$CRON_FILE" << CRONEOF
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
0 3 * * * root bash <(curl -fsSL ${BASE}/devculture-vps/main/sync.sh) --cron >> $LOG 2>&1
CRONEOF
    chmod 644 "$CRON_FILE"
    success "Cron auto-sync terpasang (setiap hari pukul 03:00)"
  else
    info "Cron sudah terpasang di $CRON_FILE"
  fi
}

# ── Report status komponen ────────────────────────────────────────
status_report() {
  echo ""
  echo -e "  ${BPURPLE}┌─────────────────────────────────────────────────────┐${RESET}"
  echo -e "  ${BPURPLE}│${RESET}  ${BOLD}${BWHITE}STATUS KOMPONEN DEVCULTURE${RESET}                          ${BPURPLE}│${RESET}"
  echo -e "  ${BPURPLE}├─────────────────────────────────────────────────────┤${RESET}"
  local entries=(
    "/usr/local/bin/devculture:DevCulture Panel"
    "/usr/local/bin/dc-notify:DC Notify"
    "/usr/local/bin/dc-monitor:DC Monitor"
    "/usr/local/bin/ssl-renew.sh:SSL Renewer"
    "/usr/local/sbin/menu:VPN Menu"
    "/usr/local/bin/dc-update:Update Script"
    "/etc/devculture/ijin.db:Ijin Database"
    "/etc/cron.d/devculture-sync:Auto-Sync Cron"
  )
  for entry in "${entries[@]}"; do
    local path="${entry%%:*}" label="${entry##*:}"
    if [[ -f "$path" ]]; then
      printf "  ${BPURPLE}│${RESET}  ${BGREEN}✔${RESET}  %-28s  ${DIM}%s${RESET}\n" "$label" "$path"
    else
      printf "  ${BPURPLE}│${RESET}  ${BRED}✘${RESET}  ${DIM}%-28s  belum terinstall${RESET}\n" "$label"
    fi
  done
  echo -e "  ${BPURPLE}└─────────────────────────────────────────────────────┘${RESET}"
  echo ""
}

# ── Main ──────────────────────────────────────────────────────────
main() {
  local MODE="${1:-interactive}"

  # Mode cron (silent)
  if [[ "$MODE" == "--cron" ]]; then
    exec >> "$LOG" 2>&1
    echo "$(date '+%Y-%m-%d %H:%M:%S') [CRON] Memulai auto-sync..."
    check_internet || exit 0
    sync_permissions
    for i in "${!COMP_NAMES[@]}"; do
      sync_component "${COMP_NAMES[$i]}" "${COMP_URLS[$i]}" "${COMP_DSTS[$i]}"
    done
    echo "$(date '+%Y-%m-%d %H:%M:%S') [CRON] Sync selesai."
    exit 0
  fi

  # Mode status
  if [[ "$MODE" == "--status" ]]; then
    banner
    status_report
    exit 0
  fi

  # Mode interaktif
  banner
  check_internet

  echo -e "  ${BPURPLE}┌─────────────────────────────────────────────────────┐${RESET}"
  echo -e "  ${BPURPLE}│${RESET}  ${BOLD}Sinkronisasi semua komponen DevCulture${RESET}              ${BPURPLE}│${RESET}"
  echo -e "  ${BPURPLE}│${RESET}  ${DIM}Repo: devculture-vps · hokagescript · vpnscript${RESET}    ${BPURPLE}│${RESET}"
  echo -e "  ${BPURPLE}│${RESET}  ${DIM}Ijin: tuyulbodo99/ijin${RESET}                               ${BPURPLE}│${RESET}"
  echo -e "  ${BPURPLE}└─────────────────────────────────────────────────────┘${RESET}"
  echo ""

  check_permission || true
  sync_permissions

  echo ""
  info "Menyinkronkan ${#COMP_NAMES[@]} komponen..."
  echo ""

  for i in "${!COMP_NAMES[@]}"; do
    sync_component "${COMP_NAMES[$i]}" "${COMP_URLS[$i]}" "${COMP_DSTS[$i]}"
  done

  install_cron

  echo ""
  echo -e "  ${BPURPLE}══════════════════════════════════════════════════════${RESET}"
  echo -e "  ${BGREEN}${BOLD}  ✔  Sinkronisasi selesai!${RESET}"
  echo -e "  ${DIM}  Log tersimpan di: $LOG${RESET}"
  echo -e "  ${BPURPLE}══════════════════════════════════════════════════════${RESET}"
  echo ""
  status_report
}

main "${@:-}"
