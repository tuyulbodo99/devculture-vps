#!/bin/bash
# =================================================================
#   DevCulture VPS — Cross-Repo Sync Script  v1.1.0
#   Sinkronisasi perbaikan script ke repo VPS lainnya via GitHub API
#
#   Cara pakai manual:
#     GITHUB_TOKEN=ghp_xxx bash sync.sh
#
#   Dijalankan otomatis oleh: .github/workflows/sync.yml
#   @devculturebot | github.com/tuyulbodo99/devculture-vps
# =================================================================
set -euo pipefail

OWNER="tuyulbodo99"
DC_REPO="devculture-vps"
DC_API="https://api.github.com/repos/${OWNER}/${DC_REPO}/contents"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[1;36m'; NC='\033[0m'; BOLD='\033[1m'

ok()      { echo -e "  ${GREEN}OK${NC}  $*"; }
err()     { echo -e "  ${RED}ERR${NC} $*"; [[ "${GITHUB_ACTIONS:-}" == "true" ]] && echo "::error::$*" || true; }
info()    { echo -e "  ${YELLOW}--${NC}  $*"; }
section() { echo -e "\n${CYAN}${BOLD}>> $*${NC}"; }
warn()    { echo -e "  ${YELLOW}WARN${NC} $*"; [[ "${GITHUB_ACTIONS:-}" == "true" ]] && echo "::warning::$*" || true; }
notice()  { [[ "${GITHUB_ACTIONS:-}" == "true" ]] && echo "::notice::$*" || true; }

TOTAL_OK=0; TOTAL_ERR=0; TOTAL_SKIP=0

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  err "GITHUB_TOKEN tidak diset!"
  echo ""
  echo "  Cara pakai:  GITHUB_TOKEN=ghp_xxx bash sync.sh"
  exit 1
fi

get_sha() {
  local REPO="$1" FPATH="$2"
  curl -sf "https://api.github.com/repos/${OWNER}/${REPO}/contents/${FPATH}" \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('sha',''))" 2>/dev/null || true
}

get_dc_b64() {
  local FPATH="$1"
  curl -sf "${DC_API}/${FPATH}" \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('content','').replace('\n',''))" 2>/dev/null || true
}

upload_b64() {
  local REPO="$1" FPATH="$2" B64="$3" MSG="$4"
  local SHA
  SHA=$(get_sha "$REPO" "$FPATH")

  local PAYLOAD
  PAYLOAD=$(python3 -c "
import json, sys
d = {'message': sys.argv[1], 'content': sys.argv[2]}
if sys.argv[3]: d['sha'] = sys.argv[3]
print(json.dumps(d))
" "$MSG" "$B64" "$SHA")

  local HTTP_CODE
  HTTP_CODE=$(curl -sf -o /tmp/gh_result.json -w "%{http_code}" \
    -X PUT "https://api.github.com/repos/${OWNER}/${REPO}/contents/${FPATH}" \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" 2>/dev/null || echo "000")

  if [[ "$HTTP_CODE" =~ ^(200|201)$ ]]; then
    local SHA8
    SHA8=$(python3 -c "import json; d=json.load(open('/tmp/gh_result.json')); print(d.get('content',{}).get('sha','?')[:8])" 2>/dev/null || echo "?")
    ok "${REPO}/${FPATH}  (sha: ${SHA8})"
    TOTAL_OK=$((TOTAL_OK+1))
    return 0
  else
    local ERRMSG
    ERRMSG=$(python3 -c "import json; d=json.load(open('/tmp/gh_result.json')); print(d.get('message','HTTP ${HTTP_CODE}'))" 2>/dev/null || echo "HTTP ${HTTP_CODE}")
    err "${REPO}/${FPATH}  --  ${ERRMSG}"
    TOTAL_ERR=$((TOTAL_ERR+1))
    return 1
  fi
}

sync_file() {
  local SRC="$1" DST_REPO="$2" DST="$3" MSG="$4"
  local BRAND_FROM="${5:-}" BRAND_TO="${6:-}"
  info "devculture-vps/${SRC}  ->  ${DST_REPO}/${DST}"

  local B64
  B64=$(get_dc_b64 "$SRC")
  if [[ -z "$B64" ]]; then
    warn "Gagal ambil ${SRC} dari devculture-vps -- dilewati"
    TOTAL_SKIP=$((TOTAL_SKIP+1))
    return 0
  fi

  if [[ -n "$BRAND_FROM" && -n "$BRAND_TO" ]]; then
    B64=$(echo "$B64" | base64 -d \
      | sed "s|${BRAND_FROM}|${BRAND_TO}|g" \
      | base64 -w 0)
  fi

  upload_b64 "$DST_REPO" "$DST" "$B64" "$MSG"
}

upload_local() {
  local LOCAL="$1" DST_REPO="$2" DST="$3" MSG="$4"
  if [[ ! -f "$LOCAL" ]]; then
    warn "File lokal tidak ditemukan: $LOCAL -- dilewati"
    TOTAL_SKIP=$((TOTAL_SKIP+1))
    return 0
  fi
  local B64
  B64=$(base64 -w 0 "$LOCAL")
  upload_b64 "$DST_REPO" "$DST" "$B64" "$MSG"
}

# ================================================================
echo ""
echo -e "${CYAN}${BOLD}DevCulture VPS -- Cross-Repo Sync v1.1.0${NC}"
echo -e "  github.com/tuyulbodo99/devculture-vps"
[[ "${GITHUB_ACTIONS:-}" == "true" ]] && echo "  Berjalan di: GitHub Actions" || echo "  Berjalan di: local shell"
echo "  Waktu: $(date -u '+%Y-%m-%d %H:%M UTC')"
echo ""

# ================================================================
#  SYNC: devculture-vps -> hokagescript
# ================================================================
section "hokagescript -- file bersama (websocket, lib)"

sync_file "websocket/insshws.sh" "hokagescript" "websocket/insshws.sh" \
  "sync: update dari devculture-vps/main [auto]" \
  "tuyulbodo99/devculture-vps" "tuyulbodo99/hokagescript"
sleep 0.4

sync_file "lib/utils.sh" "hokagescript" "lib/utils.sh" \
  "sync: update lib/utils.sh dari devculture-vps/main [auto]" \
  "tuyulbodo99/devculture-vps" "tuyulbodo99/hokagescript"
sleep 0.4

section "hokagescript -- patch ssh-vpn.sh (fix ANU, sed, URL)"

TMP_SSH=$(mktemp /tmp/hk-ssh-XXXXX.sh)
B64_SSH=$(get_dc_b64 "ssh/ssh-vpn.sh")
if [[ -n "$B64_SSH" ]]; then
  echo "$B64_SSH" | base64 -d \
    | sed 's|tuyulbodo99/devculture-vps|tuyulbodo99/hokagescript|g' \
    | sed 's|organization=DevCulture|organization=HOKAGE|g' \
    | sed 's|organizationalunit=DevCulture|organizationalunit=HOKAGE|g' \
    | sed 's|commonname=devculture.id|commonname=none|g' \
    | sed 's|email=admin@devculture.id|email=hokagelegend99@gmail.com|g' \
    > "$TMP_SSH"
  upload_local "$TMP_SSH" "hokagescript" "ssh/ssh-vpn.sh" \
    "fix: ssh-vpn.sh -- hapus ANU undefined, perbaiki sed tanpa file target [auto]"
else
  warn "Gagal mengambil ssh/ssh-vpn.sh dari devculture-vps"
  TOTAL_SKIP=$((TOTAL_SKIP+1))
fi
rm -f "$TMP_SSH"
sleep 0.4

section "hokagescript -- patch setup.sh (hapus PERMISSION, fix URL)"

TMP_SETUP=$(mktemp /tmp/hk-setup-XXXXX.sh)
B64_SETUP=$(get_dc_b64 "setup.sh")
if [[ -n "$B64_SETUP" ]]; then
  echo "$B64_SETUP" | base64 -d \
    | sed 's|tuyulbodo99/devculture-vps|tuyulbodo99/hokagescript|g' \
    | sed 's|DevCulture VPS|HokageScript VPS|g' \
    | sed 's|@devculturebot|@hokagelegend|g' \
    > "$TMP_SETUP"
  upload_local "$TMP_SETUP" "hokagescript" "setup.sh" \
    "fix: setup.sh -- hapus PERMISSION undefined, ganti URL dari hokagelegend9999/original [auto]"
else
  warn "Gagal mengambil setup.sh dari devculture-vps"
  TOTAL_SKIP=$((TOTAL_SKIP+1))
fi
rm -f "$TMP_SETUP"

# ================================================================
#  RINGKASAN
# ================================================================
echo ""
echo -e "  ${CYAN}================================================${NC}"
echo -e "  ${BOLD}Berhasil${NC} : ${GREEN}${TOTAL_OK}${NC}"
if [[ $TOTAL_ERR -gt 0 ]]; then
  echo -e "  ${BOLD}Gagal${NC}    : ${RED}${TOTAL_ERR}${NC}"
else
  echo -e "  ${BOLD}Gagal${NC}    : 0"
fi
echo -e "  ${BOLD}Dilewati${NC} : ${TOTAL_SKIP}"
echo -e "  ${CYAN}================================================${NC}"
echo ""

notice "Sync selesai: ${TOTAL_OK} berhasil, ${TOTAL_ERR} gagal, ${TOTAL_SKIP} dilewati"

[[ $TOTAL_ERR -gt 0 ]] && exit 1 || exit 0
