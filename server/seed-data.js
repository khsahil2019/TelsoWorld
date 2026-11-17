const bcrypt = require('bcryptjs');

/**
 * Fallback seed dataset used when PostgreSQL tables are empty and no data/db.json exists.
 */
function getInitialData() {
  const salt = bcrypt.genSaltSync(10);
  const hashedPassword = bcrypt.hashSync('password123', salt);
  const adminHashedPassword = bcrypt.hashSync('admin123', salt);

  const today = new Date();
  const pad = (n) => String(n).padStart(2, '0');
  const todayStr = `${today.getFullYear()}-${pad(today.getMonth() + 1)}-${pad(today.getDate())}`;
  const tomorrowDate = new Date(today.getTime() + 24 * 3600 * 1000);
  const tomorrowStr = `${tomorrowDate.getFullYear()}-${pad(tomorrowDate.getMonth() + 1)}-${pad(tomorrowDate.getDate())}`;

  return {
    admin: {
      username: 'admin',
      password: adminHashedPassword,
      name: 'System Admin',
      email: 'admin@telsoworld.com',
    },
    settings: {
      id: 1,
      name: 'dashboard_config',
      file_uploaded: '1',
      value: null,
      updated_at: new Date().toISOString(),
      app_name: 'Telso World',
      referral_reward: 50.0,
      min_withdrawal: 100.0,
      sms: {
        provider: 'fast2sms',
        api_key: 'FST_LIVE_998124810239102',
        sender_id: 'TELSOO',
        twilio_account_sid: 'AC_telso_world_prod_sid_8892',
        twilio_auth_token: 'auth_token_88291039_secret',
        twilio_phone_number: '+12058801234',
        msg91_auth_key: 'MSG91_KEY_8829103',
        template: 'Your Telso World creator verification OTP is {OTP}. Valid for 10 minutes. Do not share with anyone.',
        is_active: true,
      },
      smtp: {
        provider: 'gmail',
        host: 'smtp.gmail.com',
        port: 587,
        secure: false,
        username: 'noreply.telsoworld@gmail.com',
        password: 'gapp-xxxx-yyyy-zzzz',
        from_name: 'Telso World Official',
        from_email: 'noreply@telsoworld.com',
        subject_template: 'Telso World — Your Creator Verification OTP is {OTP}',
        is_active: true,
      },
      firebase: {
        project_id: 'telso-world-official',
        web_api_key: 'AIzaSyD-TELSO_PROD_WEB_KEY_99214',
        fcm_server_key: 'AAAA_TELSO_FCM_SERVER_KEY:APA91bF-live-production-token',
        service_account_json: '{\n  "type": "service_account",\n  "project_id": "telso-world-official"\n}',
        default_channel_id: 'telso_broadcast_channel',
        sound_enabled: true,
        is_active: true,
      },
      platform: {
        app_name: 'Telso World',
        welcome_bonus: 50.0,
        referral_reward: 50.0,
        min_withdrawal: 100.0,
        require_admin_approval: true,
        birthday_wishing_enabled: true,
        max_reel_duration_sec: 60,
        max_upload_size_mb: 250,
      },
      notifications_log: [
        {
          id: 'notif_1',
          title: '🔥 Trending: Bhojpuri Hits Folk Beat',
          body: "Aarav Sharma's new folk remix just crossed 140K views! Check it out now.",
          audience: 'all',
          sent_at: new Date(Date.now() - 24 * 3600 * 1000).toISOString(),
          delivered_count: 1420,
        },
        {
          id: 'notif_2',
          title: '🎂 Happy Birthday Aarav Sharma! 🎉',
          body: 'Join the Telso World community in wishing Aarav Sharma (@aarav_music) a wonderful birthday today!',
          audience: 'all',
          sent_at: new Date().toISOString(),
          delivered_count: 1510,
        },
      ],
    },
    users: [
      {
        id: 8,
        name: 'rahul',
        username: 'rahul',
        email: 'rahul@telsoworld.com',
        mobile_no: '9956509025',
        whatsapp: '9956509025',
        school_name: '',
        dob: '2000-01-01',
        state: 'Uttar Pradesh',
        district: 'Lucknow',
        password: hashedPassword,
        referral_code: 'TELSO8135',
        referred_by: null,
        user_type: 'musician',
        role: 'creator',
        status: 'active',
        bio: 'Official Creator on Telso World 🎵 Singer, Music Producer & Live Performer.',
        created_at: new Date(Date.now() - 30 * 24 * 3600 * 1000).toISOString(),
      },
    ],
    videos: [
      {
        id: 26,
        user_id: 8,
        name: 'rahul',
        username: 'rahul',
        title: "England's",
        subject: 'Cycling',
        category: 'Music',
        video_url: '/uploads/videos/1794941733146-259610040.mp4',
        video_path: '/uploads/videos/1794941733146-259610040.mp4',
        thumbnail_url: '',
        image: '',
        video_type: 'normal',
        status: 'Approved',
        has_audio: true,
        view_count: 1,
        likes_count: 1,
        shares_count: 0,
        comments_count: 0,
        liked_by: [8],
        viewed_by: ['user_8'],
        created_at: new Date().toISOString(),
      },
    ],
    comments: [],
    wallets: [
      { user_id: 8, balance: 50.0, pending_amount: 0.0 },
    ],
    transactions: [],
    withdrawals: [],
    web_links: [],
    notifications: [
      {
        id: 'notif_u_8',
        user_id: 8,
        title: 'Welcome Bonus Credited! 🎁',
        message: 'Welcome to Telso World! ₹50 joining bonus has been credited to your wallet.',
        type: 'wallet',
        created_at: new Date().toISOString(),
        is_read: false,
      },
    ],
  };
}

module.exports = { getInitialData };

