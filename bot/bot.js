#!/usr/bin/env node
  // ============================================================
  //   DevCulture VPS - Telegram Bot SSH Manager
  //   Bot: @devculturebot
  //   Repo: https://github.com/tuyulbodo99/devculture-vps
  // ============================================================

  const https = require('https');
  const { execSync, exec } = require('child_process');
  const fs = require('fs');
  const path = require('path');

  const BOT_TOKEN = process.env.BOT_TOKEN || require('/etc/devculture/config.json').bot_token;
  const ADMIN_ID  = process.env.ADMIN_ID  || require('/etc/devculture/config.json').admin_id;
  const DB_FILE   = '/etc/devculture/users.json';

  // ---- Helpers ----
  function tgApi(method, params = {}) {
    return new Promise((resolve, reject) => {
      const data = JSON.stringify(params);
      const req = https.request({
        hostname: 'api.telegram.org',
        path: `/bot${BOT_TOKEN}/${method}`,
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data) }
      }, res => {
        let d = '';
        res.on('data', c => d += c);
        res.on('end', () => resolve(JSON.parse(d)));
      });
      req.on('error', reject);
      req.write(data);
      req.end();
    });
  }

  function send(chatId, text, extra = {}) {
    return tgApi('sendMessage', { chat_id: chatId, text, parse_mode: 'HTML', ...extra });
  }

  function runCmd(cmd) {
    try { return execSync(cmd, { encoding: 'utf8', timeout: 15000 }).trim(); }
    catch(e) { return e.message; }
  }

  // ---- DB users ----
  function loadDB() {
    if (!fs.existsSync(DB_FILE)) return { users: [] };
    return JSON.parse(fs.readFileSync(DB_FILE, 'utf8'));
  }
  function saveDB(db) { fs.writeFileSync(DB_FILE, JSON.stringify(db, null, 2)); }

  function addUser(user, pass, exp, quota) {
    // Create linux user
    runCmd(`useradd -e ${exp} -s /bin/false -M ${user} 2>/dev/null || true`);
    runCmd(`echo "${user}:${pass}" | chpasswd`);
    const db = loadDB();
    db.users = db.users.filter(u => u.user !== user);
    db.users.push({ user, pass, exp, quota, created: new Date().toISOString() });
    saveDB(db);
  }

  function delUser(user) {
    runCmd(`userdel -r ${user} 2>/dev/null || true`);
    const db = loadDB();
    db.users = db.users.filter(u => u.user !== user);
    saveDB(db);
  }

  function listUsers() {
    const db = loadDB();
    return db.users;
  }

  function getUserOnline(user) {
    const result = runCmd(`who | grep ${user} | wc -l`);
    return parseInt(result) || 0;
  }

  function getServerInfo() {
    const ip    = runCmd("curl -s ipv4.icanhazip.com 2>/dev/null || hostname -I | awk '{print $1}'");
    const os    = runCmd("cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"'");
    const up    = runCmd("uptime -p");
    const mem   = runCmd("free -m | awk '/Mem:/{printf \"%.0f/%.0fMB\", $3, $2}'");
    const disk  = runCmd("df -h / | awk 'NR==2{printf \"%s/%s\", $3, $2}'");
    const cpu   = runCmd("top -bn1 | grep 'Cpu(s)' | awk '{print $2+$4\"% used\"}'");
    const domain = runCmd("cat /etc/xray/domain 2>/dev/null || echo 'N/A'");
    return { ip, os, up, mem, disk, cpu, domain };
  }

  // ---- State ----
  const state = {}; // { chatId: { step, data } }

  // ---- Keyboards ----
  const mainMenu = {
    inline_keyboard: [
      [{ text: '👤 Tambah SSH', callback_data: 'add_ssh' }, { text: '🗑 Hapus SSH', callback_data: 'del_ssh' }],
      [{ text: '📋 List User',  callback_data: 'list_ssh' }, { text: '🔍 Cek User',  callback_data: 'cek_ssh' }],
      [{ text: '🖥 Info Server', callback_data: 'server_info' }, { text: '🔄 Restart Services', callback_data: 'restart_svc' }],
      [{ text: '🔑 SSL Renew',  callback_data: 'ssl_renew' },  { text: '📊 Bandwidth', callback_data: 'bandwidth' }]
    ]
  };

  // ---- Handlers ----
  async function handleMessage(msg) {
    const chatId = msg.chat.id.toString();
    const text   = msg.text || '';

    // Auth check
    if (chatId !== ADMIN_ID.toString()) {
      return send(chatId, '❌ Akses ditolak. Anda bukan admin.');
    }

    const st = state[chatId];

    // Handle wizard steps
    if (st) {
      if (st.step === 'add_user') {
        st.data.user = text.trim();
        st.step = 'add_pass';
        return send(chatId, '🔑 Masukkan password:');
      }
      if (st.step === 'add_pass') {
        st.data.pass = text.trim();
        st.step = 'add_exp';
        return send(chatId, '📅 Masa aktif (hari, contoh: 30):');
      }
      if (st.step === 'add_exp') {
        const days = parseInt(text.trim());
        const expDate = new Date();
        expDate.setDate(expDate.getDate() + days);
        st.data.exp = expDate.toISOString().split('T')[0];
        st.step = 'add_quota';
        return send(chatId, '📦 Quota (GB, contoh: 10, atau 0 untuk unlimited):');
      }
      if (st.step === 'add_quota') {
        st.data.quota = text.trim();
        delete state[chatId];
        try {
          addUser(st.data.user, st.data.pass, st.data.exp, st.data.quota);
          const info = getServerInfo();
          const msg = `✅ <b>Akun SSH Berhasil Dibuat</b>

  👤 Username : <code>${st.data.user}</code>
  🔑 Password : <code>${st.data.pass}</code>
  📅 Expired  : <code>${st.data.exp}</code>
  📦 Quota    : <code>${st.data.quota} GB</code>
  🌐 IP/Domain: <code>${info.ip}</code>

  🔌 <b>Ports:</b>
  • SSH        : 22
  • Dropbear   : 443, 80
  • WebSocket  : 80, 443
  • OpenSSH WS : 2082`;
          return send(chatId, msg);
        } catch(e) {
          return send(chatId, `❌ Gagal membuat akun: ${e.message}`);
        }
      }
      if (st.step === 'del_user') {
        const user = text.trim();
        delete state[chatId];
        delUser(user);
        return send(chatId, `✅ User <code>${user}</code> berhasil dihapus.`);
      }
      if (st.step === 'cek_user') {
        const user = text.trim();
        delete state[chatId];
        const db = loadDB();
        const u = db.users.find(x => x.user === user);
        if (!u) return send(chatId, `❌ User <code>${user}</code> tidak ditemukan.`);
        const online = getUserOnline(user);
        return send(chatId, `📋 <b>Info User</b>

  👤 Username : <code>${u.user}</code>
  📅 Expired  : <code>${u.exp}</code>
  📦 Quota    : <code>${u.quota} GB</code>
  🟢 Online   : <code>${online} sesi</code>
  📆 Dibuat   : <code>${u.created}</code>`);
      }
    }

    if (text === '/start' || text === '/menu') {
      return send(chatId, '🖥 <b>DevCulture VPS Manager</b>\nPilih menu:', { reply_markup: mainMenu });
    }

    return send(chatId, '⚙️ Ketik /menu untuk membuka panel.', { reply_markup: mainMenu });
  }

  async function handleCallback(cb) {
    const chatId = cb.message.chat.id.toString();
    const data   = cb.data;
    await tgApi('answerCallbackQuery', { callback_query_id: cb.id });

    if (chatId !== ADMIN_ID.toString()) {
      return send(chatId, '❌ Akses ditolak.');
    }

    if (data === 'add_ssh') {
      state[chatId] = { step: 'add_user', data: {} };
      return send(chatId, '👤 Masukkan username SSH baru:');
    }
    if (data === 'del_ssh') {
      state[chatId] = { step: 'del_user' };
      return send(chatId, '🗑 Masukkan username yang ingin dihapus:');
    }
    if (data === 'list_ssh') {
      const users = listUsers();
      if (!users.length) return send(chatId, '📋 Belum ada user SSH.');
      let text = '📋 <b>Daftar User SSH</b>\n\n';
      users.forEach((u, i) => {
        const online = getUserOnline(u.user);
        text += `${i+1}. <code>${u.user}</code> | exp: ${u.exp} | ${online > 0 ? '🟢 online' : '🔴 offline'}\n`;
      });
      return send(chatId, text);
    }
    if (data === 'cek_ssh') {
      state[chatId] = { step: 'cek_user' };
      return send(chatId, '🔍 Masukkan username yang ingin dicek:');
    }
    if (data === 'server_info') {
      const s = getServerInfo();
      return send(chatId, `🖥 <b>Server Info</b>

  🌐 IP      : <code>${s.ip}</code>
  🌍 Domain  : <code>${s.domain}</code>
  💻 OS      : <code>${s.os}</code>
  ⏱ Uptime  : <code>${s.up}</code>
  💾 RAM     : <code>${s.mem}</code>
  💿 Disk    : <code>${s.disk}</code>
  🔥 CPU     : <code>${s.cpu}</code>`);
    }
    if (data === 'restart_svc') {
      runCmd('systemctl restart ssh dropbear nginx xray haproxy 2>/dev/null || true');
      return send(chatId, '✅ Services berhasil direstart:\n• SSH\n• Dropbear\n• Nginx\n• Xray\n• Haproxy');
    }
    if (data === 'ssl_renew') {
      send(chatId, '🔄 Memulai SSL renewal...');
      exec('bash /usr/local/bin/ssl-renew.sh renew', (err, stdout, stderr) => {
        const result = stdout || stderr || (err ? err.message : 'selesai');
        send(chatId, `🔑 <b>SSL Renewal Result:</b>\n<code>${result.slice(0, 3000)}</code>`);
      });
      return;
    }
    if (data === 'bandwidth') {
      const bw = runCmd("vnstat --oneline 2>/dev/null | awk -F';' '{print \"RX: \"$4\" TX: \"$5\" Total: \"$6}'") || 
                 runCmd("cat /sys/class/net/*/statistics/rx_bytes 2>/dev/null | head -1");
      return send(chatId, `📊 <b>Bandwidth</b>\n<code>${bw}</code>`);
    }

    return send(chatId, '⚙️ Pilih menu:', { reply_markup: mainMenu });
  }

  // ---- Polling ----
  let offset = 0;
  async function poll() {
    try {
      const res = await tgApi('getUpdates', { offset, timeout: 30, limit: 10 });
      if (res.ok && res.result.length) {
        for (const update of res.result) {
          offset = update.update_id + 1;
          if (update.message)        await handleMessage(update.message).catch(console.error);
          if (update.callback_query) await handleCallback(update.callback_query).catch(console.error);
        }
      }
    } catch(e) {
      console.error('Poll error:', e.message);
      await new Promise(r => setTimeout(r, 5000));
    }
    poll();
  }

  console.log('🤖 DevCulture Bot started...');
  poll();
  