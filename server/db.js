const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');

const DB_FILE = path.join(__dirname, 'data', 'db.json');

// Ensure data directory exists
if (!fs.existsSync(path.dirname(DB_FILE))) {
  fs.mkdirSync(path.dirname(DB_FILE), { recursive: true });
}

// Initial seed data with high-quality reel videos & creators
function getInitialData() {
  const salt = bcrypt.genSaltSync(10);
  const hashedPassword = bcrypt.hashSync('password123', salt);
  const adminHashedPassword = bcrypt.hashSync('admin123', salt);

  // Today's date components for dynamic birthday testing
  const today = new Date();
  const pad = n => String(n).padStart(2, '0');
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
      },
      notifications_log: [
        {
          id: 'notif_1',
          title: '🔥 Trending: Bhojpuri Hits Folk Beat',
          body: 'Aarav Sharma\'s new folk remix just crossed 140K views! Check it out now.',
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
        id: 1,
        name: 'Aarav Sharma',
        username: 'aarav_music',
        email: 'aarav@telsoworld.com',
        mobile_no: '9876543210',
        whatsapp: '9876543210',
        school_name: 'Delhi Academy of Music',
        dob: todayStr, // Birthday TODAY for live testing!
        state: 'Delhi',
        district: 'New Delhi',
        password: hashedPassword,
        referral_code: 'AARAV2026',
        referred_by: null,
        user_type: 'musician',
        role: 'creator',
        status: 'active',
        created_at: new Date(Date.now() - 30 * 24 * 3600 * 1000).toISOString(),
      },
      {
        id: 2,
        name: 'Priya Verma',
        username: 'priya_tunes',
        email: 'priya@telsoworld.com',
        mobile_no: '9876543211',
        whatsapp: '9876543211',
        school_name: 'Mumbai Sound School',
        dob: '2002-08-20',
        state: 'Maharashtra',
        district: 'Mumbai',
        password: hashedPassword,
        referral_code: 'PRIYA2026',
        referred_by: 'AARAV2026',
        user_type: 'musician',
        role: 'creator',
        status: 'active',
        created_at: new Date(Date.now() - 20 * 24 * 3600 * 1000).toISOString(),
      },
      {
        id: 3,
        name: 'Telso Star Creator',
        username: 'reporter',
        email: 'creator@telsoworld.com',
        mobile_no: '9876543212',
        whatsapp: '9876543212',
        school_name: 'Telso World Media Lab',
        dob: tomorrowStr, // Birthday TOMORROW for upcoming calendar!
        state: 'Karnataka',
        district: 'Bengaluru',
        password: hashedPassword,
        referral_code: 'TELSO2026',
        referred_by: null,
        user_type: 'musician',
        role: 'creator',
        status: 'active',
        created_at: new Date(Date.now() - 10 * 24 * 3600 * 1000).toISOString(),
      },
      {
        id: 4,
        name: 'Manoj Tiwari Fan Club',
        username: 'bhojpuri_king',
        email: 'manoj@telsoworld.com',
        mobile_no: '9876543213',
        whatsapp: '9876543213',
        school_name: 'Patna Folk Music Sangam',
        dob: todayStr, // Birthday TODAY for live testing!
        state: 'Bihar',
        district: 'Patna',
        password: hashedPassword,
        referral_code: 'BHOJPURI2026',
        referred_by: 'TELSO2026',
        user_type: 'musician',
        role: 'creator',
        status: 'active',
        created_at: new Date(Date.now() - 15 * 24 * 3600 * 1000).toISOString(),
      },
      {
        id: 5,
        name: 'Kavita Classical',
        username: 'classical_sur',
        email: 'kavita@telsoworld.com',
        mobile_no: '9876543214',
        whatsapp: '9876543214',
        school_name: 'Banaras Music Gharana',
        dob: '1999-03-25',
        state: 'Uttar Pradesh',
        district: 'Varanasi',
        password: hashedPassword,
        referral_code: 'KAVITA2026',
        referred_by: 'AARAV2026',
        user_type: 'musician',
        role: 'creator',
        status: 'active',
        created_at: new Date(Date.now() - 8 * 24 * 3600 * 1000).toISOString(),
      },
      {
        id: 6,
        name: 'Vikram Gill',
        username: 'punjabi_beats',
        email: 'vikram@telsoworld.com',
        mobile_no: '9876543215',
        whatsapp: '9876543215',
        school_name: 'Chandigarh Beats Academy',
        dob: '2001-12-04',
        state: 'Punjab',
        district: 'Chandigarh',
        password: hashedPassword,
        referral_code: 'VIKRAM2026',
        referred_by: null,
        user_type: 'musician',
        role: 'creator',
        status: 'active',
        created_at: new Date(Date.now() - 5 * 24 * 3600 * 1000).toISOString(),
      },
    ],
    videos: [
      {
        id: 1,
        user_id: 1,
        name: 'Aarav Sharma',
        username: 'aarav_music',
        title: 'Bhojpuri Hits Folk Beat',
        subject: 'Bhojpuri Folk Remix Beat 🔥 #bhojpuri #viral',
        category: 'Folk Music',
        video_url: '/uploads/videos/sample1.mp4',
        video_path: '/uploads/videos/sample2.mp4',
        thumbnail_url: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&auto=format&fit=crop',
        image: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&auto=format&fit=crop',
        video_type: 'normal',
        status: 'Approved',
        view_count: 142500,
        likes_count: 12400,
        shares_count: 850,
        comments_count: 42,
        liked_by: [3, 4],
        created_at: new Date(Date.now() - 5 * 24 * 3600 * 1000).toISOString(),
      },
      {
        id: 2,
        user_id: 2,
        name: 'Priya Verma',
        username: 'priya_tunes',
        title: 'Stage Live Electric Guitar',
        subject: 'Acoustic & Electric Live Session 🎸 Solo performance!',
        category: 'Live Music',
        video_url: '/uploads/videos/sample3.mp4',
        video_path: '/uploads/videos/sample4.mp4',
        thumbnail_url: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&auto=format&fit=crop',
        image: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&auto=format&fit=crop',
        video_type: 'normal',
        status: 'Approved',
        view_count: 89200,
        likes_count: 7600,
        shares_count: 430,
        comments_count: 28,
        liked_by: [1],
        created_at: new Date(Date.now() - 4 * 24 * 3600 * 1000).toISOString(),
      },
      {
        id: 3,
        user_id: 3,
        name: 'Telso Star Creator',
        username: 'reporter',
        title: 'Harmonium Classical Melody',
        subject: 'Classical Raga Bhairavi with Harmonium & Tabla ✨',
        category: 'Classical',
        video_url: '/uploads/videos/sample5.mp4',
        video_path: '/uploads/videos/sample1.mp4',
        thumbnail_url: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&auto=format&fit=crop',
        image: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&auto=format&fit=crop',
        video_type: 'normal',
        status: 'Approved',
        view_count: 215000,
        likes_count: 18200,
        shares_count: 1200,
        comments_count: 95,
        liked_by: [1, 2],
        created_at: new Date(Date.now() - 3 * 24 * 3600 * 1000).toISOString(),
      },
      {
        id: 4,
        user_id: 4,
        name: 'Manoj Tiwari Fan Club',
        username: 'bhojpuri_king',
        title: 'Bhojpuri Desi Dholak Fusion',
        subject: 'High energy Bhojpuri folk dholak remix live from Patna 🪘💥',
        category: 'Folk Music',
        video_url: '/uploads/videos/sample2.mp4',
        video_path: '/uploads/videos/sample3.mp4',
        thumbnail_url: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&auto=format&fit=crop',
        image: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&auto=format&fit=crop',
        video_type: 'normal',
        status: 'Approved',
        view_count: 168400,
        likes_count: 15400,
        shares_count: 990,
        comments_count: 54,
        liked_by: [1, 3],
        created_at: new Date(Date.now() - 3 * 24 * 3600 * 1000).toISOString(),
      },
      {
        id: 5,
        user_id: 6,
        name: 'Vikram Gill',
        username: 'punjabi_beats',
        title: 'Punjabi Bhangra Drop Bass',
        subject: 'Heavy 808s meets authentic Tumbi & Dhol! 🥁 Turn the volume up!',
        category: 'Bhangra',
        video_url: '/uploads/videos/sample4.mp4',
        video_path: '/uploads/videos/sample5.mp4',
        thumbnail_url: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&auto=format&fit=crop',
        image: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&auto=format&fit=crop',
        video_type: 'normal',
        status: 'Approved',
        view_count: 94000,
        likes_count: 8100,
        shares_count: 670,
        comments_count: 31,
        liked_by: [2],
        created_at: new Date(Date.now() - 2 * 24 * 3600 * 1000).toISOString(),
      },
      {
        id: 6,
        user_id: 2,
        name: 'Priya Verma',
        username: 'priya_tunes',
        title: 'Late Night Synthwave Chill',
        subject: 'Lo-fi beats and vintage analog synthesizers for late night focus 🎧',
        category: 'Electronic',
        video_url: '/uploads/videos/sample1.mp4',
        video_path: '/uploads/videos/sample2.mp4',
        thumbnail_url: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=600&auto=format&fit=crop',
        image: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=600&auto=format&fit=crop',
        video_type: 'normal',
        status: 'Approved',
        view_count: 32000,
        likes_count: 2450,
        shares_count: 180,
        comments_count: 19,
        liked_by: [3],
        created_at: new Date(Date.now() - 1 * 24 * 3600 * 1000).toISOString(),
      },
      {
        id: 7,
        user_id: 1,
        name: 'Telso Promotions',
        username: 'telso_ads',
        title: 'Telso World Festival Offer',
        subject: 'Exclusive Producer Discounts on Telso World Store! 🎁 50% Off',
        category: 'Promotion',
        video_url: '/uploads/videos/sample3.mp4',
        video_path: '/uploads/videos/sample4.mp4',
        thumbnail_url: 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=600&auto=format&fit=crop',
        image: 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=600&auto=format&fit=crop',
        video_type: 'ads',
        status: 'Approved',
        view_count: 55400,
        likes_count: 3200,
        shares_count: 310,
        comments_count: 15,
        liked_by: [],
        created_at: new Date(Date.now() - 2 * 24 * 3600 * 1000).toISOString(),
      },
      // ⏳ PENDING REELS IN APPROVAL QUEUE (Ready for Admin to test Approve/Reject)
      {
        id: 8,
        user_id: 5,
        name: 'Kavita Classical',
        username: 'classical_sur',
        title: 'Varanasi Ghat Morning Raga',
        subject: 'Sunrise Sitar Raga live recorded on the banks of holy Ganga ✨🎶',
        category: 'Classical',
        video_url: '/uploads/videos/sample5.mp4',
        video_path: '/uploads/videos/sample1.mp4',
        thumbnail_url: 'https://images.unsplash.com/photo-1507676184212-d03ab07a01bf?w=600&auto=format&fit=crop',
        image: 'https://images.unsplash.com/photo-1507676184212-d03ab07a01bf?w=600&auto=format&fit=crop',
        video_type: 'normal',
        status: 'Pending',
        view_count: 0,
        likes_count: 0,
        shares_count: 0,
        comments_count: 0,
        liked_by: [],
        created_at: new Date(Date.now() - 2 * 3600 * 1000).toISOString(),
      },
      {
        id: 9,
        user_id: 4,
        name: 'Manoj Tiwari Fan Club',
        username: 'bhojpuri_king',
        title: 'Patna Street Acoustic Jam',
        subject: 'Desi acoustic jugalbandi on street corner 🔥 #patna #folk',
        category: 'Folk Music',
        video_url: '/uploads/videos/sample2.mp4',
        video_path: '/uploads/videos/sample3.mp4',
        thumbnail_url: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=600&auto=format&fit=crop',
        image: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=600&auto=format&fit=crop',
        video_type: 'normal',
        status: 'Pending',
        view_count: 0,
        likes_count: 0,
        shares_count: 0,
        comments_count: 0,
        liked_by: [],
        created_at: new Date(Date.now() - 4 * 3600 * 1000).toISOString(),
      },
      {
        id: 10,
        user_id: 1,
        name: 'Aarav Sharma',
        username: 'aarav_music',
        title: 'New Delhi Studio Jam Session',
        subject: 'Testing the new condenser mic with classical acoustic chords 🎙️🎸',
        category: 'Live Music',
        video_url: '/uploads/videos/sample4.mp4',
        video_path: '/uploads/videos/sample5.mp4',
        thumbnail_url: 'https://images.unsplash.com/photo-1598488035139-bdbb2231ce04?w=600&auto=format&fit=crop',
        image: 'https://images.unsplash.com/photo-1598488035139-bdbb2231ce04?w=600&auto=format&fit=crop',
        video_type: 'normal',
        status: 'Pending',
        view_count: 0,
        likes_count: 0,
        shares_count: 0,
        comments_count: 0,
        liked_by: [],
        created_at: new Date(Date.now() - 6 * 3600 * 1000).toISOString(),
      },
    ],
    comments: [
      {
        id: 1,
        video_id: 1,
        user_id: 2,
        user: 'Priya Verma',
        user_name: 'Priya Verma',
        username: 'priya_tunes',
        comment: 'Amazing bassline! Loved the authentic folk transitions 🔥',
        content: 'Amazing bassline! Loved the authentic folk transitions 🔥',
        profile_image: '',
        likes: 14,
        liked_by: [1, 3],
        reply_count: 1,
        parent_id: null,
        created_at: new Date(Date.now() - 2 * 24 * 3600 * 1000).toISOString(),
      },
      {
        id: 2,
        video_id: 1,
        user_id: 1,
        user: 'Aarav Sharma',
        user_name: 'Aarav Sharma',
        username: 'aarav_music',
        comment: 'Thank you Priya! Full track coming out this Friday!',
        content: 'Thank you Priya! Full track coming out this Friday!',
        profile_image: '',
        likes: 5,
        liked_by: [2],
        reply_count: 0,
        parent_id: 1,
        created_at: new Date(Date.now() - 1 * 24 * 3600 * 1000).toISOString(),
      },
      {
        id: 3,
        video_id: 3,
        user_id: 1,
        user: 'Aarav Sharma',
        user_name: 'Aarav Sharma',
        username: 'aarav_music',
        comment: 'Pure soul in this harmonium rendition ❤️🙌',
        content: 'Pure soul in this harmonium rendition ❤️🙌',
        profile_image: '',
        likes: 8,
        liked_by: [3],
        reply_count: 0,
        parent_id: null,
        created_at: new Date(Date.now() - 1 * 24 * 3600 * 1000).toISOString(),
      },
      {
        id: 4,
        video_id: 4,
        user_id: 6,
        user: 'Vikram Gill',
        user_name: 'Vikram Gill',
        username: 'punjabi_beats',
        comment: 'Bhai dholak ke taals bilkul energetic hain! Love from Punjab! 🥁🔥',
        content: 'Bhai dholak ke taals bilkul energetic hain! Love from Punjab! 🥁🔥',
        profile_image: '',
        likes: 19,
        liked_by: [4, 5],
        reply_count: 0,
        parent_id: null,
        created_at: new Date(Date.now() - 2 * 24 * 3600 * 1000).toISOString(),
      },
      {
        id: 5,
        video_id: 5,
        user_id: 4,
        user: 'Manoj Tiwari Fan Club',
        user_name: 'Manoj Tiwari Fan Club',
        username: 'bhojpuri_king',
        comment: 'Super bass drop paaji! Solid track! ⚡',
        content: 'Super bass drop paaji! Solid track! ⚡',
        profile_image: '',
        likes: 12,
        liked_by: [6],
        reply_count: 0,
        parent_id: null,
        created_at: new Date(Date.now() - 1 * 24 * 3600 * 1000).toISOString(),
      },
    ],
    wallets: [
      { user_id: 1, balance: 1450.0, pending_amount: 200.0 },
      { user_id: 2, balance: 620.0, pending_amount: 50.0 },
      { user_id: 3, balance: 3850.0, pending_amount: 500.0 },
      { user_id: 4, balance: 2100.0, pending_amount: 150.0 },
      { user_id: 5, balance: 850.0, pending_amount: 0.0 },
      { user_id: 6, balance: 1200.0, pending_amount: 100.0 },
    ],
    transactions: [
      {
        id: 'tx_101',
        user_id: 3,
        title: 'Video Monetization Bonus',
        description: 'Earnings for 200K+ Views on Harmonium Solo',
        amount: 2500.0,
        type: 'credit',
        status: 'completed',
        created_at: new Date(Date.now() - 3 * 24 * 3600 * 1000).toISOString(),
      },
      {
        id: 'tx_102',
        user_id: 3,
        title: 'Referral Bonus',
        description: 'Creator referral signup bonus for @bhojpuri_king',
        amount: 50.0,
        type: 'credit',
        status: 'completed',
        created_at: new Date(Date.now() - 5 * 24 * 3600 * 1000).toISOString(),
      },
      {
        id: 'tx_103',
        user_id: 1,
        title: 'Reel Views Payout',
        description: 'Weekly payout for high engagement Bhojpuri Folk reels',
        amount: 1400.0,
        type: 'credit',
        status: 'completed',
        created_at: new Date(Date.now() - 2 * 24 * 3600 * 1000).toISOString(),
      },
      {
        id: 'tx_104',
        user_id: 4,
        title: 'Monetization Bonus',
        description: 'Earnings for 150K+ Views on Dholak Fusion',
        amount: 2050.0,
        type: 'credit',
        status: 'completed',
        created_at: new Date(Date.now() - 2 * 24 * 3600 * 1000).toISOString(),
      },
    ],
    withdrawals: [
      {
        id: 'wd_1',
        user_id: 3,
        amount: 500.0,
        upi_id: 'creator@oksbi',
        account_holder: 'Telso Star Creator',
        status: 'pending',
        created_at: new Date(Date.now() - 1 * 24 * 3600 * 1000).toISOString(),
      },
      {
        id: 'wd_2',
        user_id: 1,
        amount: 200.0,
        upi_id: 'aarav@okaxis',
        account_holder: 'Aarav Sharma',
        status: 'pending',
        created_at: new Date(Date.now() - 12 * 3600 * 1000).toISOString(),
      },
    ],
    web_links: [
      {
        id: 1,
        user_id: 1,
        subject: 'Rental Furniture Portal',
        name: 'Furniture Rentwale',
        like_limit: '10,000',
        state: 'Uttar Pradesh',
        district: 'Varanasi',
        web_link: 'https://www.furniturerentwale.com',
        utr: 'UTR9982348123',
        status: 'Approved',
        current_likes: 820,
        created_at: new Date(Date.now() - 5 * 24 * 3600 * 1000).toISOString(),
      },
      {
        id: 2,
        user_id: 3,
        subject: 'Telso Music Store',
        name: 'telsomusic',
        like_limit: '5,000',
        state: 'Bihar',
        district: 'Patna',
        web_link: 'https://telso-store.com',
        utr: 'UTR7718293940',
        status: 'Approved',
        current_likes: 3410,
        created_at: new Date(Date.now() - 3 * 24 * 3600 * 1000).toISOString(),
      },
      {
        id: 3,
        user_id: 4,
        subject: 'Bihar Folk Cultural Academy',
        name: 'biharfolk',
        like_limit: '20,000',
        state: 'Bihar',
        district: 'Patna',
        web_link: 'https://biharfolkmusic.in',
        utr: 'UTR8839201948',
        status: 'Approved',
        current_likes: 12500,
        created_at: new Date(Date.now() - 4 * 24 * 3600 * 1000).toISOString(),
      },
    ],
  };
}

class Database {
  constructor() {
    this.data = null;
    this.load();
  }

  load() {
    if (!fs.existsSync(DB_FILE)) {
      this.data = getInitialData();
      this.save();
    } else {
      try {
        const raw = fs.readFileSync(DB_FILE, 'utf-8');
        this.data = JSON.parse(raw);
        this.ensureDefaults();
      } catch (err) {
        console.error('Error reading db.json, recreating with initial seed data:', err);
        this.data = getInitialData();
        this.save();
      }
    }
  }

  ensureDefaults() {
    const initial = getInitialData();
    let modified = false;

    // Ensure settings object has sms, smtp, firebase, platform, notifications_log
    if (!this.data.settings) {
      this.data.settings = initial.settings;
      modified = true;
    } else {
      if (!this.data.settings.sms) {
        this.data.settings.sms = initial.settings.sms;
        modified = true;
      }
      if (!this.data.settings.smtp) {
        this.data.settings.smtp = initial.settings.smtp;
        modified = true;
      }
      if (!this.data.settings.firebase) {
        this.data.settings.firebase = initial.settings.firebase;
        modified = true;
      }
      if (!this.data.settings.platform) {
        this.data.settings.platform = initial.settings.platform;
        modified = true;
      }
      if (!this.data.settings.platform.max_upload_size_mb) {
        this.data.settings.platform.max_upload_size_mb = 250;
        modified = true;
      }
      if (!Array.isArray(this.data.settings.notifications_log)) {
        this.data.settings.notifications_log = initial.settings.notifications_log;
        modified = true;
      }
    }

    // Ensure user notifications collection exists
    if (!Array.isArray(this.data.notifications)) {
      this.data.notifications = [
        {
          id: 'notif_u_1',
          user_id: 1,
          title: 'Welcome Bonus Credited! 🎁',
          message: 'Welcome to Telso World! ₹50 joining bonus has been credited to your wallet.',
          type: 'wallet',
          created_at: new Date(Date.now() - 5 * 24 * 3600 * 1000).toISOString(),
          is_read: false,
        },
        {
          id: 'notif_u_2',
          user_id: 1,
          title: 'Ad Engagement Reward! 💰',
          message: 'You earned 10 paisa (Layer 1) for liking "Telso World Festival Offer".',
          type: 'earning',
          created_at: new Date(Date.now() - 2 * 24 * 3600 * 1000).toISOString(),
          is_read: false,
        },
        {
          id: 'notif_u_3',
          user_id: 1,
          title: 'Reel Approved! 🎬',
          message: 'Your reel "Bhojpuri Hits Folk Beat" is approved and live on the front feed!',
          type: 'video',
          created_at: new Date(Date.now() - 1 * 24 * 3600 * 1000).toISOString(),
          is_read: true,
        },
      ];
      modified = true;
    }

    // Ensure sponsored ad reels exist for earning testing
    if (!this.data.videos.some(v => v.id === 11)) {
      this.data.videos.push({
        id: 11,
        user_id: 1,
        name: 'Satyabhama Movie Hub',
        username: 'telso_ads',
        title: 'SATYABHAMA RETURNS | South Action Movie Official Promo',
        subject: 'Superhit South Action Movie Premiering on Telso World! 💥 Watch the exclusive trailer now. Earn 10 paisa per like & comment!',
        category: 'Entertainment',
        video_url: '/uploads/videos/sample1.mp4',
        video_path: '/uploads/videos/sample2.mp4',
        thumbnail_url: 'https://images.unsplash.com/photo-1536440136628-849c177e76a1?w=600&auto=format&fit=crop',
        image: 'https://images.unsplash.com/photo-1536440136628-849c177e76a1?w=600&auto=format&fit=crop',
        video_type: 'ads',
        status: 'Approved',
        view_count: 84200,
        likes_count: 5300,
        shares_count: 420,
        comments_count: 48,
        liked_by: [],
        viewed_by: [],
        earned_like_users: [],
        earned_comment_users: [],
        created_at: new Date(Date.now() - 1 * 24 * 3600 * 1000).toISOString(),
      });
      this.data.videos.push({
        id: 12,
        user_id: 1,
        name: 'DroneTech India',
        username: 'telso_ads',
        title: '4K Camera Drone Pro | 50% Off Early Bird Campaign',
        subject: 'Capture cinematic 4K drone footage with obstacle avoidance 🚁 Special discounted batch for creators! Earn 10 paisa per engagement.',
        category: 'Technology',
        video_url: '/uploads/videos/sample3.mp4',
        video_path: '/uploads/videos/sample4.mp4',
        thumbnail_url: 'https://images.unsplash.com/photo-1508614589041-895b88991e3e?w=600&auto=format&fit=crop',
        image: 'https://images.unsplash.com/photo-1508614589041-895b88991e3e?w=600&auto=format&fit=crop',
        video_type: 'ads',
        status: 'Approved',
        view_count: 46100,
        likes_count: 3100,
        shares_count: 190,
        comments_count: 22,
        liked_by: [],
        viewed_by: [],
        earned_like_users: [],
        earned_comment_users: [],
        created_at: new Date(Date.now() - 1 * 24 * 3600 * 1000).toISOString(),
      });
      modified = true;
    }

    // Ensure pending videos exist for testing approval queue
    const pendingVideos = this.data.videos.filter(v => v.status === 'Pending');
    if (pendingVideos.length === 0) {
      const initialPending = initial.videos.filter(v => v.status === 'Pending');
      for (const pv of initialPending) {
        const nextId = Math.max(0, ...this.data.videos.map(v => v.id)) + 1;
        this.data.videos.push({ ...pv, id: nextId });
      }
      modified = true;
    }

    // Ensure users have today's birthdays for live testing
    const todayBirthdays = this.getTodayBirthdays();
    if (todayBirthdays.length === 0 && this.data.users.length > 0) {
      const today = new Date();
      const pad = n => String(n).padStart(2, '0');
      const todayStr = `${today.getFullYear()}-${pad(today.getMonth() + 1)}-${pad(today.getDate())}`;
      this.data.users[0].dob = todayStr;
      if (this.data.users.length > 1) {
        this.data.users[1].dob = todayStr;
      }
      modified = true;
    }

    if (modified) {
      this.save();
    }
  }

  resetToSeed() {
    this.data = getInitialData();
    this.save();
    return this.data;
  }

  save() {
    try {
      const tempFile = `${DB_FILE}.tmp`;
      fs.writeFileSync(tempFile, JSON.stringify(this.data, null, 2), 'utf-8');
      fs.renameSync(tempFile, DB_FILE);
    } catch (err) {
      console.error('Failed to save db.json:', err);
    }
  }

  // --- Admin ---
  getAdmin() {
    return this.data.admin;
  }

  // --- Settings & Integrations ---
  getSettings() {
    return this.data.settings;
  }

  updateSettings(updates) {
    if (!this.data.settings) {
      this.data.settings = {};
    }

    // Deep merge for nested sections
    for (const key of Object.keys(updates)) {
      if (typeof updates[key] === 'object' && updates[key] !== null && !Array.isArray(updates[key])) {
        this.data.settings[key] = {
          ...(this.data.settings[key] || {}),
          ...updates[key],
        };
      } else {
        this.data.settings[key] = updates[key];
      }
    }

    this.data.settings.updated_at = new Date().toISOString();
    this.save();
    return this.data.settings;
  }

  addNotificationLog(item) {
    if (!this.data.settings) this.data.settings = {};
    if (!Array.isArray(this.data.settings.notifications_log)) {
      this.data.settings.notifications_log = [];
    }

    const logEntry = {
      id: `notif_${Date.now()}`,
      title: item.title || '',
      body: item.body || '',
      audience: item.audience || 'all',
      action_url: item.action_url || '',
      image_url: item.image_url || '',
      sent_at: new Date().toISOString(),
      delivered_count: item.delivered_count || this.data.users.length,
    };

    this.data.settings.notifications_log.unshift(logEntry);
    this.save();
    return logEntry;
  }

  // --- Users ---
  getUsers() {
    return this.data.users;
  }

  findUserById(id) {
    const numericId = parseInt(id, 10);
    return this.data.users.find(u => u.id === numericId) || null;
  }

  findUserByEmailOrPhone(identifier) {
    if (!identifier) return null;
    const clean = identifier.trim().toLowerCase();
    return this.data.users.find(u =>
      (u.email && u.email.toLowerCase() === clean) ||
      (u.mobile_no && u.mobile_no === clean) ||
      (u.username && u.username.toLowerCase() === clean)
    ) || null;
  }

  findUserByUsername(username) {
    if (!username) return null;
    const clean = username.trim().toLowerCase().replace(/^@/, '');
    return this.data.users.find(u => u.username && u.username.toLowerCase() === clean) || null;
  }

  getTodayBirthdays() {
    const today = new Date();
    const todayMonth = today.getMonth() + 1;
    const todayDay = today.getDate();

    return this.data.users.filter(u => {
      if (!u.dob) return false;
      const str = String(u.dob).trim();
      const parts = str.split(/[-/]/);
      if (parts.length === 3) {
        let m, d;
        if (parts[0].length === 4) {
          // YYYY-MM-DD
          m = parseInt(parts[1], 10);
          d = parseInt(parts[2], 10);
        } else {
          // DD-MM-YYYY
          d = parseInt(parts[0], 10);
          m = parseInt(parts[1], 10);
        }
        if (m === todayMonth && d === todayDay) return true;
      }
      const parsed = new Date(u.dob);
      if (!isNaN(parsed.getTime())) {
        return (parsed.getMonth() + 1) === todayMonth && parsed.getDate() === todayDay;
      }
      return false;
    });
  }

  getUpcomingBirthdays(days = 30) {
    const today = new Date();
    const todayMonth = today.getMonth() + 1;
    const todayDay = today.getDate();

    return this.data.users
      .map(u => {
        if (!u.dob) return null;
        const parts = String(u.dob).trim().split(/[-/]/);
        let m, d;
        if (parts.length === 3) {
          if (parts[0].length === 4) {
            m = parseInt(parts[1], 10);
            d = parseInt(parts[2], 10);
          } else {
            d = parseInt(parts[0], 10);
            m = parseInt(parts[1], 10);
          }
        }
        if (!m || !d) return null;

        const currentYear = today.getFullYear();
        let nextBday = new Date(currentYear, m - 1, d);
        if (nextBday < today && !(m === todayMonth && d === todayDay)) {
          nextBday = new Date(currentYear + 1, m - 1, d);
        }
        const diffTime = nextBday - today;
        const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

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
            is_today: diffDays === 0 || (m === todayMonth && d === todayDay),
          };
        }
        return null;
      })
      .filter(Boolean)
      .sort((a, b) => a.days_until - b.days_until);
  }

  findUserByReferralCode(code) {
    if (!code) return null;
    return this.data.users.find(u => u.referral_code === code.trim().toUpperCase()) || null;
  }

  createUser(userData) {
    const nextId = this.data.users.length > 0 ? Math.max(...this.data.users.map(u => u.id)) + 1 : 1;
    const newUser = {
      id: nextId,
      name: userData.name || '',
      username: userData.username || `user_${nextId}`,
      email: userData.email || '',
      mobile_no: userData.mobile_no || '',
      whatsapp: userData.whatsapp || userData.mobile_no || '',
      school_name: userData.school_name || '',
      dob: userData.dob || null,
      state: userData.state || '',
      district: userData.district || '',
      password: userData.password,
      referral_code: userData.referral_code || `TELSO${nextId}${Math.floor(100 + Math.random() * 900)}`,
      referred_by: userData.referred_by || null,
      user_type: userData.user_type || 'musician',
      role: 'creator',
      status: 'active',
      created_at: new Date().toISOString(),
    };

    this.data.users.push(newUser);

    const welcomeBonus = (this.data.settings && this.data.settings.platform && this.data.settings.platform.welcome_bonus) || 50.0;
    const refReward = (this.data.settings && this.data.settings.platform && this.data.settings.platform.referral_reward) || 50.0;

    // Create wallet for new user with signup bonus
    this.data.wallets.push({
      user_id: nextId,
      balance: welcomeBonus,
      pending_amount: 0.0,
    });

    this.data.transactions.push({
      id: `tx_${Date.now()}_${nextId}`,
      user_id: nextId,
      title: 'Welcome Bonus 🎁',
      description: 'Signup bonus credited to Telso wallet',
      amount: welcomeBonus,
      type: 'credit',
      status: 'completed',
      created_at: new Date().toISOString(),
    });

    // If referred by someone, reward the referrer too!
    if (userData.referred_by) {
      const referrer = this.findUserByReferralCode(userData.referred_by);
      if (referrer) {
        let refWallet = this.data.wallets.find(w => w.user_id === referrer.id);
        if (!refWallet) {
          refWallet = { user_id: referrer.id, balance: 0.0, pending_amount: 0.0 };
          this.data.wallets.push(refWallet);
        }
        refWallet.balance += refReward;
        this.data.transactions.push({
          id: `tx_ref_${Date.now()}`,
          user_id: referrer.id,
          title: 'Referral Bonus 👥',
          description: `Bonus for referring ${newUser.name || newUser.username}`,
          amount: refReward,
          type: 'credit',
          status: 'completed',
          created_at: new Date().toISOString(),
        });
      }
    }

    this.save();
    return newUser;
  }

  updateUser(id, updates) {
    const numericId = parseInt(id, 10);
    const index = this.data.users.findIndex(u => u.id === numericId);
    if (index === -1) return null;

    this.data.users[index] = { ...this.data.users[index], ...updates };
    this.save();
    return this.data.users[index];
  }

  deleteUser(id) {
    const numericId = parseInt(id, 10);
    this.data.users = this.data.users.filter(u => u.id !== numericId);
    this.data.videos = this.data.videos.filter(v => v.user_id !== numericId);
    this.data.wallets = this.data.wallets.filter(w => w.user_id !== numericId);
    this.save();
    return true;
  }

  // --- Videos ---
  getVideos({ type = null, status = 'Approved', currentUserId = null } = {}) {
    let list = [...this.data.videos];

    if (type) {
      list = list.filter(v => v.video_type === type);
    }
    if (status && status !== 'all') {
      list = list.filter(v => v.status === status);
    }

    return list.map(v => {
      const isLiked = currentUserId ? (v.liked_by || []).includes(parseInt(currentUserId, 10)) : false;
      return {
        ...v,
        liked: isLiked,
        is_liked: isLiked,
        liked_by_count: (v.liked_by || []).length,
      };
    });
  }

  findVideoById(id, currentUserId = null) {
    const numericId = parseInt(id, 10);
    const v = this.data.videos.find(v => v.id === numericId);
    if (!v) return null;

    const isLiked = currentUserId ? (v.liked_by || []).includes(parseInt(currentUserId, 10)) : false;
    return {
      ...v,
      liked: isLiked,
      is_liked: isLiked,
    };
  }

  createVideo(videoData) {
    const nextId = this.data.videos.length > 0 ? Math.max(...this.data.videos.map(v => v.id)) + 1 : 1;
    const requireApproval = (this.data.settings && this.data.settings.platform && this.data.settings.platform.require_admin_approval !== false);
    const defaultStatus = videoData.status || (requireApproval ? 'Pending' : 'Approved');

    const newVideo = {
      id: nextId,
      user_id: videoData.user_id || 1,
      name: videoData.name || videoData.reporter_name || 'Creator',
      username: videoData.username || 'creator',
      title: videoData.title || videoData.subject || 'New Reel',
      subject: videoData.subject || videoData.title || '',
      category: videoData.category || 'General',
      video_url: videoData.video_url || '',
      video_path: videoData.video_path || videoData.video_url || '',
      thumbnail_url: videoData.thumbnail_url || '',
      image: videoData.thumbnail_url || '',
      video_type: videoData.video_type || 'normal',
      status: defaultStatus,
      view_count: videoData.view_count || 0,
      likes_count: videoData.likes_count || 0,
      shares_count: videoData.shares_count || 0,
      comments_count: 0,
      liked_by: [],
      created_at: new Date().toISOString(),
    };

    this.data.videos.unshift(newVideo);
    this.save();
    return newVideo;
  }

  updateVideo(id, updates) {
    const numericId = parseInt(id, 10);
    const index = this.data.videos.findIndex(v => v.id === numericId);
    if (index === -1) return null;

    this.data.videos[index] = { ...this.data.videos[index], ...updates };
    this.save();
    return this.data.videos[index];
  }

  deleteVideo(id) {
    const numericId = parseInt(id, 10);
    this.data.videos = this.data.videos.filter(v => v.id !== numericId);
    this.data.comments = this.data.comments.filter(c => c.video_id !== numericId);
    this.save();
    return true;
  }

  // --- View Tracking (Strict 1 user/device = 1 view) ---
  recordVideoView(id, viewerIdentifier = 'anonymous') {
    const numericId = parseInt(id, 10);
    const v = this.data.videos.find(video => video.id === numericId);
    if (!v) return null;

    v.viewed_by = v.viewed_by || [];
    const identifier = String(viewerIdentifier || 'anonymous');
    const alreadyViewed = v.viewed_by.includes(identifier);

    if (!alreadyViewed) {
      v.viewed_by.push(identifier);
      v.view_count = (v.view_count || 0) + 1;
      this.save();
      return { incremented: true, view_count: v.view_count };
    }

    return { incremented: false, view_count: v.view_count || 0 };
  }

  // --- 5-Layer Engagement Reward Calculator ---
  calculateLayerReward(actionType, currentActionCount) {
    // 5 Tiers:
    // Layer 1 (1 - 100): 10 paisa (₹0.10)
    // Layer 2 (101 - 300): 7 paisa (₹0.07)
    // Layer 3 (301 - 600): 5 paisa (₹0.05)
    // Layer 4 (601 - 1000): 3 paisa (₹0.03)
    // Layer 5 (1001 - 1500): 1 paisa (₹0.01)
    // Beyond Layer 5: Pool Exhausted (₹0.00)
    const position = currentActionCount + 1;
    if (position <= 100) return { layer: 1, reward: 0.10, label: 'Layer 1 (10 Paisa)', pool_pct: '100%' };
    if (position <= 300) return { layer: 2, reward: 0.07, label: 'Layer 2 (7 Paisa)', pool_pct: '70%' };
    if (position <= 600) return { layer: 3, reward: 0.05, label: 'Layer 3 (5 Paisa)', pool_pct: '50%' };
    if (position <= 1000) return { layer: 4, reward: 0.03, label: 'Layer 4 (3 Paisa)', pool_pct: '30%' };
    if (position <= 1500) return { layer: 5, reward: 0.01, label: 'Layer 5 (1 Paisa)', pool_pct: '10%' };
    return { layer: 6, reward: 0.00, label: 'Pool Exhausted', pool_pct: '0%' };
  }

  toggleVideoLike(videoId, userId) {
    const numericId = parseInt(videoId, 10);
    const uId = parseInt(userId, 10);
    const video = this.data.videos.find(v => v.id === numericId);
    if (!video) return null;

    video.liked_by = video.liked_by || [];
    video.earned_like_users = video.earned_like_users || [];
    const index = video.liked_by.indexOf(uId);
    let liked = false;
    let rewardInfo = null;

    if (index === -1) {
      video.liked_by.push(uId);
      video.likes_count = (video.likes_count || 0) + 1;
      liked = true;

      // 🔔 Notify reel creator about new like
      if (video.user_id && video.user_id !== uId) {
        const likingUser = this.findUserById(uId);
        const name = likingUser ? (likingUser.name || likingUser.username) : 'A creator';
        this.addUserNotification(video.user_id, {
          title: '❤️ New Like on your Reel!',
          message: `${name} liked your reel "${video.title}".`,
          type: 'social',
          avatar: likingUser ? likingUser.profile_image : '',
          action_url: `#watch?v=${video.id}`,
          action_text: 'View Reel',
        });
      }

      // 5-Layer Engagement Reward on Ad / Sponsored Posts
      if (uId && (video.video_type === 'ads' || video.category === 'Promotion') && !video.earned_like_users.includes(uId)) {
        video.earned_like_users.push(uId);
        const layerData = this.calculateLayerReward('like', video.earned_like_users.length - 1);
        if (layerData.reward > 0) {
          const txRes = this.addWalletTransaction(uId, {
            amount: layerData.reward,
            type: 'credit',
            title: `Ad Like Reward: ${layerData.label}`,
            description: `Earned ₹${layerData.reward.toFixed(2)} for liking sponsored post "${video.title}"`,
          });
          this.addUserNotification(uId, {
            title: `+₹${layerData.reward.toFixed(2)} Credited! 💰`,
            message: `You received 10 paisa ad reward (${layerData.label}) for liking "${video.title}".`,
            type: 'earning'
          });
          rewardInfo = {
            reward: layerData.reward,
            layer: layerData.layer,
            label: layerData.label,
            new_balance: txRes.wallet.balance.toFixed(2),
          };
        }
      }
    } else {
      video.liked_by.splice(index, 1);
      video.likes_count = Math.max(0, (video.likes_count || 1) - 1);
      liked = false;
    }

    this.save();
    return {
      liked,
      is_liked: liked,
      likes_count: video.likes_count,
      reward_info: rewardInfo,
    };
  }

  // --- Comments ---
  getComments(videoId, currentUserId = null) {
    const vId = parseInt(videoId, 10);
    const cId = currentUserId ? parseInt(currentUserId, 10) : null;
    const all = this.data.comments.filter(c => c.video_id === vId);

    const parents = all.filter(c => !c.parent_id);
    return parents.map(c => {
      const isLiked = cId ? (c.liked_by || []).includes(cId) : false;
      const replies = all.filter(r => r.parent_id === c.id).map(r => ({
        ...r,
        is_liked: cId ? (r.liked_by || []).includes(cId) : false,
      }));

      return {
        ...c,
        is_liked: isLiked,
        reply_count: replies.length,
        replies,
      };
    });
  }

  getCommentReplies(commentId, currentUserId = null) {
    const parentId = parseInt(commentId, 10);
    const cId = currentUserId ? parseInt(currentUserId, 10) : null;
    return this.data.comments
      .filter(c => c.parent_id === parentId)
      .map(r => ({
        ...r,
        is_liked: cId ? (r.liked_by || []).includes(cId) : false,
      }));
  }

  createComment(commentData) {
    const nextId = this.data.comments.length > 0 ? Math.max(...this.data.comments.map(c => c.id)) + 1 : 1;
    const text = commentData.comment || commentData.content || '';
    const videoId = parseInt(commentData.video_id, 10);
    const userId = parseInt(commentData.user_id || 1, 10);

    const newComment = {
      id: nextId,
      video_id: videoId,
      user_id: userId,
      user: commentData.user_name || commentData.username || 'User',
      user_name: commentData.user_name || commentData.username || 'User',
      username: commentData.username || 'user',
      comment: text,
      content: text,
      profile_image: commentData.profile_image || '',
      likes: 0,
      liked_by: [],
      reply_count: 0,
      parent_id: commentData.parent_id ? parseInt(commentData.parent_id, 10) : null,
      created_at: new Date().toISOString(),
    };

    this.data.comments.push(newComment);

    const video = this.data.videos.find(v => v.id === videoId);
    let rewardInfo = null;

    if (video) {
      video.comments_count = (video.comments_count || 0) + 1;
      video.earned_comment_users = video.earned_comment_users || [];

      // 🔔 Notify reel creator about new comment
      if (video.user_id && video.user_id !== userId) {
        this.addUserNotification(video.user_id, {
          title: '💬 New Comment on your Reel',
          message: `${newComment.user} commented: "${text.length > 60 ? text.substring(0, 60) + '...' : text}"`,
          type: 'social',
          avatar: newComment.profile_image,
          action_url: `#watch?v=${video.id}`,
          action_text: 'Reply to Comment',
        });
      }

      // 5-Layer Engagement Reward on Ad / Sponsored Posts for comments
      if (userId && (video.video_type === 'ads' || video.category === 'Promotion') && !video.earned_comment_users.includes(userId)) {
        video.earned_comment_users.push(userId);
        const layerData = this.calculateLayerReward('comment', video.earned_comment_users.length - 1);
        if (layerData.reward > 0) {
          const txRes = this.addWalletTransaction(userId, {
            amount: layerData.reward,
            type: 'credit',
            title: `Ad Comment Reward: ${layerData.label}`,
            description: `Earned ₹${layerData.reward.toFixed(2)} for commenting on "${video.title}"`,
          });
          this.addUserNotification(userId, {
            title: `+₹${layerData.reward.toFixed(2)} Credited! 💬`,
            message: `You received 10 paisa ad reward (${layerData.label}) for your comment on "${video.title}".`,
            type: 'earning'
          });
          rewardInfo = {
            reward: layerData.reward,
            layer: layerData.layer,
            label: layerData.label,
            new_balance: txRes.wallet.balance.toFixed(2),
          };
        }
      }
    }

    this.save();
    return {
      comment: newComment,
      reward_info: rewardInfo,
    };
  }

  toggleCommentLike(commentId, userId) {
    const cId = parseInt(commentId, 10);
    const uId = parseInt(userId, 10);
    const comment = this.data.comments.find(c => c.id === cId);
    if (!comment) return null;

    comment.liked_by = comment.liked_by || [];
    const index = comment.liked_by.indexOf(uId);
    let liked = false;

    if (index === -1) {
      comment.liked_by.push(uId);
      comment.likes = (comment.likes || 0) + 1;
      liked = true;
    } else {
      comment.liked_by.splice(index, 1);
      comment.likes = Math.max(0, (comment.likes || 1) - 1);
      liked = false;
    }

    this.save();
    return {
      is_liked: liked,
      likes: comment.likes,
    };
  }

  deleteComment(id) {
    const cId = parseInt(id, 10);
    const comment = this.data.comments.find(c => c.id === cId);
    if (!comment) return false;

    const video = this.data.videos.find(v => v.id === comment.video_id);
    if (video) {
      video.comments_count = Math.max(0, (video.comments_count || 1) - 1);
    }

    this.data.comments = this.data.comments.filter(c => c.id !== cId && c.parent_id !== cId);
    this.save();
    return true;
  }

  // --- Wallets & Transactions ---
  getWallet(userId) {
    const uId = parseInt(userId, 10);
    let wallet = this.data.wallets.find(w => w.user_id === uId);
    if (!wallet) {
      wallet = { user_id: uId, balance: 0.0, pending_amount: 0.0 };
      this.data.wallets.push(wallet);
      this.save();
    }

    const txs = this.data.transactions
      .filter(t => t.user_id === uId)
      .sort((a, b) => new Date(b.created_at) - new Date(a.created_at));

    return {
      balance: wallet.balance.toFixed(2),
      total_balance: wallet.balance.toFixed(2),
      pending_amount: wallet.pending_amount.toFixed(2),
      transactions: txs,
    };
  }

  addWalletTransaction(userId, { title, description, amount, type = 'credit' }) {
    const uId = parseInt(userId, 10);
    let wallet = this.data.wallets.find(w => w.user_id === uId);
    if (!wallet) {
      wallet = { user_id: uId, balance: 0.0, pending_amount: 0.0 };
      this.data.wallets.push(wallet);
    }

    const numAmount = parseFloat(amount);
    if (type === 'credit') {
      wallet.balance += numAmount;
    } else {
      wallet.balance = Math.max(0, wallet.balance - numAmount);
    }

    const tx = {
      id: `tx_${Date.now()}`,
      user_id: uId,
      title: title || (type === 'credit' ? 'Wallet Credit' : 'Wallet Debit'),
      description: description || '',
      amount: numAmount,
      type,
      status: 'completed',
      created_at: new Date().toISOString(),
    };

    this.data.transactions.unshift(tx);
    this.save();
    return { wallet, transaction: tx };
  }

  // --- Referrals ---
  getReferral(userId, reqHost) {
    const uId = parseInt(userId, 10);
    const user = this.findUserById(uId);
    if (!user) return null;

    const referrals = this.data.users.filter(u => u.referred_by === user.referral_code);
    const reward = (this.data.settings && this.data.settings.platform && this.data.settings.platform.referral_reward) || 50.0;
    const earnings = referrals.length * reward;

    return {
      referral_code: user.referral_code,
      referral_link: `http://${reqHost}/invite/${user.referral_code}`,
      total_referrals: referrals.length,
      total_earnings: earnings,
      referrals: referrals.map(r => ({
        id: r.id,
        name: r.name,
        username: r.username,
        created_at: r.created_at,
      })),
    };
  }

  // --- Web Links ---
  getWebLinks(userId = null) {
    this.data.web_links = this.data.web_links || [];
    if (userId) {
      const uId = parseInt(userId, 10);
      return this.data.web_links.filter(w => w.user_id === uId);
    }
    return this.data.web_links;
  }

  createWebLink(linkData) {
    this.data.web_links = this.data.web_links || [];
    const nextId = this.data.web_links.length > 0 ? Math.max(...this.data.web_links.map(w => w.id)) + 1 : 1;
    const newLink = {
      id: nextId,
      user_id: linkData.user_id || 1,
      subject: linkData.subject || '',
      name: linkData.name || '',
      like_limit: linkData.like_limit || '1,000',
      state: linkData.state || '',
      district: linkData.district || '',
      web_link: linkData.web_link || '',
      utr: linkData.utr || '—',
      status: 'Pending',
      current_likes: 0,
      created_at: new Date().toISOString(),
    };
    this.data.web_links.unshift(newLink);
    this.save();
    return newLink;
  }

  // --- Notifications for Users ---
  getUserNotifications(userId, filterType = 'all') {
    this.data.notifications = this.data.notifications || [];
    const uId = parseInt(userId || 1, 10);
    const userNotifs = this.data.notifications
      .filter(n => !n.user_id || n.user_id === uId);

    const counts = {
      all: userNotifs.length,
      unread: userNotifs.filter(n => !n.is_read && !n.read).length,
      earning: userNotifs.filter(n => n.type === 'earning' || n.type === 'wallet').length,
      moderation: userNotifs.filter(n => n.type === 'moderation' || n.type === 'video').length,
      social: userNotifs.filter(n => n.type === 'social' || n.type === 'like' || n.type === 'comment' || n.type === 'follow').length,
      system: userNotifs.filter(n => n.type === 'system' || n.type === 'announcement' || n.type === 'info' || n.type === 'birthday').length,
    };

    let filtered = userNotifs;
    if (filterType && filterType !== 'all') {
      if (filterType === 'earning' || filterType === 'wallet') {
        filtered = userNotifs.filter(n => n.type === 'earning' || n.type === 'wallet');
      } else if (filterType === 'moderation' || filterType === 'video') {
        filtered = userNotifs.filter(n => n.type === 'moderation' || n.type === 'video');
      } else if (filterType === 'social') {
        filtered = userNotifs.filter(n => n.type === 'social' || n.type === 'like' || n.type === 'comment' || n.type === 'follow');
      } else if (filterType === 'system') {
        filtered = userNotifs.filter(n => n.type === 'system' || n.type === 'announcement' || n.type === 'info' || n.type === 'birthday');
      } else {
        filtered = userNotifs.filter(n => n.type === filterType);
      }
    }

    filtered.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));

    return {
      notifications: filtered,
      unread_count: counts.unread,
      counts,
    };
  }

  addUserNotification(userId, data) {
    this.data.notifications = this.data.notifications || [];
    const nextId = `notif_u_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
    const notif = {
      id: nextId,
      user_id: userId ? parseInt(userId, 10) : null,
      title: data.title || 'Notification',
      message: data.message || data.body || '',
      body: data.message || data.body || '',
      type: data.type || 'info', // earning, moderation, social, system
      icon: data.icon || (data.type === 'earning' ? 'coins' : data.type === 'moderation' ? 'check-circle' : data.type === 'social' ? 'heart' : 'bell'),
      color: data.color || (data.type === 'earning' ? 'amber' : data.type === 'moderation' ? 'purple' : data.type === 'social' ? 'rose' : 'blue'),
      avatar: data.avatar || '',
      action_url: data.action_url || '',
      action_text: data.action_text || '',
      created_at: data.created_at || new Date().toISOString(),
      is_read: false,
      read: false,
    };
    this.data.notifications.unshift(notif);
    this.save();
    return notif;
  }

  markNotificationRead(id, userId) {
    this.data.notifications = this.data.notifications || [];
    const notif = this.data.notifications.find(n => n.id === id);
    if (notif) {
      notif.is_read = true;
      notif.read = true;
      this.save();
      return true;
    }
    return false;
  }

  markAllNotificationsRead(userId) {
    this.data.notifications = this.data.notifications || [];
    const uId = parseInt(userId || 1, 10);
    let updated = 0;
    this.data.notifications.forEach(n => {
      if (!n.user_id || n.user_id === uId) {
        if (!n.is_read || !n.read) {
          n.is_read = true;
          n.read = true;
          updated++;
        }
      }
    });
    if (updated > 0) this.save();
    return updated;
  }

  deleteNotification(id, userId) {
    this.data.notifications = this.data.notifications || [];
    const initialLen = this.data.notifications.length;
    this.data.notifications = this.data.notifications.filter(n => n.id !== id);
    if (this.data.notifications.length !== initialLen) {
      this.save();
      return true;
    }
    return false;
  }

  clearUserNotifications(userId) {
    this.data.notifications = this.data.notifications || [];
    const uId = parseInt(userId || 1, 10);
    this.data.notifications = this.data.notifications.filter(n => n.user_id && n.user_id !== uId);
    this.save();
    return true;
  }

  // --- Creator Channel Stats (Total Likes, Total Views, Video Counts) ---
  getCreatorStats(userId) {
    const uId = parseInt(userId || 1, 10);
    const user = this.findUserById(uId) || this.data.users[0];
    const userVideos = this.data.videos.filter(v => v.user_id === user.id);
    const totalLikes = userVideos.reduce((sum, v) => sum + (v.likes_count || 0), 0);
    const totalViews = userVideos.reduce((sum, v) => sum + (v.view_count || 0), 0);
    const totalComments = userVideos.reduce((sum, v) => sum + (v.comments_count || 0), 0);
    const approvedVideos = userVideos.filter(v => v.status === 'Approved');
    const pendingVideos = userVideos.filter(v => v.status === 'Pending');
    const wallet = this.getWallet(user.id);

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
  createAd(adData) {
    const nextId = this.data.videos.length > 0 ? Math.max(...this.data.videos.map(v => v.id)) + 1 : 1;
    const newAd = {
      id: nextId,
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
      view_count: 0,
      likes_count: 0,
      shares_count: 0,
      comments_count: 0,
      liked_by: [],
      viewed_by: [],
      earned_like_users: [],
      earned_comment_users: [],
      created_at: new Date().toISOString(),
    };

    this.data.videos.unshift(newAd);
    this.save();
    return newAd;
  }

  // --- System Stats for Admin ---
  getStats() {
    const totalUsers = this.data.users.length;
    const totalVideos = this.data.videos.length;
    const totalViews = this.data.videos.reduce((sum, v) => sum + (v.view_count || 0), 0);
    const totalLikes = this.data.videos.reduce((sum, v) => sum + (v.likes_count || 0), 0);
    const totalComments = this.data.comments.length;
    const pendingWithdrawals = (this.data.withdrawals || []).filter(w => w.status === 'pending').length;

    const pendingVideosCount = this.data.videos.filter(v => v.status === 'Pending').length;
    const todayBirthdaysCount = this.getTodayBirthdays().length;

    return {
      total_users: totalUsers,
      total_videos: totalVideos,
      total_views: totalViews,
      total_likes: totalLikes,
      total_comments: totalComments,
      pending_withdrawals: pendingWithdrawals,
      pending_videos_count: pendingVideosCount,
      today_birthdays_count: todayBirthdaysCount,
      normal_videos_count: this.data.videos.filter(v => v.video_type === 'normal').length,
      ads_videos_count: this.data.videos.filter(v => v.video_type === 'ads').length,
    };
  }
}

const db = new Database();
module.exports = db;
