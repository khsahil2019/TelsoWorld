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
/// 📝 MusicianRegistrationScreen (Step-by-Step Guided Creator Registration)
/// ---------------------------------------------------------------------------
/// Step-by-Step Registration Flow:
/// 1. 📱 Step 1: Mobile Number Input
/// 2. 🔢 Step 2: 6-Digit OTP Verification Screen
/// 3. 👤 Step 3: Creator Details (Username @handle, Password, WhatsApp, Email Verification Link)
/// 4. 🎂 Step 4: Birthday Date & Referral (Mandatory birthday, Optional Referral, Terms)
/// 5. 🎉 Animated Welcome Modal with ₹50 bonus & Explore button
/// ---------------------------------------------------------------------------
class MusicianRegistrationScreen extends StatefulWidget {
  const MusicianRegistrationScreen({super.key});

  @override
  State<MusicianRegistrationScreen> createState() =>
      _MusicianRegistrationScreenState();
}

class _MusicianRegistrationScreenState
    extends State<MusicianRegistrationScreen> {
  // Current Active Wizard Step:
  // 0 -> Enter Mobile Number
  // 1 -> Enter OTP Verification
  // 2 -> Creator Details (Username, Password, WhatsApp, Email with Verify Link)
  // 3 -> Birthday Date, Referral Code & Terms Agreement
  int _wizardStep = 0;

  // Controllers
  final TextEditingController _mobileCtrl = TextEditingController();
  final TextEditingController _otpCtrl = TextEditingController();
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _whatsappCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _referralCtrl = TextEditingController();

  // Verification & Processing Flags
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  bool _isOtpVerified = false;
  bool _isSendingEmailLink = false;
  bool _isEmailLinkSent = false;
  bool _isRegistering = false;
  int _resendCountdown = 0;
  Timer? _countdownTimer;

  // Form State Flags
  bool _sameAsMobile = true;
  bool _obscurePassword = true;
  bool _hasReferral = false;
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
    // Pre-fill referral code if passed via route parameters/arguments
    if (Get.arguments != null && Get.arguments is Map) {
      final ref = Get.arguments['ref'] ?? Get.arguments['referral_code'];
      if (ref != null) {
        _referralCtrl.text = ref.toString();
        _hasReferral = true;
      }
    } else if (Get.parameters.containsKey('ref') &&
        Get.parameters['ref']!.isNotEmpty) {
      _referralCtrl.text = Get.parameters['ref']!;
      _hasReferral = true;
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _usernameDebounce?.cancel();
    _mobileCtrl.dispose();
    _otpCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _whatsappCtrl.dispose();
    _emailCtrl.dispose();
    _referralCtrl.dispose();
    super.dispose();
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
  // 📲 STEP 1: Send OTP to Mobile Number
  // ---------------------------------------------------------------------------
  Future<void> _sendMobileOtp() async {
    final mobile = _mobileCtrl.text.trim();

    if (mobile.isEmpty || mobile.length < 10) {
      _showSnackbar(
        'Invalid Mobile',
        'Please enter a valid 10-digit mobile number.',
        isError: true,
      );
      return;
    }

    setState(() => _isSendingOtp = true);

    try {
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/reporter/send-otp');
      final res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'mobile_no': mobile}),
          )
          .timeout(const Duration(seconds: 20));

      final data = jsonDecode(res.body);

      if (res.statusCode == 200 && data['status'] == true) {
        setState(() {
          _wizardStep = 1; // Transition immediately to Step 2: OTP Screen!
          if (data['otp'] != null) {
            _otpCtrl.text = data['otp'].toString();
          }
        });
        _startResendTimer();
        _showSnackbar(
          'OTP Sent! 📨',
          '6-digit verification code sent to +91 $mobile',
        );
      } else {
        _showSnackbar(
          'Failed',
          data['message'] ?? 'Could not send OTP.',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackbar(
        'Connection Error',
        'Please check your internet connection.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  // ---------------------------------------------------------------------------
  // 🔢 STEP 2: Verify 6-Digit OTP
  // ---------------------------------------------------------------------------
  Future<void> _verifyOtp() async {
    final mobile = _mobileCtrl.text.trim();
    final otp = _otpCtrl.text.trim();

    if (otp.isEmpty || otp.length < 4) {
      _showSnackbar(
        'Enter Code',
        'Please enter the 6-digit OTP code received.',
        isError: true,
      );
      return;
    }

    setState(() => _isVerifyingOtp = true);

    try {
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/reporter/verify-otp');
      final res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'mobile_no': mobile, 'otp': otp}),
          )
          .timeout(const Duration(seconds: 20));

      final data = jsonDecode(res.body);

      if (res.statusCode == 200 && data['status'] == true) {
        setState(() {
          _isOtpVerified = true;
          _wizardStep =
              2; // Transition immediately to Step 3: Registration Data Page!
          if (_sameAsMobile) {
            _whatsappCtrl.text = mobile;
          }
        });
        _showSnackbar(
          'Mobile Verified! ✨',
          'Mobile number verified. Now enter your profile details.',
        );
      } else {
        _showSnackbar(
          'Verification Failed',
          data['message'] ?? 'Invalid OTP code entered.',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackbar(
        'Error',
        'Could not verify code. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isVerifyingOtp = false);
    }
  }

  // ---------------------------------------------------------------------------
  // 🔍 Check Username Availability in Real-Time
  // ---------------------------------------------------------------------------
  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    final clean = value.trim().toLowerCase().replaceAll('@', '');

    if (clean.length < 3) {
      setState(() {
        _isUsernameAvailable = null;
        _usernameFeedback = clean.isEmpty
            ? ''
            : 'Username must be at least 3 characters.';
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _usernameFeedback = 'Checking availability...';
    });

    _usernameDebounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final uri = Uri.parse(
          '${ApiEndpoints.baseUrl}/reporter/check-username?username=$clean',
        );
        final res = await http.get(uri).timeout(const Duration(seconds: 10));
        final data = jsonDecode(res.body);

        if (mounted) {
          setState(() {
            _isCheckingUsername = false;
            _isUsernameAvailable = data['available'] == true;
            _usernameFeedback =
                data['message'] ??
                (data['available'] == true
                    ? '✓ @$clean is available!'
                    : '✗ Already taken');
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _isCheckingUsername = false;
            _usernameFeedback = 'Could not verify username.';
          });
        }
      }
    });
  }

  // ---------------------------------------------------------------------------
  // ✉️ Send Email Verification Link
  // ---------------------------------------------------------------------------
  Future<void> _sendEmailVerificationLink() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnackbar(
        'Invalid Email',
        'Please enter a valid email address first.',
        isError: true,
      );
      return;
    }

    setState(() => _isSendingEmailLink = true);

    try {
      final uri = Uri.parse(
        '${ApiEndpoints.baseUrl}/reporter/send-email-verify-link',
      );
      final res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 20));

      final data = jsonDecode(res.body);

      if (res.statusCode == 200 && data['status'] == true) {
        setState(() => _isEmailLinkSent = true);
        _showSnackbar(
          'Verification Link Sent! ✉️',
          data['message'] ?? 'Verification link sent to $email.',
        );
      } else {
        _showSnackbar(
          'Error',
          data['message'] ?? 'Could not send verification email.',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackbar(
        'Connection Error',
        'Could not reach server to send email link.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isSendingEmailLink = false);
    }
  }

  // ---------------------------------------------------------------------------
  // 🎂 Pick Happy Birthday Date
  // ---------------------------------------------------------------------------
  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final initialDate = _dob ?? DateTime(now.year - 18, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year - 10, now.month, now.day),
      helpText: 'SELECT YOUR HAPPY BIRTHDAY 🎂',
      confirmText: 'SET BIRTHDAY',
      cancelText: 'CANCEL',
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primaryPink,
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E2C),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF181824),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _dob = picked);
    }
  }

  // ---------------------------------------------------------------------------
  // 🚀 Final Registration Submission
  // ---------------------------------------------------------------------------
  Future<void> _submitRegistration() async {
    final username = _usernameCtrl.text.trim().toLowerCase().replaceAll(
      '@',
      '',
    );
    final password = _passwordCtrl.text;
    final mobile = _mobileCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final whatsapp = _whatsappCtrl.text.trim();
    final referral = _hasReferral ? _referralCtrl.text.trim() : '';

    if (_dob == null) {
      _showSnackbar(
        'Birthday Mandatory 🎂',
        'Happy Birthday Date is required so we can celebrate your special day!',
        isError: true,
      );
      return;
    }

    if (!_agreeTerms) {
      _showSnackbar(
        'Terms Required',
        'Please accept the Terms & Conditions to complete registration.',
        isError: true,
      );
      return;
    }

    setState(() => _isRegistering = true);

    final dobString =
        '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}';

    try {
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/reporter/register');
      final body = {
        'username': username,
        'name': username,
        'mobile_no': mobile,
        'whatsapp': whatsapp.isNotEmpty ? whatsapp : mobile,
        'whatsapp_no': whatsapp.isNotEmpty ? whatsapp : mobile,
        'email': email.isNotEmpty ? email : '$username@telsoworld.com',
        'password': password,
        'dob': dobString,
        'referral_code': referral,
        'terms': '1',
      };

      final res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 25));

      final data = jsonDecode(res.body);

      if ((res.statusCode == 200 || res.statusCode == 201) &&
          data['status'] == true) {
        final token =
            data['token']?.toString() ??
            data['data']?['token']?.toString() ??
            '';
        if (token.isNotEmpty) {
          await SessionTokenStore.setToken(token);
        }

        if (mounted) {
          _showAnimatedWelcomePopup(
            username: username,
            dobFormatted:
                '${_dob!.day.toString().padLeft(2, '0')}/${_dob!.month.toString().padLeft(2, '0')}/${_dob!.year}',
            walletBonus: '50.00',
          );
        }
      } else {
        _showSnackbar(
          'Registration Error',
          data['message'] ?? 'Failed to register. Please try again.',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackbar(
        'Server Connection',
        'Could not complete registration. Check your connection.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  // ---------------------------------------------------------------------------
  // 🎉 Animated Welcome Celebration Modal
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
      barrierColor: Colors.black.withOpacity(0.85),
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
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
                  border: Border.all(
                    color: AppColors.primaryPink.withOpacity(0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryPink.withOpacity(0.35),
                      blurRadius: 40,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF2A6D), Color(0xFFFF8008)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF2A6D).withOpacity(0.5),
                            blurRadius: 24,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text('🎉', style: TextStyle(fontSize: 40)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Welcome to Telso World!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '@$username',
                      style: const TextStyle(
                        color: AppColors.primaryPink,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white10),
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
                                    const Text(
                                      'Joining Welcome Bonus',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      '₹$walletBonus Credited to Wallet',
                                      style: const TextStyle(
                                        color: Color(0xFF10B981),
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
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
                                    const Text(
                                      'Birthday Wishes Scheduled',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      dobFormatted,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
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
                                color: const Color(
                                  0xFFFF2A6D,
                                ).withOpacity(0.35),
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
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
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

  // ---------------------------------------------------------------------------
  // 🧭 Clean & Modern Wizard Progress Indicator Header
  // ---------------------------------------------------------------------------
  Widget _buildStepIndicator() {
    final stepNames = ['Mobile', 'Verify', 'Profile', 'Birthday'];
    final currentTitle = stepNames[_wizardStep.clamp(0, 3)];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF13131E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${_wizardStep + 1} of 4: $currentTitle',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryPink.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${((_wizardStep + 1) * 25)}%',
                  style: const TextStyle(
                    color: AppColors.primaryPink,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 4-segment progress bar with step numbers
          Row(
            children: List.generate(4, (index) {
              final isCompleted = index < _wizardStep;
              final isCurrent = index == _wizardStep;

              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                    left: index == 0 ? 0 : 3,
                    right: index == 3 ? 0 : 3,
                  ),
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: isCurrent
                        ? const LinearGradient(
                            colors: [Color(0xFFFF2A6D), Color(0xFFFF8008)],
                          )
                        : null,
                    color: isCompleted
                        ? const Color(0xFF10B981)
                        : (isCurrent ? null : const Color(0xFF232336)),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 📱 STEP 1: MOBILE NUMBER SCREEN
  // ---------------------------------------------------------------------------
  Widget _buildStep1Mobile() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF13131E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryPink.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.phone_iphone_rounded,
                  color: AppColors.primaryPink,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Step 1: Enter Mobile Number',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'We will send a 6-digit verification code to this number',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          _buildFieldLabel('Mobile Number *', Icons.phone_rounded),
          const SizedBox(height: 8),
          TextField(
            controller: _mobileCtrl,
            keyboardType: TextInputType.phone,
            autofocus: true,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
            decoration: _inputDecoration(
              hint: '10-digit mobile number',
              prefixText: '+91 ',
              prefixStyle: const TextStyle(
                color: AppColors.primaryPink,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _isSendingOtp ? null : _sendMobileOtp,
              child: _isSendingOtp
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Send OTP Code',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🔢 STEP 2: OTP VERIFICATION SCREEN
  // ---------------------------------------------------------------------------
  Widget _buildStep2Otp() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF13131E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primaryPink.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: Color(0xFF10B981),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Step 2: Enter OTP Code',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Code sent to +91 ${_mobileCtrl.text}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _wizardStep = 0),
                child: const Text(
                  'Edit',
                  style: TextStyle(
                    color: AppColors.primaryPink,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          _buildFieldLabel('Enter 6-Digit OTP *', Icons.pin_rounded),
          const SizedBox(height: 8),
          TextField(
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
            textAlign: TextAlign.center,
            decoration: _inputDecoration(hint: '••••••'),
          ),
          const SizedBox(height: 12),

          // Resend Timer Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _resendCountdown > 0
                    ? 'Resend in ${_resendCountdown}s'
                    : 'Didn\'t receive code?',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              TextButton(
                onPressed: _resendCountdown > 0 ? null : _sendMobileOtp,
                child: Text(
                  'Resend OTP',
                  style: TextStyle(
                    color: _resendCountdown > 0
                        ? Colors.white24
                        : AppColors.primaryPink,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _isVerifyingOtp ? null : _verifyOtp,
              child: _isVerifyingOtp
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Verify OTP & Continue',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 👤 STEP 3: CREATOR PROFILE DETAILS & EMAIL VERIFY LINK
  // ---------------------------------------------------------------------------
  Widget _buildStep3Details() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF13131E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryPink.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.badge_rounded,
                  color: AppColors.primaryPink,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Step 3: Creator Profile Data',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Choose your unique @handle and password',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 1. User Name (Instagram @handle)
          _buildFieldLabel(
            'User Name (Instagram @handle) *',
            Icons.alternate_email_rounded,
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _usernameCtrl,
            onChanged: _onUsernameChanged,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            decoration: _inputDecoration(
              hint: 'e.g. rahul_beats, priya_music',
              prefixText: '@',
              prefixStyle: const TextStyle(
                color: AppColors.primaryPink,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              suffixIcon: _isCheckingUsername
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryPink,
                        ),
                      ),
                    )
                  : (_isUsernameAvailable == true
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF10B981),
                            size: 20,
                          )
                        : (_isUsernameAvailable == false
                              ? const Icon(
                                  Icons.cancel_rounded,
                                  color: Color(0xFFFF6584),
                                  size: 20,
                                )
                              : null)),
            ),
          ),
          if (_usernameFeedback.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _usernameFeedback,
              style: TextStyle(
                color: _isUsernameAvailable == true
                    ? const Color(0xFF10B981)
                    : const Color(0xFFFF6584),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          const SizedBox(height: 16),

          // 2. Mo no (Verified Mobile, Locked)
          _buildFieldLabel(
            'Mo no (Verified Mobile)',
            Icons.phone_android_rounded,
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _mobileCtrl,
            enabled: false,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            decoration: _inputDecoration(
              hint: 'Mobile number',
              prefixText: '+91 ',
              prefixStyle: const TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              suffixIcon: Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (_isOtpVerified ? const Color(0xFF10B981) : Colors.orangeAccent).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _isOtpVerified ? '✓ Verified' : 'Pending',
                  style: TextStyle(
                    color: _isOtpVerified ? const Color(0xFF10B981) : Colors.orangeAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            decoration: _inputDecoration(
              hint: 'Minimum 4 characters',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: Colors.white54,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 4. WhatsApp No. (with "Same as Mobile")
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
                  const Text(
                    'Same as Mobile',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            decoration: _inputDecoration(hint: '10-digit WhatsApp number'),
          ),

          const SizedBox(height: 16),

          // 5. Email with Verification Link Trigger
          _buildFieldLabel(
            'Email Address (Verification Link)',
            Icons.email_rounded,
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            decoration: _inputDecoration(
              hint: 'e.g. yourname@gmail.com',
              suffixIcon: IconButton(
                icon: _isSendingEmailLink
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryPink,
                        ),
                      )
                    : Icon(
                        _isEmailLinkSent
                            ? Icons.mark_email_read_rounded
                            : Icons.send_rounded,
                        color: _isEmailLinkSent
                            ? const Color(0xFF10B981)
                            : AppColors.primaryPink,
                        size: 20,
                      ),
                tooltip: 'Send Verification Link',
                onPressed: _isSendingEmailLink
                    ? null
                    : _sendEmailVerificationLink,
              ),
            ),
          ),
          if (_isEmailLinkSent) ...[
            const SizedBox(height: 4),
            const Text(
              '✓ Verification link sent to your email inbox.',
              style: TextStyle(
                color: Color(0xFF10B981),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Continue to Step 4 Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                final uname = _usernameCtrl.text.trim();
                final pass = _passwordCtrl.text;
                if (uname.isEmpty || uname.length < 3) {
                  _showSnackbar(
                    'Username Required',
                    'Please enter a valid Instagram handle.',
                    isError: true,
                  );
                  return;
                }
                if (pass.isEmpty || pass.length < 4) {
                  _showSnackbar(
                    'Password Required',
                    'Password must be at least 4 characters.',
                    isError: true,
                  );
                  return;
                }
                setState(() => _wizardStep = 3);
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Next: Birthday & Rewards',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🎂 STEP 4: BIRTHDAY DATE & REFERRAL (YES/NO) & TERMS
  // ---------------------------------------------------------------------------
  Widget _buildStep4BirthdayAndReferral() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF13131E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryPink.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryPink.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cake_rounded,
                  color: AppColors.primaryPink,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Birthday & Referral',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 1. Birthday Date Field
          _buildFieldLabel('Birthday *', Icons.calendar_today_rounded),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickBirthday,
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C28),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _dob != null
                      ? AppColors.primaryPink
                      : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.cake_rounded,
                    color: _dob != null
                        ? AppColors.primaryPink
                        : Colors.white38,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _dob != null
                          ? '${_dob!.day.toString().padLeft(2, '0')}/${_dob!.month.toString().padLeft(2, '0')}/${_dob!.year}'
                          : 'Select your birthday',
                      style: TextStyle(
                        color: _dob != null ? Colors.white : Colors.white38,
                        fontSize: 14,
                        fontWeight: _dob != null
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.calendar_month_rounded,
                    color: Colors.white38,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 2. Referral Code Decision (Yes / No)
          const Text(
            'Have a Referral Code?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _hasReferral = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !_hasReferral
                          ? AppColors.primaryPink.withOpacity(0.2)
                          : const Color(0xFF1C1C28),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: !_hasReferral
                            ? AppColors.primaryPink
                            : Colors.white10,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'No',
                        style: TextStyle(
                          color: !_hasReferral ? Colors.white : Colors.white54,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _hasReferral = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _hasReferral
                          ? const Color(0xFF10B981).withOpacity(0.2)
                          : const Color(0xFF1C1C28),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _hasReferral
                            ? const Color(0xFF10B981)
                            : Colors.white10,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Yes (Bonus)',
                        style: TextStyle(
                          color: _hasReferral
                              ? const Color(0xFF10B981)
                              : Colors.white54,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (_hasReferral) ...[
            const SizedBox(height: 14),
            _buildFieldLabel(
              'Referral Code (Optional)',
              Icons.card_giftcard_rounded,
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _referralCtrl,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              decoration: _inputDecoration(hint: 'e.g. TELSO2026'),
            ),
          ],

          const SizedBox(height: 18),

          // 3. Terms Checkbox
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: 24,
                width: 24,
                child: Checkbox(
                  value: _agreeTerms,
                  activeColor: AppColors.primaryPink,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (val) =>
                      setState(() => _agreeTerms = val ?? false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _agreeTerms = !_agreeTerms),
                  child: const Text(
                    'I agree to the Terms & Privacy Policy',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 4. Complete Registration Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _isRegistering ? null : _submitRegistration,
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF2A6D), Color(0xFF7928CA)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF2A6D).withOpacity(0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: _isRegistering
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'COMPLETE REGISTRATION',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
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

  // ---------------------------------------------------------------------------
  // 🎨 HELPER LABELS & INPUT DECORATION
  // ---------------------------------------------------------------------------
  Widget _buildFieldLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryPink, size: 15),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
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
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primaryPink, width: 1.5),
      ),
      suffixIcon: suffixIcon,
    );
  }

  // ---------------------------------------------------------------------------
  // 🎨 MAIN BUILD METHOD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07070B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F16),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () {
            if (_wizardStep > 0) {
              setState(() => _wizardStep--);
            } else {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                Get.offAllNamed(AppRoutes.login);
              }
            }
          },
        ),
        title: const Text(
          'Creator Registration',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
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
                color: const Color(0xFFD70F64).withOpacity(0.16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD70F64).withOpacity(0.3),
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
                  // Step Indicator Header
                  _buildStepIndicator(),

                  // Wizard Body Switcher
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _wizardStep == 0
                        ? _buildStep1Mobile()
                        : (_wizardStep == 1
                              ? _buildStep2Otp()
                              : (_wizardStep == 2
                                    ? _buildStep3Details()
                                    : _buildStep4BirthdayAndReferral())),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
