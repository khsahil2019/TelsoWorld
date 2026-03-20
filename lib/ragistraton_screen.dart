import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:telsoworld/app_routes.dart';
import 'package:telsoworld/session_token_store.dart';

const kPink = Color(0xFFD70F64);
const kFieldBg = Color(0xFFFAF0F4);

class MusicianRegistrationScreen extends StatefulWidget {
  const MusicianRegistrationScreen({super.key});

  @override
  State<MusicianRegistrationScreen> createState() =>
      _MusicianRegistrationScreenState();
}

class _MusicianRegistrationScreenState
    extends State<MusicianRegistrationScreen> {
  // ── Form state ──────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final Logger _logger = Logger();

  bool _agreeTerms = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  String? _selectedState;
  String? _selectedDistrict;
  DateTime? _dob;

  // ── Controllers  (key → API field name) ─────────────────
  final _schoolNameCtrl = TextEditingController(); // school_name
  final _mobileCtrl = TextEditingController(); // mobile_no
  final _whatsappCtrl = TextEditingController(); // whatsapp
  final _emailCtrl = TextEditingController(); // email
  final _villageCtrl = TextEditingController(); // village
  final _pincodeCtrl = TextEditingController(); // pincode
  final _usernameCtrl = TextEditingController(); // username
  final _passwordCtrl = TextEditingController(); // password
  final _referralCtrl = TextEditingController(); // referral_code

  // ── Static data ─────────────────────────────────────────
  final _states = [
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chhattisgarh',
    'Delhi',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
  ];

  final _districtsByState = <String, List<String>>{
    'Rajasthan': ['Jodhpur', 'Jaipur', 'Udaipur', 'Kota', 'Ajmer', 'Bikaner'],
    'Gujarat': ['Surat', 'Ahmedabad', 'Vadodara', 'Rajkot'],
    'Maharashtra': ['Mumbai', 'Pune', 'Nashik', 'Nagpur'],
    'Delhi': ['New Delhi', 'South Delhi', 'North Delhi', 'East Delhi'],
    'Karnataka': ['Bengaluru', 'Mysuru', 'Hubballi', 'Mangaluru'],
    'Tamil Nadu': ['Chennai', 'Coimbatore', 'Madurai', 'Salem'],
    'Uttar Pradesh': ['Lucknow', 'Agra', 'Varanasi', 'Kanpur'],
    'West Bengal': ['Kolkata', 'Howrah', 'Siliguri', 'Durgapur'],
  };

  List<String> get _districts =>
      _selectedState != null ? (_districtsByState[_selectedState!] ?? []) : [];

  String? _extractApiMessage(String responseBody) {
    if (responseBody.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message']?.toString().trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      // Ignore invalid JSON and fall back to generic messaging.
    }

    return null;
  }

  String _messageForNetworkError(Object error) {
    if (error is TimeoutException) {
      return 'Server is taking too long to respond. Please try again.';
    }
    if (error is SocketException) {
      return 'Unable to reach the server. Please check your internet connection and try again.';
    }
    if (error is HandshakeException) {
      return 'Secure connection to the server failed. Please try again in a moment.';
    }
    if (error is FormatException) {
      return 'The server returned invalid data. Please try again later.';
    }
    return 'Something went wrong while contacting the server. Please try again.';
  }

  @override
  void dispose() {
    _schoolNameCtrl.dispose();
    _mobileCtrl.dispose();
    _whatsappCtrl.dispose();
    _emailCtrl.dispose();
    _villageCtrl.dispose();
    _pincodeCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _referralCtrl.dispose();
    super.dispose();
  }

  // ── DOB helper ───────────────────────────────────────────
  String get _dobDisplay => _dob == null
      ? 'Select date of birth'
      : '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-'
            '${_dob!.day.toString().padLeft(2, '0')}';

  String get _dobApi => _dob == null
      ? ''
      : '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-'
            '${_dob!.day.toString().padLeft(2, '0')}';

  Future<void> _pickDob() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: kPink),
        ),
        child: child!,
      ),
    );
    if (d != null) setState(() => _dob = d);
  }

  // ── API call ─────────────────────────────────────────────
  Future<void> _register() async {
    // Basic validation
    if (!_agreeTerms) {
      _showDialog(
        'Error',
        'Please agree to the Terms & Conditions to continue.',
      );
      return;
    }
    if (_dob == null) {
      _showDialog('Error', 'Please select your date of birth.');
      return;
    }
    if (_selectedState == null || _selectedDistrict == null) {
      _showDialog('Error', 'Please select your State and District.');
      return;
    }

    // Field-level validation
    final fields = {
      'School / Organisation Name': _schoolNameCtrl.text.trim(),
      'Mobile Number': _mobileCtrl.text.trim(),
      'WhatsApp Number': _whatsappCtrl.text.trim(),
      'Email': _emailCtrl.text.trim(),
      'Village/Mohalla': _villageCtrl.text.trim(),
      'Pincode': _pincodeCtrl.text.trim(),
      'Username': _usernameCtrl.text.trim(),
      'Password': _passwordCtrl.text,
    };
    for (final entry in fields.entries) {
      if (entry.value.isEmpty) {
        _showDialog('Error', '${entry.key} cannot be empty.');
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final uri = Uri.parse('https://telsoworld.com/api/reporter/register');

      // API expects x-www-form-urlencoded
      final body = {
        'school_name': _schoolNameCtrl.text.trim(),
        'mobile_no': _mobileCtrl.text.trim(),
        'whatsapp': _whatsappCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'village': _villageCtrl.text.trim(),
        'pincode': _pincodeCtrl.text.trim(),
        'dob': _dobApi,
        'district': _selectedDistrict!,
        'state': _selectedState!,
        'terms': '1',
        'username': _usernameCtrl.text.trim(),
        'password': _passwordCtrl.text,
        'referral_code': _referralCtrl.text.trim(),
      };

      // Safe logging for request (mask sensitive fields like password)
      final logBody = Map<String, dynamic>.from(body)
        ..update('password', (value) => '***', ifAbsent: () => '***');
      _logger.i('Register request → $uri\nParams: ${jsonEncode(logBody)}');

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 25));

      if (kDebugMode) {
        debugPrint('=== REGISTER API RESPONSE ===');
        debugPrint('Status Code : ${response.statusCode}');
        debugPrint('Body        : ${response.body}');
        debugPrint('=============================');
      }
      _logger.i(
        'Register response [${response.statusCode}] ← $uri\nBody: ${response.body}',
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> json =
            jsonDecode(response.body) as Map<String, dynamic>;

        final bool status = json['status'] == true || json['status'] == 1;

        if (status) {
          // Persist token (if provided by API) for dashboard calls
          try {
            final dynamic rawToken = json['token'] ?? (json['data']?['token']);
            final token = rawToken?.toString();
            if (token != null && token.isNotEmpty) {
              await SessionTokenStore.setToken(token);
              _logger.i('Register token saved: $token');
            }
          } catch (e, st) {
            _logger.w(
              'Failed to save register token',
              error: e,
              stackTrace: st,
            );
          }

          if (!mounted) return;
          Navigator.of(context).pushReplacementNamed(AppRoutes.main);
        } else {
          _showDialog(
            'Registration Failed',
            json['message']?.toString() ??
                'Something went wrong. Please try again.',
          );
        }
      } else {
        final apiMessage = _extractApiMessage(response.body);
        _showDialog(
          'Error',
          apiMessage ??
              'Server returned status ${response.statusCode}. Please try again.',
        );
      }
    } catch (e, st) {
      _logger.e('Register error', error: e, stackTrace: st);
      if (!mounted) return;
      _showDialog(
        'Error',
        '${_messageForNetworkError(e)}${kDebugMode ? '\n\n$e' : ''}',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showDialog(String title, String message, {VoidCallback? onOk}) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onOk?.call();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPink,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.maybePop(context),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const Text(
                    'Telso World',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable Form ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon + title
                      Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.broadcast_on_personal_rounded,
                            color: Colors.white,
                            size: 38,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Center(
                        child: Text(
                          'Reporter Registration',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          'Join the Telso World community and start reporting',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 13.5,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── School / Organisation ──
                      _FieldLabel('School / Organisation Name *'),
                      _CtrlField(
                        controller: _schoolNameCtrl,
                        hint: 'e.g. ABC School',
                      ),

                      // ── Mobile ──
                      _FieldLabel('Mobile Number *'),
                      _CtrlField(
                        controller: _mobileCtrl,
                        hint: '+91 00000 00000',
                        keyboardType: TextInputType.phone,
                      ),

                      // ── WhatsApp ──
                      _FieldLabel('WhatsApp Number *'),
                      _CtrlField(
                        controller: _whatsappCtrl,
                        hint: 'Same or different from mobile',
                        keyboardType: TextInputType.phone,
                      ),

                      // ── Email ──
                      _FieldLabel('Email *'),
                      _CtrlField(
                        controller: _emailCtrl,
                        hint: 'yourname@example.com',
                        keyboardType: TextInputType.emailAddress,
                      ),

                      // ── Village / Pincode ──
                      _FieldLabel('Village / Mohalla *'),
                      Row(
                        children: [
                          Expanded(
                            child: _CtrlField(
                              controller: _villageCtrl,
                              hint: 'Locality',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _CtrlField(
                              controller: _pincodeCtrl,
                              hint: 'Pincode',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),

                      // ── Date of Birth ──
                      _FieldLabel('Date of Birth *'),
                      GestureDetector(
                        onTap: _pickDob,
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: kFieldBg,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _dobDisplay,
                                  style: TextStyle(
                                    color: _dob == null
                                        ? Colors.grey.shade400
                                        : const Color(0xFF333333),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.calendar_today_outlined,
                                color: Colors.grey.shade400,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── State / District ──
                      _FieldLabel('State *'),
                      Row(
                        children: [
                          Expanded(
                            child: _DropdownField(
                              hint: 'Select State',
                              value: _selectedState,
                              items: _states,
                              onChanged: (v) => setState(() {
                                _selectedState = v;
                                _selectedDistrict = null;
                              }),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DropdownField(
                              hint: 'Select District',
                              value: _selectedDistrict,
                              items: _districts,
                              onChanged: (v) =>
                                  setState(() => _selectedDistrict = v),
                            ),
                          ),
                        ],
                      ),

                      // ── Username ──
                      _FieldLabel('Username *'),
                      _CtrlField(
                        controller: _usernameCtrl,
                        hint: 'Choose a unique username',
                      ),

                      // ── Password ──
                      _FieldLabel('Password *'),
                      _PasswordCtrlField(
                        controller: _passwordCtrl,
                        obscure: _obscurePassword,
                        onToggle: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),

                      // ── Referral Code ──
                      _FieldLabel('Referral Code (Optional)'),
                      _CtrlField(
                        controller: _referralCtrl,
                        hint: 'e.g. TELSONGZY',
                      ),

                      const SizedBox(height: 20),

                      // ── Terms ──
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _agreeTerms,
                              onChanged: (v) =>
                                  setState(() => _agreeTerms = v ?? false),
                              activeColor: Colors.white,
                              checkColor: kPink,
                              side: const BorderSide(
                                color: Colors.white,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                                children: const [
                                  TextSpan(text: 'I agree to the '),
                                  TextSpan(
                                    text: 'Terms & Conditions',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' and privacy policy of Telso World.',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // ── Register Now Button ──
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: (_agreeTerms && !_isLoading)
                              ? _register
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            disabledBackgroundColor: Colors.black.withOpacity(
                              0.4,
                            ),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(32),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Register Now',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ── Login link ──
                      Center(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 13.5,
                            ),
                            children: [
                              const TextSpan(text: 'Already have an account? '),
                              TextSpan(
                                text: 'Login',
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    Navigator.of(
                                      context,
                                    ).pushReplacementNamed(AppRoutes.login);
                                  },
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Field Label
// ─────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 14),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Controlled Text Field
// ─────────────────────────────────────────
class _CtrlField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;

  const _CtrlField({
    required this.controller,
    required this.hint,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: kFieldBg,
        borderRadius: BorderRadius.circular(30),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Controlled Password Field
// ─────────────────────────────────────────
class _PasswordCtrlField extends StatelessWidget {
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;

  const _PasswordCtrlField({
    required this.controller,
    required this.obscure,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: kFieldBg,
        borderRadius: BorderRadius.circular(30),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
        decoration: InputDecoration(
          hintText: 'Minimum 8 characters',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
          suffixIcon: GestureDetector(
            onTap: onToggle,
            child: Icon(
              obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: Colors.grey.shade400,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Dropdown Field
// ─────────────────────────────────────────
class _DropdownField extends StatelessWidget {
  final String hint;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DropdownField({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: kFieldBg,
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            hint,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF666666),
            size: 22,
          ),
          isExpanded: true,
          style: const TextStyle(color: Color(0xFF333333), fontSize: 13),
          items: items
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
