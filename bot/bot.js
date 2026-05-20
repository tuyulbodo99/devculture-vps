#!/usr/bin/env node
  // ============================================================
  //   DevCulture VPS - Telegram Bot SSH Manager
  //   Bot: @devculturebot
  //   Admin Chat ID: 7451969762
  //   Repo: https://github.com/tuyulbodo99/devculture-vps
  // ============================================================

  const https = require('https');
  const { execSync, exec } = require('child_process');
  const fs   = require('fs');

  // Config - bisa dari file atau env
  let BOT_TOKEN = process.env.BOT_TOKEN || '';
  let ADMIN_ID  = process.env.ADMIN_ID  || '';

  try {
    const cfg = JSON.parse(fs.readFileSync('/etc/devculture/config.json', 'utf8'));
    if (!BOT_TOKEN) BOT_TOKEN = cfg.bot_token;
    if (!ADMIN_ID)  ADMIN_ID  = String(cfg.admin_id);
  } catch(e) {}

  const DB_FILE = '/etc/devculture/users.json';

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
        res.on('end', () => { try { resolve(JSON.parse(d)); } catch(e) { resolve({}); } });
      });
      req.on('error', () => resolve({}));
      req.write(data);
      req.end();
    });
  }

  function send(chatId, text, extra = {}) {
    return tgApi('sendMessage', { chat_id: chatId, text, parse_mode: 'HTML', ...extra });
  }

  function runCmd(cmd) {
    try { return execSync(cmd, { encoding: 'utf8', timeout: 15000 }).trim(); }
    catch(e) { return e.stderr || e.message || 'error'; }
  }

  // ---- DB ----
  function loadDB() {
    if (!fs.existsSync(DB_FILE)) return { users: [] };
    try { return JSON.parse(fs.readFileSync(DB_FILE, 'utf8')); } catch(e) { return { users: [] }; }
  }
  function saveDB(db) {
    fs.mkdirSync('/etc/devculture', { recursive: true });
    fs.writeFileSync(DB_FILE, JSON.stringify(db, null, 2));
  }

  function addUser(user, pass, exp, quota) {
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

  function getUserOnline(user) {
    const r = runCmd(`who 2>/dev/null | grep -w "${user}" | wc -l`);
    return parseInt(r) || 0;
  }

  function getServerInfo() {
    return {
      ip:     runCmd("curl -s --max-time 5 ipv4.icanhazip.com 2>/dev/null || hostname -I | awk '{print $1}'"),
      os:     runCmd("cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '"'"),
      up:     runCmd("uptime -p 2>/dev/null"),
      mem:    runCmd("free -m 2>/dev/null | awk '/Mem:/{printf \"%.0f/%.0fMB\", $3, $2}'"),
      disk:   runCmd("df -h / 2>/dev/null | awk 'NR==2{printf \"%s/%s\", $3, $2}'"),
      cpu:    runCmd("top -bn1 2>/dev/null | grep 'Cpu' | awk '{print $2+$4\"% used\"}'"),
      domain: runCmd("cat /etc/xray/domain 2>/dev/null || echo 'N/A'")
    };
  }

  // ---- State ----
  const state = {};

  // ---- Keyboards ----
  const mainMenu = {
    inline_keyboard: [
      [{ text: '➕ Tambah SSH', callback_data: 'add_ssh' },   { text: '🗑 Hapus SSH', callback_data: 'del_ssh' }],
      [{ text: '📋 List User',  callback_data: 'list_ssh' },  { text: '🔍 Cek User',  callback_data: 'cek_ssh' }],
      [{ text: '🖥 Info Server',callback_data: 'server_info' },{ text: '🔄 Restart',  callback_data: 'restart_svc' }],
      [{ text: '🔑 SSL Renew',  callback_data: 'ssl_renew' }, { text: '📊 Bandwidth', callback_data: 'bandwidth' }]
    ]
  };

  // ---- Message Handler ----
  async function handleMessage(msg) {
    const chatId = String(msg.chat.id);
    const text   = msg.text || '';
    if (chatId !== String(ADMIN_ID)) return send(chatId, '❌ Akses ditolak.');

    const st = state[chatId];

    if (st) {
      if (st.step === 'add_user') { st.data.user = text.trim(); st.step = 'add_pass'; return send(chatId, '🔑 Masukkan password:'); }
      if (st.step === 'add_pass') { st.data.pass = text.trim(); st.step = 'add_exp';  return send(chatId, '📅 Masa aktif (hari, contoh: 30):'); }
      if (st.step === 'add_exp') {
        const days = parseInt(text.trim()) || 30;
        const d = new Date(); d.setDate(d.getDate() + days);
        st.data.exp = d.toISOString().split('T')[0];
        st.step = 'add_quota';
        return send(chatId, '📦 Quota GB (0 = unlimited):');
      }
      if (st.step === 'add_quota') {
        st.data.quota = text.trim();
        delete state[chatId];
        try {
          addUser(st.data.user, st.data.pass, st.data.exp, st.data.quota);
          const info = getServerInfo();
          return send(chatId, `✅ <b>Akun SSH Dibuat</b>

  👤 Username  : <code>${st.data.user}</code>
  🔑 Password  : <code>${st.data.pass}</code>
  📅 Expired   : <code>${st.data.exp}</code>
  📦 Quota     : <code>${st.data.quota} GB</code>
  🌐 Host      : <code>${info.ip}</code>

  🔌 <b>Ports:</b>
  • SSH         : 22
  • Dropbear    : 443, 80
  • WebSocket   : 80, 443
  • OpenSSH WS  : 2082`);
        } catch(e) { return send(chatId, `❌ Error: ${e.message}`); }
      }
      if (st.step === 'del_user') {
        const u = text.trim(); delete state[chatId];
        delUser(u);
        return send(chatId, `✅ User <code>${u}</code> dihapus.`);
      }
      if (st.step === 'cek_user') {
        const u = text.trim(); delete state[chatId];
        const db = loadDB();
        const found = db.users.find(x => x.user === u);
        if (!found) return send(chatId, `❌ User <code>${u}</code> tidak ditemukan.`);
        const online = getUserOnline(u);
        return send(chatId, `📋 <b>Info User</b>

  👤 Username : <code>${found.user}</code>
  📅 Expired  : <code>${found.exp}</code>
  📦 Quota    : <code>${found.quota} GB</code>
  🟢 Online   : <code>${online} sesi</code>
  📆 Dibuat   : <code>${found.created}</code>`);
      }
    }

    if (text === '/start' || text === '/menu') {
      return send(chatId,
        '🖥 <b>DevCulture VPS Manager</b>\n' +
        '━━━━━━━━━━━━━━━━━━━━\n' +
        'Selamat datang! Pilih menu di bawah:',
        { reply_markup: mainMenu }
      );
    }
    return send(chatId, '⚙️ Ketik /menu untuk membuka panel.', { reply_markup: mainMenu });
  }

  // ---- Callback Handler ----
  async function handleCallback(cb) {
    const chatId = String(cb.message.chat.id);
    const data   = cb.data;
    await tgApi('answerCallbackQuery', { callback_query_id: cb.id });
    if (chatId !== String(ADMIN_ID)) return send(chatId, '❌ Akses ditolak.');

    if (data === 'add_ssh') { state[chatId] = { step: 'add_user', data: {} }; return send(chatId, '👤 Masukkan username SSH baru:'); }
    if (data === 'del_ssh') { state[chatId] = { step: 'del_user' }; return send(chatId, '🗑 Masukkan username yang ingin dihapus:'); }
    if (data === 'cek_ssh') { state[chatId] = { step: 'cek_user' }; return send(chatId, '🔍 Masukkan username yang ingin dicek:'); }
    if (data === 'list_ssh') {
      const users = loadDB().users;
      if (!users.length) return send(chatId, '📋 Belum ada user SSH.');
      let text = '📋 <b>Daftar User SSH</b>\n━━━━━━━━━━━━━━━\n';
      users.forEach((u, i) => {
        const online = getUserOnline(u.user);
        text += `${i+1}. <code>${u.user}</code> | exp: ${u.exp} | ${online > 0 ? '🟢' : '🔴'}\n`;
      });
      return send(chatId, text);
    }
    if (data === 'server_info') {
      const s = getServerInfo();
      return send(chatId, `🖥 <b>Server Info</b>
  ━━━━━━━━━━━━━━━
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
      return send(chatId, '✅ Services direstart:\n• SSH • Dropbear • Nginx • Xray • Haproxy');
    }
    if (data === 'ssl_renew') {
      send(chatId, '🔄 Memulai SSL renewal...');
      exec('bash /usr/local/bin/ssl-renew.sh renew 2>&1', (err, stdout) => {
        const r = (stdout || (err ? err.message : 'selesai')).slice(0, 3000);
        send(chatId, `🔑 <b>SSL Result:</b>\n<code>${r}</code>`);
      });
      return;
    }
    if (data === 'bandwidth') {
      const bw = runCmd("vnstat --oneline 2>/dev/null | awk -F';' '{print \"RX: \"$4\" | TX: \"$5\" | Total: \"$6}'") || 'vnstat tidak tersedia';
      return send(chatId, `📊 <b>Bandwidth</b>\n<code>${bw}</code>`);
    }
    return send(chatId, '⚙️ Pilih menu:', { reply_markup: mainMenu });
  }

  // ---- Polling ----
  let offset = 0;
  async function poll() {
    try {
      const res = await tgApi('getUpdates', { offset, timeout: 30, limit: 10 });
      if (res.ok && res.result && res.result.length) {
        for (const update of res.result) {
          offset = update.update_id + 1;
          if (update.message)        handleMessage(update.message).catch(() => {});
          if (update.callback_query) handleCallback(update.callback_query).catch(() => {});
        }
      }
    } catch(e) {
      await new Promise(r => setTimeout(r, 5000));
    }
    setTimeout(poll, 100);
  }

  console.log('🤖 DevCulture Bot @devculturebot started...');
  console.log(`👤 Admin: ${ADMIN_ID}`);
  poll();
  