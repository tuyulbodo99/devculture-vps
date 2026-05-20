#!/bin/bash
# =================================================================
#   DevCulture VPS — SSH Login Notifier  v3.2.0
#   Pasang di PAM: tambahkan ke /etc/pam.d/sshd:
#     session optional pam_exec.so /usr/local/bin/dc-ssh-notify
#   @devculturebot | github.com/tuyulbodo99/devculture-vps
# =================================================================
[ "$PAM_TYPE" != "open_session" ] && exit 0

NOTIFY="/usr/local/bin/dc-notify"
USER="$PAM_USER"
IP="${PAM_RHOST:-unknown}"
TIME=$(date "+%Y-%m-%d %H:%M:%S")

# Skip system users
case "$USER" in
  root|nobody|daemon|www-data) exit 0 ;;
esac

[ -x "$NOTIFY" ] || exit 0

MSG="🔐 <b>SSH Login Baru</b>
━━━━━━━━━━━━━━━━━━━━
👤 User   : <code>${USER}</code>
📍 IP     : <code>${IP}</code>
🕐 Waktu  : <code>${TIME}</code>"

"$NOTIFY" "$MSG" "warn"
exit 0
