<div align="center">

<img src="https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main/assets/cyberpunk-typing.png" width="100%" alt="DevCulture VPS Store — DevCulture Cyberpunk" />

<br/>

[![Typing SVG](https://readme-typing-svg.demolab.com?font=JetBrains+Mono&weight=700&size=26&pause=1000&color=A855F7&center=true&vCenter=true&width=650&lines=DevCulture+VPS+Store;Premium+SSH+WebSocket+VPN+Panel;Ubuntu+22.04+%7C+Multi-Port+%7C+TCP+%2B+UDP)](https://git.io/typing-svg)

<br/>

![Stars](https://img.shields.io/github/stars/tuyulbodo99/devculture-vps?style=for-the-badge&color=a855f7&labelColor=0d0d0d)
![Platform](https://img.shields.io/badge/Ubuntu-22.04-a855f7?style=for-the-badge&logo=ubuntu&logoColor=white&labelColor=0d0d0d)
![Shell](https://img.shields.io/badge/Bash-5.x-7c3aed?style=for-the-badge&logo=gnubash&logoColor=white&labelColor=0d0d0d)
![TCP+UDP](https://img.shields.io/badge/Protocol-TCP%20%2B%20UDP-a855f7?style=for-the-badge&labelColor=0d0d0d)

</div>

---

<div align="center">

### 🚀 ONE-CLICK INSTALL

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main/install.sh)
```

</div>

---

## 📡 Port & Protokol

| # | Protokol | Port | Tipe |
|---|----------|------|------|
| 1 | OpenSSH | 22 | TCP |
| 2 | Dropbear | 109, 143 | TCP |
| 3 | SSH WebSocket | 80 | TCP |
| 4 | SSH SSL WebSocket | 443 | TCP |
| 5 | Stunnel (SSL Tunnel) | 777 | TCP |
| 6 | UDPGW / BadVPN | 7300 | **UDP** |
| 7 | SlowDNS | 5300 | **UDP** |
| 8 | OpenVPN | 1194 TCP / 2200 UDP | TCP+UDP |

---

## 🔗 Format Connection String

```
user@pass:host:port

Contoh per protokol:
  devculture@pass:host:22      → OpenSSH
  devculture@pass:host:109     → Dropbear
  devculture@pass:host:143     → Dropbear Alt
  devculture@pass:host:80      → SSH WebSocket
  devculture@pass:host:443     → SSH SSL/WSS
  devculture@pass:host:777     → Stunnel
  devculture@pass:host:7300    → UDPGW (UDP)
  devculture@pass:host:5300    → SlowDNS (UDP)

KPN Tunnel / VNPK:
  devculture@pass:host:22:udp:7300

SlowDNS format:
  devculture@pass:host:5300:dns:ns1.devculture.id
```

---

## 📱 Config HTTP Injector / NPay / NetSpark

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

> Alt Payload (CONNECT mode):
> ```
> CONNECT [IP VPS]:22 HTTP/1.1[crlf]
> Host: bug.com[crlf][crlf]
> ```

---

## 🌐 Config SlowDNS / DNS Tunnel

```
Mode         : DNS Tunnel
DNS Server   : [IP VPS kamu]
DNS Port     : 5300 (UDP)
Nameserver   : ns1.devculture.id
SSH Host     : [IP VPS kamu]
SSH Port     : 22
Username     : [username]
Password     : [password]
UDPGW        : [IP VPS]:7300
```

---

## ⚡ Config KPN Tunnel / OpenTunnel / VNPK

```
Mode         : SSH + UDP
SSH Server   : [IP VPS kamu]
SSH Port     : 22
SSH User     : [username]
SSH Pass     : [password]
UDPGW Host   : [IP VPS kamu]
UDPGW Port   : 7300 (UDP)
```

---

## 📦 Fitur Tambahan

- Buat akun SSH + tampil semua config otomatis
- Auto-delete akun expired (cron)
- Backup & restore data
- Xray VLESS / VMess / Trojan
- Telegram bot notifikasi
- Sistem ijin/lisensi berbasis GitHub



## 🛠️ Perintah Utama

```bash
# Install
bash <(curl -fsSL https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main/install.sh)

# SSH langsung semua port
ssh user@host -p 22    # OpenSSH
ssh user@host -p 109   # Dropbear
ssh user@host -p 80    # WebSocket HTTP
ssh user@host -p 443   # WebSocket SSL
ssh user@host -p 777   # Stunnel

# BadVPN UDPGW (aktifkan UDP di VPS)
badvpn-udpgw --listen-addr 127.0.0.1:7300
```

---

## 🌐 Ekosistem DevCulture

| Repo | Fungsi | Install |
|------|--------|---------|
| 🟣 [devculture-vps](https://github.com/tuyulbodo99/devculture-vps) | Core Panel SSH + WebSocket | `install.sh` |
| 🟣 [hokagescript](https://github.com/tuyulbodo99/hokagescript) | Menu Layanan & Services | `setup.sh` |
| 🟣 [vpnscript](https://github.com/tuyulbodo99/vpnscript) | Full VPN (OpenVPN+WG+SlowDNS) | `premi.sh` |
| 🟣 [vps-script](https://github.com/tuyulbodo99/vps-script) | SSH Tunnel Setup | `setup.sh` |
| 🟣 [ijin](https://github.com/tuyulbodo99/ijin) | Sistem Lisensi & Perizinan | `check-ijin.sh` |

---

## 🖥️ Persyaratan

| OS | RAM | Storage | Akses |
|----|-----|---------|-------|
| Ubuntu 20.04 / 22.04 LTS | Min 512 MB | Min 5 GB | Root |

---

<div align="center">

**DevCulture VPS Store** · [github.com/tuyulbodo99](https://github.com/tuyulbodo99) · [@devculturebot](https://t.me/devculturebot)

![Footer](https://capsule-render.vercel.app/api?type=waving&color=a855f7&height=80&section=footer)

</div>
