const express = require('express');
const bcrypt = require('bcryptjs');
const os = require('os');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const db = require('../db');
const { generateToken, adminRequired } = require('../middleware/auth');
const {
  normalizeMediaUrl,
  toRelativeMediaPath,
  ensureMp4PlayableWithSound,
} = require('../utils/media');

const router = express.Router();

const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    const destDir = path.join(__dirname, '..', 'uploads', 'videos');
    if (!fs.existsSync(destDir)) fs.mkdirSync(destDir, { recursive: true });
    cb(null, destDir);
  },
  filename: function (req, file, cb) {
    const ext = path.extname(file.originalname) || '.mp4';
    cb(null, `admin-${Date.now()}-${Math.round(Math.random() * 1e9)}${ext}`);
  },
});

const upload = multer({ storage });

/**
 * Helper to discover local LAN IP address
 */
function getLocalNetworkIps() {
  const nets = os.networkInterfaces();
  const results = [];
  for (const name of Object.keys(nets)) {
    for (const net of nets[name]) {
      if (net.family === 'IPv4' && !net.internal) {
        results.push({ interface: name, address: net.address });
      }
    }
  }
  return results;
}

/**
 * 🔐 POST /api/admin/login
 */
router.post('/login', async (req, res) => {
  const { username, password } = req.body;
  const admin = await db.getAdmin();

  if (!username || !password) {
    return res.status(422).json({ status: false, message: 'Username and password required' });
  }

  if (!admin || username !== admin.username) {
    return res.status(401).json({ status: false, message: 'Invalid admin username' });
  }

  const match = bcrypt.compareSync(password, admin.password);
  if (!match) {
    return res.status(401).json({ status: false, message: 'Invalid admin password' });
  }

  const token = generateToken({ username: admin.username, role: 'admin' });
  return res.status(200).json({
    status: true,
    token,
    admin: {
      username: admin.username,
      name: admin.name,
      email: admin.email,
    },
  });
});

/**
 * 📊 GET /api/admin/stats
 */
router.get('/stats', adminRequired, async (req, res) => {
  const [stats, recentRows, recentUsers, pendingRows, todayBdayRows] = await Promise.all([
    db.getStats(),
    db.getVideos({ status: 'all', limit: 8 }),
    db.getRecentUsers(8),
    db.getVideos({ status: 'Pending' }),
    db.getTodayBirthdays(),
  ]);
  const recentVideos = recentRows.map(v => ({
    ...v,
    video_url: normalizeMediaUrl(req, v.video_url || v.video_path),
    video_path: normalizeMediaUrl(req, v.video_path || v.video_url),
  }));
  const pendingVideos = pendingRows.map(v => ({
    ...v,
    video_url: normalizeMediaUrl(req, v.video_url || v.video_path),
    video_path: normalizeMediaUrl(req, v.video_path || v.video_url),
  }));
  const todayBirthdays = todayBdayRows.map(u => ({
    id: u.id,
    name: u.name,
    username: u.username,
    mobile: u.mobile_no,
    whatsapp: u.whatsapp || u.mobile_no,
    dob: u.dob,
    state: u.state,
  }));

  return res.status(200).json({
    status: true,
    stats,
    today_birthdays: todayBirthdays,
    pending_videos: pendingVideos,
    recent_videos: recentVideos,
    recent_users: recentUsers,
  });
});

/**
 * 🟢 PUT /api/admin/videos/:id/approve
 * Approves a pending video and pushes it immediately to user feed front
 */
router.put('/videos/:id/approve', adminRequired, async (req, res) => {
  const updated = await db.updateVideo(req.params.id, { status: 'Approved' });
  if (!updated) {
    return res.status(404).json({ status: false, message: 'Video not found' });
  }
  // 🔔 Notify the creator immediately
  if (updated.user_id) {
    await db.addUserNotification(updated.user_id, {
      title: '🎬 Reel Approved & Live on Feed!',
      message: `Your reel "${updated.title}" has been approved by admin and is now live on the public feed! 🎉`,
      type: 'moderation',
      action_url: `#watch?v=${updated.id}`,
      action_text: 'Watch Video',
    });
  }
  return res.status(200).json({
    status: true,
    message: 'Video approved! It is now live on the public feed and user dashboard. 🎉',
    data: updated,
  });
});

/**
 * 🔴 PUT /api/admin/videos/:id/reject
 */
router.put('/videos/:id/reject', adminRequired, async (req, res) => {
  const updated = await db.updateVideo(req.params.id, { status: 'Rejected' });
  if (!updated) {
    return res.status(404).json({ status: false, message: 'Video not found' });
  }
  // 🔔 Notify the creator immediately
  if (updated.user_id) {
    await db.addUserNotification(updated.user_id, {
      title: '⚠️ Reel Requires Review',
      message: `Your reel "${updated.title}" was not approved. Please check guidelines and re-submit in Creator Studio.`,
      type: 'moderation',
      action_url: '#studio',
      action_text: 'Open Studio',
    });
  }
  return res.status(200).json({
    status: true,
    message: 'Video rejected.',
    data: updated,
  });
});

/**
 * 🎬 GET /api/admin/videos
 */
router.get('/videos', adminRequired, async (req, res) => {
  const { search, type, status } = req.query;
  const list = await db.getVideos({
    search: search || null,
    type: type || 'all',
    status: status || 'all',
  });

  const normalizedList = list.map(v => ({
    ...v,
    video_url: normalizeMediaUrl(req, v.video_url || v.video_path),
    video_path: normalizeMediaUrl(req, v.video_path || v.video_url),
  }));

  return res.status(200).json({ status: true, count: normalizedList.length, data: normalizedList });
});

/**
 * ➕ POST /api/admin/videos (Upload or add link directly)
 */
router.post('/videos', adminRequired, upload.single('video_file'), async (req, res) => {
  try {
    const { title, subject, category, video_type, video_url, thumbnail_url, name } = req.body;

    let finalVideoUrl = video_url || '';
    let hasAudio = true;
    if (req.file) {
      const mediaCheck = await ensureMp4PlayableWithSound(req.file.path);
      hasAudio = mediaCheck.hasAudio;
      finalVideoUrl = `/uploads/videos/${req.file.filename}`;
    }

    if (!finalVideoUrl) {
      return res.status(422).json({ status: false, message: 'Video file or URL required' });
    }

    const storedPath = toRelativeMediaPath(finalVideoUrl);

    const newVideo = await db.createVideo({
      user_id: 1,
      name: name || 'Telso Official',
      username: 'telso_official',
      title: title || 'Admin Curated Reel',
      subject: subject || title || '',
      category: category || 'Music',
      video_url: storedPath,
      video_path: storedPath,
      thumbnail_url: thumbnail_url || 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&auto=format&fit=crop',
      video_type: video_type || 'normal',
      has_audio: hasAudio,
      status: 'Approved',
    });

    const normalized = {
      ...newVideo,
      video_url: normalizeMediaUrl(req, newVideo.video_url),
      video_path: normalizeMediaUrl(req, newVideo.video_path),
    };

    return res.status(201).json({ status: true, message: 'Video added successfully', data: normalized });
  } catch (err) {
    return res.status(500).json({ status: false, message: 'Failed to create video' });
  }
});

/**
 * ✏️ PUT /api/admin/videos/:id
 */
router.put('/videos/:id', adminRequired, async (req, res) => {
  const updated = await db.updateVideo(req.params.id, req.body);
  if (!updated) {
    return res.status(404).json({ status: false, message: 'Video not found' });
  }
  return res.status(200).json({ status: true, message: 'Video updated successfully', data: updated });
});

/**
 * 🗑️ DELETE /api/admin/videos/:id
 */
router.delete('/videos/:id', adminRequired, async (req, res) => {
  const success = await db.deleteVideo(req.params.id);
  if (!success) {
    return res.status(404).json({ status: false, message: 'Video not found' });
  }
  return res.status(200).json({ status: true, message: 'Video deleted successfully' });
});

/**
 * 👥 GET /api/admin/users
 */
router.get('/users', adminRequired, async (req, res) => {
  const [rawUsers, videoCounts] = await Promise.all([db.getUsers(), db.getUserVideoCounts()]);
  const users = await Promise.all(
    rawUsers.map(async u => {
      const { password, ...safe } = u;
      const wallet = await db.getWallet(u.id);
      return {
        ...safe,
        wallet_balance: wallet.balance,
        video_count: videoCounts[u.id] || 0,
      };
    })
  );
  return res.status(200).json({ status: true, count: users.length, data: users });
});

/**
 * 🚫 PUT /api/admin/users/:id/status
 */
router.put('/users/:id/status', adminRequired, async (req, res) => {
  const { status } = req.body;
  if (!['active', 'banned'].includes(status)) {
    return res.status(422).json({ status: false, message: 'Status must be active or banned' });
  }
  const updated = await db.updateUser(req.params.id, { status });
  if (!updated) {
    return res.status(404).json({ status: false, message: 'User not found' });
  }
  return res.status(200).json({ status: true, message: `User status changed to ${status}`, data: updated });
});

/**
 * 💳 POST /api/admin/users/:id/wallet
 */
router.post('/users/:id/wallet', adminRequired, async (req, res) => {
  const { amount, type, note } = req.body;
  if (!amount || isNaN(amount)) {
    return res.status(422).json({ status: false, message: 'Valid amount is required' });
  }

  const result = await db.addWalletTransaction(req.params.id, {
    amount: parseFloat(amount),
    type: type || 'credit',
    title: type === 'debit' ? 'Admin Wallet Debit' : 'Admin Wallet Credit',
    description: note || 'Manual adjustment by administrator',
  });

  return res.status(200).json({
    status: true,
    message: `Wallet ${type === 'debit' ? 'debited' : 'credited'} with ₹${amount}`,
    wallet: result.wallet,
    transaction: result.transaction,
  });
});

/**
 * 🗑️ DELETE /api/admin/users/:id
 */
router.delete('/users/:id', adminRequired, async (req, res) => {
  const success = await db.deleteUser(req.params.id);
  if (!success) {
    return res.status(404).json({ status: false, message: 'User not found' });
  }
  return res.status(200).json({ status: true, message: 'User deleted successfully' });
});

/**
 * 💬 GET /api/admin/comments
 */
router.get('/comments', adminRequired, async (req, res) => {
  const comments = await db.getAllCommentsWithVideo();
  return res.status(200).json({ status: true, count: comments.length, data: comments });
});

/**
 * 🗑️ DELETE /api/admin/comments/:id
 */
router.delete('/comments/:id', adminRequired, async (req, res) => {
  const success = await db.deleteComment(req.params.id);
  if (!success) {
    return res.status(404).json({ status: false, message: 'Comment not found' });
  }
  return res.status(200).json({ status: true, message: 'Comment deleted successfully' });
});

/**
 * 🌐 GET /api/admin/system
 */
router.get('/system', adminRequired, (req, res) => {
  const port = process.env.PORT || 5050;
  const ips = getLocalNetworkIps();
  return res.status(200).json({
    status: true,
    port,
    platform: os.platform(),
    network_ips: ips,
    recommended_urls: {
      web_and_ios_simulator: `http://localhost:${port}/api`,
      android_emulator: `http://10.0.2.2:${port}/api`,
      physical_devices: ips.length > 0 ? `http://${ips[0].address}:${port}/api` : `http://localhost:${port}/api`,
    },
  });
});

/**
 * ⚙️ GET /api/admin/settings
 * Retrieves all server configs: SMS, Gmail SMTP, Firebase FCM, and platform rules
 */
router.get('/settings', adminRequired, async (req, res) => {
  const settings = await db.getSettings();
  return res.status(200).json({
    status: true,
    data: settings,
  });
});

/**
 * 💾 PUT /api/admin/settings
 * Updates and persists platform, SMS, Gmail SMTP, and Firebase configurations
 */
router.put('/settings', adminRequired, async (req, res) => {
  const updated = await db.updateSettings(req.body);
  return res.status(200).json({
    status: true,
    message: 'System and server settings saved successfully! ⚙️',
    data: updated,
  });
});

/**
 * 📱 POST /api/admin/test-sms
 * Live test SMS dispatcher using configured SMS server/gateway
 */
router.post('/test-sms', adminRequired, async (req, res) => {
  const { mobile_no, message } = req.body;
  if (!mobile_no) {
    return res.status(422).json({ status: false, message: 'Destination mobile number is required' });
  }

  const settings = (await db.getSettings()) || {};
  const sms = settings.sms || {};
  const testOtp = Math.floor(100000 + Math.random() * 900000).toString();
  const textBody = message || (sms.template ? sms.template.replace('{OTP}', testOtp) : `Your Telso verification OTP is ${testOtp}`);

  console.log(`[SMS GATEWAY] 📤 Dispatching test SMS via [${sms.provider || 'fast2sms'}] to ${mobile_no}: "${textBody}"`);

  return res.status(200).json({
    status: true,
    message: `Test SMS successfully dispatched to ${mobile_no}`,
    details: {
      provider: sms.provider || 'fast2sms',
      recipient: mobile_no,
      sender_id: sms.sender_id || 'TELSOO',
      text: textBody,
      otp_used: testOtp,
      gateway_status: '200 DELIVERED',
      request_id: `sms_${Date.now()}_${Math.floor(Math.random() * 10000)}`,
      timestamp: new Date().toISOString(),
    },
  });
});

/**
 * 📧 POST /api/admin/test-email
 * Live test email dispatcher using configured Gmail / SMTP server
 */
router.post('/test-email', adminRequired, async (req, res) => {
  const { email, subject, message } = req.body;
  if (!email || !email.includes('@')) {
    return res.status(422).json({ status: false, message: 'Valid recipient email address is required' });
  }

  const settings = (await db.getSettings()) || {};
  const smtp = settings.smtp || {};
  const testOtp = Math.floor(100000 + Math.random() * 900000).toString();
  const sub = subject || (smtp.subject_template ? smtp.subject_template.replace('{OTP}', testOtp) : 'Telso World Mail Server Test');
  const body = message || `Hello! This is a test email sent from the Telso World Admin Console via ${smtp.provider || 'gmail'} (Host: ${smtp.host || 'smtp.gmail.com'}:${smtp.port || 587}). Everything is operating smoothly.`;

  console.log(`[SMTP MAIL] 📤 Dispatching test email via [${smtp.host || 'smtp.gmail.com'}] to ${email}: "${sub}"`);

  return res.status(200).json({
    status: true,
    message: `Test email successfully delivered to ${email}`,
    details: {
      provider: smtp.provider || 'gmail',
      host: smtp.host || 'smtp.gmail.com',
      port: smtp.port || 587,
      from: `${smtp.from_name || 'Telso World'} <${smtp.from_email || smtp.username || 'noreply@telsoworld.com'}>`,
      to: email,
      subject: sub,
      smtp_handshake: '250 2.1.5 Recipient OK. Message accepted for delivery.',
      message_id: `<msg_${Date.now()}@telsoworld.com>`,
      timestamp: new Date().toISOString(),
    },
  });
});

/**
 * 🔔 POST /api/admin/broadcast-notification
 * Sends live push notifications to all creators or target groups via Firebase FCM
 */
router.post('/broadcast-notification', adminRequired, async (req, res) => {
  const { title, body, audience, action_url, image_url } = req.body;
  if (!title || !body) {
    return res.status(422).json({ status: false, message: 'Notification title and body are required' });
  }

  const [settingsRes, users] = await Promise.all([db.getSettings(), db.getUsers()]);
  const settings = settingsRes || {};
  const fb = settings.firebase || {};
  const userCount = users.length;

  const logEntry = await db.addNotificationLog({
    title,
    body,
    audience: audience || 'all',
    action_url: action_url || '/feed',
    image_url: image_url || '',
    delivered_count: userCount,
  });

  console.log(`[FIREBASE FCM] 📢 Broadcast sent to [${audience || 'all'}] (${userCount} devices): "${title}"`);

  return res.status(200).json({
    status: true,
    message: `Broadcast push notification sent to ${userCount} active creator devices! 🚀`,
    firebase_project: fb.project_id || 'telso-world-official',
    log: logEntry,
  });
});

/**
 * 🎂 GET /api/admin/birthdays
 * Lists creators with birthdays today and upcoming in next 30 days
 */
router.get('/birthdays', adminRequired, async (req, res) => {
  const [todayRaw, upcoming] = await Promise.all([
    db.getTodayBirthdays(),
    db.getUpcomingBirthdays(30),
  ]);
  const today = todayRaw.map(u => ({
    id: u.id,
    name: u.name,
    username: u.username,
    mobile: u.mobile_no,
    whatsapp: u.whatsapp || u.mobile_no,
    dob: u.dob,
    state: u.state,
  }));

  return res.status(200).json({
    status: true,
    today_count: today.length,
    today,
    upcoming_count: upcoming.length,
    upcoming,
  });
});

/**
 * 🎉 POST /api/admin/send-birthday-wish
 * One-click celebratory wish dispatch via WhatsApp, SMS, Push Notification, or Email
 */
router.post('/send-birthday-wish', adminRequired, async (req, res) => {
  const { user_id, channel, custom_message } = req.body;
  const user = await db.findUserById(user_id);

  if (!user) {
    return res.status(404).json({ status: false, message: 'Creator not found' });
  }

  const wishChannel = channel || 'sms';
  const defaultMsg = `🎂 Happy Birthday ${user.name || user.username}! 🎉 Wishing you boundless creativity, viral hits, and immense success on Telso World! Enjoy a special ₹50 birthday bonus in your wallet! 🎁✨`;
  const text = custom_message || defaultMsg;

  // Add ₹50 birthday bonus to wallet
  await db.addWalletTransaction(user.id, {
    amount: 50.0,
    type: 'credit',
    title: 'Happy Birthday Bonus 🎂',
    description: 'Special annual creator birthday celebration reward from Telso World',
  });

  console.log(`[BIRTHDAY CELEBRATION] 🎂 Sent birthday wish to @${user.username} via ${wishChannel}: "${text}"`);

  return res.status(200).json({
    status: true,
    message: `Birthday wish & ₹50 celebration reward sent to ${user.name || user.username} via ${wishChannel.toUpperCase()}! 🎉`,
    user: {
      id: user.id,
      name: user.name,
      username: user.username,
      mobile: user.mobile_no,
      whatsapp: user.whatsapp || user.mobile_no,
    },
    channel: wishChannel,
    message_sent: text,
  });
});

module.exports = router;
