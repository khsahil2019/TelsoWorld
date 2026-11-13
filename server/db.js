const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');
const { getInitialData } = require('./seed-data');

const DB_JSON_FILE = path.join(__dirname, 'data', 'db.json');
const SCHEMA_FILE = path.join(__dirname, 'schema.sql');

const pool = new Pool(
  process.env.DATABASE_URL
    ? { connectionString: process.env.DATABASE_URL }
    : {
        host: process.env.PGHOST || '127.0.0.1',
        port: parseInt(process.env.PGPORT || '5432', 10),
        database: process.env.PGDATABASE || 'telsoworld',
        user: process.env.PGUSER || process.env.USER || 'sahilkhan',
        password: process.env.PGPASSWORD || undefined,
      }
);

function toIso(val) {
  if (!val) return new Date().toISOString();
  return val instanceof Date ? val.toISOString() : String(val);
}

function mapUser(row) {
  if (!row) return null;
  return {
    ...row,
    created_at: toIso(row.created_at),
  };
}

function mapVideo(row) {
  if (!row) return null;
  return {
    ...row,
    budget: row.budget !== null && row.budget !== undefined ? parseFloat(row.budget) : 0,
    liked_by: Array.isArray(row.liked_by) ? row.liked_by : [],
    viewed_by: Array.isArray(row.viewed_by) ? row.viewed_by : [],
    earned_like_users: Array.isArray(row.earned_like_users) ? row.earned_like_users : [],
    earned_comment_users: Array.isArray(row.earned_comment_users) ? row.earned_comment_users : [],
    created_at: toIso(row.created_at),
  };
}

function mapComment(row) {
  if (!row) return null;
  return {
    ...row,
    user: row.user_name,
    content: row.comment,
    liked_by: Array.isArray(row.liked_by) ? row.liked_by : [],
    created_at: toIso(row.created_at),
  };
}

function mapTransaction(row) {
  if (!row) return null;
  return {
    ...row,
    amount: parseFloat(row.amount || 0),
    created_at: toIso(row.created_at),
  };
}

function mapNotification(row) {
  if (!row) return null;
  return {
    ...row,
    body: row.body || row.message || '',
    message: row.message || row.body || '',
    created_at: toIso(row.created_at),
  };
}

function mapSettings(row) {
  if (!row) return null;
  return {
    ...row,
    referral_reward: parseFloat(row.referral_reward || 50),
    min_withdrawal: parseFloat(row.min_withdrawal || 100),
    updated_at: toIso(row.updated_at),
  };
}

function parseBirthdayMonthDay(dob) {
  if (!dob) return null;
  const str = String(dob).trim();
  const parts = str.split(/[-/]/);
  if (parts.length === 3) {
    let m;
    let d;
    if (parts[0].length === 4) {
      m = parseInt(parts[1], 10);
      d = parseInt(parts[2], 10);
    } else {
      d = parseInt(parts[0], 10);
      m = parseInt(parts[1], 10);
    }
    if (m >= 1 && m <= 12 && d >= 1 && d <= 31) return { m, d };
  }
  const parsed = new Date(str);
  if (!isNaN(parsed.getTime())) {
    return { m: parsed.getMonth() + 1, d: parsed.getDate() };
  }
  return null;
}

class PostgresDatabase {
  constructor() {
    this.pool = pool;
    this._initPromise = null;
  }

  async init() {
    if (this._initPromise) return this._initPromise;
    this._initPromise = this._runInit();
    return this._initPromise;
  }

  async _runInit() {
    const schemaSql = fs.readFileSync(SCHEMA_FILE, 'utf-8');
    await this.pool.query(schemaSql);

    const { rows: countRows } = await this.pool.query('SELECT COUNT(*)::int AS cnt FROM users');
    if (countRows[0].cnt === 0) {
      let seedSource = null;
      if (fs.existsSync(DB_JSON_FILE)) {
        try {
          seedSource = JSON.parse(fs.readFileSync(DB_JSON_FILE, 'utf-8'));
          console.log('[POSTGRES] Importing existing data from server/data/db.json...');
        } catch (err) {
          console.warn('[POSTGRES] Could not parse db.json, falling back to default seed:', err.message);
        }
      }
      await this._importDataset(seedSource || getInitialData());
    }

    await this._syncSequences();
  }

  async _syncSequences() {
    const tables = ['users', 'videos', 'comments', 'web_links'];
    for (const t of tables) {
      await this.pool.query(
        `SELECT setval(pg_get_serial_sequence('${t}', 'id'), COALESCE((SELECT MAX(id) FROM ${t}), 0) + 1, false)`
      );
    }
  }

  async _importDataset(data) {
    const fallback = getInitialData();
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      const admin = data.admin || fallback.admin;
      await client.query(
        `INSERT INTO admin (id, username, password, name, email)
         VALUES (1, $1, $2, $3, $4)
         ON CONFLICT (id) DO NOTHING`,
        [admin.username, admin.password, admin.name || 'System Admin', admin.email || 'admin@telsoworld.com']
      );

      const s = data.settings || fallback.settings;
      await client.query(
        `INSERT INTO settings (id, name, file_uploaded, value, app_name, referral_reward, min_withdrawal, sms, smtp, firebase, platform, notifications_log, updated_at)
         VALUES (1, $1, $2, $3, $4, $5, $6, $7::jsonb, $8::jsonb, $9::jsonb, $10::jsonb, $11::jsonb, $12)
         ON CONFLICT (id) DO NOTHING`,
        [
          s.name || 'dashboard_config',
          s.file_uploaded || '1',
          s.value ?? null,
          s.app_name || 'Telso World',
          parseFloat(s.referral_reward || 50),
          parseFloat(s.min_withdrawal || 100),
          JSON.stringify(s.sms || fallback.settings.sms),
          JSON.stringify(s.smtp || fallback.settings.smtp),
          JSON.stringify(s.firebase || fallback.settings.firebase),
          JSON.stringify(s.platform || fallback.settings.platform),
          JSON.stringify(s.notifications_log || []),
          s.updated_at || new Date().toISOString(),
        ]
      );

      for (const u of data.users || []) {
        await client.query(
          `INSERT INTO users (id, name, username, email, mobile_no, whatsapp, school_name, dob, state, district, password, referral_code, referred_by, user_type, role, status, profile_image, bio, created_at)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19)
           ON CONFLICT (id) DO NOTHING`,
          [
            u.id,
            u.name || '',
            u.username,
            u.email || '',
            u.mobile_no || '',
            u.whatsapp || u.mobile_no || '',
            u.school_name || '',
            u.dob || null,
            u.state || '',
            u.district || '',
            u.password,
            u.referral_code || `TELSO${u.id}`,
            u.referred_by || null,
            u.user_type || 'musician',
            u.role || 'creator',
            u.status || 'active',
            u.profile_image || '',
            u.bio || '',
            u.created_at || new Date().toISOString(),
          ]
        );
      }

      for (const v of data.videos || []) {
        await client.query(
          `INSERT INTO videos (id, user_id, name, username, title, subject, category, video_url, video_path, thumbnail_url, image, target_url, budget, duration, audio_title, audio_artist, has_audio, video_type, status, view_count, likes_count, shares_count, comments_count, liked_by, viewed_by, earned_like_users, earned_comment_users, created_at)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23,$24::jsonb,$25::jsonb,$26::jsonb,$27::jsonb,$28)
           ON CONFLICT (id) DO NOTHING`,
          [
            v.id,
            v.user_id || 1,
            v.name || 'Creator',
            v.username || 'creator',
            v.title || 'New Reel',
            v.subject || '',
            v.category || 'General',
            v.video_url || '',
            v.video_path || v.video_url || '',
            v.thumbnail_url || '',
            v.image || v.thumbnail_url || '',
            v.target_url || '',
            parseFloat(v.budget || 0),
            v.duration || '',
            v.audio_title || '',
            v.audio_artist || '',
            v.has_audio !== false,
            v.video_type || 'normal',
            v.status || 'Approved',
            parseInt(v.view_count || 0, 10),
            parseInt(v.likes_count || 0, 10),
            parseInt(v.shares_count || 0, 10),
            parseInt(v.comments_count || 0, 10),
            JSON.stringify(v.liked_by || []),
            JSON.stringify(v.viewed_by || []),
            JSON.stringify(v.earned_like_users || []),
            JSON.stringify(v.earned_comment_users || []),
            v.created_at || new Date().toISOString(),
          ]
        );
      }

      // Insert parent comments first, then replies
      const comments = data.comments || [];
      const orderedComments = [
        ...comments.filter((c) => !c.parent_id),
        ...comments.filter((c) => c.parent_id),
      ];
      for (const c of orderedComments) {
        await client.query(
          `INSERT INTO comments (id, video_id, user_id, user_name, username, comment, profile_image, likes, liked_by, reply_count, parent_id, created_at)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9::jsonb,$10,$11,$12)
           ON CONFLICT (id) DO NOTHING`,
          [
            c.id,
            c.video_id,
            c.user_id || 1,
            c.user_name || c.user || 'User',
            c.username || 'user',
            c.comment || c.content || '',
            c.profile_image || '',
            parseInt(c.likes || 0, 10),
            JSON.stringify(c.liked_by || []),
            parseInt(c.reply_count || 0, 10),
            c.parent_id || null,
            c.created_at || new Date().toISOString(),
          ]
        );
      }

      for (const w of data.wallets || []) {
        await client.query(
          `INSERT INTO wallets (user_id, balance, pending_amount)
           VALUES ($1, $2, $3)
           ON CONFLICT (user_id) DO NOTHING`,
          [w.user_id, parseFloat(w.balance || 0), parseFloat(w.pending_amount || 0)]
        );
      }

      for (const t of data.transactions || []) {
        await client.query(
          `INSERT INTO transactions (id, user_id, title, description, amount, type, status, created_at)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
           ON CONFLICT (id) DO NOTHING`,
          [
            String(t.id),
            t.user_id,
            t.title || '',
            t.description || '',
            parseFloat(t.amount || 0),
            t.type || 'credit',
            t.status || 'completed',
            t.created_at || new Date().toISOString(),
          ]
        );
      }

      for (const wd of data.withdrawals || []) {
        await client.query(
          `INSERT INTO withdrawals (id, user_id, user_name, amount, upi_id, account_holder, status, created_at)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
           ON CONFLICT (id) DO NOTHING`,
          [
            String(wd.id),
            wd.user_id,
            wd.user_name || wd.account_holder || '',
            parseFloat(wd.amount || 0),
            wd.upi_id || '',
            wd.account_holder || '',
            wd.status || 'pending',
            wd.created_at || new Date().toISOString(),
          ]
        );
      }

      for (const wl of data.web_links || []) {
        await client.query(
          `INSERT INTO web_links (id, user_id, subject, name, like_limit, state, district, web_link, utr, status, current_likes, created_at)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
           ON CONFLICT (id) DO NOTHING`,
          [
            wl.id,
            wl.user_id || 1,
            wl.subject || '',
            wl.name || '',
            wl.like_limit || '1,000',
            wl.state || '',
            wl.district || '',
            wl.web_link || '',
            wl.utr || '—',
            wl.status || 'Pending',
            parseInt(wl.current_likes || 0, 10),
            wl.created_at || new Date().toISOString(),
          ]
        );
      }

      for (const n of data.notifications || []) {
        await client.query(
          `INSERT INTO notifications (id, user_id, title, message, body, type, icon, color, avatar, action_url, action_text, created_at, is_read, read)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
           ON CONFLICT (id) DO NOTHING`,
          [
            String(n.id),
            n.user_id ? parseInt(n.user_id, 10) : null,
            n.title || 'Notification',
            n.message || n.body || '',
            n.body || n.message || '',
            n.type || 'info',
            n.icon || 'bell',
            n.color || 'blue',
            n.avatar || '',
            n.action_url || '',
            n.action_text || '',
            n.created_at || new Date().toISOString(),
            Boolean(n.is_read),
            Boolean(n.read || n.is_read),
          ]
        );
      }

      await client.query('COMMIT');
      console.log('[POSTGRES] Initial dataset migrated cleanly into PostgreSQL.');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  // --- Admin ---
  async getAdmin() {
    const { rows } = await this.pool.query('SELECT * FROM admin WHERE id = 1 LIMIT 1');
    return rows[0] || null;
  }

  // --- Settings & Integrations ---
  async getSettings() {
    const { rows } = await this.pool.query('SELECT * FROM settings WHERE id = 1 LIMIT 1');
    return mapSettings(rows[0]);
  }

  async updateSettings(updates) {
    const current = (await this.getSettings()) || {};
    const merged = { ...current };

    for (const key of Object.keys(updates)) {
      if (typeof updates[key] === 'object' && updates[key] !== null && !Array.isArray(updates[key])) {
        merged[key] = { ...(merged[key] || {}), ...updates[key] };
      } else {
        merged[key] = updates[key];
      }
    }

    const { rows } = await this.pool.query(
      `UPDATE settings
       SET app_name = $1,
           referral_reward = $2,
           min_withdrawal = $3,
           sms = $4::jsonb,
           smtp = $5::jsonb,
           firebase = $6::jsonb,
           platform = $7::jsonb,
           notifications_log = $8::jsonb,
           file_uploaded = $9,
           value = $10,
           updated_at = NOW()
       WHERE id = 1
       RETURNING *`,
      [
        merged.app_name || 'Telso World',
        parseFloat(merged.referral_reward || 50),
        parseFloat(merged.min_withdrawal || 100),
        JSON.stringify(merged.sms || {}),
        JSON.stringify(merged.smtp || {}),
        JSON.stringify(merged.firebase || {}),
        JSON.stringify(merged.platform || {}),
        JSON.stringify(merged.notifications_log || []),
        merged.file_uploaded || '1',
        merged.value ?? null,
      ]
    );
    return mapSettings(rows[0]);
  }

  async addNotificationLog(item) {
    const current = (await this.getSettings()) || {};
    const users = await this.getUsers();
    const logEntry = {
      id: `notif_${Date.now()}`,
      title: item.title || '',
      body: item.body || '',
      audience: item.audience || 'all',
      action_url: item.action_url || '',
      image_url: item.image_url || '',
      sent_at: new Date().toISOString(),
      delivered_count: item.delivered_count || users.length,
    };
    const nextLog = [logEntry, ...(Array.isArray(current.notifications_log) ? current.notifications_log : [])];
    await this.pool.query(
      'UPDATE settings SET notifications_log = $1::jsonb, updated_at = NOW() WHERE id = 1',
      [JSON.stringify(nextLog)]
    );
    return logEntry;
  }

  // --- Users ---
  async getUsers() {
    const { rows } = await this.pool.query('SELECT * FROM users ORDER BY id ASC');
    return rows.map(mapUser);
  }

  async getRecentUsers(limit = 8) {
    const { rows } = await this.pool.query('SELECT * FROM users ORDER BY id DESC LIMIT $1', [limit]);
    return rows.map(mapUser);
  }

  async findUserById(id) {
    const numericId = parseInt(id, 10);
    if (isNaN(numericId)) return null;
    const { rows } = await this.pool.query('SELECT * FROM users WHERE id = $1 LIMIT 1', [numericId]);
    return mapUser(rows[0]);
  }

  async findUserByEmailOrPhone(identifier) {
    if (!identifier) return null;
    const clean = identifier.trim().toLowerCase();
    const { rows } = await this.pool.query(
      `SELECT * FROM users
       WHERE LOWER(email) = $1 OR mobile_no = $2 OR LOWER(username) = $1
       LIMIT 1`,
      [clean, identifier.trim()]
    );
    return mapUser(rows[0]);
  }

  async findUserByUsername(username) {
    if (!username) return null;
    const clean = username.trim().toLowerCase().replace(/^@/, '');
    const { rows } = await this.pool.query(
      'SELECT * FROM users WHERE LOWER(username) = $1 LIMIT 1',
      [clean]
    );
    return mapUser(rows[0]);
  }

  async findUserByMobile(mobile) {
    if (!mobile) return null;
    const { rows } = await this.pool.query('SELECT * FROM users WHERE mobile_no = $1 LIMIT 1', [mobile]);
    return mapUser(rows[0]);
  }

  async findUserByReferralCode(code) {
    if (!code) return null;
    const { rows } = await this.pool.query(
      'SELECT * FROM users WHERE referral_code = $1 LIMIT 1',
      [code.trim().toUpperCase()]
    );
    return mapUser(rows[0]);
  }

  async getTodayBirthdays() {
    const users = await this.getUsers();
    const today = new Date();
    const todayMonth = today.getMonth() + 1;
    const todayDay = today.getDate();

    return users.filter((u) => {
      const md = parseBirthdayMonthDay(u.dob);
      return md && md.m === todayMonth && md.d === todayDay;
    });
  }

  async getUpcomingBirthdays(days = 30) {
    const users = await this.getUsers();
    const today = new Date();
    const todayMonth = today.getMonth() + 1;
    const todayDay = today.getDate();

    return users
      .map((u) => {
        const md = parseBirthdayMonthDay(u.dob);
        if (!md) return null;
        const currentYear = today.getFullYear();
        let nextBday = new Date(currentYear, md.m - 1, md.d);
        if (nextBday < today && !(md.m === todayMonth && md.d === todayDay)) {
          nextBday = new Date(currentYear + 1, md.m - 1, md.d);
        }
        const diffDays = Math.ceil((nextBday - today) / (1000 * 60 * 60 * 24));
        if (diffDays >= 0 && diffDays <= days) {
          return {
            id: u.id,
            name: u.name,
            username: u.username,
            mobile: u.mobile_no,
            whatsapp: u.whatsapp || u.mobile_no,
            dob: u.dob,
            state: u.state,
            days_until: diffDays,
            is_today: diffDays === 0 || (md.m === todayMonth && md.d === todayDay),
          };
        }
        return null;
      })
      .filter(Boolean)
      .sort((a, b) => a.days_until - b.days_until);
  }

  async createUser(userData) {
    const settings = (await this.getSettings()) || {};
    const welcomeBonus = parseFloat((settings.platform && settings.platform.welcome_bonus) || 50.0);
    const refReward = parseFloat((settings.platform && settings.platform.referral_reward) || 50.0);

    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      const tempCode = userData.referral_code || `TELSO_${Date.now()}_${Math.floor(100 + Math.random() * 900)}`;
      const { rows: inserted } = await client.query(
        `INSERT INTO users (name, username, email, mobile_no, whatsapp, school_name, dob, state, district, password, referral_code, referred_by, user_type, role, status)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,'creator','active')
         RETURNING *`,
        [
          userData.name || '',
          userData.username,
          userData.email || '',
          userData.mobile_no || '',
          userData.whatsapp || userData.mobile_no || '',
          userData.school_name || '',
          userData.dob || null,
          userData.state || '',
          userData.district || '',
          userData.password,
          tempCode,
          userData.referred_by || null,
          userData.user_type || 'musician',
        ]
      );
      let newUser = inserted[0];
      if (!userData.referral_code) {
        const finalCode = `TELSO${newUser.id}${Math.floor(100 + Math.random() * 900)}`;
        const { rows: updated } = await client.query(
          'UPDATE users SET referral_code = $1 WHERE id = $2 RETURNING *',
          [finalCode, newUser.id]
        );
        newUser = updated[0];
      }

      await client.query(
        'INSERT INTO wallets (user_id, balance, pending_amount) VALUES ($1, $2, 0)',
        [newUser.id, welcomeBonus]
      );

      await client.query(
        `INSERT INTO transactions (id, user_id, title, description, amount, type, status)
         VALUES ($1, $2, $3, $4, $5, 'credit', 'completed')`,
        [
          `tx_${Date.now()}_${newUser.id}`,
          newUser.id,
          'Welcome Bonus 🎁',
          'Signup bonus credited to Telso wallet',
          welcomeBonus,
        ]
      );

      if (userData.referred_by) {
        const { rows: refRows } = await client.query(
          'SELECT * FROM users WHERE referral_code = $1 LIMIT 1',
          [userData.referred_by.trim().toUpperCase()]
        );
        if (refRows[0]) {
          const refId = refRows[0].id;
          await client.query(
            `INSERT INTO wallets (user_id, balance, pending_amount)
             VALUES ($1, $2, 0)
             ON CONFLICT (user_id) DO UPDATE SET balance = wallets.balance + $2`,
            [refId, refReward]
          );
          await client.query(
            `INSERT INTO transactions (id, user_id, title, description, amount, type, status)
             VALUES ($1, $2, $3, $4, $5, 'credit', 'completed')`,
            [
              `tx_ref_${Date.now()}_${refId}`,
              refId,
              'Referral Bonus 👥',
              `Bonus for referring ${newUser.name || newUser.username}`,
              refReward,
            ]
          );
        }
      }

      await client.query('COMMIT');
      return mapUser(newUser);
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  async updateUser(id, updates) {
    const numericId = parseInt(id, 10);
    if (isNaN(numericId)) return null;
    const allowed = ['name', 'bio', 'email', 'whatsapp', 'status', 'profile_image', 'state', 'district'];
    const sets = [];
    const vals = [];
    let idx = 1;
    for (const k of allowed) {
      if (updates[k] !== undefined) {
        sets.push(`${k} = $${idx++}`);
        vals.push(updates[k]);
      }
    }
    if (sets.length === 0) return this.findUserById(numericId);
    vals.push(numericId);
    const { rows } = await this.pool.query(
      `UPDATE users SET ${sets.join(', ')} WHERE id = $${idx} RETURNING *`,
      vals
    );
    return mapUser(rows[0]);
  }

  async deleteUser(id) {
    const numericId = parseInt(id, 10);
    if (isNaN(numericId)) return false;
    const res = await this.pool.query('DELETE FROM users WHERE id = $1', [numericId]);
    return res.rowCount > 0;
  }

  async getUserVideoCounts() {
    const { rows } = await this.pool.query(
      'SELECT user_id, COUNT(*)::int AS cnt FROM videos GROUP BY user_id'
    );
    const map = {};
    for (const r of rows) map[r.user_id] = r.cnt;
    return map;
  }

  // --- Videos ---
  async getVideos({ type = null, status = 'Approved', search = null, currentUserId = null, limit = null } = {}) {
    const where = [];
    const vals = [];
    let idx = 1;

    if (type && type !== 'all') {
      where.push(`video_type = $${idx++}`);
      vals.push(type);
    }
    if (status && status !== 'all') {
      where.push(`status = $${idx++}`);
      vals.push(status);
    }
    if (search) {
      where.push(`(LOWER(title) LIKE $${idx} OR LOWER(subject) LIKE $${idx} OR LOWER(name) LIKE $${idx})`);
      vals.push(`%${search.toLowerCase()}%`);
      idx++;
    }

    const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';
    const limitSql = limit ? `LIMIT $${idx}` : '';
    if (limit) vals.push(limit);

    const { rows } = await this.pool.query(
      `SELECT * FROM videos ${whereSql} ORDER BY id DESC ${limitSql}`,
      vals
    );

    const cId = currentUserId ? parseInt(currentUserId, 10) : null;
    return rows.map((row) => {
      const v = mapVideo(row);
      const isLiked = cId ? v.liked_by.includes(cId) : false;
      return {
        ...v,
        liked: isLiked,
        is_liked: isLiked,
        liked_by_count: v.liked_by.length,
      };
    });
  }

  async getUserVideos(userId) {
    const numericId = parseInt(userId, 10);
    const { rows } = await this.pool.query(
      'SELECT * FROM videos WHERE user_id = $1 ORDER BY id DESC',
      [numericId]
    );
    return rows.map(mapVideo);
  }

  async findVideoById(id, currentUserId = null) {
    const numericId = parseInt(id, 10);
    if (isNaN(numericId)) return null;
    const { rows } = await this.pool.query('SELECT * FROM videos WHERE id = $1 LIMIT 1', [numericId]);
    if (!rows[0]) return null;
    const v = mapVideo(rows[0]);
    const cId = currentUserId ? parseInt(currentUserId, 10) : null;
    const isLiked = cId ? v.liked_by.includes(cId) : false;
    return { ...v, liked: isLiked, is_liked: isLiked };
  }

  async createVideo(videoData) {
    const settings = (await this.getSettings()) || {};
    const requireApproval = !settings.platform || settings.platform.require_admin_approval !== false;
    const defaultStatus = videoData.status || (requireApproval ? 'Pending' : 'Approved');

    const { rows } = await this.pool.query(
      `INSERT INTO videos (
        user_id, name, username, title, subject, category,
        video_url, video_path, thumbnail_url, image, target_url, budget,
        duration, audio_title, audio_artist, has_audio, video_type, status,
        view_count, likes_count, shares_count, comments_count
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,0)
      RETURNING *`,
      [
        videoData.user_id || 1,
        videoData.name || videoData.reporter_name || 'Creator',
        videoData.username || 'creator',
        videoData.title || videoData.subject || 'New Reel',
        videoData.subject || videoData.title || '',
        videoData.category || 'General',
        videoData.video_url || '',
        videoData.video_path || videoData.video_url || '',
        videoData.thumbnail_url || '',
        videoData.image || videoData.thumbnail_url || '',
        videoData.target_url || '',
        parseFloat(videoData.budget || 0),
        videoData.duration || '',
        videoData.audio_title || '',
        videoData.audio_artist || '',
        videoData.has_audio !== false,
        videoData.video_type || 'normal',
        defaultStatus,
        parseInt(videoData.view_count || 0, 10),
        parseInt(videoData.likes_count || 0, 10),
        parseInt(videoData.shares_count || 0, 10),
      ]
    );
    return mapVideo(rows[0]);
  }

  async updateVideo(id, updates) {
    const numericId = parseInt(id, 10);
    if (isNaN(numericId)) return null;
    const allowed = ['title', 'subject', 'category', 'video_url', 'video_path', 'thumbnail_url', 'image', 'video_type', 'status', 'has_audio', 'audio_title'];
    const sets = [];
    const vals = [];
    let idx = 1;
    for (const k of allowed) {
      if (updates[k] !== undefined) {
        sets.push(`${k} = $${idx++}`);
        vals.push(updates[k]);
      }
    }
    if (sets.length === 0) return this.findVideoById(numericId);
    vals.push(numericId);
    const { rows } = await this.pool.query(
      `UPDATE videos SET ${sets.join(', ')} WHERE id = $${idx} RETURNING *`,
      vals
    );
    return mapVideo(rows[0]);
  }

  async deleteVideo(id) {
    const numericId = parseInt(id, 10);
    if (isNaN(numericId)) return false;
    const res = await this.pool.query('DELETE FROM videos WHERE id = $1', [numericId]);
    return res.rowCount > 0;
  }

  // --- View Tracking (Strict 1 user/device = 1 view) ---
  async recordVideoView(id, viewerIdentifier = 'anonymous') {
    const numericId = parseInt(id, 10);
    if (isNaN(numericId)) return null;
    const identifier = String(viewerIdentifier || 'anonymous');

    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const { rows } = await client.query('SELECT id, view_count, viewed_by FROM videos WHERE id = $1 FOR UPDATE', [numericId]);
      if (!rows[0]) {
        await client.query('ROLLBACK');
        return null;
      }
      const viewedBy = Array.isArray(rows[0].viewed_by) ? [...rows[0].viewed_by] : [];
      if (viewedBy.includes(identifier)) {
        await client.query('COMMIT');
        return { incremented: false, view_count: rows[0].view_count || 0 };
      }
      viewedBy.push(identifier);
      const nextCount = (rows[0].view_count || 0) + 1;
      await client.query(
        'UPDATE videos SET viewed_by = $1::jsonb, view_count = $2 WHERE id = $3',
        [JSON.stringify(viewedBy), nextCount, numericId]
      );
      await client.query('COMMIT');
      return { incremented: true, view_count: nextCount };
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  // --- 5-Layer Engagement Reward Calculator ---
  calculateLayerReward(actionType, currentActionCount) {
    const position = currentActionCount + 1;
    if (position <= 100) return { layer: 1, reward: 0.10, label: 'Layer 1 (10 Paisa)', pool_pct: '100%' };
    if (position <= 300) return { layer: 2, reward: 0.07, label: 'Layer 2 (7 Paisa)', pool_pct: '70%' };
    if (position <= 600) return { layer: 3, reward: 0.05, label: 'Layer 3 (5 Paisa)', pool_pct: '50%' };
    if (position <= 1000) return { layer: 4, reward: 0.03, label: 'Layer 4 (3 Paisa)', pool_pct: '30%' };
    if (position <= 1500) return { layer: 5, reward: 0.01, label: 'Layer 5 (1 Paisa)', pool_pct: '10%' };
    return { layer: 6, reward: 0.00, label: 'Pool Exhausted', pool_pct: '0%' };
  }

  async toggleVideoLike(videoId, userId) {
    const numericId = parseInt(videoId, 10);
    const uId = parseInt(userId, 10);
    if (isNaN(numericId)) return null;

    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const { rows } = await client.query('SELECT * FROM videos WHERE id = $1 FOR UPDATE', [numericId]);
      if (!rows[0]) {
        await client.query('ROLLBACK');
        return null;
      }
      const video = mapVideo(rows[0]);
      const likedBy = [...video.liked_by];
      const earnedLikeUsers = [...video.earned_like_users];
      const idx = likedBy.indexOf(uId);

      let liked = false;
      let likesCount = video.likes_count || 0;
      let rewardInfo = null;
      let notifyOwner = false;

      if (idx === -1) {
        likedBy.push(uId);
        likesCount += 1;
        liked = true;
        if (video.user_id && video.user_id !== uId) notifyOwner = true;

        if (uId && (video.video_type === 'ads' || video.category === 'Promotion') && !earnedLikeUsers.includes(uId)) {
          earnedLikeUsers.push(uId);
          const layerData = this.calculateLayerReward('like', earnedLikeUsers.length - 1);
          if (layerData.reward > 0) {
            const { rows: wRows } = await client.query(
              `INSERT INTO wallets (user_id, balance, pending_amount)
               VALUES ($1, $2, 0)
               ON CONFLICT (user_id) DO UPDATE SET balance = wallets.balance + $2
               RETURNING balance`,
              [uId, layerData.reward]
            );
            await client.query(
              `INSERT INTO transactions (id, user_id, title, description, amount, type, status)
               VALUES ($1, $2, $3, $4, $5, 'credit', 'completed')`,
              [
                `tx_${Date.now()}_like_${uId}`,
                uId,
                `Ad Like Reward: ${layerData.label}`,
                `Earned ₹${layerData.reward.toFixed(2)} for liking sponsored post "${video.title}"`,
                layerData.reward,
              ]
            );
            rewardInfo = {
              reward: layerData.reward,
              layer: layerData.layer,
              label: layerData.label,
              new_balance: parseFloat(wRows[0].balance).toFixed(2),
            };
          }
        }
      } else {
        likedBy.splice(idx, 1);
        likesCount = Math.max(0, likesCount - 1);
      }

      await client.query(
        'UPDATE videos SET liked_by = $1::jsonb, earned_like_users = $2::jsonb, likes_count = $3 WHERE id = $4',
        [JSON.stringify(likedBy), JSON.stringify(earnedLikeUsers), likesCount, numericId]
      );
      await client.query('COMMIT');

      if (notifyOwner) {
        const likingUser = await this.findUserById(uId);
        const name = likingUser ? (likingUser.name || likingUser.username) : 'A creator';
        await this.addUserNotification(video.user_id, {
          title: '❤️ New Like on your Reel!',
          message: `${name} liked your reel "${video.title}".`,
          type: 'social',
          avatar: likingUser ? likingUser.profile_image : '',
          action_url: `#watch?v=${video.id}`,
          action_text: 'View Reel',
        });
      }
      if (rewardInfo) {
        await this.addUserNotification(uId, {
          title: `+₹${rewardInfo.reward.toFixed(2)} Credited! 💰`,
          message: `You received 10 paisa ad reward (${rewardInfo.label}) for liking "${video.title}".`,
          type: 'earning',
        });
      }

      return { liked, is_liked: liked, likes_count: likesCount, reward_info: rewardInfo };
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  // --- Comments ---
  async getComments(videoId, currentUserId = null) {
    const vId = parseInt(videoId, 10);
    const cId = currentUserId ? parseInt(currentUserId, 10) : null;
    const { rows } = await this.pool.query(
      'SELECT * FROM comments WHERE video_id = $1 ORDER BY id ASC',
      [vId]
    );
    const all = rows.map(mapComment);
    const parents = all.filter((c) => !c.parent_id);

    return parents.map((c) => {
      const replies = all
        .filter((r) => r.parent_id === c.id)
        .map((r) => ({ ...r, is_liked: cId ? r.liked_by.includes(cId) : false }));
      return {
        ...c,
        is_liked: cId ? c.liked_by.includes(cId) : false,
        reply_count: replies.length,
        replies,
      };
    });
  }

  async getCommentReplies(commentId, currentUserId = null) {
    const parentId = parseInt(commentId, 10);
    const cId = currentUserId ? parseInt(currentUserId, 10) : null;
    const { rows } = await this.pool.query(
      'SELECT * FROM comments WHERE parent_id = $1 ORDER BY id ASC',
      [parentId]
    );
    return rows.map((row) => {
      const r = mapComment(row);
      return { ...r, is_liked: cId ? r.liked_by.includes(cId) : false };
    });
  }

  async getAllCommentsWithVideo() {
    const { rows } = await this.pool.query(
      `SELECT c.*, COALESCE(v.title, 'Deleted Video') AS video_title
       FROM comments c
       LEFT JOIN videos v ON v.id = c.video_id
       ORDER BY c.id DESC`
    );
    return rows.map((row) => ({ ...mapComment(row), video_title: row.video_title }));
  }

  async createComment(commentData) {
    const text = commentData.comment || commentData.content || '';
    const videoId = parseInt(commentData.video_id, 10);
    const userId = parseInt(commentData.user_id || 1, 10);
    const parentId = commentData.parent_id ? parseInt(commentData.parent_id, 10) : null;

    const client = await this.pool.connect();
    let newComment = null;
    let videoRow = null;
    let rewardInfo = null;

    try {
      await client.query('BEGIN');
      const { rows: inserted } = await client.query(
        `INSERT INTO comments (video_id, user_id, user_name, username, comment, profile_image, parent_id)
         VALUES ($1,$2,$3,$4,$5,$6,$7)
         RETURNING *`,
        [
          videoId,
          userId,
          commentData.user_name || commentData.username || 'User',
          commentData.username || 'user',
          text,
          commentData.profile_image || '',
          parentId,
        ]
      );
      newComment = mapComment(inserted[0]);

      const { rows: vRows } = await client.query('SELECT * FROM videos WHERE id = $1 FOR UPDATE', [videoId]);
      if (vRows[0]) {
        videoRow = mapVideo(vRows[0]);
        const earnedUsers = [...videoRow.earned_comment_users];
        if (userId && (videoRow.video_type === 'ads' || videoRow.category === 'Promotion') && !earnedUsers.includes(userId)) {
          earnedUsers.push(userId);
          const layerData = this.calculateLayerReward('comment', earnedUsers.length - 1);
          if (layerData.reward > 0) {
            const { rows: wRows } = await client.query(
              `INSERT INTO wallets (user_id, balance, pending_amount)
               VALUES ($1, $2, 0)
               ON CONFLICT (user_id) DO UPDATE SET balance = wallets.balance + $2
               RETURNING balance`,
              [userId, layerData.reward]
            );
            await client.query(
              `INSERT INTO transactions (id, user_id, title, description, amount, type, status)
               VALUES ($1, $2, $3, $4, $5, 'credit', 'completed')`,
              [
                `tx_${Date.now()}_cmt_${userId}`,
                userId,
                `Ad Comment Reward: ${layerData.label}`,
                `Earned ₹${layerData.reward.toFixed(2)} for commenting on "${videoRow.title}"`,
                layerData.reward,
              ]
            );
            rewardInfo = {
              reward: layerData.reward,
              layer: layerData.layer,
              label: layerData.label,
              new_balance: parseFloat(wRows[0].balance).toFixed(2),
            };
          }
        }
        await client.query(
          'UPDATE videos SET comments_count = comments_count + 1, earned_comment_users = $1::jsonb WHERE id = $2',
          [JSON.stringify(earnedUsers), videoId]
        );
      }

      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }

    if (videoRow && videoRow.user_id && videoRow.user_id !== userId) {
      await this.addUserNotification(videoRow.user_id, {
        title: '💬 New Comment on your Reel',
        message: `${newComment.user} commented: "${text.length > 60 ? text.substring(0, 60) + '...' : text}"`,
        type: 'social',
        avatar: newComment.profile_image,
        action_url: `#watch?v=${videoRow.id}`,
        action_text: 'Reply to Comment',
      });
    }
    if (rewardInfo && videoRow) {
      await this.addUserNotification(userId, {
        title: `+₹${rewardInfo.reward.toFixed(2)} Credited! 💬`,
        message: `You received 10 paisa ad reward (${rewardInfo.label}) for your comment on "${videoRow.title}".`,
        type: 'earning',
      });
    }

    return { comment: newComment, reward_info: rewardInfo };
  }

  async toggleCommentLike(commentId, userId) {
    const cId = parseInt(commentId, 10);
    const uId = parseInt(userId, 10);
    if (isNaN(cId)) return null;

    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const { rows } = await client.query('SELECT id, likes, liked_by FROM comments WHERE id = $1 FOR UPDATE', [cId]);
      if (!rows[0]) {
        await client.query('ROLLBACK');
        return null;
      }
      const likedBy = Array.isArray(rows[0].liked_by) ? [...rows[0].liked_by] : [];
      const idx = likedBy.indexOf(uId);
      let liked = false;
      let likes = rows[0].likes || 0;
      if (idx === -1) {
        likedBy.push(uId);
        likes += 1;
        liked = true;
      } else {
        likedBy.splice(idx, 1);
        likes = Math.max(0, likes - 1);
      }
      await client.query('UPDATE comments SET liked_by = $1::jsonb, likes = $2 WHERE id = $3', [
        JSON.stringify(likedBy),
        likes,
        cId,
      ]);
      await client.query('COMMIT');
      return { is_liked: liked, likes };
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  async deleteComment(id) {
    const cId = parseInt(id, 10);
    if (isNaN(cId)) return false;

    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const { rows } = await client.query('SELECT id, video_id FROM comments WHERE id = $1 LIMIT 1', [cId]);
      if (!rows[0]) {
        await client.query('ROLLBACK');
        return false;
      }
      const del = await client.query('DELETE FROM comments WHERE id = $1 OR parent_id = $1', [cId]);
      await client.query(
        'UPDATE videos SET comments_count = GREATEST(0, comments_count - $1) WHERE id = $2',
        [del.rowCount || 1, rows[0].video_id]
      );
      await client.query('COMMIT');
      return true;
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  // --- Wallets & Transactions ---
  async getWallet(userId) {
    const uId = parseInt(userId, 10);
    let { rows } = await this.pool.query('SELECT * FROM wallets WHERE user_id = $1 LIMIT 1', [uId]);
    if (!rows[0]) {
      const inserted = await this.pool.query(
        `INSERT INTO wallets (user_id, balance, pending_amount)
         VALUES ($1, 0, 0)
         ON CONFLICT (user_id) DO NOTHING
         RETURNING *`,
        [uId]
      );
      rows = inserted.rows.length
        ? inserted.rows
        : (await this.pool.query('SELECT * FROM wallets WHERE user_id = $1 LIMIT 1', [uId])).rows;
    }
    const wallet = rows[0] || { user_id: uId, balance: 0, pending_amount: 0 };
    const { rows: txRows } = await this.pool.query(
      'SELECT * FROM transactions WHERE user_id = $1 ORDER BY created_at DESC',
      [uId]
    );
    const bal = parseFloat(wallet.balance || 0);
    const pend = parseFloat(wallet.pending_amount || 0);
    return {
      balance: bal.toFixed(2),
      total_balance: bal.toFixed(2),
      pending_amount: pend.toFixed(2),
      transactions: txRows.map(mapTransaction),
    };
  }

  async addWalletTransaction(userId, { title, description, amount, type = 'credit' }) {
    const uId = parseInt(userId, 10);
    const numAmount = parseFloat(amount);
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(
        'INSERT INTO wallets (user_id, balance, pending_amount) VALUES ($1, 0, 0) ON CONFLICT (user_id) DO NOTHING',
        [uId]
      );
      const { rows: wRows } = await client.query(
        type === 'credit'
          ? 'UPDATE wallets SET balance = balance + $1 WHERE user_id = $2 RETURNING *'
          : 'UPDATE wallets SET balance = GREATEST(0, balance - $1) WHERE user_id = $2 RETURNING *',
        [numAmount, uId]
      );
      const txId = `tx_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
      const { rows: txRows } = await client.query(
        `INSERT INTO transactions (id, user_id, title, description, amount, type, status)
         VALUES ($1,$2,$3,$4,$5,$6,'completed')
         RETURNING *`,
        [
          txId,
          uId,
          title || (type === 'credit' ? 'Wallet Credit' : 'Wallet Debit'),
          description || '',
          numAmount,
          type,
        ]
      );
      await client.query('COMMIT');
      const w = wRows[0];
      return {
        wallet: { user_id: w.user_id, balance: parseFloat(w.balance), pending_amount: parseFloat(w.pending_amount) },
        transaction: mapTransaction(txRows[0]),
      };
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  // --- Referrals ---
  async getReferral(userId, reqHost) {
    const user = await this.findUserById(userId);
    if (!user) return null;
    const { rows } = await this.pool.query(
      'SELECT id, name, username, created_at FROM users WHERE referred_by = $1 ORDER BY id DESC',
      [user.referral_code]
    );
    const settings = (await this.getSettings()) || {};
    const reward = parseFloat((settings.platform && settings.platform.referral_reward) || 50.0);
    return {
      referral_code: user.referral_code,
      referral_link: `http://${reqHost}/invite/${user.referral_code}`,
      total_referrals: rows.length,
      total_earnings: rows.length * reward,
      referrals: rows.map((r) => ({ ...r, created_at: toIso(r.created_at) })),
    };
  }

  // --- Web Links ---
  async getWebLinks(userId = null) {
    if (userId) {
      const { rows } = await this.pool.query('SELECT * FROM web_links WHERE user_id = $1 ORDER BY id DESC', [
        parseInt(userId, 10),
      ]);
      return rows.map((r) => ({ ...r, created_at: toIso(r.created_at) }));
    }
    const { rows } = await this.pool.query('SELECT * FROM web_links ORDER BY id DESC');
    return rows.map((r) => ({ ...r, created_at: toIso(r.created_at) }));
  }

  async createWebLink(linkData) {
    const { rows } = await this.pool.query(
      `INSERT INTO web_links (user_id, subject, name, like_limit, state, district, web_link, utr, status, current_likes)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,'Pending',0)
       RETURNING *`,
      [
        linkData.user_id || 1,
        linkData.subject || '',
        linkData.name || '',
        linkData.like_limit || '1,000',
        linkData.state || '',
        linkData.district || '',
        linkData.web_link || '',
        linkData.utr || '—',
      ]
    );
    return { ...rows[0], created_at: toIso(rows[0].created_at) };
  }

  // --- Notifications for Users ---
  async getUserNotifications(userId, filterType = 'all') {
    const uId = parseInt(userId || 1, 10);
    const { rows } = await this.pool.query(
      'SELECT * FROM notifications WHERE user_id IS NULL OR user_id = $1 ORDER BY created_at DESC',
      [uId]
    );
    const userNotifs = rows.map(mapNotification);

    const counts = {
      all: userNotifs.length,
      unread: userNotifs.filter((n) => !n.is_read && !n.read).length,
      earning: userNotifs.filter((n) => n.type === 'earning' || n.type === 'wallet').length,
      moderation: userNotifs.filter((n) => n.type === 'moderation' || n.type === 'video').length,
      social: userNotifs.filter((n) => ['social', 'like', 'comment', 'follow'].includes(n.type)).length,
      system: userNotifs.filter((n) => ['system', 'announcement', 'info', 'birthday'].includes(n.type)).length,
    };

    let filtered = userNotifs;
    if (filterType && filterType !== 'all') {
      if (filterType === 'earning' || filterType === 'wallet') {
        filtered = userNotifs.filter((n) => n.type === 'earning' || n.type === 'wallet');
      } else if (filterType === 'moderation' || filterType === 'video') {
        filtered = userNotifs.filter((n) => n.type === 'moderation' || n.type === 'video');
      } else if (filterType === 'social') {
        filtered = userNotifs.filter((n) => ['social', 'like', 'comment', 'follow'].includes(n.type));
      } else if (filterType === 'system') {
        filtered = userNotifs.filter((n) => ['system', 'announcement', 'info', 'birthday'].includes(n.type));
      } else {
        filtered = userNotifs.filter((n) => n.type === filterType);
      }
    }

    return { notifications: filtered, unread_count: counts.unread, counts };
  }

  async addUserNotification(userId, data) {
    const nextId = `notif_u_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
    const { rows } = await this.pool.query(
      `INSERT INTO notifications (id, user_id, title, message, body, type, icon, color, avatar, action_url, action_text, created_at, is_read, read)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,false,false)
       RETURNING *`,
      [
        nextId,
        userId ? parseInt(userId, 10) : null,
        data.title || 'Notification',
        data.message || data.body || '',
        data.message || data.body || '',
        data.type || 'info',
        data.icon || (data.type === 'earning' ? 'coins' : data.type === 'moderation' ? 'check-circle' : data.type === 'social' ? 'heart' : 'bell'),
        data.color || (data.type === 'earning' ? 'amber' : data.type === 'moderation' ? 'purple' : data.type === 'social' ? 'rose' : 'blue'),
        data.avatar || '',
        data.action_url || '',
        data.action_text || '',
        data.created_at || new Date().toISOString(),
      ]
    );
    return mapNotification(rows[0]);
  }

  async markNotificationRead(id) {
    const res = await this.pool.query('UPDATE notifications SET is_read = true, read = true WHERE id = $1', [String(id)]);
    return res.rowCount > 0;
  }

  async markAllNotificationsRead(userId) {
    const uId = parseInt(userId || 1, 10);
    const res = await this.pool.query(
      'UPDATE notifications SET is_read = true, read = true WHERE (user_id IS NULL OR user_id = $1) AND (is_read = false OR read = false)',
      [uId]
    );
    return res.rowCount;
  }

  async deleteNotification(id) {
    const res = await this.pool.query('DELETE FROM notifications WHERE id = $1', [String(id)]);
    return res.rowCount > 0;
  }

  async clearUserNotifications(userId) {
    const uId = parseInt(userId || 1, 10);
    await this.pool.query('DELETE FROM notifications WHERE user_id IS NULL OR user_id = $1', [uId]);
    return true;
  }

  // --- Creator Channel Stats ---
  async getCreatorStats(userId) {
    const uId = parseInt(userId || 1, 10);
    const user = (await this.findUserById(uId)) || (await this.getUsers())[0];
    const userVideos = await this.getUserVideos(user.id);
    const totalLikes = userVideos.reduce((sum, v) => sum + (v.likes_count || 0), 0);
    const totalViews = userVideos.reduce((sum, v) => sum + (v.view_count || 0), 0);
    const totalComments = userVideos.reduce((sum, v) => sum + (v.comments_count || 0), 0);
    const approvedVideos = userVideos.filter((v) => v.status === 'Approved');
    const pendingVideos = userVideos.filter((v) => v.status === 'Pending');
    const wallet = await this.getWallet(user.id);

    return {
      user_id: user.id,
      name: user.name,
      username: user.username,
      avatar: (user.name || user.username || 'TW').substring(0, 2).toUpperCase(),
      subscribers_count: 52,
      total_videos: userVideos.length,
      approved_count: approvedVideos.length,
      pending_count: pendingVideos.length,
      total_likes: totalLikes,
      total_views: totalViews,
      total_comments: totalComments,
      wallet_balance: wallet.balance,
      videos: userVideos,
    };
  }

  // --- Create Ad Campaign ---
  async createAd(adData) {
    return this.createVideo({
      user_id: adData.user_id || 1,
      name: adData.name || 'Sponsored Creator',
      username: adData.username || 'sponsored',
      title: adData.title || 'Sponsored Campaign',
      subject: adData.subject || adData.title || 'Check out this special promotion on Telso World!',
      category: 'Promotion',
      video_url: adData.video_url || '/uploads/videos/sample5.mp4',
      video_path: adData.video_url || '/uploads/videos/sample1.mp4',
      thumbnail_url: adData.thumbnail_url || 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&auto=format&fit=crop',
      image: adData.thumbnail_url || 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&auto=format&fit=crop',
      target_url: adData.target_url || '',
      budget: parseFloat(adData.budget) || 500.0,
      video_type: 'ads',
      status: 'Approved',
    });
  }

  // --- System Stats for Admin ---
  async getStats() {
    const [uRes, vRes, cRes, wRes, bdays] = await Promise.all([
      this.pool.query('SELECT COUNT(*)::int AS cnt FROM users'),
      this.pool.query(
        `SELECT COUNT(*)::int AS total_videos,
                COALESCE(SUM(view_count), 0)::int AS total_views,
                COALESCE(SUM(likes_count), 0)::int AS total_likes,
                COUNT(*) FILTER (WHERE status = 'Pending')::int AS pending_videos_count,
                COUNT(*) FILTER (WHERE video_type = 'normal')::int AS normal_videos_count,
                COUNT(*) FILTER (WHERE video_type = 'ads')::int AS ads_videos_count
         FROM videos`
      ),
      this.pool.query('SELECT COUNT(*)::int AS cnt FROM comments'),
      this.pool.query("SELECT COUNT(*)::int AS cnt FROM withdrawals WHERE status = 'pending'"),
      this.getTodayBirthdays(),
    ]);
    const v = vRes.rows[0];
    return {
      total_users: uRes.rows[0].cnt,
      total_videos: v.total_videos,
      total_views: v.total_views,
      total_likes: v.total_likes,
      total_comments: cRes.rows[0].cnt,
      pending_withdrawals: wRes.rows[0].cnt,
      pending_videos_count: v.pending_videos_count,
      today_birthdays_count: bdays.length,
      normal_videos_count: v.normal_videos_count,
      ads_videos_count: v.ads_videos_count,
    };
  }
}

const db = new PostgresDatabase();
module.exports = db;
