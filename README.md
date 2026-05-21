<div align="center">

<img src="https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main/assets/cyberpunk-typing.png" width="100%" alt="DevCulture VPS - Cyberpunk Hacker" />

<br/>

[![Typing SVG](https://readme-typing-svg.demolab.com?font=JetBrains+Mono&weight=700&size=28&pause=1000&color=A855F7&center=true&vCenter=true&width=600&lines=DevCulture+VPS+Store;Premium+SSH+%2B+WebSocket+Panel;Ubuntu+22.04+Ready;Auto+Update+%7C+Multi+Protocol)](https://git.io/typing-svg)

<br/>

![GitHub Stars](https://img.shields.io/github/stars/tuyulbodo99/devculture-vps?style=for-the-badge&color=a855f7&labelColor=0d0d0d)
![GitHub Forks](https://img.shields.io/github/forks/tuyulbodo99/devculture-vps?style=for-the-badge&color=7c3aed&labelColor=0d0d0d)
![Platform](https://img.shields.io/badge/Platform-Ubuntu%2022.04-a855f7?style=for-the-badge&logo=ubuntu&logoColor=white&labelColor=0d0d0d)
![Shell](https://img.shields.io/badge/Shell-Bash%205-7c3aed?style=for-the-badge&logo=gnubash&logoColor=white&labelColor=0d0d0d)
![License](https://img.shields.io/badge/License-MIT-a855f7?style=for-the-badge&labelColor=0d0d0d)

</div>

---

<div align="center">

### 🚀 ONE-CLICK INSTALL

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main/install.sh)
```

</div>

---

## 📦 Fitur Unggulan

<table>
<tr>
<td width="50%">

**🔐 SSH & WebSocket**
- OpenSSH (port 22)
- Dropbear (port 109, 143)
- SSH WebSocket HTTP (port 80)
- SSH SSL WebSocket HTTPS (port 443)
- Stunnel SSL Tunnel (port 777)

</td>
<td width="50%">

**⚡ Manajemen Akun**
- Buat / Hapus / Perpanjang akun SSH
- Output config WebSocket lengkap
- Log otomatis ke `/root/dc-ssh-accounts.log`
- Anti multi-login (max 2 sesi)
- Auto-delete akun expired

</td>
</tr>
<tr>
<td width="50%">

**🛡️ Keamanan & Performa**
- BBR TCP congestion control
- Fail2ban anti brute-force
- UFW firewall rules
- SSL/TLS auto-renewal (Let's Encrypt)
- IPv6 disabled by default

</td>
<td width="50%">

**🤖 Otomasi**
- Sistem cron auto-sync & update
- Telegram bot notifikasi
- Backup & restore data
- Sistem ijin/lisensi (github.com/tuyulbodo99/ijin)
- Xray VLESS / VMess / Trojan

</td>
</tr>
</table>

---

## 🛠️ Perintah Utama

### Install Full VPS
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main/install.sh)
```

### Buat Akun SSH + WebSocket
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main/ssh/adduser-ssh.sh)
```

### Install WebSocket Services
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main/websocket/insshws.sh)
```

### Setup SSH + Panel
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main/setup.sh)
```

### Auto Sync & Update Semua Script
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main/sync.sh)
```

### Install Dependencies
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main/dependencies.sh)
```

### Uninstall
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main/uninstall.sh)
```

---

## 🌐 Ekosistem DevCulture

| Repository | Fungsi | Install |
|------------|--------|---------|
| 🟣 [devculture-vps](https://github.com/tuyulbodo99/devculture-vps) | Core Panel + SSH + WebSocket | `install.sh` |
| 🟣 [hokagescript](https://github.com/tuyulbodo99/hokagescript) | Menu Layanan & Services | `setup.sh` |
| 🟣 [vpnscript](https://github.com/tuyulbodo99/vpnscript) | Full VPN Installer (OpenVPN, WireGuard) | `premi.sh` |
| 🟣 [vps-script](https://github.com/tuyulbodo99/vps-script) | SSH Tunnel Setup | `setup.sh` |
| 🟣 [ijin](https://github.com/tuyulbodo99/ijin) | Sistem Lisensi & Perizinan VPS | `check-ijin.sh` |

---

## 📱 Konfigurasi WebSocket (HTTP Injector / NPay / NetSpark)

```
Proxy Type   : SSH
SSH Host     : [IP VPS kamu]
SSH Port     : 22
SSH User     : [username]
SSH Pass     : [password]
Remote Proxy : 127.0.0.1:8080
Listen Port  : 8989

Payload:
GET wss://bug.com/ HTTP/1.1[crlf]
Host: bug.com[crlf]
Upgrade: websocket[crlf][crlf]
```

---

## 🖥️ Persyaratan Sistem

| Komponen | Minimum | Rekomendasi |
|----------|---------|-------------|
| OS | Ubuntu 20.04 | Ubuntu 22.04 LTS |
| RAM | 512 MB | 1 GB+ |
| Storage | 5 GB | 10 GB+ |
| CPU | 1 Core | 2 Core+ |
| Akses | Root | Root |

---

<div align="center">

**DevCulture VPS Store** · [github.com/tuyulbodo99](https://github.com/tuyulbodo99) · [@devculturebot](https://t.me/devculturebot)

![Footer](https://capsule-render.vercel.app/api?type=waving&color=a855f7&height=80&section=footer)

</div>
