#!/bin/bash
# =================================================================
#   DevCulture VPS — Install WebSocket Services
#   github.com/tuyulbodo99/devculture-vps | @devculturebot
# =================================================================
set -euo pipefail

BASE="https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main"
cd /root

echo "[*] Download WebSocket proxy — Dropbear..."
curl -fsSL "${BASE}/websocket/dropbear-ws.py" -o /usr/local/bin/ws-dropbear \
  || wget -qO /usr/local/bin/ws-dropbear "${BASE}/websocket/dropbear-ws.py"

echo "[*] Download WebSocket proxy — OpenSSH..."
curl -fsSL "${BASE}/websocket/openssh-socket.py" -o /usr/local/bin/ws-openssh \
  || wget -qO /usr/local/bin/ws-openssh "${BASE}/websocket/openssh-socket.py"

echo "[*] Download WebSocket proxy — Stunnel..."
curl -fsSL "${BASE}/websocket/ws-epro" -o /usr/local/bin/ws-stunnel \
  || wget -qO /usr/local/bin/ws-stunnel "${BASE}/websocket/ws-epro"

chmod +x /usr/local/bin/ws-dropbear
chmod +x /usr/local/bin/ws-openssh
chmod +x /usr/local/bin/ws-stunnel

echo "[*] Install systemd service — ws-dropbear..."
curl -fsSL "${BASE}/websocket/service-wsdropbear" \
  -o /etc/systemd/system/ws-dropbear.service \
  || wget -qO /etc/systemd/system/ws-dropbear.service "${BASE}/websocket/service-wsdropbear"

echo "[*] Install systemd service — ws-openssh..."
curl -fsSL "${BASE}/websocket/service-wsopenssh" \
  -o /etc/systemd/system/ws-openssh.service \
  || wget -qO /etc/systemd/system/ws-openssh.service "${BASE}/websocket/service-wsopenssh"

echo "[*] Install systemd service — ws-stunnel..."
curl -fsSL "${BASE}/websocket/ws-stunnel.service" \
  -o /etc/systemd/system/ws-stunnel.service \
  || wget -qO /etc/systemd/system/ws-stunnel.service "${BASE}/websocket/ws-stunnel.service"

echo "[*] Reload systemd daemon..."
systemctl daemon-reload

for svc in ws-dropbear ws-openssh ws-stunnel; do
  echo "[*] Enable & start: $svc"
  systemctl enable "$svc" 2>/dev/null || true
  systemctl restart "$svc" 2>/dev/null \
    && echo "    ✔ $svc running" \
    || echo "    ✘ $svc gagal start (python2 diperlukan?)"
done

echo ""
echo "✔ WebSocket services berhasil diinstall!"
echo "  ws-dropbear  → port 80 (HTTP WebSocket untuk Dropbear:109)"
echo "  ws-openssh   → port 2095 (HTTP WebSocket untuk OpenSSH:22)"
echo "  ws-stunnel   → port 8880 (HTTP WebSocket untuk Stunnel)"
