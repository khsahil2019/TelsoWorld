require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');
const os = require('os');
const fs = require('fs');

const authRoutes = require('./routes/auth');
const reporterRoutes = require('./routes/reporter');
const commentRoutes = require('./routes/comments');
const adminRoutes = require('./routes/admin');
const db = require('./db');

const app = express();
app.enable('trust proxy');
const PORT = process.env.PORT || 5050;

// Enable CORS for all requests (Flutter Web, Emulators, Admin Panel)
app.use(cors());

// Body parsers
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Admin console explicit route
app.get(['/admin', '/admin/'], (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'admin', 'index.html'));
});

// Static file servers for uploads, admin console & YouTube-style web platform
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));
app.use('/admin', express.static(path.join(__dirname, 'public', 'admin')));
app.use(express.static(path.join(__dirname, 'public', 'web')));

// API Routes
app.use('/api/reporter', authRoutes);
app.use('/api/reporter', reporterRoutes);
app.use('/api/comments', commentRoutes);
app.use('/api/admin', adminRoutes);

// 🎬 Dynamic Deep Link / Social Sharing for Reels
app.get('/reel/:id', async (req, res) => {
  const reelId = parseInt(req.params.id, 10);
  let title = 'Telso World Reel';
  let desc = 'Watch this reel on Telso World!';
  let videoUrl = '';
  let thumbUrl = 'https://telsoworld.com/uploads/thumbnails/sample1_thumb.jpg';

  try {
    const video = await db.findVideoById(reelId);
    if (video) {
      title = `${video.title || video.subject || 'Telso Reel'} by @${video.username}`;
      desc = video.subject || `Watch ${video.title} on Telso World`;
      videoUrl = video.video_url.startsWith('http') ? video.video_url : `https://telsoworld.com${video.video_url}`;
      thumbUrl = video.thumbnail_url ? (video.thumbnail_url.startsWith('http') ? video.thumbnail_url : `https://telsoworld.com${video.thumbnail_url}`) : thumbUrl;
    }
  } catch (_) {}

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${title}</title>
  <meta property="og:title" content="${title}">
  <meta property="og:description" content="${desc}">
  <meta property="og:image" content="${thumbUrl}">
  <meta property="og:video" content="${videoUrl}">
  <meta property="og:type" content="video.other">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="${title}">
  <meta name="twitter:description" content="${desc}">
  <meta name="twitter:image" content="${thumbUrl}">
  <style>
    body { background: #000; color: #fff; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; margin: 0; padding: 20px; box-sizing: border-box; text-align: center; }
    .card { background: #181822; padding: 28px; border-radius: 20px; max-width: 400px; width: 100%; border: 1px solid rgba(255,255,255,0.1); box-shadow: 0 12px 36px rgba(0,0,0,0.6); }
    img { width: 100%; height: 260px; object-fit: cover; border-radius: 14px; margin-bottom: 18px; }
    h2 { font-size: 20px; margin: 0 0 8px 0; color: #fff; font-weight: 700; }
    p { color: rgba(255,255,255,0.65); font-size: 14px; margin: 0 0 20px 0; }
    .btn { display: block; width: 100%; padding: 14px; background: linear-gradient(135deg, #D70F64, #FF2D55); color: #fff; text-decoration: none; font-weight: bold; font-size: 16px; border-radius: 12px; box-sizing: border-box; }
    .watch-web { display: inline-block; margin-top: 14px; color: #00E5FF; font-size: 13px; text-decoration: none; }
  </style>
  <script>
    window.onload = function() {
      window.location.href = "telsoworld://reel/${reelId}";
    };
  </script>
</head>
<body>
  <div class="card">
    <img src="${thumbUrl}" alt="Reel Thumbnail">
    <h2>${title}</h2>
    <p>${desc}</p>
    <a href="telsoworld://reel/${reelId}" class="btn">Open in Telso World App 🚀</a>
    <a href="/watch?v=${reelId}" class="watch-web">Watch on Web instead →</a>
  </div>
</body>
</html>`;

  res.send(html);
});

// YouTube-style Web Platform SPA Routes
app.get(['/', '/watch', '/shorts', '/studio', '/wallet', '/profile', '/notifications', '/login', '/register'], (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'web', 'index.html'));
});

// Android APK Download for wireless debugging / mobile devices
app.get(['/download/app-debug.apk', '/download/app.apk', '/download/telso.apk'], (req, res) => {
  const debugApk = path.join(__dirname, '..', 'build', 'app', 'outputs', 'flutter-apk', 'app-debug.apk');
  const releaseApk = path.join(__dirname, '..', 'build', 'app', 'outputs', 'flutter-apk', 'app-release.apk');
  if (fs.existsSync(debugApk)) {
    return res.download(debugApk, 'TelsoWorld.apk');
  } else if (fs.existsSync(releaseApk)) {
    return res.download(releaseApk, 'TelsoWorld.apk');
  } else {
    return res.status(404).send('APK not found.');
  }
});

app.get('/api/health', async (req, res) => {
  try {
    await db.pool.query('SELECT 1');
    res.json({
      status: true,
      service: 'Telso World API Backend',
      database: 'PostgreSQL',
      version: '1.0.0',
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    res.status(500).json({
      status: false,
      service: 'Telso World API Backend',
      database: 'PostgreSQL (disconnected)',
      error: err.message,
    });
  }
});

// 404 handler for unknown APIs
app.use('/api/*', (req, res) => {
  res.status(404).json({
    status: false,
    message: `Endpoint ${req.originalUrl} not found on Telso World API`,
  });
});

function getLocalIp() {
  const nets = os.networkInterfaces();
  for (const name of Object.keys(nets)) {
    for (const net of nets[name]) {
      if (net.family === 'IPv4' && !net.internal) {
        return net.address;
      }
    }
  }
  return 'localhost';
}

db.init()
  .then(() => {
    app.listen(PORT, '0.0.0.0', () => {
      const localIp = getLocalIp();
      console.log('====================================================');
      console.log(`🚀 Telso World API Server is running on PORT: ${PORT}`);
      console.log(`🐘 PostgreSQL Database : Connected`);
      console.log(`💻 Local Admin Panel : http://localhost:${PORT}/admin`);
      console.log(`🌐 Network Admin      : http://${localIp}:${PORT}/admin`);
      console.log('----------------------------------------------------');
      console.log(`📱 Flutter Base URL configuration:`);
      console.log(`   • Android Emulator  : http://10.0.2.2:${PORT}/api`);
      console.log(`   • iOS / macOS / Web : http://localhost:${PORT}/api`);
      console.log(`   • Physical Devices  : http://${localIp}:${PORT}/api`);
      console.log('====================================================');
    });
  })
  .catch((err) => {
    console.error('❌ Failed to initialize PostgreSQL database:', err);
    process.exit(1);
  });
