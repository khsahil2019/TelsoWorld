import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:telsoworld/app_routes.dart';
import 'package:telsoworld/session_token_store.dart';

const kPink = Color(0xFFD70F64);
const kFieldBg = Color(0xFFFAF0F4);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;
  bool _isLoading = false;
  final Logger _logger = Logger();
  late final Dio _dio;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 35),
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 35),
        validateStatus: (_) => true,
        responseType: ResponseType.plain,
      ),
    );
  }

  Future<Response<String>> _postLoginWithRetry({
    required List<String> urls,
    required Map<String, String> headers,
    required Map<String, String> body,
    int maxAttempts = 3,
  }) async {
    DioException? lastError;

    for (final url in urls) {
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          return await _dio.post<String>(
            url,
            data: body,
            options: Options(
              headers: <String, String>{
                ...headers,
                'User-Agent': 'TelsoWorldApp/1.0 (Android; Flutter)',
              },
              contentType: Headers.formUrlEncodedContentType,
              followRedirects: true,
              maxRedirects: 5,
              persistentConnection: false,
            ),
          );
        } on DioException catch (e, s) {
          lastError = e;
          _logger.w(
            'LOGIN REQUEST failed for $url (attempt $attempt/$maxAttempts): $e',
            error: e,
            stackTrace: s,
          );

          if (!_shouldRetry(e) || attempt >= maxAttempts) {
            break;
          }
          await Future<void>.delayed(Duration(seconds: attempt));
        }
      }
    }

    if (lastError != null) throw lastError;
    throw DioException(
      requestOptions: RequestOptions(path: urls.isNotEmpty ? urls.first : ''),
      type: DioExceptionType.unknown,
      error: 'Login request could not be started.',
    );
  }

  bool _shouldRetry(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.badCertificate;
  }

  String? _extractApiMessage(String? responseBody) {
    if (responseBody == null || responseBody.trim().isEmpty) return null;

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

  String _messageForDioError(DioException error) {
    final apiMessage = _extractApiMessage(error.response?.data?.toString());
    if (apiMessage != null) return apiMessage;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Server is taking too long to respond. Please try again.';
      case DioExceptionType.connectionError:
        final innerError = error.error;
        if (innerError is SocketException) {
          return 'Unable to reach the server. Please check your internet connection and try again.';
        }
        if (innerError is HandshakeException) {
          return 'Secure connection to the server failed. Please try again in a moment.';
        }
        return 'Could not connect to server right now. Please try again in a moment.';
      case DioExceptionType.badCertificate:
        return 'The server security certificate could not be verified.';
      case DioExceptionType.badResponse:
        return 'The server returned an unexpected response. Please try again.';
      default:
        return 'Something went wrong while contacting the server. Please try again.';
    }
  }

  String _messageForUnexpectedError(Object error) {
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
    _dio.close(force: true);
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      _showErrorDialog('Please enter your username and password.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      const urls = <String>[
        'https://telsoworld.com/api/reporter/login',
        'https://www.telsoworld.com/api/reporter/login',
      ];
      final headers = <String, String>{'Accept': 'application/json'};
      final body = {'username': username, 'password': password};
      final safeBody = {'username': username, 'password': '***'};

      _logger.i('LOGIN REQUEST -> URLs: $urls');
      _logger.i('LOGIN REQUEST -> Headers: $headers');
      _logger.i('LOGIN REQUEST -> Body: $safeBody');

      final response = await _postLoginWithRetry(
        urls: urls,
        headers: headers,
        body: body,
      );

      final responseBody = response.data ?? '';
      _logger.i('LOGIN RESPONSE -> Status: ${response.statusCode}');
      _logger.i('LOGIN RESPONSE -> Headers: ${response.headers.map}');
      _logger.i('LOGIN RESPONSE -> Body: $responseBody');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> json =
        jsonDecode(responseBody) as Map<String, dynamic>;

        final bool status = json['status'] == true;

        if (status) {
          try {
            final String? token = json['token']?.toString();
            if (token != null && token.isNotEmpty) {
              await SessionTokenStore.setToken(token);
              debugPrint('Token saved: $token');
            }
          } catch (_) {
            // Ignore persistence errors and continue navigation
          }

          Navigator.of(context).pushReplacementNamed(AppRoutes.main);
        } else {
          final message =
              json['message']?.toString() ??
                  'Invalid username or password. Please try again.';
          _showErrorDialog(message);
        }
      } else {
        final apiMessage = _extractApiMessage(responseBody);
        _showErrorDialog(
          apiMessage ??
              'Login failed with status code ${response.statusCode}. Please try again.',
        );
      }
    } on DioException catch (e, s) {
      _logger.e('LOGIN ERROR (dio) -> $e', error: e, stackTrace: s);
      if (e.response != null) {
        _logger.e(
          'LOGIN ERROR RESPONSE -> Status: ${e.response?.statusCode}, Body: ${e.response?.data}',
        );
      }
      if (!mounted) return;
      final details = kDebugMode ? '\n\n${e.message}' : '';
      _showErrorDialog('${_messageForDioError(e)}$details');
    } catch (e, s) {
      _logger.e('LOGIN ERROR (unexpected) -> $e', error: e, stackTrace: s);
      if (!mounted) return;
      final details = kDebugMode ? '\n\n$e' : '';
      _showErrorDialog('${_messageForUnexpectedError(e)}$details');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Login Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPink,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              // ── Logo ──
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.language_rounded, color: kPink, size: 48),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Brand Name ──
              const Center(
                child: Text(
                  'TELSO WORLD',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3.0,
                  ),
                ),
              ),

              const SizedBox(height: 44),

              // ── Login heading ──
              const Text(
                'Login',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Welcome back to the premium experience.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 14.5,
                ),
              ),

              const SizedBox(height: 32),

              // ── Username / Email ──
              _FieldLabel('Username or Email'),
              const SizedBox(height: 8),
              _InputField(
                usernameController: _usernameController,
                hint: 'Enter your username or email',
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 20),

              // ── Password ──
              _FieldLabel('Password'),
              const SizedBox(height: 8),
              _PasswordInput(
                passwordController: _passwordController,
                obscure: _obscurePassword,
                onToggle: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),

              const SizedBox(height: 12),

              // ── Forgot Password ──
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {},
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Login Button ──
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    disabledBackgroundColor: Colors.black.withOpacity(0.5),
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
                    'Login',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // ── OR CONTINUE WITH ──
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: Colors.white.withOpacity(0.35),
                      thickness: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      'OR CONTINUE WITH',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: Colors.white.withOpacity(0.35),
                      thickness: 1,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // ── Social Buttons ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SocialButton(child: _GoogleIcon()),
                  const SizedBox(width: 20),
                  _SocialButton(
                    child: const Icon(
                      Icons.apple,
                      color: Colors.black,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 20),
                  _SocialButton(child: _FacebookIcon()),
                ],
              ),

              const SizedBox(height: 36),

              // ── Sign Up link ──
              Center(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    children: [
                      const TextSpan(
                        text: "Don't have an account? ",
                        style: TextStyle(fontWeight: FontWeight.w400),
                      ),
                      TextSpan(
                        text: 'Sign Up',
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Navigator.of(
                              context,
                            ).pushReplacementNamed(AppRoutes.register);
                          },
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
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
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ─────────────────────────────────────────
// Input Field
// ─────────────────────────────────────────
class _InputField extends StatelessWidget {
  final String hint;
  final TextInputType? keyboardType;
  final TextEditingController usernameController;

  const _InputField({
    required this.hint,
    this.keyboardType,
    required this.usernameController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller: usernameController,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 15, color: Color(0xFF333333)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 18,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Password Input
// ─────────────────────────────────────────
class _PasswordInput extends StatelessWidget {
  final bool obscure;
  final VoidCallback onToggle;
  final TextEditingController passwordController;

  const _PasswordInput({
    required this.obscure,
    required this.onToggle,
    required this.passwordController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller: passwordController,
        obscureText: obscure,
        style: const TextStyle(fontSize: 15, color: Color(0xFF333333)),
        decoration: InputDecoration(
          hintText: 'Enter your password',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 18,
          ),
          suffixIcon: GestureDetector(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(
                obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: Colors.blueGrey.shade300,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Social Button
// ─────────────────────────────────────────
class _SocialButton extends StatelessWidget {
  final Widget child;
  const _SocialButton({required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Google Icon (painted)
// ─────────────────────────────────────────
class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(28, 28), painter: _GooglePainter());
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // Draw colored arc segments
    final colors = [
      (const Color(0xFF4285F4), -0.1, 0.5), // blue
      (const Color(0xFF34A853), 0.5, 1.0), // green
      (const Color(0xFFFBBC05), 1.0, 1.35), // yellow
      (const Color(0xFFEA4335), 1.35, 2.0), // red
    ];

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.18;

    for (final (color, start, end) in colors) {
      paint.color = color;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.72),
        start * 3.14159,
        (end - start) * 3.14159,
        false,
        paint,
      );
    }

    // Blue horizontal bar (right side)
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - size.height * 0.1, r * 0.9, size.height * 0.2),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────
// Facebook Icon
// ─────────────────────────────────────────
class _FacebookIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        color: Color(0xFF1877F2),
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Text(
          'f',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}
