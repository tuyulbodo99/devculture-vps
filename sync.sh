#!/bin/bash
# =================================================================
#   DevCulture VPS — Central Sync & Auto-Update System v1.1.0
#   Menghubungkan & menyinkronkan semua komponen DevCulture
#   github.com/tuyulbodo99 | @devculturebot
# =================================================================
set -euo pipefail

RESET="\033[0m"; BOLD="\033[1m"; DIM="\033[2m"
BCYAN="\033[1;36m"; BGREEN="\033[1;32m"
BYELLOW="\033[1;33m"; BRED="\033[1;31m"; BPURPLE="\033[1;35m"
BWHITE="\033[1;37m"

DC_VERSION="1.1.0"
BASE="https://raw.githubusercontent.com/tuyulbodo99"
LOCK="/tmp/dc-sync.lock"

# ── Setup path berdasarkan root/non-root ─────────────────────────
if [[ $EUID -eq 0 ]]; then
  LOG="/var/log/devculture-sync.log"
  SYNC_DIR="/etc/devculture/sync"
  IJIN_DB="/etc/devculture/ijin.db"
  CRON_FILE="/etc/cron.d/devculture-sync"
else
  LOG="/tmp/devculture-sync.log"
  SYNC_DIR="$HOME/.devculture/sync"
  IJIN_DB="$HOME/.devculture/ijin.db"
  CRON_FILE=""
fi

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

# ── Init direktori dan log ────────────────────────────────────────
mkdir -p "$SYNC_DIR" 2>/dev/null || true
touch "$LOG" 2>/dev/null || LOG="/tmp/devculture-sync.log" && touch "$LOG"

# ── Cek lock ─────────────────────────────────────────────────────
if [[ -f "$LOCK" ]]; then
  echo -e "${BRED}[ERROR]${RESET} Sync sedang berjalan (lock: $LOCK). Keluar." >&2
  exit 1
fi
touch "$LOCK"
trap "rm -f '$LOCK'" EXIT

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

# FIX #6: Validasi file tidak kosong setelah download
safe_dl() {
  local url="$1" dst="$2"
  local tmp; tmp=$(mktemp /tmp/dc-dl-XXXXX)
  if curl -fsSL --max-time 30 "$url" -o "$tmp" 2>/dev/null && [[ -s "$tmp" ]]; then
    mv "$tmp" "$dst"
    return 0
  elif command -v wget >/dev/null 2>&1 && wget -qO "$tmp" "$url" 2>/dev/null && [[ -s "$tmp" ]]; then
    mv "$tmp" "$dst"
    return 0
  else
    rm -f "$tmp"
    return 1
  fi
}

check_internet() {
  if ! curl -fsSL --max-time 5 https://github.com >/dev/null 2>&1; then
    error "Tidak ada koneksi internet! Script dihentikan."
    exit 1
  fi
  success "Koneksi internet OK"
}

# FIX #2: Root check dengan pesan jelas
require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo ""
    echo -e "  ${BYELLOW}╔══════════════════════════════════════════════════╗${RESET}"
    echo -e "  ${BYELLOW}║${RESET}  ${BRED}${BOLD}PERINGATAN: Script dijalankan tanpa root!${RESET}      ${BYELLOW}║${RESET}"
    echo -e "  ${BYELLOW}║${RESET}  Instalasi komponen ke /usr/local/bin akan GAGAL ${BYELLOW}║${RESET}"
    echo -e "  ${BYELLOW}║${RESET}  Jalankan dengan: ${BWHITE}sudo bash sync.sh${RESET}              ${BYELLOW}║${RESET}"
    echo -e "  ${BYELLOW}╚══════════════════════════════════════════════════╝${RESET}"
    echo ""
    read -rp "  Tetap lanjutkan? (beberapa fitur tidak akan berfungsi) [y/N]: " CONFIRM
    [[ "${CONFIRM,,}" == "y" ]] || exit 0
  fi
}

# ── Sync database ijin ────────────────────────────────────────────
sync_permissions() {
  step "Memperbarui database ijin dari tuyulbodo99/ijin..."
  local IJIN_URL="${BASE}/ijin/main/youtube"
  mkdir -p "$(dirname "$IJIN_DB")" 2>/dev/null || true
  if safe_dl "$IJIN_URL" "$IJIN_DB"; then
    success "Database ijin berhasil diperbarui → ${DIM}${IJIN_DB}${RESET}"
  else
    warn "Gagal memperbarui database ijin (akan gunakan cache lama)"
  fi
}

# ── Validasi ijin VPS ini ─────────────────────────────────────────
check_permission() {
  step "Validasi ijin VPS ini..."
  local MYIP; MYIP=$(curl -sS --max-time 5 ipv4.icanhazip.com 2>/dev/null \
    || curl -sS --max-time 5 ifconfig.me 2>/dev/null \
    || hostname -I 2>/dev/null | awk '{print $1}' \
    || echo "unknown")
  local IZIN=""
  if [[ -f "$IJIN_DB" ]]; then
    IZIN=$(awk '{print $4}' "$IJIN_DB" | grep -w "$MYIP" 2>/dev/null || true)
  else
    IZIN=$(curl -sS --max-time 10 "${BASE}/ijin/main/youtube" 2>/dev/null \
      | awk '{print $4}' | grep -w "$MYIP" 2>/dev/null || true)
  fi
  if [[ -n "$IZIN" ]]; then
    success "VPS terotorisasi: ${BWHITE}${MYIP}${RESET}"
  else
    warn "VPS tidak terdaftar: ${BYELLOW}${MYIP}${RESET}"
    info "Hubungi admin untuk mendaftarkan VPS Anda"
  fi
}

# ── Sync satu komponen ────────────────────────────────────────────
sync_component() {
  local name="$1" url="$2" dst="$3"
  local tmp; tmp=$(mktemp /tmp/dc-sync-XXXXX)
  step "Syncing: ${BWHITE}${name}${RESET}"
  if safe_dl "$url" "$tmp"; then
    chmod +x "$tmp"
    mkdir -p "$(dirname "$dst")" 2>/dev/null || true
    if mv "$tmp" "$dst" 2>/dev/null; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') SYNCED $name -> $dst" >> "$SYNC_DIR/sync.log" 2>/dev/null || true
      success "$name diperbarui → ${DIM}$dst${RESET}"
    else
      warn "$name gagal dipindahkan ke $dst (perlu root?)"
      rm -f "$tmp"
    fi
  else
    warn "$name gagal diunduh (URL tidak tersedia), skip."
    rm -f "$tmp"
  fi
}

# FIX #4: install_cron dengan error handling ─────────────────────
install_cron() {
  if [[ $EUID -ne 0 ]]; then
    warn "Cron otomatis tidak dapat dipasang tanpa root. Skip."
    info "Jalankan manual: sudo bash sync.sh untuk install cron"
    return 0
  fi
  if [[ ! -f "$CRON_FILE" ]]; then
    cat > "$CRON_FILE" << CRONEOF
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
0 3 * * * root bash <(curl -fsSL ${BASE}/devculture-vps/main/sync.sh) --cron >> $LOG 2>&1
CRONEOF
    chmod 644 "$CRON_FILE"
    success "Cron auto-sync terpasang: setiap hari pukul 03:00"
    info "File cron: $CRON_FILE"
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
    "${IJIN_DB}:Ijin Database"
    "${CRON_FILE:-/etc/cron.d/devculture-sync}:Auto-Sync Cron"
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
  echo -e "  ${DIM}Log: $LOG${RESET}"
  echo -e "  ${DIM}Root: $([ $EUID -eq 0 ] && echo 'Ya' || echo 'Tidak')${RESET}"
  echo ""
}

# ── Main ──────────────────────────────────────────────────────────
# FIX #1: Gunakan "$@" bukan "${@:-}"
main() {
  local MODE="${1:-interactive}"

  # FIX #3: Mode cron — log ke file dengan fallback
  if [[ "$MODE" == "--cron" ]]; then
    if [[ -w "$LOG" ]] || touch "$LOG" 2>/dev/null; then
      exec >> "$LOG" 2>&1
    fi
    echo "$(date '+%Y-%m-%d %H:%M:%S') [CRON] Memulai auto-sync v${DC_VERSION}..."
    check_internet 2>/dev/null || { echo "$(date) [CRON] Tidak ada internet, batal."; exit 0; }
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
  require_root

  echo -e "  ${BPURPLE}┌─────────────────────────────────────────────────────┐${RESET}"
  echo -e "  ${BPURPLE}│${RESET}  ${BOLD}Sinkronisasi semua komponen DevCulture${RESET}              ${BPURPLE}│${RESET}"
  echo -e "  ${BPURPLE}│${RESET}  ${DIM}Repo: devculture-vps · hokagescript · vpnscript${RESET}    ${BPURPLE}│${RESET}"
  echo -e "  ${BPURPLE}│${RESET}  ${DIM}Ijin: tuyulbodo99/ijin${RESET}                               ${BPURPLE}│${RESET}"
  echo -e "  ${BPURPLE}└─────────────────────────────────────────────────────┘${RESET}"
  echo ""

  sync_permissions
  check_permission

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
  echo -e "  ${DIM}  Log: $LOG${RESET}"
  echo -e "  ${BPURPLE}══════════════════════════════════════════════════════${RESET}"
  echo ""
  status_report
}

main "$@"
