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
  generateVideoThumbnail,
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
  const fallbackMedia = v.media_type === 'photo' ? videoUrl : '';
  const resolvedThumb = thumbUrl || fallbackMedia;
  const userAvatar = normalizeMediaUrl(req, v.user_profile_image || v.profile_image || '');

  return {
    id: v.id,
    user_id: v.user_id,
    name: v.user_name || v.name || v.username || 'Telso Creator',
    username: v.user_handle || v.username || 'creator',
    user_profile_image: userAvatar,
    profile_image: userAvatar,
    title: v.title,
    subject: v.subject || v.title,
    category: v.category || 'Music',
    video_url: videoUrl,
    video_path: videoUrl,
    url: videoUrl,
    thumbnail_url: resolvedThumb,
    image: resolvedThumb,
    video_type: v.video_type || 'normal',
    likes_count: v.likes_count || 0,
    shares_count: v.shares_count || 0,
    view_count: v.view_count || 0,
    comments_count: v.comments_count || 0,
    liked: Boolean(v.liked || v.is_liked),
    is_liked: Boolean(v.is_liked || v.liked),
    has_audio: v.has_audio !== false,
    audio_title: v.audio_title || '',
    media_type: v.media_type || 'video',
    photo_url: v.photo_url ? normalizeMediaUrl(req, v.photo_url) : (v.media_type === 'photo' ? videoUrl : resolvedThumb),
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
router.get('/dashboard', authOptional, async (req, res) => {
  const currentUserId = req.user ? req.user.id : null;
  const videos = await db.getVideos({ type: 'normal', status: 'Approved', currentUserId });
  const settings = (await db.getSettings()) || {};
  const user = req.user || (await db.findUserById(1));

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
router.get('/ads-all-videos', authOptional, async (req, res) => {
  const currentUserId = req.user ? req.user.id : null;
  const ads = await db.getVideos({ type: 'ads', status: 'Approved', currentUserId });
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
router.get('/video/:id', authOptional, async (req, res) => {
  const currentUserId = req.user ? req.user.id : null;
  const video = await db.findVideoById(req.params.id, currentUserId);
  if (!video) {
    return res.status(404).json({ status: false, message: 'Video not found' });
  }
  return res.status(200).json({
    status: true,
    data: formatVideoResponse(req, video),
  });
});

/**
 * 👁️ POST /api/reporter/normal-video/view
 * 👁️ POST /api/reporter/adsvideo/view
 * Strict Unique View: Counted only once per user / device
 */
const handleRecordView = async (req, res) => {
  const videoId = req.body.video_id || req.body.id || req.query.video_id;
  if (!videoId) {
    return res.status(422).json({ status: false, message: 'video_id is required' });
  }

  const viewerIdentifier = req.user ? `user_${req.user.id}` : (req.body.viewer_id || req.ip || req.connection.remoteAddress || 'guest');
  const result = await db.recordVideoView(videoId, viewerIdentifier);
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

router.post(['/normal-video/view', '/video/view'], authOptional, handleRecordView);
router.post('/adsvideo/view', authOptional, handleRecordView);

/**
 * ❤️ POST /api/reporter/normal-video/like
 * ❤️ POST /api/reporter/adsvideo/like
 * Includes 5-Layer Engagement Reward on Ad / Sponsored Posts
 */
const handleToggleLike = async (req, res) => {
  const videoId = req.body.video_id || req.body.id;
  if (!videoId) {
    return res.status(422).json({ status: false, message: 'video_id is required' });
  }

  const userId = req.user ? req.user.id : (req.body.user_id ? parseInt(req.body.user_id, 10) : 8);
  const result = await db.toggleVideoLike(videoId, userId);

  if (!result) {
    return res.status(404).json({ status: false, message: 'Video not found' });
  }

  return res.status(200).json({
    status: true,
    message: result.liked ? 'Video liked' : 'Video unliked',
    liked: result.liked,
    is_liked: result.liked,
    action: result.liked ? 'liked' : 'unliked',
    likes_count: result.likes_count,
    reward_info: result.reward_info,
  });
};

router.post(['/normal-video/like', '/video/like'], authOptional, handleToggleLike);
router.post('/adsvideo/like', authOptional, handleToggleLike);

/**
 * 📊 GET /api/reporter/creator-stats
 * Returns creator channel stats (total likes received, total views, video counts)
 */
router.get('/creator-stats', authOptional, async (req, res) => {
  const userId = req.user ? req.user.id : (req.query.user_id || 1);
  const stats = await db.getCreatorStats(userId);
  return res.status(200).json({ status: true, data: stats });
});

/**
 * 👤 GET /api/reporter/profile
 * Returns full profile info for the logged-in user
 */
router.get('/profile', authOptional, async (req, res) => {
  const userId = req.user ? req.user.id : (req.query.user_id || 8);
  const user = (await db.findUserById(userId)) || (await db.getUsers())[0];
  if (!user) {
    return res.status(404).json({ status: false, message: 'No user profile found' });
  }
  const stats = await db.getCreatorStats(user.id);
  const wallet = await db.getWallet(user.id);

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
      profile_image: normalizeMediaUrl(req, user.profile_image || ''),
      verified: true,
      followers_count: stats.followers_count || 0,
      following_count: stats.following_count || 0,
      subscribers_count: stats.followers_count || 0,
      total_videos: stats.total_videos || 0,
      total_likes: stats.total_likes || 0,
      total_views: stats.total_views || 0,
      approved_count: stats.approved_count || 0,
      pending_count: stats.pending_count || 0,
      wallet_balance: wallet.balance,
      referral_code: user.referral_code || 'TELSO2026',
      videos: (stats.videos || []).map(v => formatVideoResponse(req, v)),
      liked_videos: (stats.liked_videos || []).map(v => formatVideoResponse(req, v)),
    },
  });
});

/**
 * 🤝 POST /api/reporter/follow/:id
 * Toggle follow/unfollow for a creator
 */
router.post('/follow/:id', authOptional, async (req, res) => {
  const currentUserId = req.user ? req.user.id : (req.body.user_id || 8);
  const targetId = parseInt(req.params.id, 10);
  if (!targetId || targetId === currentUserId) {
    return res.status(400).json({ status: false, message: 'Invalid target user' });
  }

  const result = await db.toggleFollow(currentUserId, targetId);
  const followersCount = await db.getFollowersCount(targetId);
  return res.status(200).json({
    status: true,
    following: result.following,
    followers_count: followersCount,
    message: result.following ? 'Followed successfully! ✨' : 'Unfollowed successfully.',
  });
});

/**
 * ✏️ PUT /api/reporter/profile & POST /api/reporter/profile
 * Updates creator profile info (name, bio, whatsapp, email, username, profile_image)
 */
const handleUpdateProfile = async (req, res) => {
  const userId = req.user ? req.user.id : (req.body.user_id || 1);
  const existing = await db.findUserById(userId);
  if (!existing) {
    return res.status(404).json({ status: false, message: 'User not found' });
  }

  const updates = {};
  if (req.body.name) updates.name = req.body.name.trim();
  if (req.body.bio !== undefined) updates.bio = req.body.bio.trim();
  if (req.body.email) updates.email = req.body.email.trim();
  if (req.body.whatsapp) updates.whatsapp = req.body.whatsapp.trim();
  if (req.body.username) updates.username = req.body.username.trim().toLowerCase();
  if (req.body.mobile_no) updates.mobile_no = req.body.mobile_no.trim();
  if (req.body.profile_image) updates.profile_image = req.body.profile_image.trim();

  if (req.file) {
    updates.profile_image = `/uploads/thumbnails/${req.file.filename}`;
  }

  const updated = await db.updateUser(userId, updates);

  return res.status(200).json({
    status: true,
    message: 'Profile updated successfully! ✨',
    data: {
      ...updated,
      profile_image: normalizeMediaUrl(req, updated.profile_image),
    },
  });
};

router.put('/profile', authOptional, upload.single('avatar'), handleUpdateProfile);
router.post('/profile', authOptional, upload.single('avatar'), handleUpdateProfile);

/**
 * 👥 GET /api/reporter/followers/:id
 */
router.get('/followers/:id', authOptional, async (req, res) => {
  const targetId = parseInt(req.params.id, 10);
  const currentUserId = req.user ? req.user.id : null;
  const list = await db.getFollowers(targetId);
  const formatted = await Promise.all(
    list.map(async (u) => ({
      id: u.id,
      name: u.name,
      username: u.username,
      profile_image: normalizeMediaUrl(req, u.profile_image),
      bio: u.bio,
      is_following: currentUserId ? await db.isFollowing(currentUserId, u.id) : false,
    }))
  );
  return res.status(200).json({ status: true, data: formatted });
});

/**
 * 👥 GET /api/reporter/following/:id
 */
router.get('/following/:id', authOptional, async (req, res) => {
  const targetId = parseInt(req.params.id, 10);
  const currentUserId = req.user ? req.user.id : null;
  const list = await db.getFollowing(targetId);
  const formatted = await Promise.all(
    list.map(async (u) => ({
      id: u.id,
      name: u.name,
      username: u.username,
      profile_image: normalizeMediaUrl(req, u.profile_image),
      bio: u.bio,
      is_following: currentUserId ? await db.isFollowing(currentUserId, u.id) : false,
    }))
  );
  return res.status(200).json({ status: true, data: formatted });
});

/**
 * 🌟 GET /api/reporter/highlights/:id
 */
router.get('/highlights/:id', authOptional, async (req, res) => {
  const userId = parseInt(req.params.id, 10);
  const list = await db.getHighlights(userId);
  return res.status(200).json({
    status: true,
    data: list.map((h) => ({
      ...h,
      cover_url: normalizeMediaUrl(req, h.cover_url),
    })),
  });
});

/**
 * 🌟 POST /api/reporter/highlights
 */
router.post('/highlights', authOptional, upload.single('cover'), async (req, res) => {
  const userId = req.user ? req.user.id : (req.body.user_id || 1);
  const title = (req.body.title || 'Highlight').trim();
  let coverUrl = req.body.cover_url || '';
  if (req.file) {
    coverUrl = `/uploads/thumbnails/${req.file.filename}`;
  }
  let items = [];
  try {
    if (req.body.items) items = JSON.parse(req.body.items);
  } catch (_) {}

  const highlight = await db.createHighlight({
    userId,
    title,
    coverUrl,
    items,
  });

  return res.status(201).json({
    status: true,
    message: 'Highlight created! 🌟',
    data: {
      ...highlight,
      cover_url: normalizeMediaUrl(req, highlight.cover_url),
    },
  });
});

/**
 * 🔔 GET /api/reporter/notifications
 * Returns notifications for current user with counts and category filter
 */
router.get('/notifications', authOptional, async (req, res) => {
  const userId = req.user ? req.user.id : (req.query.user_id || 1);
  const category = req.query.category || 'all';
  const result = await db.getUserNotifications(userId, category);
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
router.post('/notifications/read', authOptional, async (req, res) => {
  const userId = req.user ? req.user.id : (req.query.user_id || 1);
  const { id, all } = req.body || {};
  if (all) {
    const updated = await db.markAllNotificationsRead(userId);
    return res.status(200).json({ status: true, message: 'All notifications marked as read', updated });
  }
  if (id) {
    const success = await db.markNotificationRead(id, userId);
    return res.status(200).json({ status: success, message: success ? 'Marked as read' : 'Notification not found' });
  }
  return res.status(400).json({ status: false, message: 'Missing notification id or all flag' });
});

/**
 * 🗑️ POST /api/reporter/notifications/clear
 * Clears all notifications for current user
 */
router.post('/notifications/clear', authOptional, async (req, res) => {
  const userId = req.user ? req.user.id : (req.query.user_id || 1);
  await db.clearUserNotifications(userId);
  return res.status(200).json({ status: true, message: 'All notifications cleared successfully' });
});

/**
 * 🗑️ DELETE /api/reporter/notifications/:id
 * Removes a single notification
 */
router.delete('/notifications/:id', authOptional, async (req, res) => {
  const userId = req.user ? req.user.id : (req.query.user_id || 1);
  const success = await db.deleteNotification(req.params.id, userId);
  return res.status(200).json({ status: success, message: success ? 'Notification deleted' : 'Notification not found' });
});

/**
 * 📢 POST /api/reporter/create-ad
 * Allows users to create sponsored ad campaigns with 5-layer rewards
 */
router.post('/create-ad', authOptional, async (req, res) => {
  const user = req.user || (await db.findUserById(1));
  const newAd = await db.createAd({
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
    { name: 'photo', maxCount: 1 },
    { name: 'image', maxCount: 1 },
  ]),
  async (req, res) => {
    try {
      const user = req.user || (await db.findUserById(8));
      const title = req.body.title || req.body.subject || 'New Reel';
      const subject = req.body.subject || req.body.title || '';
      const category = req.body.category || 'General';
      const videoType = req.body.video_type || 'normal';
      const mediaType = req.body.media_type || 'video'; // 'video' | 'photo'
      const hasAudio = req.body.has_audio !== 'false' && req.body.has_audio !== false;

      let videoUrl = req.body.video_url || req.body.url || '';
      let thumbUrl = req.body.thumbnail_url || '';
      let photoUrl = '';

      const videoFile = (req.files && (req.files['video'] || req.files['file'])) ? (req.files['video'] || req.files['file'])[0] : null;
      const thumbFile = (req.files && req.files['thumbnail']) ? req.files['thumbnail'][0] : null;
      const photoFile = (req.files && (req.files['photo'] || req.files['image'])) ? (req.files['photo'] || req.files['image'])[0] : null;

      if (photoFile) {
        photoUrl = `/uploads/thumbnails/${photoFile.filename}`;
        thumbUrl = photoUrl;
        if (!videoFile) {
          videoUrl = photoUrl;
        }
      }

      if (videoFile) {
        const isPhotoMime = videoFile.mimetype.startsWith('image/');
        if (isPhotoMime) {
          photoUrl = `/uploads/thumbnails/${videoFile.filename}`;
          thumbUrl = photoUrl;
          videoUrl = photoUrl;
        } else {
          const settings = (await db.getSettings()) || {};
          const maxMb = (settings.platform && settings.platform.max_upload_size_mb) || 250;
          if (videoFile.size > maxMb * 1024 * 1024) {
            try { fs.unlinkSync(videoFile.path); } catch(_) {}
            return res.status(413).json({
              status: false,
              message: `Video file exceeds the maximum allowed size of ${maxMb}MB.`,
            });
          }
          const mediaCheck = await ensureMp4PlayableWithSound(videoFile.path);
          videoUrl = `/uploads/videos/${videoFile.filename}`;

          if (!thumbFile) {
            const thumbDir = path.join(__dirname, '..', 'uploads', 'thumbnails');
            if (!fs.existsSync(thumbDir)) {
              fs.mkdirSync(thumbDir, { recursive: true });
            }
            const generatedThumbName = `${path.parse(videoFile.filename).name}_thumb.jpg`;
            const generatedThumbPath = path.join(thumbDir, generatedThumbName);
            const ok = await generateVideoThumbnail(videoFile.path, generatedThumbPath);
            if (ok) {
              thumbUrl = `/uploads/thumbnails/${generatedThumbName}`;
            }
          }
        }
      }
      if (thumbFile) {
        thumbUrl = `/uploads/thumbnails/${thumbFile.filename}`;
      }

      if (!videoUrl && !photoUrl) {
        return res.status(422).json({
          status: false,
          message: 'Video file, photo, or media URL is required',
        });
      }

      const storedVideoPath = toRelativeMediaPath(videoUrl || photoUrl);
      const storedThumbPath = toRelativeMediaPath(thumbUrl || photoUrl);

      const settings = (await db.getSettings()) || {};
      const platform = settings.platform || {};

      let initialStatus = 'Approved';
      const isAd = videoType === 'ads';
      const isPhoto = photoFile || mediaType === 'photo';
      const isReel = !isPhoto && !isAd;

      if (platform.auto_approve_all === false) {
        initialStatus = 'Pending';
      } else if (isPhoto && platform.auto_approve_posts === false) {
        initialStatus = 'Pending';
      } else if (isReel && platform.auto_approve_reels === false) {
        initialStatus = 'Pending';
      } else if (isAd && platform.auto_approve_ads === false) {
        initialStatus = 'Pending';
      }

      const newVideo = await db.createVideo({
        user_id: user ? user.id : 8,
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
        media_type: photoFile || mediaType === 'photo' ? 'photo' : 'video',
        photo_url: photoUrl ? toRelativeMediaPath(photoUrl) : (photoFile || mediaType === 'photo' ? storedVideoPath : ''),
        target_url: req.body.target_url || req.body.link || '',
        budget: parseFloat(req.body.budget) || 0.0,
        has_audio: hasAudio,
        status: initialStatus,
        audio_title: hasAudio ? (req.body.audio_title || `Original Audio - ${user ? (user.name || user.username) : 'Telso Creator'}`) : 'No Audio',
      });

      const responseVideo = formatVideoResponse(req, newVideo);

      return res.status(201).json({
        status: true,
        message: 'Content uploaded successfully! Sent to Admin for review. ⏳',
        video: responseVideo,
        data: responseVideo,
      });
    } catch (err) {
      console.error('Upload video error:', err);
      return res.status(500).json({
        status: false,
        message: 'Upload processing failed',
      });
    }
  }
);

/**
 * 💰 GET /api/reporter/wallet
 */
router.get('/wallet', authOptional, async (req, res) => {
  const userId = req.user ? req.user.id : 3; // Default to user 3 (Telso Star Creator) if guest
  const walletData = await db.getWallet(userId);

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
router.get('/referral', authOptional, async (req, res) => {
  const userId = req.user ? req.user.id : 3;
  const refData = await db.getReferral(userId, req.get('host'));

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
router.get('/my-videos', authOptional, async (req, res) => {
  const currentUserId = req.user ? req.user.id : 1;
  const videos = await db.getUserVideos(currentUserId);
  const userVideos = videos.map(v => formatVideoResponse(req, v));
  return res.status(200).json({
    status: true,
    data: userVideos,
    videos: userVideos,
  });
});

/**
 * 🌐 GET /api/reporter/web-links
 */
router.get('/web-links', authOptional, async (req, res) => {
  const currentUserId = req.user ? req.user.id : null;
  const links = await db.getWebLinks(currentUserId);
  return res.status(200).json({
    status: true,
    data: links,
    links,
  });
});

/**
 * ➕ POST /api/reporter/web-links
 */
router.post('/web-links', authOptional, async (req, res) => {
  const user = req.user || (await db.findUserById(1));
  const newLink = await db.createWebLink({
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
router.get('/today-birthdays', async (req, res) => {
  const birthdays = (await db.getTodayBirthdays()).map(u => ({
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

/**
 * 📸 POST /api/reporter/stories
 * Upload a 24-hour expiring Story (image or short video)
 */
router.post(
  '/stories',
  authOptional,
  upload.fields([
    { name: 'file', maxCount: 1 },
    { name: 'image', maxCount: 1 },
    { name: 'video', maxCount: 1 },
  ]),
  async (req, res) => {
    try {
      const user = req.user || (await db.findUserById(8));
      const file = (req.files && (req.files['file'] || req.files['image'] || req.files['video']))
        ? (req.files['file'] || req.files['image'] || req.files['video'])[0]
        : null;

      let mediaUrl = req.body.media_url || '';
      let mediaType = req.body.media_type || 'image';

      if (file) {
        const isVid = file.mimetype.startsWith('video/');
        mediaType = isVid ? 'video' : 'image';
        mediaUrl = `/uploads/${isVid ? 'videos' : 'thumbnails'}/${file.filename}`;
      }

      if (!mediaUrl) {
        return res.status(422).json({ status: false, message: 'Media file or media_url is required' });
      }

      const storedPath = toRelativeMediaPath(mediaUrl);
      const story = await db.createStory({
        userId: user ? user.id : 8,
        mediaUrl: storedPath,
        mediaType,
        caption: req.body.caption || '',
      });

      return res.status(201).json({
        status: true,
        message: 'Story posted! Active for 24 hours ⏳',
        data: {
          ...story,
          media_url: normalizeMediaUrl(req, story.media_url),
        },
      });
    } catch (err) {
      console.error('Story upload error:', err);
      return res.status(500).json({ status: false, message: 'Story upload failed' });
    }
  }
);

/**
 * 📸 GET /api/reporter/stories
 * Get active stories grouped by followed creators (and self)
 */
router.get('/stories', authOptional, async (req, res) => {
  const currentUserId = req.user ? req.user.id : (req.query.user_id ? parseInt(req.query.user_id, 10) : 8);
  const stories = await db.getActiveStories(currentUserId);
  const formatted = stories.map(u => ({
    ...u,
    profile_image: normalizeMediaUrl(req, u.profile_image),
    stories: u.stories.map(s => ({
      ...s,
      media_url: normalizeMediaUrl(req, s.media_url),
    })),
  }));

  return res.status(200).json({
    status: true,
    data: formatted,
    stories: formatted,
  });
});

/**
 * 👁️ POST /api/reporter/stories/:id/view
 */
router.post('/stories/:id/view', authOptional, async (req, res) => {
  const currentUserId = req.user ? req.user.id : (req.body.user_id || 8);
  await db.recordStoryView(req.params.id, currentUserId);
  return res.status(200).json({ status: true, message: 'Story view recorded' });
});

/**
 * 🚫 POST /api/reporter/block/:id
 * Toggle block / unblock a creator
 */
router.post('/block/:id', authOptional, async (req, res) => {
  const currentUserId = req.user ? req.user.id : (req.body.user_id || 8);
  const targetId = parseInt(req.params.id, 10);
  if (!targetId || targetId === currentUserId) {
    return res.status(400).json({ status: false, message: 'Invalid target user' });
  }

  const result = await db.toggleBlock(currentUserId, targetId);
  return res.status(200).json({
    status: true,
    blocked: result.blocked,
    message: result.blocked ? 'User blocked. You will no longer see their reels or messages.' : 'User unblocked.',
  });
});

/**
 * 🚫 GET /api/reporter/blocked
 */
router.get('/blocked', authOptional, async (req, res) => {
  const currentUserId = req.user ? req.user.id : (req.query.user_id || 8);
  const blocked = await db.getBlockedUsers(currentUserId);
  return res.status(200).json({
    status: true,
    data: blocked.map(u => ({
      ...u,
      profile_image: normalizeMediaUrl(req, u.profile_image),
    })),
  });
});

/**
 * 💬 GET /api/reporter/messages/inbox
 * Returns active chats and message requests
 */
router.get('/messages/inbox', authOptional, async (req, res) => {
  const currentUserId = req.user ? req.user.id : (req.query.user_id || 8);
  const { chats, requests } = await db.getConversations(currentUserId);

  const formatConv = (c) => ({
    id: c.id,
    user_id: c.other_user_id,
    username: c.other_username,
    name: c.other_user_name,
    avatar: normalizeMediaUrl(req, c.other_user_avatar),
    status: c.status,
    initiated_by: c.initiated_by,
    is_request: c.status === 'pending' && c.initiated_by !== currentUserId,
    last_message: c.last_message || '',
    last_message_time: c.last_message_time,
  });

  return res.status(200).json({
    status: true,
    data: {
      chats: chats.map(formatConv),
      requests: requests.map(formatConv),
    },
  });
});

/**
 * ✉️ POST /api/reporter/messages/send
 * Send a message with request acceptance check
 */
router.post('/messages/send', authOptional, async (req, res) => {
  const senderId = req.user ? req.user.id : (req.body.sender_id || req.body.user_id || 8);
  const receiverId = parseInt(req.body.receiver_id, 10);
  const message = (req.body.message || '').trim();

  if (!receiverId || !message) {
    return res.status(422).json({ status: false, message: 'receiver_id and message are required' });
  }

  const result = await db.sendMessage({
    senderId,
    receiverId,
    message,
    mediaUrl: req.body.media_url || '',
  });

  if (!result.success) {
    return res.status(200).json({
      status: false,
      request_pending: result.requestPending || false,
      blocked: result.blocked || false,
      message: result.message,
    });
  }

  return res.status(201).json({
    status: true,
    message: 'Message sent successfully! 🚀',
    data: result.message,
    conversation: result.conversation,
  });
});

/**
 * 💬 GET /api/reporter/messages/chat/:conversationId
 */
router.get('/messages/chat/:conversationId', authOptional, async (req, res) => {
  const currentUserId = req.user ? req.user.id : (req.query.user_id || 8);
  const convId = parseInt(req.params.conversationId, 10);
  const messages = await db.getMessages(convId, currentUserId);

  return res.status(200).json({
    status: true,
    data: messages.map(m => ({
      id: m.id,
      conversation_id: m.conversation_id,
      sender_id: m.sender_id,
      receiver_id: m.receiver_id,
      sender_username: m.sender_username,
      sender_name: m.sender_name,
      sender_avatar: normalizeMediaUrl(req, m.sender_avatar),
      message: m.message,
      media_url: normalizeMediaUrl(req, m.media_url),
      is_me: m.sender_id === currentUserId,
      is_read: m.is_read,
      created_at: m.created_at,
    })),
  });
});

/**
 * 🤝 POST /api/reporter/messages/respond/:conversationId
 * Accept, decline, or block a message request
 */
router.post('/messages/respond/:conversationId', authOptional, async (req, res) => {
  const currentUserId = req.user ? req.user.id : (req.body.user_id || 8);
  const convId = parseInt(req.params.conversationId, 10);
  const action = req.body.action || 'accept'; // accept | decline | block

  const result = await db.respondToRequest(convId, currentUserId, action);
  return res.status(200).json({
    status: result.success,
    message: result.message,
  });
});

module.exports = router;

