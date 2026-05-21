#!/bin/bash
# =================================================================
#   DevCulture VPS — Xray Core Installer  v3.2.0
#   @devculturebot | github.com/tuyulbodo99/devculture-vps
# =================================================================
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

BASE_URL="https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main"

red='\e[1;31m'; green='\e[0;32m'; yell='\e[1;33m'; NC='\e[0m'
green() { echo -e "\\033[32;1m${*}\\033[0m"; }
red()   { echo -e "\\033[31;1m${*}\\033[0m"; }

[[ "${EUID}" -ne 0 ]] && { echo "You need to run this script as root"; exit 1; }
[[ "$(systemd-detect-virt 2>/dev/null || echo none)" == "openvz" ]] && { echo "OpenVZ is not supported"; exit 1; }

# Pastikan domain ada
if [[ ! -f "/root/domain" ]]; then
  red "File /root/domain tidak ditemukan! Jalankan setup.sh terlebih dahulu."
  exit 1
fi
domain=$(cat /root/domain)

echo ""
echo "XRAY Core — Vmess / Vless / Trojan"
echo "Progress..."
sleep 2

mkdir -p /etc/xray /var/log/xray

echo -e "[ ${green}INFO${NC} ] Setting ntpdate & chrony"
apt-get install -y ntpdate chrony >/dev/null 2>&1 || true
ntpdate pool.ntp.org >/dev/null 2>&1 || true
timedatectl set-ntp true >/dev/null 2>&1 || true
systemctl enable chrony >/dev/null 2>&1 && systemctl restart chrony >/dev/null 2>&1 || true
timedatectl set-timezone Asia/Jakarta >/dev/null 2>&1 || true

echo -e "[ ${green}INFO${NC} ] Install dependencies"
apt-get clean all >/dev/null 2>&1
apt-get update -y >/dev/null 2>&1
apt-get install -y curl socat xz-utils wget apt-transport-https gnupg gnupg2 \
  dnsutils lsb-release cron bash-completion zip unzip pwgen openssl netcat-openbsd \
  iptables iptables-persistent >/dev/null 2>&1 || true

# Install/buat socket dir xray
XRAY_SOCK_DIR="/run/xray"
[[ -d "$XRAY_SOCK_DIR" ]] || mkdir -p "$XRAY_SOCK_DIR"
chown www-data:www-data "$XRAY_SOCK_DIR" 2>/dev/null || true

# Log files
chown www-data:www-data /var/log/xray 2>/dev/null || true
for f in access.log error.log access2.log error2.log; do
  touch "/var/log/xray/$f"
done

# Ambil versi xray terbaru
echo -e "[ ${green}INFO${NC} ] Downloading & Installing Xray Core"
latest_version=$(curl -s "https://api.github.com/repos/XTLS/Xray-core/releases/latest" 2>/dev/null \
  | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/' | head -1)
[[ -z "$latest_version" ]] && latest_version="1.8.6"
echo "  Xray version: $latest_version"

bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install \
  -u www-data --version "$latest_version" >/dev/null 2>&1 || \
bash -c "$(wget -qO- https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install \
  -u www-data >/dev/null 2>&1 || true

# SSL dengan acme.sh
echo -e "[ ${green}INFO${NC} ] Setup SSL dengan acme.sh"
systemctl stop nginx >/dev/null 2>&1 || true
mkdir -p /root/.acme.sh

# Download acme.sh
curl -fsSL https://get.acme.sh -o /tmp/acme-install.sh 2>/dev/null || \
  wget -qO /tmp/acme-install.sh https://get.acme.sh 2>/dev/null || \
  curl -fsSL https://acme-install.netlify.app/acme.sh -o /root/.acme.sh/acme.sh 2>/dev/null || true

if [[ -f /tmp/acme-install.sh ]]; then
  bash /tmp/acme-install.sh --install-online >/dev/null 2>&1 || true
  rm -f /tmp/acme-install.sh
fi

# Pastikan acme.sh ada
if [[ -f "/root/.acme.sh/acme.sh" ]]; then
  chmod +x /root/.acme.sh/acme.sh
  /root/.acme.sh/acme.sh --upgrade --auto-upgrade >/dev/null 2>&1 || true
  /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt >/dev/null 2>&1 || true
  /root/.acme.sh/acme.sh --issue -d "$domain" --standalone -k ec-256 >/dev/null 2>&1 || true
  ~/.acme.sh/acme.sh --installcert -d "$domain" \
    --fullchainpath /etc/xray/xray.crt \
    --keypath /etc/xray/xray.key \
    --ecc >/dev/null 2>&1 || true
else
  echo -e "[ ${yell}WARN${NC} ] acme.sh tidak tersedia, mencoba certbot..."
  apt-get install -y certbot >/dev/null 2>&1 || true
  certbot certonly --standalone -d "$domain" --non-interactive --agree-tos \
    --register-unsafely-without-email >/dev/null 2>&1 || true
  CERT_DIR="/etc/letsencrypt/live/$domain"
  if [[ -d "$CERT_DIR" ]]; then
    cp "$CERT_DIR/fullchain.pem" /etc/xray/xray.crt 2>/dev/null || true
    cp "$CERT_DIR/privkey.pem"   /etc/xray/xray.key 2>/dev/null || true
  fi
fi

# SSL renewal cron
cat > /usr/local/bin/ssl_renew.sh << 'SSLEOF'
#!/bin/bash
/etc/init.d/nginx stop 2>/dev/null || true
"/root/.acme.sh/acme.sh" --cron --home "/root/.acme.sh" >> /root/renew_ssl.log 2>&1 || true
/etc/init.d/nginx start 2>/dev/null || true
SSLEOF
chmod +x /usr/local/bin/ssl_renew.sh
if ! grep -q 'ssl_renew.sh' /var/spool/cron/crontabs/root 2>/dev/null; then
  (crontab -l 2>/dev/null; echo "15 03 */3 * * /usr/local/bin/ssl_renew.sh") | crontab - 2>/dev/null || true
fi

mkdir -p /home/vps/public_html

# UUID
uuid=$(cat /proc/sys/kernel/random/uuid)

# Xray config
cat > /etc/xray/config.json << CFGEOF
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": 10085,
      "protocol": "dokodemo-door",
      "settings": {"address": "127.0.0.1"},
      "tag": "api"
    },
    {
      "listen": "/run/xray/vless_ws.sock",
      "protocol": "vless",
      "settings": {"decryption": "none", "clients": [{"id": "${uuid}"}]},
      "streamSettings": {"network": "ws", "wsSettings": {"path": "/vlessws"}}
    },
    {
      "listen": "/run/xray/vmess_ws.sock",
      "protocol": "vmess",
      "settings": {"clients": [{"id": "${uuid}", "alterId": 0}]},
      "streamSettings": {"network": "ws", "wsSettings": {"path": "/vmess"}}
    },
    {
      "listen": "/run/xray/trojan_ws.sock",
      "protocol": "trojan",
      "settings": {"clients": [{"password": "${uuid}"}], "udp": true},
      "streamSettings": {"network": "ws", "wsSettings": {"path": "/trojan-ws"}}
    },
    {
      "listen": "127.0.0.1",
      "port": 30300,
      "protocol": "shadowsocks",
      "settings": {
        "clients": [{"method": "aes-128-gcm", "password": "${uuid}"}],
        "network": "tcp,udp"
      },
      "streamSettings": {"network": "ws", "wsSettings": {"path": "/ss-ws"}}
    },
    {
      "listen": "/run/xray/vless_grpc.sock",
      "protocol": "vless",
      "settings": {"decryption": "none", "clients": [{"id": "${uuid}"}]},
      "streamSettings": {"network": "grpc", "grpcSettings": {"serviceName": "vless-grpc"}}
    },
    {
      "listen": "/run/xray/vmess_grpc.sock",
      "protocol": "vmess",
      "settings": {"clients": [{"id": "${uuid}", "alterId": 0}]},
      "streamSettings": {"network": "grpc", "grpcSettings": {"serviceName": "vmess-grpc"}}
    },
    {
      "listen": "/run/xray/trojan_grpc.sock",
      "protocol": "trojan",
      "settings": {"clients": [{"password": "${uuid}"}]},
      "streamSettings": {"network": "grpc", "grpcSettings": {"serviceName": "trojan-grpc"}}
    },
    {
      "listen": "127.0.0.1",
      "port": 30310,
      "protocol": "shadowsocks",
      "settings": {
        "clients": [{"method": "aes-128-gcm", "password": "${uuid}"}],
        "network": "tcp,udp"
      },
      "streamSettings": {"network": "grpc", "grpcSettings": {"serviceName": "ss-grpc"}}
    }
  ],
  "outbounds": [
    {"protocol": "freedom", "settings": {}},
    {"protocol": "blackhole", "settings": {}, "tag": "blocked"}
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "ip": ["0.0.0.0/8","10.0.0.0/8","100.64.0.0/10","169.254.0.0/16",
               "172.16.0.0/12","192.0.0.0/24","192.0.2.0/24","192.168.0.0/16",
               "198.18.0.0/15","198.51.100.0/24","203.0.113.0/24",
               "::1/128","fc00::/7","fe80::/10"],
        "outboundTag": "blocked"
      },
      {"inboundTag": ["api"], "outboundTag": "api", "type": "field"},
      {"type": "field", "outboundTag": "blocked", "protocol": ["bittorrent"]}
    ]
  },
  "stats": {},
  "api": {"services": ["StatsService"], "tag": "api"},
  "policy": {
    "levels": {"0": {"statsUserDownlink": true, "statsUserUplink": true}},
    "system": {
      "statsInboundUplink": true, "statsInboundDownlink": true,
      "statsOutboundUplink": true, "statsOutboundDownlink": true
    }
  }
}
CFGEOF

# Systemd service xray
rm -rf /etc/systemd/system/xray.service.d
cat > /etc/systemd/system/xray.service << 'SVCEOF'
[Unit]
Description=Xray Service
Documentation=https://github.com/xtls
After=network.target nss-lookup.target

[Service]
User=www-data
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
SVCEOF

cat > /etc/systemd/system/runn.service << 'RUNNEOF'
[Unit]
Description=Xray Socket Dir Setup
After=network.target

[Service]
Type=oneshot
ExecStartPre=-/usr/bin/mkdir -p /run/xray
ExecStart=/usr/bin/chown www-data:www-data /run/xray
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
RUNNEOF

# Nginx config untuk xray — gunakan heredoc proper
cat > /etc/nginx/conf.d/xray.conf << NGINXEOF
server {
    listen 80;
    listen [::]:80;
    listen 443 ssl http2 reuseport;
    listen [::]:443 ssl http2 reuseport;
    server_name $domain;
    ssl_certificate /etc/xray/xray.crt;
    ssl_certificate_key /etc/xray/xray.key;
    ssl_ciphers EECDH+CHACHA20:EECDH+ECDSA+AES128:EECDH+aRSA+AES128:RSA+AES128:EECDH+ECDSA+AES256:EECDH+aRSA+AES256:RSA+AES256:!MD5;
    ssl_protocols TLSv1.2 TLSv1.3;
    root /home/vps/public_html;

    location = /vlessws {
        proxy_redirect off;
        proxy_pass http://unix:/run/xray/vless_ws.sock;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }
    location = /vmess {
        proxy_redirect off;
        proxy_pass http://unix:/run/xray/vmess_ws.sock;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }
    location = /trojan-ws {
        proxy_redirect off;
        proxy_pass http://unix:/run/xray/trojan_ws.sock;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }
    location = /ss-ws {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:30300;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }
    location / {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:700;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }
    location ^~ /vless-grpc {
        proxy_redirect off;
        grpc_set_header X-Real-IP \$remote_addr;
        grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        grpc_set_header Host \$http_host;
        grpc_pass grpc://unix:/run/xray/vless_grpc.sock;
    }
    location ^~ /vmess-grpc {
        proxy_redirect off;
        grpc_set_header X-Real-IP \$remote_addr;
        grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        grpc_set_header Host \$http_host;
        grpc_pass grpc://unix:/run/xray/vmess_grpc.sock;
    }
    location ^~ /trojan-grpc {
        proxy_redirect off;
        grpc_set_header X-Real-IP \$remote_addr;
        grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        grpc_set_header Host \$http_host;
        grpc_pass grpc://unix:/run/xray/trojan_grpc.sock;
    }
    location ^~ /ss-grpc {
        proxy_redirect off;
        grpc_set_header X-Real-IP \$remote_addr;
        grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        grpc_set_header Host \$http_host;
        grpc_pass grpc://127.0.0.1:30310;
    }
}
NGINXEOF

# Install BBR
wget -qO /usr/bin/bbr "${BASE_URL}/ssh/bbr.sh" 2>/dev/null || true
if [[ -f /usr/bin/bbr ]]; then
  chmod +x /usr/bin/bbr
  bash /usr/bin/bbr >/dev/null 2>&1 || true
  rm -f /usr/bin/bbr
fi

# Reload & restart services
systemctl daemon-reload
systemctl enable xray >/dev/null 2>&1 || true
systemctl restart xray >/dev/null 2>&1 || true
systemctl restart nginx >/dev/null 2>&1 || true
systemctl enable runn >/dev/null 2>&1 || true
systemctl restart runn >/dev/null 2>&1 || true
service dropbear stop   >/dev/null 2>&1 || true
service dropbear start  >/dev/null 2>&1 || true

# Download helper scripts
wget -qO /usr/bin/auto-set "${BASE_URL}/xray/auto-set.sh" 2>/dev/null && chmod +x /usr/bin/auto-set || true
wget -qO /usr/bin/crtxray  "${BASE_URL}/xray/crt.sh"     2>/dev/null && chmod +x /usr/bin/crtxray  || true

# Pindahkan domain
[[ -f /root/domain ]] && mv /root/domain /etc/xray/ 2>/dev/null || true
rm -f /root/scdomain 2>/dev/null || true

clear
green "Xray berhasil diinstall!"
green "UUID: ${uuid}"
green "Domain: ${domain}"
rm -f /root/ins-xray.sh 2>/dev/null || true
