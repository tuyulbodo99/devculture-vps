#!/usr/bin/env node
  // ============================================================
  //   DevCulture VPS - Telegram Bot SSH Manager
  //   Bot: @devculturebot
  //   Repo: https://github.com/tuyulbodo99/devculture-vps
  // ============================================================

  const https = require('https');
  const { execSync, exec } = require('child_process');
  const fs   = require('fs');

  let BOT_TOKEN = process.env.BOT_TOKEN || '';
  let ADMIN_ID  = process.env.ADMIN_ID  || '';

  try {
    const cfg = JSON.parse(fs.readFileSync('/etc/devculture/config.json', 'utf8'));
    if (!BOT_TOKEN) BOT_TOKEN = cfg.bot_token;
    if (!ADMIN_ID)  ADMIN_ID  = String(cfg.admin_id);
  } catch(e) {}

  const DB_FILE    = '/etc/devculture/users.json';
  const TRIAL_FILE = '/etc/devculture/trials.json';

  // ---- Telegram API ----
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

  function sendPhoto(chatId, photoUrl, caption = '') {
    return tgApi('sendPhoto', { chat_id: chatId, photo: photoUrl, caption, parse_mode: 'HTML' });
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

  // ---- Trial DB ----
  function loadTrials() {
    if (!fs.existsSync(TRIAL_FILE)) return { trials: [] };
    try { return JSON.parse(fs.readFileSync(TRIAL_FILE, 'utf8')); } catch(e) { return { trials: [] }; }
  }
  function saveTrials(db) {
    fs.mkdirSync('/etc/devculture', { recursive: true });
    fs.writeFileSync(TRIAL_FILE, JSON.stringify(db, null, 2));
  }

  // ---- Trial Config (edit sesuai kebutuhan) ----
  const TRIAL_DURATION_HOURS = 3;   // Masa aktif trial (jam)
  const TRIAL_QUOTA_GB       = 1;   // Quota trial (GB)
  const TRIAL_MAX_ONLINE     = 1;   // Max sesi bersamaan
  const TRIAL_PER_USER       = 1;   // 1 trial per Telegram user

  // ---- User Management ----
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

  // ---- Trial Functions ----
  function generateTrialUser() {
    const rand = Math.random().toString(36).substring(2, 7);
    return `trial${rand}`;
  }

  function generateTrialPass() {
    return Math.random().toString(36).substring(2, 10) + Math.random().toString(36).substring(2, 6);
  }

  function hasUsedTrial(telegramId) {
    const db = loadTrials();
    return db.trials.some(t => t.telegram_id === String(telegramId));
  }

  function createTrial(telegramId, username, firstName) {
    if (hasUsedTrial(telegramId)) return null;

    const user = generateTrialUser();
    const pass = generateTrialPass();
    const exp  = new Date(Date.now() + TRIAL_DURATION_HOURS * 3600 * 1000);
    const expStr = exp.toISOString().split('T')[0];

    addUser(user, pass, expStr, String(TRIAL_QUOTA_GB));

    // Record trial usage
    const db = loadTrials();
    db.trials.push({
      telegram_id: String(telegramId),
      username: username || 'unknown',
      first_name: firstName || '',
      ssh_user: user,
      created: new Date().toISOString(),
      expires: exp.toISOString()
    });
    saveTrials(db);

    // Schedule auto-delete
    setTimeout(() => {
      delUser(user);
      console.log(`Trial user ${user} expired and deleted.`);
    }, TRIAL_DURATION_HOURS * 3600 * 1000);

    return { user, pass, expStr, exp };
  }

  function cleanExpiredTrials() {
    const db = loadTrials();
    const now = Date.now();
    db.trials.forEach(t => {
      if (new Date(t.expires).getTime() < now) {
        delUser(t.ssh_user);
      }
    });
  }

  // ---- State ----
  const state = {};

  // ---- Keyboards ----
  const mainMenu = {
    inline_keyboard: [
      [{ text: '➕ Tambah SSH',   callback_data: 'add_ssh' },    { text: '🗑 Hapus SSH',    callback_data: 'del_ssh' }],
      [{ text: '📋 List User',    callback_data: 'list_ssh' },   { text: '🔍 Cek User',     callback_data: 'cek_ssh' }],
      [{ text: '🖥 Info Server',  callback_data: 'server_info' },{ text: '🔄 Restart',      callback_data: 'restart_svc' }],
      [{ text: '🔑 SSL Renew',    callback_data: 'ssl_renew' },  { text: '📊 Bandwidth',    callback_data: 'bandwidth' }],
      [{ text: '🎁 Trial Akun',   callback_data: 'trial_list' }, { text: '⚙️ Trial Config', callback_data: 'trial_cfg' }]
    ]
  };

  const publicMenu = {
    inline_keyboard: [
      [{ text: '🎁 Coba SSH Gratis (Trial)', callback_data: 'req_trial' }],
      [{ text: '📞 Hubungi Admin',           callback_data: 'contact_admin' }]
    ]
  };

  // ---- Message Handler ----
  async function handleMessage(msg) {
    const chatId    = String(msg.chat.id);
    const text      = msg.text || '';
    const isAdmin   = chatId === String(ADMIN_ID);
    const fromUser  = msg.from;

    const st = state[chatId];

    // ---- Admin wizard ----
    if (isAdmin && st) {
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

  🔌 <b>Ports:</b> SSH:22 | Dropbear:443,80 | WS:2082`);
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

    // /start
    if (text === '/start' || text === '/menu') {
      if (isAdmin) {
        return send(chatId,
          '🖥 <b>DevCulture VPS Manager</b>\n━━━━━━━━━━━━━━━━━━━━\nSelamat datang Admin! Pilih menu:',
          { reply_markup: mainMenu }
        );
      } else {
        return send(chatId,
          '👋 <b>DevCulture VPS Bot</b>\n━━━━━━━━━━━━━━━━━━━━\nHalo! Kamu bisa coba SSH gratis (trial ' + TRIAL_DURATION_HOURS + ' jam).',
          { reply_markup: publicMenu }
        );
      }
    }

    // /trial command
    if (text === '/trial') {
      return handleTrialRequest(chatId, fromUser);
    }

    if (isAdmin) {
      return send(chatId, '⚙️ Pilih menu:', { reply_markup: mainMenu });
    } else {
      return send(chatId, '⚙️ Pilih menu:', { reply_markup: publicMenu });
    }
  }

  // ---- Trial Handler ----
  async function handleTrialRequest(chatId, fromUser) {
    if (hasUsedTrial(fromUser.id)) {
      return send(chatId, '❌ Maaf, kamu sudah pernah menggunakan trial.\n\nUntuk berlangganan, hubungi admin.');
    }

    send(chatId, '⏳ Membuat akun trial kamu...');

    const trial = createTrial(fromUser.id, fromUser.username, fromUser.first_name);
    if (!trial) {
      return send(chatId, '❌ Gagal membuat trial. Mungkin kamu sudah pernah trial sebelumnya.');
    }

    const info = getServerInfo();
    const expTime = new Date(trial.exp);
    const expFormatted = trial.exp + ' (dalam ' + TRIAL_DURATION_HOURS + ' jam)';

    // Notify admin
    const tdb = loadTrials();
    const lastTrial = tdb.trials[tdb.trials.length - 1];
    send(ADMIN_ID,
      `🎁 <b>Trial Baru!</b>\n👤 Telegram: @${fromUser.username || fromUser.first_name} (ID: ${fromUser.id})\n🔑 SSH User: <code>${trial.user}</code>\n⏰ Expires: ${expFormatted}`
    );

    return send(chatId, `✅ <b>Akun Trial SSH Berhasil Dibuat!</b>

  👤 Username : <code>${trial.user}</code>
  🔑 Password : <code>${trial.pass}</code>
  🌐 Host     : <code>${info.ip}</code>
  ⏰ Expired  : <code>${expFormatted}</code>
  📦 Quota    : <code>${TRIAL_QUOTA_GB} GB</code>

  🔌 <b>Cara Connect:</b>
  • SSH         : Port 22
  • Dropbear    : Port 443 / 80
  • WebSocket   : Port 2082

  ⚠️ <i>Akun trial otomatis terhapus setelah ${TRIAL_DURATION_HOURS} jam.</i>
  📞 Untuk langganan hubungi admin.`);
  }

  // ---- Callback Handler ----
  async function handleCallback(cb) {
    const chatId  = String(cb.message.chat.id);
    const data    = cb.data;
    const isAdmin = chatId === String(ADMIN_ID);
    const fromUser = cb.from;
    await tgApi('answerCallbackQuery', { callback_query_id: cb.id });

    // Public callbacks
    if (data === 'req_trial') {
      return handleTrialRequest(chatId, fromUser);
    }
    if (data === 'contact_admin') {
      return send(chatId, '📞 Hubungi admin untuk berlangganan:\n@' + (process.env.ADMIN_USERNAME || 'admin'));
    }

    if (!isAdmin) return send(chatId, '❌ Akses ditolak.', { reply_markup: publicMenu });

    // Admin callbacks
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
      return send(chatId, '✅ Services direstart: SSH · Dropbear · Nginx · Xray · Haproxy');
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
    if (data === 'trial_list') {
      const db = loadTrials();
      if (!db.trials.length) return send(chatId, '🎁 Belum ada pengguna trial.');
      let text = '🎁 <b>Daftar Trial Users</b>\n━━━━━━━━━━━━━━━\n';
      db.trials.slice(-20).forEach((t, i) => {
        const expired = new Date(t.expires) < new Date();
        text += `${i+1}. @${t.username} → <code>${t.ssh_user}</code> | ${expired ? '🔴 expired' : '🟢 aktif'}\n`;
      });
      return send(chatId, text);
    }
    if (data === 'trial_cfg') {
      return send(chatId, `⚙️ <b>Konfigurasi Trial</b>
  ━━━━━━━━━━━━━━━
  ⏰ Durasi    : ${TRIAL_DURATION_HOURS} jam
  📦 Quota     : ${TRIAL_QUOTA_GB} GB
  👥 Max sesi  : ${TRIAL_MAX_ONLINE}
  🔁 Per user  : ${TRIAL_PER_USER}x

  Edit di: /usr/local/bin/devculture-bot.js`);
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

  // Clean expired trials on startup
  cleanExpiredTrials();
  console.log('🤖 DevCulture Bot @devculturebot started...');
  console.log(`👤 Admin: ${ADMIN_ID}`);
  poll();
  