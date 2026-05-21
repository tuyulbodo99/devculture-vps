<div align="center">

<img src="https://readme-typing-svg.demolab.com?font=JetBrains+Mono&weight=700&size=28&pause=1000&color=9B59B6&center=true&vCenter=true&width=700&lines=DevCulture+VPS;Premium+All-in-One+VPS+Suite;Built+by+tuyulbodo99" alt="Typing SVG" />

<br/>

[![Version](https://img.shields.io/badge/version-3.2.0-9b59b6?style=for-the-badge&logo=git&logoColor=white)](https://github.com/tuyulbodo99/devculture-vps)
[![Shell](https://img.shields.io/badge/shell-bash-1a1a2e?style=for-the-badge&logo=gnubash&logoColor=white)](https://github.com/tuyulbodo99/devculture-vps)
[![OS](https://img.shields.io/badge/OS-Ubuntu%20%7C%20Debian-2c2c54?style=for-the-badge&logo=linux&logoColor=white)](https://github.com/tuyulbodo99/devculture-vps)
[![Sync](https://img.shields.io/badge/ecosystem-connected-5b2c6f?style=for-the-badge&logo=githubactions&logoColor=white)](https://github.com/tuyulbodo99)

```
██████╗ ███████╗██╗   ██╗ ██████╗██╗   ██╗██╗  ████████╗██╗   ██╗██████╗ ███████╗
██╔══██╗██╔════╝██║   ██║██╔════╝██║   ██║██║  ╚══██╔══╝██║   ██║██╔══██╗██╔════╝
██║  ██║█████╗  ██║   ██║██║     ██║   ██║██║     ██║   ██║   ██║██████╔╝█████╗
██║  ██║██╔══╝  ╚██╗ ██╔╝██║     ██║   ██║██║     ██║   ██║   ██║██╔══██╗██╔══╝
██████╔╝███████╗ ╚████╔╝ ╚██████╗╚██████╔╝███████╗██║   ╚██████╔╝██║  ██║███████╗
╚═════╝ ╚══════╝  ╚═══╝   ╚═════╝ ╚═════╝ ╚══════╝╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝
```

**Premium VPS Management Suite — Powerful. Automated. Yours.**

</div>

---

## ⚡ Install — Satu Perintah, Langsung Jalan

> **Copy → Paste → Enter. Selesai.**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main/install.sh)
```

### 🔄 Sync & Update Semua Komponen

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main/sync.sh)
```

### 🛡️ Kelola Database Ijin (Admin)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tuyulbodo99/ijin/main/check-ijin.sh)
```

---

## 🟣 Overview

**DevCulture VPS** adalah script manajemen VPS premium all-in-one yang mendukung SSH, Xray (VMess/VLess/Trojan), WebSocket, OpenVPN, Telegram Bot, SSL otomatis, dan sistem sinkronisasi terpusat di seluruh ekosistem DevCulture.

---

## 🌐 Ekosistem DevCulture

> Semua repo terhubung dan disinkronkan otomatis via **Central Sync System**

| Repo | Fungsi | One-Click Install |
|------|--------|-------------------|
| [`devculture-vps`](https://github.com/tuyulbodo99/devculture-vps) | 🏠 Core — installer & panel utama | `bash <(curl -fsSL https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main/install.sh)` |
| [`hokagescript`](https://github.com/tuyulbodo99/hokagescript) | ⚙️ Menu & service scripts | `bash <(curl -fsSL https://raw.githubusercontent.com/tuyulbodo99/hokagescript/main/setup.sh)` |
| [`vpnscript`](https://github.com/tuyulbodo99/vpnscript) | 🔒 VPN installer lengkap | `bash <(curl -fsSL https://raw.githubusercontent.com/tuyulbodo99/vpnscript/main/premi.sh)` |
| [`vps-script`](https://github.com/tuyulbodo99/vps-script) | 🔧 SSH tunnel setup | `bash <(curl -fsSL https://raw.githubusercontent.com/tuyulbodo99/vps-script/main/install)` |
| [`ijin`](https://github.com/tuyulbodo99/ijin) | 🛡️ License & permission DB | `bash <(curl -fsSL https://raw.githubusercontent.com/tuyulbodo99/ijin/main/check-ijin.sh)` |

---

## 📦 Fitur Utama

<table>
<tr>
<td width="50%">

### 🔐 Protokol
- SSH + WebSocket (port 80/443)
- SSH SSL WebSocket
- Dropbear (port 109/143)
- Stunnel4 (port 447/777)
- OpenVPN UDP

</td>
<td width="50%">

### 🚀 Xray Core
- VMess TLS / Non-TLS
- VLess TLS / Non-TLS
- Trojan WS + gRPC
- Shadowsocks GRPC

</td>
</tr>
<tr>
<td>

### 🤖 Automation
- Telegram Bot Manager
- Auto SSL Renewal (Certbot)
- Auto-Reboot Scheduler
- Auto Kill Multi Login
- Auto Delete Expired User

</td>
<td>

### 🔄 Sync System
- Central auto-update harian (03:00)
- Sinkronisasi antar semua repo
- Database ijin terpusat
- Log di `/var/log/devculture-sync.log`

</td>
</tr>
</table>

---

## 🛠️ Perintah Panel

```bash
devculture              # Buka panel interaktif
devculture status       # Status sistem & services
devculture restart      # Restart semua service
devculture update       # Update ke versi terbaru
devculture ssl          # Renew SSL certificate
devculture log          # Lihat log instalasi
```

---

## 🗂️ Struktur Repo

```
devculture-vps/
├── install.sh          # 🚀 Installer utama (one-click)
├── setup.sh            # Setup core (SSH + Xray + VPN)
├── sync.sh             # 🔗 Central sync system
├── devculture          # Panel management script
├── uninstall.sh        # Uninstaller
├── lib/                # Shared utilities
├── ssh/                # SSH & Dropbear scripts
├── xray/               # Xray installation
├── bot/                # Telegram bot
├── ssl/                # SSL auto-renewal
├── vpn/                # VPN configs
├── websocket/          # WebSocket setup
└── update/             # Update scripts
```

---

## 🔧 Requirements

| Komponen | Keterangan |
|----------|------------|
| OS | Debian 10/11/12 · Ubuntu 20.04/22.04 |
| Akses | **Root** (`sudo` atau `su -`) |
| RAM | Min. 256 MB |
| Disk | Min. 300 MB free |
| Network | IP Publik + Domain |

---

<div align="center">

[![Telegram](https://img.shields.io/badge/Order%20%26%20Support-@devculturebot-9b59b6?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/devculturebot)
[![GitHub](https://img.shields.io/badge/GitHub-tuyulbodo99-1a1a2e?style=for-the-badge&logo=github&logoColor=white)](https://github.com/tuyulbodo99)

<sub>© 2024 DevCulture VPS Store · Built with 🟣 by <a href="https://github.com/tuyulbodo99">tuyulbodo99</a></sub>

</div>
