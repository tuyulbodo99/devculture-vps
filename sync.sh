#!/bin/bash
# =================================================================
#   DevCulture VPS — Cross-Repo Sync Script  v1.0.0
#   Sinkronisasi perbaikan script ke repo VPS lainnya
#   via GitHub API.
#
#   Cara pakai:
#     GITHUB_TOKEN=ghp_xxx bash sync.sh
#   atau:
#     export GITHUB_TOKEN=ghp_xxx
#     bash sync.sh
#
#   Repo yang disinkronisasi:
#     - tuyulbodo99/hokagescript  (ssh/, xray/, update/, websocket/)
#
#   @devculturebot | github.com/tuyulbodo99/devculture-vps
# =================================================================
set -euo pipefail

DC_BASE="https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main"
DC_API="https://api.github.com/repos/tuyulbodo99/devculture-vps/contents"
OWNER="tuyulbodo99"

# ─── Warna ───────────────────────────────────────────────────────
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[1;36m'; NC='\033[0m'; BOLD='\033[1m'
ok()   { echo -e "  ${GREEN}✔${NC}  $*"; }
err()  { echo -e "  ${RED}✘${NC}  $*"; }
info() { echo -e "  ${YELLOW}→${NC}  $*"; }
head_msg() { echo -e "\n${CYAN}${BOLD}$*${NC}"; }

# ─── Cek token ───────────────────────────────────────────────────
if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  err "GITHUB_TOKEN tidak diset!"
  echo ""
  echo "  Cara pakai:  GITHUB_TOKEN=ghp_xxx bash sync.sh"
  exit 1
fi

# ─── Helper: get file SHA ────────────────────────────────────────
get_sha() {
  local REPO="$1" PATH="$2"
  curl -sf "https://api.github.com/repos/${OWNER}/${REPO}/contents/${PATH}" \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    2>/dev/null \
  | grep '"sha"' | head -1 | sed 's/.*"sha"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' || true
}

# ─── Helper: get file content as base64 from devculture-vps ──────
get_dc_content_b64() {
  local FPATH="$1"
  curl -sf "${DC_API}/${FPATH}" \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    2>/dev/null \
  | grep '"content"' | head -1 \
  | sed 's/.*"content"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' \
  | tr -d '\\n' || true
}

# ─── Helper: upload to target repo ───────────────────────────────
upload_to_repo() {
  local REPO="$1" DST_PATH="$2" CONTENT_B64="$3" MSG="$4"
  local SHA
  SHA=$(get_sha "$REPO" "$DST_PATH")

  local PAYLOAD
  if [[ -n "$SHA" ]]; then
    PAYLOAD="{\"message\":\"${MSG}\",\"content\":\"${CONTENT_B64}\",\"sha\":\"${SHA}\"}"
  else
    PAYLOAD="{\"message\":\"${MSG}\",\"content\":\"${CONTENT_B64}\"}"
  fi

  local RESULT
  RESULT=$(curl -sf -X PUT \
    "https://api.github.com/repos/${OWNER}/${REPO}/contents/${DST_PATH}" \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" 2>/dev/null \
    | grep '"name"' | head -1 | sed 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' || true)

  if [[ -n "$RESULT" ]]; then
    ok "${REPO}/${DST_PATH}"
    return 0
  else
    err "${REPO}/${DST_PATH} — gagal upload"
    return 1
  fi
}

# ─── Helper: sync satu file DC → target ──────────────────────────
sync_file() {
  local SRC_PATH="$1" REPO="$2" DST_PATH="${3:-$1}"
  local MSG="$4"
  info "Syncing ${SRC_PATH} → ${REPO}/${DST_PATH}..."

  local B64
  B64=$(get_dc_content_b64 "$SRC_PATH")
  if [[ -z "$B64" ]]; then
    err "Gagal ambil konten dari devculture-vps/${SRC_PATH}"
    return 1
  fi
  upload_to_repo "$REPO" "$DST_PATH" "$B64" "$MSG"
}

# ─── Helper: upload file lokal → repo ────────────────────────────
upload_local() {
  local LOCAL="$1" REPO="$2" DST_PATH="$3" MSG="$4"
  local B64
  B64=$(base64 -w 0 "$LOCAL")
  upload_to_repo "$REPO" "$DST_PATH" "$B64" "$MSG"
}

# ================================================================
# BANNER
# ================================================================
clear
echo -e "${CYAN}${BOLD}"
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║   DevCulture VPS — Cross-Repo Sync  v1.0    ║"
echo "  ║   github.com/tuyulbodo99/devculture-vps      ║"
echo "  ╚══════════════════════════════════════════════╝"
echo -e "${NC}"
echo "  Token : ${GITHUB_TOKEN:0:8}***"
echo "  Date  : $(date '+%Y-%m-%d %H:%M %Z')"
echo ""

TOTAL_OK=0; TOTAL_ERR=0

# ================================================================
# SYNC: devculture-vps → hokagescript
# ================================================================
head_msg "[ hokagescript ]  Syncing shared scripts..."

declare -A SYNC_MAP=(
  # websocket — identik
  ["websocket/insshws.sh"]="websocket/insshws.sh"
  # xray — shared base (ins-xray.sh pakai path hokagescript sendiri)
  # update scripts — bisa langsung dipakai
  ["update/update-devculture.sh"]="update/update-devculture.sh"
  ["lib/utils.sh"]="lib/utils.sh"
)

for SRC in "${!SYNC_MAP[@]}"; do
  DST="${SYNC_MAP[$SRC]}"
  if sync_file "$SRC" "hokagescript" "$DST" "sync: update ${DST} dari devculture-vps"; then
    TOTAL_OK=$((TOTAL_OK + 1))
  else
    TOTAL_ERR=$((TOTAL_ERR + 1))
  fi
  sleep 0.3
done

# Upload file yang sudah dipatch khusus untuk hokagescript
head_msg "[ hokagescript ]  Upload patched files..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOKAGE_SSH_VPN="${SCRIPT_DIR}/scripts/hokagescript/ssh-vpn.sh"
HOKAGE_SETUP="${SCRIPT_DIR}/scripts/hokagescript/setup.sh"

# Jika file patch tersedia secara lokal
if [[ -f "$HOKAGE_SSH_VPN" ]]; then
  if upload_local "$HOKAGE_SSH_VPN" "hokagescript" "ssh/ssh-vpn.sh" \
    "fix: ssh-vpn.sh — hapus \$ANU undefined, perbaiki sed tanpa file target, fix URL"; then
    TOTAL_OK=$((TOTAL_OK + 1))
  else
    TOTAL_ERR=$((TOTAL_ERR + 1))
  fi
else
  # Fallback: ambil dari devculture-vps dan patch on-the-fly
  info "Patching hokagescript/ssh/ssh-vpn.sh on-the-fly..."
  TMP_SSH=$(mktemp /tmp/hk-ssh-XXXXX.sh)
  curl -fsSL "${DC_BASE}/ssh/ssh-vpn.sh" -o "$TMP_SSH" 2>/dev/null || \
    wget -qO "$TMP_SSH" "${DC_BASE}/ssh/ssh-vpn.sh" 2>/dev/null
  # Ganti branding devculture → hokagescript
  sed -i 's|tuyulbodo99/devculture-vps|tuyulbodo99/hokagescript|g' "$TMP_SSH"
  sed -i 's|organization=DevCulture|organization=HOKAGE|g' "$TMP_SSH"
  sed -i 's|organizationalunit=DevCulture|organizationalunit=HOKAGE|g' "$TMP_SSH"
  sed -i 's|email=admin@devculture.id|email=hokagelegend99@gmail.com|g' "$TMP_SSH"
  if upload_local "$TMP_SSH" "hokagescript" "ssh/ssh-vpn.sh" \
    "fix: ssh-vpn.sh — hapus \$ANU undefined, perbaiki sed tanpa file target"; then
    TOTAL_OK=$((TOTAL_OK + 1))
  else
    TOTAL_ERR=$((TOTAL_ERR + 1))
  fi
  rm -f "$TMP_SSH"
fi
sleep 0.3

if [[ -f "$HOKAGE_SETUP" ]]; then
  if upload_local "$HOKAGE_SETUP" "hokagescript" "setup.sh" \
    "fix: setup.sh — hapus PERMISSION undefined, ganti URL dari hokagelegend9999/original"; then
    TOTAL_OK=$((TOTAL_OK + 1))
  else
    TOTAL_ERR=$((TOTAL_ERR + 1))
  fi
else
  info "Patching hokagescript/setup.sh on-the-fly..."
  TMP_SETUP=$(mktemp /tmp/hk-setup-XXXXX.sh)
  curl -fsSL "${DC_BASE}/setup.sh" -o "$TMP_SETUP" 2>/dev/null || \
    wget -qO "$TMP_SETUP" "${DC_BASE}/setup.sh" 2>/dev/null
  sed -i 's|tuyulbodo99/devculture-vps|tuyulbodo99/hokagescript|g' "$TMP_SETUP"
  sed -i 's|DevCulture VPS|HokageScript VPS|g' "$TMP_SETUP"
  if upload_local "$TMP_SETUP" "hokagescript" "setup.sh" \
    "fix: setup.sh — hapus PERMISSION undefined, ganti URL dari hokagelegend9999/original"; then
    TOTAL_OK=$((TOTAL_OK + 1))
  else
    TOTAL_ERR=$((TOTAL_ERR + 1))
  fi
  rm -f "$TMP_SETUP"
fi
sleep 0.3

# ================================================================
# RINGKASAN
# ================================================================
echo ""
echo -e "  ${CYAN}══════════════════════════════════════════════${NC}"
echo -e "  ${BOLD}Hasil Sync${NC}"
echo -e "  ${GREEN}✔ Berhasil${NC} : ${TOTAL_OK}"
if [[ $TOTAL_ERR -gt 0 ]]; then
  echo -e "  ${RED}✘ Gagal${NC}    : ${TOTAL_ERR}"
else
  echo -e "  Gagal    : 0"
fi
echo -e "  ${CYAN}══════════════════════════════════════════════${NC}"
echo ""

[[ $TOTAL_ERR -gt 0 ]] && exit 1 || exit 0
