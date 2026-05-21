# Changelog — DevCulture VPS Scripts

Semua perubahan signifikan pada script VPS ini didokumentasikan di sini.
Format: `[YYYY-MM-DD]` · Repo yang terdampak · Deskripsi singkat

---

## [2026-05-21] — Perbaikan Massal (Bug Fix Release)

### devculture-vps

| File | Bug | Perbaikan |
|------|-----|-----------|
| `setup.sh` | Download dari `tuyulbodo99/original` (repo tidak ada, 404) | Ganti ke `devculture-vps/main` + gunakan `safe_dl()` |
| `ssh/ssh-vpn.sh` | `sed -i 's/PasswordAuthentication no/.../g'` tanpa nama file target | Tambahkan `/etc/ssh/sshd_config` sebagai argumen |
| `ssh/ssh-vpn.sh` | Variable `$ANU` tidak terdefinisi di deteksi interface | Ganti dengan `ip -o -4 route show to default` |
| `xray/ins-xray.sh` | Variable `$ANU` tidak terdefinisi | Dihapus, deteksi interface dibenahi |
| `xray/ins-xray.sh` | Nginx config pakai `sed -i '$ i...'` berulang (rapuh) | Diganti heredoc proper |
| `xray/ins-xray.sh` | Referensi ke `ijin/original` untuk permission check | Dihapus |
| `update/update.sh` | Semua wget dari `tuyulbodo99/original` | Ganti ke `devculture-vps/main` |
| `update/update-devculture.sh` | Path install tidak konsisten | Perbaiki ke `/usr/local/sbin/` + tambah semua menu |
| `update/menu.sh` | `check_license` dan `PERMISSION` dipanggil — fungsi tidak terdefinisi | Dihapus, diganti logika mandiri |
| `update/menu.sh` | `updatews()` download dari `tuyulbodo99/original` | Ganti ke `devculture-vps/main` |

### hokagescript

| File | Bug | Perbaikan |
|------|-----|-----------|
| `ssh/ssh-vpn.sh` | Variable `$ANU` tidak terdefinisi | Hapus `$ANU`, pakai `ip -o -4 route` |
| `ssh/ssh-vpn.sh` | `sed -i 's/PasswordAuthentication...'` tanpa nama file | Tambahkan `/etc/ssh/sshd_config` |
| `ssh/ssh-vpn.sh` | Download dari `hokagelegend9999/original` (tidak ada) | Ganti ke `hokagescript/main` |
| `ssh/ssh-vpn.sh` | Section `[dropbear]` duplikat di stunnel.conf | Ganti section pertama ke `[openssh]` |
| `setup.sh` | `PERMISSION` dipanggil — fungsi tidak terdefinisi | Dihapus |
| `setup.sh` | Download dari `hokagelegend9999/original` (tidak ada) | Ganti ke `hokagescript/main` |

---

## [2026-05-21] — Infrastruktur Otomatis

### devculture-vps

- Tambah `sync.sh` — sinkronisasi perbaikan ke repo VPS lain via GitHub API
- Tambah `.github/workflows/sync.yml` — auto-sync ke `hokagescript` setiap push ke `main`
- Setup `SYNC_TOKEN` sebagai repo secret untuk GitHub Actions

---

*Log ini diperbarui otomatis oleh GitHub Actions sync workflow.*
*Untuk melihat semua commit: [github.com/tuyulbodo99/devculture-vps/commits](https://github.com/tuyulbodo99/devculture-vps/commits/main)*
