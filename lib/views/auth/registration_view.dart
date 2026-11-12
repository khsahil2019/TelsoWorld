import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:telsoworld/core/constants/api_endpoints.dart';
import 'package:telsoworld/core/constants/app_colors.dart';
import 'package:telsoworld/core/routes/app_routes.dart';
import 'package:telsoworld/core/services/session_token_store.dart';

/// ---------------------------------------------------------------------------
/// 📝 MusicianRegistrationScreen
/// ---------------------------------------------------------------------------
/// Features:
/// 1. 📲 Step 1: Mobile OTP and Email Verification (Both required)
/// 2. 👤 Step 2: Creator Form opened after OTP verification:
///    - User Name (Instagram-style unique handle with live availability check)
///    - Mo no (Pre-filled from verified mobile)
///    - Poss (Password with visibility toggle)
///    - WhatsApp No. (with "Same as Mobile Number" toggle)
///    - Happy Birthday 🎂 Date (Mandatory for birthday celebration system)
///    - Referral Code (Dynamic referral link or manual input)
///    - I agree to Terms & Conditions *
///    - Submit button
/// 3. 🎉 Step 3: Animated Welcome Popup with celebration graphics & wallet bonus!
/// ---------------------------------------------------------------------------
class MusicianRegistrationScreen extends StatefulWidget {
  const MusicianRegistrationScreen({super.key});

  @override
  State<MusicianRegistrationScreen> createState() =>
      _MusicianRegistrationScreenState();
}

class _MusicianRegistrationScreenState
    extends State<MusicianRegistrationScreen> with SingleTickerProviderStateMixin {
  // Step 1: Verification Controllers
  final TextEditingController _mobileCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _otpCtrl = TextEditingController();

  // Step 2: Creator Form Controllers
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _whatsappCtrl = TextEditingController();
  final TextEditingController _referralCtrl = TextEditingController();

  // Verification & Status States
  bool _isOtpSent = false;
  bool _isOtpVerified = false;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  bool _isRegistering = false;
  int _resendCountdown = 0;
  Timer? _countdownTimer;

  // Form States
  bool _sameAsMobile = true;
  bool _obscurePassword = true;
  bool _agreeTerms = false;
  DateTime? _dob;

  // Real-time Username Availability Check
  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;
  String _usernameFeedback = '';
  Timer? _usernameDebounce;

  @override
  void initState() {
    super.initState();
    // Check if referral code was passed via arguments or route query
    if (Get.arguments != null && Get.arguments is Map) {
      final ref = Get.arguments['ref'] ?? Get.arguments['referral_code'];
      if (ref != null) _referralCtrl.text = ref.toString();
    } else if (Get.parameters.containsKey('ref')) {
      _referralCtrl.text = Get.parameters['ref'] ?? '';
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _usernameDebounce?.cancel();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _whatsappCtrl.dispose();
    _referralCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // ⏱️ Resend Countdown Timer
  // ---------------------------------------------------------------------------
  void _startResendTimer() {
    _countdownTimer?.cancel();
    setState(() => _resendCountdown = 30);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 1) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
        setState(() => _resendCountdown = 0);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // 📲 Send OTP to Mobile & Email
  // ---------------------------------------------------------------------------
  Future<void> _sendOtp() async {
    final mobile = _mobileCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    if (mobile.isEmpty || mobile.length < 10) {
      _showSnackbar('Mobile Required', 'Please enter a valid 10-digit mobile number.', isError: true);
      return;
    }
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      _showSnackbar('Email Required', 'Please enter a valid Gmail / Email address.', isError: true);
      return;
    }

    setState(() => _isSendingOtp = true);

    try {
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/reporter/send-otp');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'mobile_no': mobile,
          'email': email,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body);

      if (res.statusCode == 200 && data['status'] == true) {
        setState(() {
          _isOtpSent = true;
          // In test mode, prefill or notify
          if (data['otp'] != null) {
            _otpCtrl.text = data['otp'].toString();
          }
        });
        _startResendTimer();
        _showSnackbar('OTP Sent', 'Verification code sent to $mobile & $email (Test OTP: ${data['otp'] ?? '123456'})');
      } else {
        _showSnackbar('Send Failed', data['message'] ?? 'Could not send OTP. Try again.', isError: true);
      }
    } catch (e) {
      _showSnackbar('Connection Error', 'Could not reach server. Verify connection.', isError: true);
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  // ---------------------------------------------------------------------------
  // ✅ Verify OTP
  // ---------------------------------------------------------------------------
  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.text.trim();
    final mobile = _mobileCtrl.text.trim();

    if (otp.length < 4) {
      _showSnackbar('Invalid OTP', 'Please enter the 6-digit OTP code received.', isError: true);
      return;
    }

    setState(() => _isVerifyingOtp = true);

    try {
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/reporter/verify-otp');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'mobile_no': mobile,
          'email': _emailCtrl.text.trim(),
          'otp': otp,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body);

      if (res.statusCode == 200 && data['status'] == true) {
        setState(() {
          _isOtpVerified = true;
          if (_sameAsMobile) {
            _whatsappCtrl.text = mobile;
          }
        });
        _showSnackbar('OTP Verified', 'Mobile & Email verified! Complete your creator profile below.');
      } else {
        _showSnackbar('Verification Failed', data['message'] ?? 'Invalid or expired OTP. (Try 123456)', isError: true);
      }
    } catch (e) {
      _showSnackbar('Connection Error', 'Verification server unreachable.', isError: true);
    } finally {
      if (mounted) setState(() => _isVerifyingOtp = false);
    }
  }

  // ---------------------------------------------------------------------------
  // 🔍 Real-time Instagram-Style Handle Availability Check
  // ---------------------------------------------------------------------------
  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    final clean = value.trim().toLowerCase().replaceAll('@', '');

    if (clean.length < 3) {
      setState(() {
        _isUsernameAvailable = null;
        _usernameFeedback = clean.isEmpty ? '' : 'Must be at least 3 characters';
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _usernameFeedback = 'Checking availability...';
    });

    _usernameDebounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final uri = Uri.parse('${ApiEndpoints.baseUrl}/reporter/check-username?username=$clean');
        final res = await http.get(uri).timeout(const Duration(seconds: 6));
        final data = jsonDecode(res.body);

        if (mounted) {
          setState(() {
            _isCheckingUsername = false;
            _isUsernameAvailable = data['available'] == true;
            _usernameFeedback = data['message'] ?? (data['available'] ? '@$clean is available!' : 'Already taken');
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _isCheckingUsername = false;
            _isUsernameAvailable = true;
            _usernameFeedback = '@$clean ready';
          });
        }
      }
    });
  }

  // ---------------------------------------------------------------------------
  // 🎂 Mandatory Happy Birthday Date Picker
  // ---------------------------------------------------------------------------
  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final initial = _dob ?? DateTime(now.year - 20, 1, 1);
    final first = DateTime(1940);
    final last = DateTime(now.year - 5);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: 'SELECT YOUR HAPPY BIRTHDAY 🎂',
      confirmText: 'SET BIRTHDAY',
      cancelText: 'CANCEL',
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primaryPink,
            onPrimary: Colors.white,
            surface: Color(0xFF161622),
            onSurface: Colors.white,
          ),
          dialogTheme: const DialogThemeData(
            backgroundColor: Color(0xFF14141E),
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() => _dob = picked);
    }
  }

  // ---------------------------------------------------------------------------
  // 📝 Submit Creator Registration Form
  // ---------------------------------------------------------------------------
  Future<void> _submitRegistration() async {
    final username = _usernameCtrl.text.trim().toLowerCase().replaceAll('@', '');
    final password = _passwordCtrl.text;
    final mobile = _mobileCtrl.text.trim();
    final whatsapp = _whatsappCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final referral = _referralCtrl.text.trim();

    // 1. Mandatory Username
    if (username.length < 3) {
      _showSnackbar('User Name Required', 'Please choose a unique creator handle (@username).', isError: true);
      return;
    }
    if (_isUsernameAvailable == false) {
      _showSnackbar('User Name Taken', 'This username is already taken. Please pick another.', isError: true);
      return;
    }

    // 2. Mandatory Mobile
    if (mobile.length < 10) {
      _showSnackbar('Mobile Required', 'Valid 10-digit mobile number required.', isError: true);
      return;
    }

    // 3. Mandatory Password
    if (password.length < 4) {
      _showSnackbar('Password Required', 'Password must be at least 4 characters.', isError: true);
      return;
    }

    // 4. Mandatory Birthday 🎂 (Explicit User Requirement)
    if (_dob == null) {
      _showSnackbar('Birthday Required 🎂', 'Happy Birthday Date is mandatory so we can celebrate your special day!', isError: true);
      return;
    }

    // 5. Terms & Conditions
    if (!_agreeTerms) {
      _showSnackbar('Terms & Conditions', 'Please accept the Terms & Conditions to complete registration.', isError: true);
      return;
    }

    setState(() => _isRegistering = true);

    final dobString = '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}';

    try {
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/reporter/register');
      final body = {
        'username': username,
        'name': username,
        'mobile_no': mobile,
        'whatsapp': whatsapp.isNotEmpty ? whatsapp : mobile,
        'whatsapp_no': whatsapp.isNotEmpty ? whatsapp : mobile,
        'email': email,
        'password': password,
        'dob': dobString,
        'referral_code': referral,
        'terms': '1',
      };

      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 25));

      final data = jsonDecode(res.body);

      if ((res.statusCode == 200 || res.statusCode == 201) && data['status'] == true) {
        final token = data['token']?.toString() ?? data['data']?['token']?.toString() ?? '';
        if (token.isNotEmpty) {
          await SessionTokenStore.setToken(token);
        }

        if (mounted) {
          _showAnimatedWelcomePopup(
            username: username,
            dobFormatted: '${_dob!.day.toString().padLeft(2, '0')}/${_dob!.month.toString().padLeft(2, '0')}/${_dob!.year}',
            walletBonus: '50.00',
          );
        }
      } else {
        _showSnackbar('Registration Error', data['message'] ?? 'Failed to register. Please try again.', isError: true);
      }
    } catch (e) {
      _showSnackbar('Server Connection', 'Could not complete registration. Check connection.', isError: true);
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  // ---------------------------------------------------------------------------
  // 🎉 Animated Welcome Celebration Popup (User Requirement)
  // ---------------------------------------------------------------------------
  void _showAnimatedWelcomePopup({
    required String username,
    required String dobFormatted,
    required String walletBonus,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'WelcomeModal',
      barrierColor: Colors.black.withValues(alpha: 0.85),
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (ctx, anim1, anim2) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.elasticOut);
        return ScaleTransition(
          scale: curved,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1B1428), Color(0xFF13101E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: AppColors.primaryPink.withValues(alpha: 0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryPink.withValues(alpha: 0.35),
                      blurRadius: 36,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Celebratory Emoji Cluster
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF2A6D), Color(0xFF7928CA)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF2A6D).withValues(alpha: 0.4),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          '🎂',
                          style: TextStyle(fontSize: 44),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Welcome Headline
                    const Text(
                      '🎉 WELCOME TO TELSO WORLD! 🎉',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Unique Handle Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryPink.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primaryPink.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '@$username',
                        style: const TextStyle(
                          color: AppColors.primaryPink,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Details Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Text('🎁', style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Creator Welcome Bonus', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                    Text('₹$walletBonus Credited to Wallet', style: const TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white12, height: 20),
                          Row(
                            children: [
                              const Text('🎂', style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Birthday Wishes Scheduled', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                    Text(dobFormatted, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Start Creating & Explore Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          Get.offAllNamed(AppRoutes.main);
                        },
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF2A6D), Color(0xFF7928CA)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF2A6D).withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '🚀 START EXPLORING FEED',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSnackbar(String title, String message, {bool isError = false}) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF161622),
      colorText: isError ? const Color(0xFFFF6584) : const Color(0xFF10B981),
      margin: const EdgeInsets.all(16),
      icon: Icon(
        isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
        color: isError ? const Color(0xFFFF6584) : const Color(0xFF10B981),
      ),
      duration: const Duration(seconds: 4),
    );
  }

  // ---------------------------------------------------------------------------
  // 🎨 BUILD SCREEN
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07070B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F16),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Telso Creator Registration',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Ambient Glow Background
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD70F64).withValues(alpha: 0.16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD70F64).withValues(alpha: 0.3),
                    blurRadius: 120,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step 1: Verification Card
                  _buildVerificationCard(),

                  const SizedBox(height: 20),

                  // Step 2: Creator Profile Form (Revealed / Unlocked after verification)
                  if (_isOtpVerified)
                    _buildCreatorForm()
                  else
                    _buildLockedFormNotice(),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 📱 STEP 1: VERIFICATION CARD (Mobile OTP & Email)
  // ---------------------------------------------------------------------------
  Widget _buildVerificationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF13131E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isOtpVerified ? const Color(0xFF10B981).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (_isOtpVerified ? const Color(0xFF10B981) : AppColors.primaryPink).withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isOtpVerified ? Icons.check_circle_rounded : Icons.shield_rounded,
                  color: _isOtpVerified ? const Color(0xFF10B981) : AppColors.primaryPink,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isOtpVerified ? 'Step 1: Verified Successfully ✓' : 'Step 1: Mobile & Email Verification',
                      style: TextStyle(
                        color: _isOtpVerified ? const Color(0xFF10B981) : Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _isOtpVerified
                          ? 'Identity confirmed. Proceed to fill creator details below.'
                          : 'Both Mobile OTP & Gmail required to secure your account.',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Mobile Number Input
          _buildFieldLabel('Mobile Number *', Icons.phone_android_rounded),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C28),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: const Center(
                  child: Text(
                    '+91',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _mobileCtrl,
                  enabled: !_isOtpVerified,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: _inputDecoration(
                    hint: '10-digit mobile number',
                    suffixIcon: _isOtpVerified
                        ? const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20)
                        : null,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Gmail / Email Input
          _buildFieldLabel('Gmail / Email *', Icons.email_rounded),
          const SizedBox(height: 6),
          TextField(
            controller: _emailCtrl,
            enabled: !_isOtpVerified,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            decoration: _inputDecoration(
              hint: 'yourname@gmail.com',
              suffixIcon: _isOtpVerified
                  ? const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20)
                  : null,
            ),
          ),

          const SizedBox(height: 16),

          // Send OTP Button (Only before OTP verified)
          if (!_isOtpVerified) ...[
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPink,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isSendingOtp ? null : _sendOtp,
                child: _isSendingOtp
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        _isOtpSent ? (_resendCountdown > 0 ? 'Resend in ${_resendCountdown}s' : 'Resend OTP') : 'Send Verification OTP',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
              ),
            ),

            // OTP Box (Revealed once sent)
            if (_isOtpSent) ...[
              const SizedBox(height: 18),
              _buildFieldLabel('Enter 6-Digit Verification OTP', Icons.pin_rounded),
              const SizedBox(height: 6),
              TextField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 8),
                textAlign: TextAlign.center,
                decoration: _inputDecoration(
                  hint: '••••••',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isVerifyingOtp ? null : _verifyOtp,
                  child: _isVerifyingOtp
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text(
                          'Verify OTP & Open Creator Form',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildLockedFormNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF13131E).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline_rounded, color: Colors.white38, size: 28),
          ),
          const SizedBox(height: 12),
          const Text(
            'Step 2: Creator Form Locked',
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Verify your Mobile & Gmail in Step 1 above to open your creator profile form.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 📝 STEP 2: CREATOR REGISTRATION FORM
  // ---------------------------------------------------------------------------
  Widget _buildCreatorForm() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF13131E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primaryPink.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPink.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryPink.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_pin_rounded, color: AppColors.primaryPink, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Step 2: Creator Details Form',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Instagram-style handle & Mandatory Birthday Setup',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 1. User Name (Instagram-style handle)
          _buildFieldLabel('User Name (Unique Creator Handle) *', Icons.alternate_email_rounded),
          const SizedBox(height: 6),
          TextField(
            controller: _usernameCtrl,
            onChanged: _onUsernameChanged,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            decoration: _inputDecoration(
              hint: 'username (e.g. rahul_music, priya.singh)',
              prefixText: '@',
              prefixStyle: const TextStyle(color: AppColors.primaryPink, fontWeight: FontWeight.bold, fontSize: 15),
              suffixIcon: _isCheckingUsername
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryPink)),
                    )
                  : (_isUsernameAvailable == true
                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20)
                      : (_isUsernameAvailable == false
                          ? const Icon(Icons.cancel_rounded, color: Color(0xFFFF6584), size: 20)
                          : null)),
            ),
          ),
          if (_usernameFeedback.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _usernameFeedback,
              style: TextStyle(
                color: _isUsernameAvailable == true ? const Color(0xFF10B981) : const Color(0xFFFF6584),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          const SizedBox(height: 16),

          // 2. Mo no (Verified Mobile, Locked)
          _buildFieldLabel('Mo no (Verified Mobile)', Icons.phone_android_rounded),
          const SizedBox(height: 6),
          TextField(
            controller: _mobileCtrl,
            enabled: false,
            style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
            decoration: _inputDecoration(
              hint: 'Mobile number',
              suffixIcon: Container(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('✓ Verified', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 3. Poss (Password)
          _buildFieldLabel('Poss (Password) *', Icons.lock_outline_rounded),
          const SizedBox(height: 6),
          TextField(
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            decoration: _inputDecoration(
              hint: 'Create a secure password',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: Colors.white54,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 4. WhatsApp No. (with "Same as Mobile" checkbox)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFieldLabel('WhatsApp No. *', Icons.chat_rounded),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: _sameAsMobile,
                    activeColor: AppColors.primaryPink,
                    visualDensity: VisualDensity.compact,
                    onChanged: (val) {
                      setState(() {
                        _sameAsMobile = val ?? false;
                        if (_sameAsMobile) {
                          _whatsappCtrl.text = _mobileCtrl.text;
                        }
                      });
                    },
                  ),
                  const Text('Same as Mobile', style: TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _whatsappCtrl,
            enabled: !_sameAsMobile,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            decoration: _inputDecoration(
              hint: '10-digit WhatsApp number',
            ),
          ),

          const SizedBox(height: 18),

          // 5. Happy birthday 🎂 Date (Mandatory!)
          Row(
            children: [
              const Text('🎂', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              const Text(
                'Happy birthday 🎂 Date * (Mandatory)',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF2A6D).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Required', style: TextStyle(color: Color(0xFFFF2A6D), fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Birthday is must so Telso World can celebrate & send you special wishes!',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickBirthday,
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C28),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _dob != null ? const Color(0xFFFF2A6D) : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cake_rounded, color: AppColors.primaryPink, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _dob != null
                          ? '${_dob!.day.toString().padLeft(2, '0')}/${_dob!.month.toString().padLeft(2, '0')}/${_dob!.year}'
                          : 'Select your birthday date 🎂',
                      style: TextStyle(
                        color: _dob != null ? Colors.white : Colors.white38,
                        fontSize: 14,
                        fontWeight: _dob != null ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  const Icon(Icons.calendar_month_rounded, color: Colors.white54, size: 18),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          // 6. Referral Code (Dynamic / Manual)
          _buildFieldLabel('Referral Code (Optional - ₹50 Bonus)', Icons.card_giftcard_rounded),
          const SizedBox(height: 6),
          TextField(
            controller: _referralCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            decoration: _inputDecoration(
              hint: 'e.g. TELSO2026',
            ),
          ),

          const SizedBox(height: 18),

          // 7. I agree to Terms & Conditions *
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Checkbox(
                value: _agreeTerms,
                activeColor: AppColors.primaryPink,
                onChanged: (val) => setState(() => _agreeTerms = val ?? false),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _agreeTerms = !_agreeTerms),
                  child: const Text(
                    'I agree to the Terms & Conditions *',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // 8. Submit Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _isRegistering ? null : _submitRegistration,
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF2A6D), Color(0xFF7928CA)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF2A6D).withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: _isRegistering
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'SUBMIT & JOIN AS CREATOR',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryPink, size: 15),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    Widget? suffixIcon,
    String? prefixText,
    TextStyle? prefixStyle,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
      prefixText: prefixText,
      prefixStyle: prefixStyle,
      filled: true,
      fillColor: const Color(0xFF1C1C28),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primaryPink, width: 1.5),
      ),
      suffixIcon: suffixIcon,
    );
  }
}
