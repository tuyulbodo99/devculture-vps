# DevCulture VPS

  **All-in-One VPS Script Installer** — Terintegrasi penuh, siap pakai.

  ## Cara Install (1 Perintah)

  ```bash
  bash <(curl -sSL https://raw.githubusercontent.com/tuyulbodo99/devculture-vps/main/install.sh)
  ```

  ## Fitur

  - SSH Tunneling (Dropbear + OpenSSH + WebSocket)
  - Xray (VMess, VLess, Trojan)
  - BBR Optimizer
  - VPN (OpenVPN + Stunnel)
  - Auto Backup & Restore
  - UDP Custom
  - Bandwidth Monitor
  - Menu Management System
  - Bot Integration
  - Multi-port support

  ## Struktur

  ```
  devculture-vps/
  ├── install.sh          # Entry point utama
  ├── dependencies.sh     # Install semua package
  ├── setup.sh            # Setup utama VPS
  ├── ssh/                # SSH & WebSocket scripts
  ├── xray/               # Xray installer & config
  ├── websocket/          # WebSocket proxy scripts
  ├── update/             # Menu & update scripts
  ├── backup/             # Backup & restore scripts
  ├── vpn/                # VPN scripts (OpenVPN, UDP)
  ├── config/             # Config files
  ├── addon/              # Addon scripts
  └── corn/               # Cron job scripts
  ```

  ## Requirement

  - OS: Ubuntu 20.04 / 22.04 / Debian 10 / 11
  - Akses root
  - VPS (bukan OpenVZ)

  ## Author

  - GitHub: [tuyulbodo99](https://github.com/tuyulbodo99)
  