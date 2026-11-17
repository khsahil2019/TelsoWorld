import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:telsoworld/core/constants/api_endpoints.dart';
import 'package:telsoworld/core/constants/app_colors.dart';
import 'package:telsoworld/core/routes/app_routes.dart';

/// ---------------------------------------------------------------------------
/// 🔑 ForgotPasswordView
/// ---------------------------------------------------------------------------
/// Allows creators to reset their password using either their registered
/// Mobile number or Email address via OTP verification.
/// ---------------------------------------------------------------------------
class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final TextEditingController _identifierCtrl = TextEditingController();
  final TextEditingController _otpCtrl = TextEditingController();
  final TextEditingController _newPasswordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();

  bool _isOtpSent = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _otpCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
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

  Future<void> _sendResetOtp() async {
    final identifier = _identifierCtrl.text.trim();
    if (identifier.isEmpty) {
      _showSnackbar('Required', 'Please enter your registered Mobile number or Email.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/reporter/forgot-password/send-otp');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'identifier': identifier}),
      ).timeout(const Duration(seconds: 20));

      final data = jsonDecode(res.body);

      if (res.statusCode == 200 && data['status'] == true) {
        setState(() {
          _isOtpSent = true;
          if (data['otp'] != null) {
            _otpCtrl.text = data['otp'].toString();
          }
        });
        _showSnackbar('OTP Sent! 📨', data['message'] ?? 'Password reset OTP sent successfully.');
      } else {
        _showSnackbar('Error', data['message'] ?? 'Failed to send reset OTP.', isError: true);
      }
    } catch (e) {
      _showSnackbar('Connection Error', 'Could not reach server. Please check internet connection.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final identifier = _identifierCtrl.text.trim();
    final otp = _otpCtrl.text.trim();
    final newPassword = _newPasswordCtrl.text;
    final confirmPassword = _confirmPasswordCtrl.text;

    if (otp.isEmpty || otp.length < 4) {
      _showSnackbar('OTP Required', 'Please enter the 6-digit verification code.', isError: true);
      return;
    }

    if (newPassword.isEmpty || newPassword.length < 4) {
      _showSnackbar('Invalid Password', 'New password must be at least 4 characters.', isError: true);
      return;
    }

    if (newPassword != confirmPassword) {
      _showSnackbar('Mismatch', 'Passwords do not match. Please re-enter.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/reporter/forgot-password/reset');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'identifier': identifier,
          'otp': otp,
          'new_password': newPassword,
        }),
      ).timeout(const Duration(seconds: 20));

      final data = jsonDecode(res.body);

      if (res.statusCode == 200 && data['status'] == true) {
        Get.snackbar(
          'Password Reset! 🔑',
          'Your password has been updated. Please log in with your new password.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF161622),
          colorText: const Color(0xFF10B981),
          duration: const Duration(seconds: 3),
        );
        Get.offAllNamed(AppRoutes.login);
      } else {
        _showSnackbar('Reset Failed', data['message'] ?? 'Could not reset password.', isError: true);
      }
    } catch (e) {
      _showSnackbar('Connection Error', 'Server communication error. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
          'Reset Password',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Ambient Glow
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryPink.withOpacity(0.15),
                        border: Border.all(color: AppColors.primaryPink.withOpacity(0.3), width: 1.5),
                      ),
                      child: const Center(
                        child: Icon(Icons.lock_reset_rounded, color: AppColors.primaryPink, size: 36),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Center(
                    child: Text(
                      'Forgot Your Password?',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      _isOtpSent
                          ? 'Enter the 6-digit code received and choose your new password.'
                          : 'Enter your registered Mobile number or Email address to receive a reset code.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 28),

                  Container(
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
                        // Identifier Field
                        const Row(
                          children: [
                            Icon(Icons.person_pin_rounded, color: AppColors.primaryPink, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'Mobile Number or Email *',
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _identifierCtrl,
                          enabled: !_isOtpSent,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: 'Enter registered mobile or email',
                            hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
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
                          ),
                        ),
                        const SizedBox(height: 18),

                        if (!_isOtpSent) ...[
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryPink,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: _isLoading ? null : _sendResetOtp,
                              child: _isLoading
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text(
                                      'Send Reset Code',
                                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                        ] else ...[
                          // OTP Input
                          const Row(
                            children: [
                              Icon(Icons.pin_rounded, color: AppColors.primaryPink, size: 16),
                              SizedBox(width: 8),
                              Text(
                                'Enter 6-Digit OTP *',
                                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _otpCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 8),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              hintText: '••••••',
                              hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 8),
                              filled: true,
                              fillColor: const Color(0xFF1C1C28),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // New Password
                          const Row(
                            children: [
                              Icon(Icons.lock_outline_rounded, color: AppColors.primaryPink, size: 16),
                              SizedBox(width: 8),
                              Text(
                                'New Password *',
                                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _newPasswordCtrl,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Enter new password (min 4 chars)',
                              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                              filled: true,
                              fillColor: const Color(0xFF1C1C28),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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

                          // Confirm Password
                          const Row(
                            children: [
                              Icon(Icons.lock_rounded, color: AppColors.primaryPink, size: 16),
                              SizedBox(width: 8),
                              Text(
                                'Confirm New Password *',
                                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _confirmPasswordCtrl,
                            obscureText: _obscureConfirmPassword,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Re-enter new password',
                              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                              filled: true,
                              fillColor: const Color(0xFF1C1C28),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                  color: Colors.white54,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),

                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: _isLoading ? null : _resetPassword,
                              child: _isLoading
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text(
                                      'Reset Password & Login',
                                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  Center(
                    child: TextButton(
                      onPressed: () => Get.offNamed(AppRoutes.login),
                      child: const Text(
                        'Remembered password? Back to Login',
                        style: TextStyle(color: AppColors.primaryPink, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
