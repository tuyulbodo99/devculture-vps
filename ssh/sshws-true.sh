#!/bin/bash
# DevCulture VPS — Start SSH WebSocket Services via tmux
# github.com/tuyulbodo99/devculture-vps

LOG="/root/log-install.txt"

portdb=$(grep -w "Dropbear" "$LOG" 2>/dev/null | cut -d: -f2 | sed 's/ //g' | cut -f2 -d"," || echo "143")
portdb2=$(grep -w "Dropbear" "$LOG" 2>/dev/null | cut -d: -f2 | sed 's/ //g' | cut -f1 -d"," || echo "109")
portsshws=$(grep -w "SSH Websocket" "$LOG" 2>/dev/null | cut -d: -f2 | awk '{print $1}' || echo "80")
wsssl=$(grep -w "SSH SSL Websocket" "$LOG" 2>/dev/null | cut -d: -f2 | awk '{print $1}' || echo "443")

# Pastikan tmux tersedia
if ! command -v tmux >/dev/null 2>&1; then
  apt-get install -y tmux >/dev/null 2>&1 || true
fi

# Matikan sesi lama jika ada
tmux kill-session -t sshws 2>/dev/null || true
tmux kill-session -t sshwsssl 2>/dev/null || true

# Start WebSocket proxy via node (proxy3.js)
if [[ -f /usr/bin/proxy3.js ]]; then
  tmux new-session -d -s sshws \
    "node /usr/bin/proxy3.js -dport ${portdb} -mport ${portsshws} -o /root/sshws.log"
  tmux new-session -d -s sshwsssl \
    "node /usr/bin/proxy3.js -dport ${portdb} -mport 700"
  echo "✔ SSH WebSocket started: port ${portsshws} (HTTP), 700 (SSL)"
else
  echo "⚠ proxy3.js tidak ditemukan di /usr/bin/proxy3.js"
  echo "  Gunakan ws-dropbear service sebagai gantinya:"
  echo "  systemctl start ws-dropbear"
fi
