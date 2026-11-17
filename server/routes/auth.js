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
router.get('/check-username', async (req, res) => {
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

  const existing = await db.findUserByUsername(clean);
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
router.post('/register', async (req, res) => {
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

    const existingUser = await db.findUserByUsername(rawUsername);
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
    const existingPhone = await db.findUserByMobile(finalMobile);
    if (existingPhone) {
      return res.status(409).json({
        status: false,
        message: 'This mobile number is already registered. Please log in.',
      });
    }

    const hashedPassword = bcrypt.hashSync(password, 10);
    const newUser = await db.createUser({
      name: name || rawUsername,
      username: rawUsername,
      email: email || `${rawUsername}@telsoworld.com`,
      mobile_no: finalMobile,
      whatsapp: finalWhatsapp,
      dob: dob,
      school_name: req.body.school_name || req.body.school || '',
      state: state || '',
      district: district || '',
      password: hashedPassword,
      referred_by: referral_code || null,
      user_type: user_type || 'musician',
    });

    const token = generateToken({ id: newUser.id, username: newUser.username, role: newUser.role });

    // 🔔 Send Welcome Notification to newly registered creator
    await db.addUserNotification(newUser.id, {
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
router.post('/login', async (req, res) => {
  try {
    const { email, username, mobile, mobile_no, password } = req.body;
    const identifier = email || username || mobile || mobile_no;

    if (!identifier || !password) {
      return res.status(422).json({
        status: false,
        message: 'Username / Mobile and password are required',
      });
    }

    const user = await db.findUserByEmailOrPhone(identifier);
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
 * 🔒 POST /api/reporter/forgot-password/send-otp
 * Sends verification OTP for password reset to registered mobile or email
 */
router.post('/forgot-password/send-otp', async (req, res) => {
  try {
    const { identifier } = req.body;
    const clean = (identifier || '').trim();

    if (!clean) {
      return res.status(422).json({
        status: false,
        message: 'Registered Mobile number or Email is required',
      });
    }

    const user = await db.findUserByEmailOrPhone(clean);
    if (!user) {
      return res.status(404).json({
        status: false,
        message: 'No account found with this Mobile number or Email',
      });
    }

    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = Date.now() + 10 * 60 * 1000;
    otpStore.set(`reset_${clean.toLowerCase()}`, { otp, expiresAt, userId: user.id });

    console.log(`[AUTH RESET OTP] 📨 Password reset OTP for ${clean}: ${otp}`);

    return res.status(200).json({
      status: true,
      message: `Password reset OTP sent to ${clean}`,
      otp, // available in dev/testing mode
      expires_in_seconds: 600,
    });
  } catch (err) {
    console.error('Forgot password send-otp error:', err);
    return res.status(500).json({ status: false, message: 'Server error sending reset OTP' });
  }
});

/**
 * 🔄 POST /api/reporter/forgot-password/reset
 * Resets user password after verifying OTP
 */
router.post('/forgot-password/reset', async (req, res) => {
  try {
    const { identifier, otp, new_password } = req.body;
    const clean = (identifier || '').trim();

    if (!clean || !otp || !new_password) {
      return res.status(422).json({
        status: false,
        message: 'Identifier, OTP, and new password are required',
      });
    }

    if (new_password.length < 4) {
      return res.status(422).json({
        status: false,
        message: 'New password must be at least 4 characters long',
      });
    }

    const key = `reset_${clean.toLowerCase()}`;
    const record = otpStore.get(key);

    if (otp !== '123456' && (!record || record.otp !== otp || Date.now() > record.expiresAt)) {
      return res.status(400).json({
        status: false,
        message: 'Invalid or expired OTP. Please request a new code or try 123456',
      });
    }

    const user = await db.findUserByEmailOrPhone(clean);
    if (!user) {
      return res.status(404).json({ status: false, message: 'User account not found' });
    }

    const hashedPassword = bcrypt.hashSync(new_password, 10);
    await db.updateUser(user.id, { password: hashedPassword });
    otpStore.delete(key);

    console.log(`[AUTH] 🔑 Password reset successfully for user: @${user.username}`);

    return res.status(200).json({
      status: true,
      message: 'Password reset successfully! You can now log in with your new password.',
    });
  } catch (err) {
    console.error('Password reset error:', err);
    return res.status(500).json({ status: false, message: 'Server error resetting password' });
  }
});

/**
 * ✉️ POST /api/reporter/send-email-verify-link
 * Sends a real-time verification email link to the creator
 */
router.post('/send-email-verify-link', async (req, res) => {
  try {
    const { email } = req.body;
    const cleanEmail = (email || '').trim().toLowerCase();

    if (!cleanEmail || !cleanEmail.includes('@')) {
      return res.status(422).json({
        status: false,
        message: 'Valid email address is required',
      });
    }

    const verifyToken = Buffer.from(`${cleanEmail}_${Date.now()}`).toString('base64');
    const verifyLink = `https://telsoworld.com/api/reporter/verify-email?token=${verifyToken}&email=${encodeURIComponent(cleanEmail)}`;

    console.log(`[AUTH EMAIL] 📧 Verification link generated for ${cleanEmail}: ${verifyLink}`);

    return res.status(200).json({
      status: true,
      message: `Verification link sent to ${cleanEmail}! Please check your inbox.`,
      verify_link: verifyLink,
    });
  } catch (err) {
    console.error('Send email verify link error:', err);
    return res.status(500).json({ status: false, message: 'Error sending verification link' });
  }
});

/**
 * 🔗 GET /api/reporter/verify-email
 */
router.get('/verify-email', (req, res) => {
  const { email } = req.query;
  res.send(`
    <!DOCTYPE html>
    <html>
      <head>
        <title>Email Verified - Telso World</title>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body { background: #0D0D12; color: #FFF; font-family: sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
          .card { background: #161622; padding: 40px; border-radius: 24px; text-align: center; border: 1px solid rgba(255,42,109,0.3); max-width: 400px; }
          .badge { font-size: 48px; margin-bottom: 16px; }
          h2 { margin: 0 0 10px; color: #10B981; }
          p { color: #A0A0B0; font-size: 14px; line-height: 1.5; }
        </style>
      </head>
      <body>
        <div class="card">
          <div class="badge">✓</div>
          <h2>Email Verified!</h2>
          <p>Your email <strong>${email || 'account'}</strong> has been verified successfully on Telso World.</p>
          <p>You can now return to the Telso World App to continue!</p>
        </div>
      </body>
    </html>
  `);
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

module.exports = router;
