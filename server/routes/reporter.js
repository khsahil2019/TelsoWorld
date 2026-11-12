const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const db = require('../db');
const { authRequired, authOptional } = require('../middleware/auth');
const {
  normalizeMediaUrl,
  toRelativeMediaPath,
  ensureMp4PlayableWithSound,
} = require('../utils/media');

const router = express.Router();

/**
 * Normalizes any video object so `video_url`, `video_path`, `url`, and thumbnails
 * always resolve against the incoming request host (works across localhost, Wi-Fi LAN, and production).
 */
function formatVideoResponse(req, v) {
  const rawVideo = v.video_url || v.video_path || v.url || '';
  const videoUrl = normalizeMediaUrl(req, rawVideo);
  const rawThumb = v.thumbnail_url || v.image || '';
  const thumbUrl = normalizeMediaUrl(req, rawThumb);

  return {
    id: v.id,
    user_id: v.user_id,
    name: v.name || v.username || 'Telso Creator',
    username: v.username || 'creator',
    title: v.title,
    subject: v.subject || v.title,
    category: v.category || 'Music',
    video_url: videoUrl,
    video_path: videoUrl,
    url: videoUrl,
    thumbnail_url: thumbUrl,
    image: thumbUrl,
    video_type: v.video_type || 'normal',
    likes_count: v.likes_count || 0,
    shares_count: v.shares_count || 0,
    view_count: v.view_count || 0,
    comments_count: v.comments_count || 0,
    liked: Boolean(v.liked || v.is_liked),
    is_liked: Boolean(v.is_liked || v.liked),
    has_audio: v.has_audio !== false,
    audio_title: v.audio_title || '',
    status: v.status || 'Approved',
    created_at: v.created_at,
  };
}

// Multer storage for uploaded video & thumbnail files
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    let destDir = path.join(__dirname, '..', 'uploads', 'videos');
    if (file.fieldname === 'thumbnail' || file.mimetype.startsWith('image/')) {
      destDir = path.join(__dirname, '..', 'uploads', 'thumbnails');
    }
    if (!fs.existsSync(destDir)) {
      fs.mkdirSync(destDir, { recursive: true });
    }
    cb(null, destDir);
  },
  filename: function (req, file, cb) {
    const ext = path.extname(file.originalname) || (file.fieldname === 'video' ? '.mp4' : '.jpg');
    const unique = `${Date.now()}-${Math.round(Math.random() * 1e9)}${ext}`;
    cb(null, unique);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 250 * 1024 * 1024 }, // 250 MB
});

/**
 * 🎬 GET /api/reporter/dashboard
 * Returns the primary video reels feed for home/explore screen
 */
router.get('/dashboard', authOptional, (req, res) => {
  const currentUserId = req.user ? req.user.id : null;
  const videos = db.getVideos({ type: 'normal', status: 'Approved', currentUserId });
  const settings = db.data.settings;
  const user = req.user || db.findUserById(1);

  const formattedVideos = videos.map(v => formatVideoResponse(req, v));

  return res.status(200).json({
    status: true,
    message: 'Dashboard loaded successfully',
    referral_code: user ? user.referral_code : 'TELSO2026',
    setting: {
      id: settings.id,
      name: settings.name,
      file_uploaded: settings.file_uploaded,
      value: settings.value,
      updated_at: settings.updated_at,
    },
    videos: formattedVideos,
  });
});

/**
 * 📢 GET /api/reporter/ads-all-videos
 * Returns promotional & sponsor reels
 */
router.get('/ads-all-videos', authOptional, (req, res) => {
  const currentUserId = req.user ? req.user.id : null;
  const ads = db.getVideos({ type: 'ads', status: 'Approved', currentUserId });
  const formatted = ads.map(v => formatVideoResponse(req, { ...v, video_type: 'ads' }));

  return res.status(200).json({
    status: true,
    data: formatted,
    videos: formatted,
  });
});

/**
 * 🎬 GET /api/reporter/video/:id
 * Fetch a single video (including Pending uploads for Studio/Watch preview)
 */
router.get('/video/:id', authOptional, (req, res) => {
  const targetId = String(req.params.id);
  const video = db.data.videos.find(v => String(v.id) === targetId);
  if (!video) {
    return res.status(404).json({ status: false, message: 'Video not found' });
  }
  const currentUserId = req.user ? req.user.id : null;
  const liked = currentUserId && Array.isArray(video.liked_by)
    ? video.liked_by.includes(currentUserId)
    : false;
  return res.status(200).json({
    status: true,
    data: formatVideoResponse(req, { ...video, liked, is_liked: liked }),
  });
});

/**
 * 👁️ POST /api/reporter/normal-video/view
 * 👁️ POST /api/reporter/adsvideo/view
 * Strict Unique View: Counted only once per user / device
 */
const handleRecordView = (req, res) => {
  const videoId = req.body.video_id || req.body.id || req.query.video_id;
  if (!videoId) {
    return res.status(422).json({ status: false, message: 'video_id is required' });
  }

  const viewerIdentifier = req.user ? `user_${req.user.id}` : (req.body.viewer_id || req.ip || req.connection.remoteAddress || 'guest');
  const result = db.recordVideoView(videoId, viewerIdentifier);
  if (!result) {
    return res.status(404).json({ status: false, message: 'Video not found' });
  }

  return res.status(200).json({
    status: true,
    message: result.incremented ? 'View counted successfully' : 'View already counted for this user',
    incremented: result.incremented,
    views_count: result.view_count,
  });
};

router.post('/normal-video/view', authOptional, handleRecordView);
router.post('/adsvideo/view', authOptional, handleRecordView);

/**
 * ❤️ POST /api/reporter/normal-video/like
 * ❤️ POST /api/reporter/adsvideo/like
 * Includes 5-Layer Engagement Reward on Ad / Sponsored Posts
 */
const handleToggleLike = (req, res) => {
  const videoId = req.body.video_id || req.body.id;
  if (!videoId) {
    return res.status(422).json({ status: false, message: 'video_id is required' });
  }

  const userId = req.user ? req.user.id : (req.body.user_id ? parseInt(req.body.user_id, 10) : 1);
  const result = db.toggleVideoLike(videoId, userId);

  if (!result) {
    return res.status(404).json({ status: false, message: 'Video not found' });
  }

  return res.status(200).json({
    status: true,
    message: result.liked ? 'Video liked' : 'Video unliked',
    liked: result.liked,
    is_liked: result.liked,
    likes_count: result.likes_count,
    reward_info: result.reward_info,
  });
};

router.post('/normal-video/like', authOptional, handleToggleLike);
router.post('/adsvideo/like', authOptional, handleToggleLike);

/**
 * 📊 GET /api/reporter/creator-stats
 * Returns creator channel stats (total likes received, total views, video counts)
 */
router.get('/creator-stats', authOptional, (req, res) => {
  const userId = req.user ? req.user.id : (req.query.user_id || 1);
  const stats = db.getCreatorStats(userId);
  return res.status(200).json({ status: true, data: stats });
});

/**
 * 👤 GET /api/reporter/profile
 * Returns full profile info for the logged-in user
 */
router.get('/profile', authOptional, (req, res) => {
  const userId = req.user ? req.user.id : (req.query.user_id || 1);
  const user = db.findUserById(userId) || db.getUsers()[0];
  const stats = db.getCreatorStats(user.id);
  const wallet = db.getWallet(user.id);

  return res.status(200).json({
    status: true,
    data: {
      id: user.id,
      name: user.name,
      username: user.username,
      email: user.email,
      mobile_no: user.mobile_no,
      whatsapp: user.whatsapp || user.mobile_no,
      dob: user.dob,
      bio: user.bio || 'Official Creator on Telso World 🎵 Singer, Music Producer & Live Performer.',
      verified: true,
      subscribers_count: stats.subscribers_count || 52,
      total_videos: stats.total_videos,
      total_likes: stats.total_likes,
      total_views: stats.total_views,
      wallet_balance: wallet.balance,
      referral_code: user.referral_code || 'TELSO2026',
      videos: (stats.videos || []).map(v => formatVideoResponse(req, v)),
    },
  });
});

/**
 * ✏️ PUT /api/reporter/profile
 * Updates creator profile info (name, bio, whatsapp, email)
 */
router.put('/profile', authOptional, (req, res) => {
  const userId = req.user ? req.user.id : (req.body.user_id || 1);
  const user = db.findUserById(userId);
  if (!user) {
    return res.status(404).json({ status: false, message: 'User not found' });
  }

  if (req.body.name) user.name = req.body.name.trim();
  if (req.body.bio) user.bio = req.body.bio.trim();
  if (req.body.email) user.email = req.body.email.trim();
  if (req.body.whatsapp) user.whatsapp = req.body.whatsapp.trim();

  db.save();

  return res.status(200).json({
    status: true,
    message: 'Profile updated successfully! ✨',
    data: user,
  });
});

/**
 * 🔔 GET /api/reporter/notifications
 * Returns notifications for current user with counts and category filter
 */
router.get('/notifications', authOptional, (req, res) => {
  const userId = req.user ? req.user.id : (req.query.user_id || 1);
  const category = req.query.category || 'all';
  const result = db.getUserNotifications(userId, category);
  return res.status(200).json({
    status: true,
    data: result.notifications,
    unread_count: result.unread_count,
    counts: result.counts,
  });
});

/**
 * 🔔 POST /api/reporter/notifications/read
 * Marks single notification or all as read
 */
router.post('/notifications/read', authOptional, (req, res) => {
  const userId = req.user ? req.user.id : (req.query.user_id || 1);
  const { id, all } = req.body || {};
  if (all) {
    const updated = db.markAllNotificationsRead(userId);
    return res.status(200).json({ status: true, message: 'All notifications marked as read', updated });
  }
  if (id) {
    const success = db.markNotificationRead(id, userId);
    return res.status(200).json({ status: success, message: success ? 'Marked as read' : 'Notification not found' });
  }
  return res.status(400).json({ status: false, message: 'Missing notification id or all flag' });
});

/**
 * 🗑️ POST /api/reporter/notifications/clear
 * Clears all notifications for current user
 */
router.post('/notifications/clear', authOptional, (req, res) => {
  const userId = req.user ? req.user.id : (req.query.user_id || 1);
  db.clearUserNotifications(userId);
  return res.status(200).json({ status: true, message: 'All notifications cleared successfully' });
});

/**
 * 🗑️ DELETE /api/reporter/notifications/:id
 * Removes a single notification
 */
router.delete('/notifications/:id', authOptional, (req, res) => {
  const userId = req.user ? req.user.id : (req.query.user_id || 1);
  const success = db.deleteNotification(req.params.id, userId);
  return res.status(200).json({ status: success, message: success ? 'Notification deleted' : 'Notification not found' });
});

/**
 * 📢 POST /api/reporter/create-ad
 * Allows users to create sponsored ad campaigns with 5-layer rewards
 */
router.post('/create-ad', authOptional, (req, res) => {
  const user = req.user || db.findUserById(1);
  const newAd = db.createAd({
    user_id: user ? user.id : 1,
    name: user ? (user.name || user.username) : 'Sponsored Ad',
    username: user ? user.username : 'sponsored',
    title: req.body.title || 'Sponsored Campaign',
    subject: req.body.subject || req.body.description || 'Exclusive Telso World Promotion',
    category: req.body.category || 'Promotion',
    video_url: req.body.video_url || '/uploads/videos/sample1.mp4',
    thumbnail_url: req.body.thumbnail_url || 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&auto=format&fit=crop',
    target_url: req.body.target_url || req.body.link || '',
    budget: req.body.budget || 500.0,
  });
  return res.status(201).json({ status: true, message: 'Sponsored Ad campaign created! 🎉', data: newAd });
});

/**
 * 📤 POST /api/reporter/upload-video
 * Multipart form data upload for video reels with MP4 + AAC audio normalization
 */
router.post(
  '/upload-video',
  authOptional,
  upload.fields([
    { name: 'video', maxCount: 1 },
    { name: 'file', maxCount: 1 },
    { name: 'thumbnail', maxCount: 1 },
  ]),
  async (req, res) => {
    try {
      const user = req.user || db.findUserById(1);
      const title = req.body.title || req.body.subject || 'New Reel';
      const subject = req.body.subject || req.body.title || '';
      const category = req.body.category || 'Music';
      const videoType = req.body.video_type || 'normal';

      let videoUrl = req.body.video_url || req.body.url || '';
      let thumbUrl = req.body.thumbnail_url || '';
      let hasAudio = true;

      const videoFile = (req.files && (req.files['video'] || req.files['file'])) ? (req.files['video'] || req.files['file'])[0] : null;
      const thumbFile = (req.files && req.files['thumbnail']) ? req.files['thumbnail'][0] : null;

      if (videoFile) {
        const settings = db.getSettings();
        const maxMb = (settings.platform && settings.platform.max_upload_size_mb) || 250;
        if (videoFile.size > maxMb * 1024 * 1024) {
          try { fs.unlinkSync(videoFile.path); } catch(_) {}
          return res.status(413).json({
            status: false,
            message: `Video file exceeds the maximum allowed size of ${maxMb}MB configured by administrator.`,
          });
        }
        // Guarantee web & Android MP4 compatibility (H.264 + AAC audio + faststart)
        const mediaCheck = await ensureMp4PlayableWithSound(videoFile.path);
        hasAudio = mediaCheck.hasAudio;
        videoUrl = `/uploads/videos/${videoFile.filename}`;
      }
      if (thumbFile) {
        thumbUrl = `/uploads/thumbnails/${thumbFile.filename}`;
      }

      if (!videoUrl) {
        return res.status(422).json({
          status: false,
          message: 'Video file or video_url is required',
        });
      }

      // Store relative path for local uploads so it works on localhost, LAN IP, and production
      const storedVideoPath = toRelativeMediaPath(videoUrl);
      const storedThumbPath = toRelativeMediaPath(thumbUrl);

      const newVideo = db.createVideo({
        user_id: user ? user.id : 1,
        name: user ? (user.name || user.username) : 'Telso Creator',
        username: user ? user.username : 'creator',
        title,
        subject,
        category,
        video_url: storedVideoPath,
        video_path: storedVideoPath,
        thumbnail_url: storedThumbPath,
        image: storedThumbPath,
        video_type: videoType,
        has_audio: hasAudio,
        status: 'Pending', // Sent to Admin approval list first!
        audio_title: `Original Audio - ${user ? (user.name || user.username) : 'Telso Creator'}`,
      });

      const responseVideo = formatVideoResponse(req, newVideo);

      return res.status(201).json({
        status: true,
        message: 'Video uploaded successfully! Sent to Admin for approval. It will appear on the feed once approved. ⏳',
        video: responseVideo,
        data: responseVideo,
      });
    } catch (err) {
      console.error('Upload video error:', err);
      return res.status(500).json({
        status: false,
        message: 'Video upload processing failed',
      });
    }
  }
);

/**
 * 💰 GET /api/reporter/wallet
 */
router.get('/wallet', authOptional, (req, res) => {
  const userId = req.user ? req.user.id : 3; // Default to user 3 (Telso Star Creator) if guest
  const walletData = db.getWallet(userId);

  return res.status(200).json({
    status: true,
    balance: walletData.balance,
    total_balance: walletData.total_balance,
    pending_amount: walletData.pending_amount,
    transactions: walletData.transactions,
  });
});

/**
 * 🔗 GET /api/reporter/referral
 */
router.get('/referral', authOptional, (req, res) => {
  const userId = req.user ? req.user.id : 3;
  const refData = db.getReferral(userId, req.get('host'));

  if (!refData) {
    return res.status(404).json({ status: false, message: 'User not found' });
  }

  return res.status(200).json({
    status: true,
    ...refData,
  });
});

/**
 * 🎥 GET /api/reporter/my-videos
 */
router.get('/my-videos', authOptional, (req, res) => {
  const currentUserId = req.user ? req.user.id : 1;
  const userVideos = db.data.videos
    .filter(v => v.user_id === currentUserId)
    .map(v => formatVideoResponse(req, v));
  return res.status(200).json({
    status: true,
    data: userVideos,
    videos: userVideos,
  });
});

/**
 * 🌐 GET /api/reporter/web-links
 */
router.get('/web-links', authOptional, (req, res) => {
  const currentUserId = req.user ? req.user.id : null;
  const links = db.getWebLinks(currentUserId);
  return res.status(200).json({
    status: true,
    data: links,
    links,
  });
});

/**
 * ➕ POST /api/reporter/web-links
 */
router.post('/web-links', authOptional, (req, res) => {
  const user = req.user || db.findUserById(1);
  const newLink = db.createWebLink({
    user_id: user ? user.id : 1,
    subject: req.body.subject,
    name: req.body.name,
    like_limit: req.body.like_limit,
    state: req.body.state,
    district: req.body.district,
    web_link: req.body.web_link || req.body.link,
    utr: req.body.utr,
  });

  return res.status(201).json({
    status: true,
    message: 'Web Link submitted for review',
    data: newLink,
  });
});

/**
 * 🎂 GET /api/reporter/today-birthdays
 * Public endpoint for web visitors & creators to view today's celebrating creators
 */
router.get('/today-birthdays', (req, res) => {
  const birthdays = db.getTodayBirthdays().map(u => ({
    id: u.id,
    name: u.name,
    username: u.username,
    whatsapp: u.whatsapp || u.mobile_no,
    dob: u.dob,
    state: u.state,
  }));
  return res.status(200).json({
    status: true,
    count: birthdays.length,
    data: birthdays,
  });
});

module.exports = router;

