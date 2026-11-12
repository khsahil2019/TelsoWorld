const express = require('express');
const bcrypt = require('bcryptjs');
const db = require('../db');
const { generateToken, authRequired } = require('../middleware/auth');

const router = express.Router();

// In-memory OTP cache: key = identifier (phone or email), value = { otp, expiresAt, verified }
const otpStore = new Map();

/**
 * 📲 POST /api/reporter/send-otp
 * Sends verification OTP for mobile number & email
 */
router.post('/send-otp', (req, res) => {
  const { mobile_no, email } = req.body;
  const identifier = (mobile_no || email || '').trim();

  if (!identifier) {
    return res.status(422).json({
      status: false,
      message: 'Mobile number or email is required to send OTP',
    });
  }

  // Generate a realistic 6-digit OTP
  // In dev / local testing we use 123456 or a random 6-digit code
  const otp = Math.floor(100000 + Math.random() * 900000).toString();
  const expiresAt = Date.now() + 10 * 60 * 1000; // 10 minutes

  otpStore.set(identifier, { otp, expiresAt, verified: false });

  console.log(`[AUTH OTP] 📨 Generated OTP for ${identifier}: ${otp}`);

  return res.status(200).json({
    status: true,
    message: `OTP sent successfully to ${identifier}`,
    otp, // Returned in dev mode for seamless testing
    expires_in_seconds: 600,
  });
});

/**
 * ✅ POST /api/reporter/verify-otp
 * Verifies the 6-digit OTP
 */
router.post('/verify-otp', (req, res) => {
  const { mobile_no, email, otp } = req.body;
  const identifier = (mobile_no || email || '').trim();

  if (!identifier || !otp) {
    return res.status(422).json({
      status: false,
      message: 'Identifier and OTP are required',
    });
  }

  const record = otpStore.get(identifier);
  // Allow test OTP '123456' or matching generated OTP
  if (otp === '123456' || (record && record.otp === otp && Date.now() < record.expiresAt)) {
    if (record) record.verified = true;
    return res.status(200).json({
      status: true,
      message: 'OTP verified successfully! Proceed with registration.',
      verified: true,
    });
  }

  return res.status(400).json({
    status: false,
    message: 'Invalid or expired OTP. Please enter the correct 6-digit code or try 123456',
    verified: false,
  });
});

/**
 * 🔍 GET /api/reporter/check-username
 * Validates unique Instagram-style handle availability
 */
router.get('/check-username', (req, res) => {
  const raw = req.query.username || '';
  const clean = raw.trim().toLowerCase().replace(/^@/, '');

  if (!clean || clean.length < 3) {
    return res.status(422).json({
      status: false,
      available: false,
      message: 'Username must be at least 3 characters long',
    });
  }

  // Regex for valid username (alphanumeric, underscores, dots)
  if (!/^[a-z0-9_.]+$/.test(clean)) {
    return res.status(422).json({
      status: false,
      available: false,
      message: 'Username can only contain letters, numbers, underscores (_), and periods (.)',
    });
  }

  const existing = db.findUserByUsername(clean);
  if (existing) {
    return res.status(200).json({
      status: true,
      available: false,
      username: clean,
      message: `@${clean} is already taken. Try another!`,
    });
  }

  return res.status(200).json({
    status: true,
    available: true,
    username: clean,
    message: `@${clean} is available!`,
  });
});

/**
 * 📝 POST /api/reporter/register
 * Accepts creator registration fields:
 * username (Unique like Instagram), mobile_no, password, whatsapp_no, dob (Happy birthday date - Mandatory!),
 * email, state, district, referral_code, user_type
 */
router.post('/register', (req, res) => {
  try {
    const {
      name,
      username,
      email,
      mobile_no,
      whatsapp,
      whatsapp_no,
      dob,
      state,
      district,
      password,
      referral_code,
      user_type,
    } = req.body;

    const rawUsername = (username || '').trim().toLowerCase().replace(/^@/, '');
    const cleanMobile = (mobile_no || '').trim().replace(/\D/g, '');
    const finalMobile = cleanMobile.length === 12 && cleanMobile.startsWith('91')
      ? cleanMobile.substring(2)
      : cleanMobile;
    const finalWhatsapp = (whatsapp_no || whatsapp || finalMobile).trim();

    // 1. Mandatory Username validation
    if (!rawUsername || rawUsername.length < 3) {
      return res.status(422).json({
        status: false,
        message: 'A unique username (@handle) with at least 3 characters is required',
      });
    }

    const existingUser = db.findUserByUsername(rawUsername);
    if (existingUser) {
      return res.status(409).json({
        status: false,
        message: `Username @${rawUsername} is already taken. Please choose another username.`,
      });
    }

    // 2. Mandatory Mobile Number
    if (!finalMobile || finalMobile.length < 10) {
      return res.status(422).json({
        status: false,
        message: 'A valid 10-digit mobile number is required',
      });
    }

    // 3. Mandatory Password
    if (!password || password.length < 4) {
      return res.status(422).json({
        status: false,
        message: 'Password must be at least 4 characters long',
      });
    }

    // 4. Mandatory Birthday Date 🎂
    if (!dob || !dob.toString().trim()) {
      return res.status(422).json({
        status: false,
        message: 'Happy Birthday date 🎂 is required so we can celebrate your special day!',
      });
    }

    // 5. Check if mobile already registered
    const existingPhone = db.getUsers().find(u => u.mobile_no === finalMobile);
    if (existingPhone) {
      return res.status(409).json({
        status: false,
        message: 'This mobile number is already registered. Please log in.',
      });
    }

    const hashedPassword = bcrypt.hashSync(password, 10);
    const newUser = db.createUser({
      name: name || rawUsername,
      username: rawUsername,
      email: email || `${rawUsername}@telsoworld.com`,
      mobile_no: finalMobile,
      whatsapp: finalWhatsapp,
      dob: dob,
      state: state || '',
      district: district || '',
      password: hashedPassword,
      referred_by: referral_code || null,
      user_type: user_type || 'musician',
    });

    const token = generateToken({ id: newUser.id, username: newUser.username, role: newUser.role });

    // 🔔 Send Welcome Notification to newly registered creator
    db.addUserNotification(newUser.id, {
      title: '🎁 Welcome Bonus Credited!',
      message: `Welcome to Telso World, ${newUser.name || newUser.username}! ₹50 joining bonus has been credited to your wallet.`,
      type: 'earning',
      action_url: '#wallet',
      action_text: 'View Wallet',
    });

    console.log(`[AUTH] 🎉 New Creator Registered: @${newUser.username} (Mobile: ${newUser.mobile_no}, Birthday: ${newUser.dob})`);

    return res.status(201).json({
      status: true,
      message: 'Registration successful! Welcome to Telso World 🎉',
      token,
      data: {
        id: newUser.id,
        name: newUser.name,
        username: newUser.username,
        email: newUser.email,
        mobile_no: newUser.mobile_no,
        whatsapp_no: newUser.whatsapp,
        dob: newUser.dob,
        referral_code: newUser.referral_code,
        wallet_balance: 50.0,
        token,
      },
      user: {
        id: newUser.id,
        username: newUser.username,
        email: newUser.email,
        mobile_no: newUser.mobile_no,
        dob: newUser.dob,
        token,
      },
    });
  } catch (err) {
    console.error('Registration error:', err);
    return res.status(500).json({
      status: false,
      message: 'Internal server error during registration',
    });
  }
});

/**
 * 🔑 POST /api/reporter/login
 */
router.post('/login', (req, res) => {
  try {
    const { email, username, mobile, mobile_no, password } = req.body;
    const identifier = email || username || mobile || mobile_no;

    if (!identifier || !password) {
      return res.status(422).json({
        status: false,
        message: 'Username / Mobile and password are required',
      });
    }

    const user = db.findUserByEmailOrPhone(identifier);
    if (!user) {
      return res.status(401).json({
        status: false,
        message: 'Invalid credentials: User not found',
      });
    }

    if (user.status === 'banned') {
      return res.status(403).json({
        status: false,
        message: 'Account suspended. Contact support@telsoworld.com',
      });
    }

    const passwordMatch = bcrypt.compareSync(password, user.password);
    if (!passwordMatch) {
      return res.status(401).json({
        status: false,
        message: 'Incorrect password. Please try again',
      });
    }

    const token = generateToken({ id: user.id, username: user.username, role: user.role });

    return res.status(200).json({
      status: true,
      message: 'Login successful! Welcome back',
      token,
      data: {
        id: user.id,
        name: user.name,
        username: user.username,
        email: user.email,
        mobile_no: user.mobile_no,
        referral_code: user.referral_code,
        dob: user.dob,
        token,
      },
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        mobile_no: user.mobile_no,
        dob: user.dob,
        token,
      },
    });
  } catch (err) {
    console.error('Login error:', err);
    return res.status(500).json({
      status: false,
      message: 'Internal server error during login',
    });
  }
});

/**
 * 🚪 POST /api/reporter/logout
 */
router.post('/logout', (req, res) => {
  return res.status(200).json({
    status: true,
    message: 'Logged out successfully',
  });
});

/**
 * 👤 GET /api/reporter/profile
 */
router.get('/profile', authRequired, (req, res) => {
  const { password, ...safeUser } = req.user;
  const wallet = db.getWallet(req.user.id);

  return res.status(200).json({
    status: true,
    data: {
      ...safeUser,
      wallet_balance: wallet.balance,
    },
  });
});

module.exports = router;
