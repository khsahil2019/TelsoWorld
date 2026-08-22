import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:telsoworld/controllers/auth_controller.dart';
import 'package:telsoworld/core/routes/app_routes.dart';

/// ---------------------------------------------------------------------------
/// 🔐 LoginView (World-Class Dark Luxury Glassmorphic Login Experience)
/// ---------------------------------------------------------------------------
/// Yeh screen user ke credentials verify karke login karne ke liye hai.
/// Includes:
/// - Breathing brand halo & play logo
/// - Translucent glassmorphism container
/// - Glowing focused input borders & icons
/// - Remember me switch & help modal
/// - Gradient Sign In button with drop shadows
/// ---------------------------------------------------------------------------
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> with SingleTickerProviderStateMixin {
  final AuthController controller = Get.find<AuthController>();
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _rememberMe = true;
  AnimationController? _animController;
  Animation<double>? _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimation();
    _usernameFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));
  }

  void _initAnimation() {
    _animController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animController!, curve: Curves.easeInOut),
    );
  }

  @override
  void reassemble() {
    super.reassemble();
    _initAnimation();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _animController?.dispose();
    super.dispose();
  }

  void _handleLogin() {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;
    controller.login(username, password);
  }

  void _showHelpSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF14141E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF2A6D).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.help_outline_rounded, color: Color(0xFFFF2A6D), size: 22),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Need Help Logging In?',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'If you forgot your password or cannot access your account, please reach out to Telso World Support or contact your reporter coordinator.',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B26),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: const [
                  Icon(Icons.email_outlined, color: Color(0xFF00E5FF), size: 20),
                  SizedBox(width: 10),
                  Text('support@telsoworld.com', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD70F64),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Got it', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF07070B),
      body: Stack(
        children: [
          // 🌌 Background Glowing Ambient Orbs
          Positioned(
            top: -size.width * 0.25,
            right: -size.width * 0.15,
            child: Container(
              width: size.width * 0.8,
              height: size.width * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD70F64).withOpacity(0.18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD70F64).withOpacity(0.35),
                    blurRadius: 130,
                    spreadRadius: 35,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -size.width * 0.25,
            left: -size.width * 0.15,
            child: Container(
              width: size.width * 0.8,
              height: size.width * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8A2387).withOpacity(0.16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8A2387).withOpacity(0.3),
                    blurRadius: 130,
                    spreadRadius: 35,
                  ),
                ],
              ),
            ),
          ),

          // 📱 Main Scrollable Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10),

                    // Animated Brand Badge
                    ScaleTransition(
                      scale: _scaleAnimation ?? const AlwaysStoppedAnimation(1.0),
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD70F64), Color(0xFFFF2A6D), Color(0xFFFF8008)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD70F64).withOpacity(0.55),
                              blurRadius: 28,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(3.5),
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF0F0F16),
                          ),
                          child: const Center(
                            child: Icon(Icons.play_arrow_rounded, size: 48, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // App Title
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Colors.white, Color(0xFFFF7597), Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: const Text(
                        'TELSO WORLD',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Welcome back! Sign in to continue',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // 🔲 Luxury Glassmorphic Card Container
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: const Color(0xFF12121A).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Username / Mobile Field
                          const Text(
                            'Username or Email',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: const Color(0xFF191924),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _usernameFocus.hasFocus
                                    ? const Color(0xFFFF2A6D)
                                    : Colors.white.withOpacity(0.07),
                                width: _usernameFocus.hasFocus ? 1.5 : 1.0,
                              ),
                              boxShadow: _usernameFocus.hasFocus
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFFF2A6D).withOpacity(0.2),
                                        blurRadius: 10,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: TextField(
                              controller: _usernameCtrl,
                              focusNode: _usernameFocus,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Enter your username or email',
                                hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                                prefixIcon: Container(
                                  margin: const EdgeInsets.all(8),
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF2A6D).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.person_rounded, color: Color(0xFFFF2A6D), size: 18),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // 2. Password Field
                          const Text(
                            'Password',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: const Color(0xFF191924),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _passwordFocus.hasFocus
                                    ? const Color(0xFFFF2A6D)
                                    : Colors.white.withOpacity(0.07),
                                width: _passwordFocus.hasFocus ? 1.5 : 1.0,
                              ),
                              boxShadow: _passwordFocus.hasFocus
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFFF2A6D).withOpacity(0.2),
                                        blurRadius: 10,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: TextField(
                              controller: _passwordCtrl,
                              focusNode: _passwordFocus,
                              obscureText: _obscurePassword,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Enter your password',
                                hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                                prefixIcon: Container(
                                  margin: const EdgeInsets.all(8),
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF2A6D).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.lock_rounded, color: Color(0xFFFF2A6D), size: 18),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                    color: Colors.white38,
                                    size: 18,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Remember Me & Forgot Password Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () => setState(() => _rememberMe = !_rememberMe),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: Checkbox(
                                        value: _rememberMe,
                                        activeColor: const Color(0xFFFF2A6D),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                        side: BorderSide(color: Colors.white.withOpacity(0.3)),
                                        onChanged: (val) => setState(() => _rememberMe = val ?? true),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Remember me',
                                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: _showHelpSheet,
                                child: const Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    color: Color(0xFFFF6584),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // 🚀 Sign In Gradient Action Button
                          Obx(() {
                            final isLoading = controller.isLoading.value;
                            return SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: isLoading ? null : _handleLogin,
                                child: Ink(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFD70F64), Color(0xFFFF2A6D)],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFD70F64).withOpacity(0.5),
                                        blurRadius: 18,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: isLoading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                'Sign In',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 📝 Sign Up Call to Action Container
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "New to Telso World? ",
                            style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 13),
                          ),
                          GestureDetector(
                            onTap: () => Get.toNamed(AppRoutes.register),
                            child: const Text(
                              'Create Account',
                              style: TextStyle(
                                color: Color(0xFFFF2A6D),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
