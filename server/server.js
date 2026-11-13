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
