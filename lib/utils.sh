#!/bin/bash
# =================================================================
#   DevCulture VPS — Premium Shared Library
#   Version : 2.0.0  |  @devculturebot
#   GitHub  : github.com/tuyulbodo99/devculture-vps
# =================================================================

RESET='\033[0m';   BOLD='\033[1m';   DIM='\033[2m'
RED='\033[0;31m';  BRED='\033[1;31m'
GREEN='\033[0;32m'; BGREEN='\033[1;32m'
YELLOW='\033[0;33m'; BYELLOW='\033[1;33m'
BLUE='\033[0;34m';  BBLUE='\033[1;34m'
MAGENTA='\033[0;35m'; BMAGENTA='\033[1;35m'
CYAN='\033[0;36m';  BCYAN='\033[1;36m'
WHITE='\033[0;37m'; BWHITE='\033[1;37m'

success() { echo -e "${BGREEN}  ✔  ${RESET}${GREEN}${*}${RESET}"; }
warn()    { echo -e "${BYELLOW}  ⚠  ${RESET}${YELLOW}${*}${RESET}"; }
error()   { echo -e "${BRED}  ✘  ${RESET}${RED}${*}${RESET}"; }
info()    { echo -e "${BCYAN}  ➜  ${RESET}${CYAN}${*}${RESET}"; }
step()    { echo -e "${BMAGENTA}  ●  ${RESET}${BOLD}${*}${RESET}"; }
dim()     { echo -e "${DIM}${*}${RESET}"; }

LINE_TOP='╔══════════════════════════════════════════════════════════╗'
LINE_MID='╠══════════════════════════════════════════════════════════╣'
LINE_BOT='╚══════════════════════════════════════════════════════════╝'
LINE_SEP='╟──────────────────────────────────────────────────────────╢'

box_line() {
  local text="$1" width=58
  local plain; plain=$(printf '%b' "$text" | sed 's/\x1b\[[0-9;]*m//g')
  local pad=$(( width - ${#plain} ))
  [[ $pad -lt 0 ]] && pad=0
  printf "║ %b%${pad}s ║\n" "$text" ""
}
box_empty() { printf '║%60s║\n' ''; }

SPINNER_PID=""
_SPIN='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
start_spin() {
  local msg="${1:-Loading...}"
  ( i=0
    while true; do
      c=${_SPIN:$((i % ${#_SPIN})):1}
      printf "\r  ${BCYAN}%s${RESET} ${BOLD}%s${RESET}   " "$c" "$msg"
      sleep 0.08; (( i++ )) || true
    done ) &
  SPINNER_PID=$!; disown "$SPINNER_PID" 2>/dev/null || true
}
stop_spin()  { [[ -n "$SPINNER_PID" ]] && kill "$SPINNER_PID" 2>/dev/null; SPINNER_PID=""; printf "\r%70s\r" ""; }
spin_ok()    { stop_spin; success "$1"; }
spin_fail()  { stop_spin; error "$1"; }

progress_bar() {
  local cur=$1 tot=$2 lbl="${3:-}" w=40
  local pct=$(( cur * 100 / tot ))
  local fill=$(( cur * w / tot ))
  local emp=$(( w - fill ))
  local bar; bar=$(printf '%.0s█' $(seq 1 $fill 2>/dev/null || true))
  local space; space=$(printf '%.0s░' $(seq 1 $emp 2>/dev/null || true))
  printf "\r  ${BCYAN}[%s%s]${RESET} ${BOLD}%3d%%${RESET}  ${DIM}%s${RESET}   " \
         "$bar" "$space" "$pct" "$lbl"
}
progress_done() { printf "\r%80s\r" ""; }

detect_os() {
  if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    OS_ID="${ID:-unknown}"; OS_VER="${VERSION_ID:-0}"
    OS_CODENAME="${VERSION_CODENAME:-$(lsb_release -cs 2>/dev/null || echo '-')}"
  elif [[ -f /etc/debian_version ]]; then
    OS_ID="debian"; OS_VER=$(cat /etc/debian_version); OS_CODENAME="unknown"
  else
    error "OS tidak didukung."; exit 1
  fi
  OS_MAJOR=$(echo "$OS_VER" | cut -d. -f1 | tr -dc '0-9')
  [[ "$OS_MAJOR" =~ ^[0-9]+$ ]] || OS_MAJOR=0
  case "$OS_ID" in ubuntu|debian) ;; *) error "OS tidak didukung: $OS_ID"; exit 1 ;; esac
}

get_sysinfo() {
  SYS_IP=$(curl -s --max-time 5 https://ipv4.icanhazip.com 2>/dev/null \
           || wget -qO- --timeout=5 https://ipv4.icanhazip.com 2>/dev/null \
           || hostname -I 2>/dev/null | awk '{print $1}' || echo "N/A")
  SYS_RAM=$(free -m 2>/dev/null | awk '/^Mem:/{printf "%dMB / %dMB",$3,$2}' || echo "N/A")
  SYS_DISK=$(df -h / 2>/dev/null | awk 'NR==2{printf "%s / %s (%s)",$3,$2,$5}' || echo "N/A")
  SYS_CPU=$(nproc 2>/dev/null || grep -c processor /proc/cpuinfo 2>/dev/null || echo "N/A")
  SYS_LOAD=$(uptime 2>/dev/null | awk -F'load average:' '{print $2}' | tr -d ' ' | cut -d, -f1 || echo "N/A")
  SYS_UPTIME=$(uptime -p 2>/dev/null | sed 's/up //' || echo "N/A")
  SYS_KERNEL=$(uname -r 2>/dev/null || echo "N/A")
  NODE_VER=$(node -v 2>/dev/null || echo "not installed")
}

check_root()  { [[ ${EUID} -eq 0 ]] || { error "Harus root! (sudo -i)"; exit 1; }; }
check_virt()  { local v; v=$(systemd-detect-virt 2>/dev/null || echo none)
                [[ "$v" == "openvz" ]] && { error "OpenVZ tidak didukung."; exit 1; }; return 0; }
check_internet() {
  start_spin "Memeriksa koneksi internet..."
  if ping -c1 -W3 8.8.8.8 >/dev/null 2>&1 \
     || curl -s --max-time 5 https://google.com >/dev/null 2>&1; then
    spin_ok "Internet terhubung"
  else
    spin_fail "Tidak ada koneksi internet!"; exit 1
  fi
}
check_disk() {
  local MIN=${1:-300}
  local FREE; FREE=$(df -m / | awk 'NR==2{print $4}')
  [[ $FREE -lt $MIN ]] && { error "Disk tidak cukup: ${FREE}MB < ${MIN}MB"; exit 1; }
  success "Disk: ${FREE}MB tersedia"
}
check_ram() {
  local MIN=${1:-256}
  local RAM; RAM=$(free -m | awk '/^Mem:/{print $2}')
  [[ $RAM -lt $MIN ]] && warn "RAM ${RAM}MB (disarankan ${MIN}MB+)" || success "RAM: ${RAM}MB"
}

wait_apt() {
  local W=0
  while fuser /var/lib/dpkg/lock /var/lib/apt/lists/lock \
              /var/cache/apt/archives/lock >/dev/null 2>&1; do
    [[ $W -eq 0 ]] && info "Menunggu apt lock..."
    sleep 3; W=$((W+3))
    [[ $W -ge 120 ]] && { error "apt lock timeout!"; exit 1; }
  done
}
safe_apt() {
  wait_apt
  DEBIAN_FRONTEND=noninteractive apt-get "$@" \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    -o APT::Get::Assume-Yes=true >/dev/null 2>&1 || true
}

safe_dl() {
  local URL="$1" OUT="$2" i=0
  while [[ $i -lt 3 ]]; do
    wget -qO "$OUT" "$URL" 2>/dev/null && return 0
    curl -fsSL "$URL" -o "$OUT" 2>/dev/null && return 0
    i=$((i+1)); warn "  Retry $i/3..."; sleep 4
  done
  error "Gagal download: $URL"; return 1
}

install_nodejs() {
  local NODE_VER=20
  [[ "$OS_ID" == "ubuntu" && "$OS_MAJOR" -le 16 ]] && NODE_VER=16
  [[ "$OS_ID" == "ubuntu" && "$OS_MAJOR" -eq 18 ]] && NODE_VER=18
  safe_apt remove nodejs npm 2>/dev/null || true
  if curl -fsSL "https://deb.nodesource.com/setup_${NODE_VER}.x" | bash - >/dev/null 2>&1; then
    safe_apt install nodejs
    command -v node &>/dev/null && { success "Node.js $(node -v) via NodeSource"; return 0; }
  fi
  export NVM_DIR="/root/.nvm"
  safe_dl "https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh" /tmp/nvm.sh
  bash /tmp/nvm.sh >/dev/null 2>&1 || true; rm -f /tmp/nvm.sh
  [[ -f "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
  nvm install "$NODE_VER" >/dev/null 2>&1 && nvm use "$NODE_VER" >/dev/null 2>&1 || true
  local NB; NB=$(nvm which "$NODE_VER" 2>/dev/null || echo "")
  if [[ -n "$NB" && -x "$NB" ]]; then
    ln -sf "$NB" /usr/local/bin/node 2>/dev/null
    ln -sf "$(dirname "$NB")/npm" /usr/local/bin/npm 2>/dev/null
    success "Node.js $(node -v) via nvm"; return 0
  fi
  safe_apt install nodejs
  command -v node &>/dev/null && { success "Node.js $(node -v) via apt"; return 0; }
  error "Gagal install Node.js!"; return 1
}

get_node_bin() {
  local N; N=$(command -v node 2>/dev/null)
  [[ -z "$N" ]] && source /root/.nvm/nvm.sh 2>/dev/null && N=$(command -v node 2>/dev/null)
  echo "${N:-/usr/local/bin/node}"
}

setup_trap() { trap '_trap_err $LINENO $?' ERR; }
_trap_err() {
  echo ""; error "Error pada baris $1 (exit $2)"
  dim "  Log: /var/log/devculture-install.log"
  dim "  Bantuan: @devculturebot"; echo ""
}

VERSION="2.0.0"
BASE_URL="https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main"
LOG_FILE="/var/log/devculture-install.log"
