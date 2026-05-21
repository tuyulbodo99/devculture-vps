<div align="center">

<img src="https://readme-typing-svg.demolab.com?font=JetBrains+Mono&weight=700&size=28&pause=1000&color=9B59B6&center=true&vCenter=true&width=700&lines=DevCulture+VPS;Premium+All-in-One+VPS+Suite;Built+by+tuyulbodo99" alt="Typing SVG" />

<br/>

[![Version](https://img.shields.io/badge/version-3.2.0-9b59b6?style=for-the-badge&logo=git&logoColor=white)](https://github.com/tuyulbodo99/devculture-vps)
[![Shell](https://img.shields.io/badge/shell-bash-1a1a2e?style=for-the-badge&logo=gnubash&logoColor=white)](https://github.com/tuyulbodo99/devculture-vps)
[![License](https://img.shields.io/badge/license-Private-6c3483?style=for-the-badge)](https://github.com/tuyulbodo99/devculture-vps)
[![OS](https://img.shields.io/badge/OS-Debian%20%7C%20Ubuntu-2c2c54?style=for-the-badge&logo=linux&logoColor=white)](https://github.com/tuyulbodo99/devculture-vps)
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

## 🟣 Overview

**DevCulture VPS** adalah script manajemen VPS premium all-in-one yang mendukung SSH, Xray (VMess/VLess/Trojan), WebSocket, OpenVPN, Telegram Bot, SSL otomatis, dan sistem sinkronisasi terpusat di seluruh ekosistem DevCulture.

---

## 🌐 Ekosistem DevCulture

> Semua repo terhubung dan disinkronkan melalui **Central Sync System**

| Repo | Fungsi | Status |
|------|--------|--------|
| [`devculture-vps`](https://github.com/tuyulbodo99/devculture-vps) | 🏠 Core — installer & panel utama | ✅ Active |
| [`hokagescript`](https://github.com/tuyulbodo99/hokagescript) | ⚙️ Menu & service scripts | ✅ Active |
| [`vpnscript`](https://github.com/tuyulbodo99/vpnscript) | 🔒 VPN installer lengkap | ✅ Active |
| [`vps-script`](https://github.com/tuyulbodo99/vps-script) | 🔧 SSH tunnel setup | ✅ Active |
| [`ijin`](https://github.com/tuyulbodo99/ijin) | 🛡️ License & permission system | ✅ Active |

---

## ⚡ Quick Install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main/install.sh)
```

### Sync & Update Semua Komponen

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main/sync.sh)
```

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
- Central auto-update harian
- Sinkronisasi antar semua repo
- Database ijin terpusat
- Version tracking

</td>
</tr>
</table>

---

## 🛠️ Menu Panel

```
devculture              → Buka panel interaktif
devculture status       → Status sistem & services
devculture restart      → Restart semua service
devculture update       → Update ke versi terbaru
devculture ssl          → Renew SSL certificate
devculture log          → Lihat log instalasi
```

---

## 🗂️ Struktur Repo

```
devculture-vps/
├── install.sh          # Installer utama
├── setup.sh            # Setup core (SSH + Xray + VPN)
├── devculture          # Panel management script
├── dependencies.sh     # Instalasi dependensi
├── sync.sh             # 🔗 Central sync system
├── uninstall.sh        # Uninstaller
├── lib/
│   └── utils.sh        # Shared utility functions
├── ssh/                # SSH & OpenVPN scripts
├── xray/               # Xray installation
├── bot/                # Telegram bot
├── ssl/                # SSL auto-renewal
├── udp/                # UDP support
├── vpn/                # VPN configs
├── websocket/          # WebSocket setup
├── update/             # Update scripts
└── backup/             # Backup & restore
```

---

## 📋 Sistem Ijin

Script ini menggunakan sistem lisensi berbasis IP. VPS Anda harus terdaftar di database:

```
tuyulbodo99/ijin → youtube (license database)
```

Hubungi admin untuk mendaftarkan VPS Anda.

---

## 🔧 Requirements

| Komponen | Versi |
|----------|-------|
| OS | Debian 10/11/12 · Ubuntu 20.04/22.04 |
| Akses | Root |
| RAM | Minimum 256 MB |
| Disk | Minimum 300 MB free |
| Network | IP Publik + Domain |

---

## 📞 Kontak

<div align="center">

[![Telegram](https://img.shields.io/badge/Telegram-@devculturebot-9b59b6?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/devculturebot)
[![GitHub](https://img.shields.io/badge/GitHub-tuyulbodo99-1a1a2e?style=for-the-badge&logo=github&logoColor=white)](https://github.com/tuyulbodo99)

</div>

---

<div align="center">
<sub>© 2024 DevCulture VPS Store · Built with 🟣 by <a href="https://github.com/tuyulbodo99">tuyulbodo99</a></sub>
</div>
