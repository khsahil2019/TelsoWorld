import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:telsoworld/controllers/auth_controller.dart';
import 'package:telsoworld/core/routes/app_routes.dart';

/// ---------------------------------------------------------------------------
/// 🌟 SplashView (Cinematic Luxury Splash Screen)
/// ---------------------------------------------------------------------------
/// Yeh app ka cinematic, animated splash screen hai jisme:
/// - Breathing Neon Aura Rings
/// - Dynamic Equalizer Sound Waves
/// - Metallic Shader Brand Typography
/// - Smooth 0-100% Linear Progress Bar
/// - Safe Auto-Login Router
/// ---------------------------------------------------------------------------
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Logo scale & breathe animation controller
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: const Interval(0.0, 0.6, curve: Curves.easeIn)),
    );

    // 2. Linear loading progress bar controller (0.0 -> 1.0 over 2.4s)
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOutCubic),
    );

    _progressController.forward();
    _startRoutingTimer();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _startRoutingTimer() {
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      try {
        final authController = Get.find<AuthController>();
        if (authController.isLoggedIn) {
          Get.offAllNamed(AppRoutes.main);
        } else {
          Get.offAllNamed(AppRoutes.login);
        }
      } catch (_) {
        Get.offAllNamed(AppRoutes.login);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF07070B),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // 🌌 Multi-Layer Ambient Glowing Mesh Background
          Positioned(
            top: -size.width * 0.3,
            right: -size.width * 0.2,
            child: Container(
              width: size.width * 0.85,
              height: size.width * 0.85,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD70F64).withOpacity(0.18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD70F64).withOpacity(0.35),
                    blurRadius: 130,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -size.width * 0.3,
            left: -size.width * 0.2,
            child: Container(
              width: size.width * 0.85,
              height: size.width * 0.85,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8A2387).withOpacity(0.16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8A2387).withOpacity(0.32),
                    blurRadius: 140,
                    spreadRadius: 45,
                  ),
                ],
              ),
            ),
          ),

          // 🎶 Ambient Equalizer Wave Background
          Positioned(
            bottom: 140,
            child: _buildEqualizerSoundBars(),
          ),

          // 🌟 Centerpiece: Glowing Animated Logo & Brand Identity
          Center(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Breathing Neon Halo Rings
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer Pulsing Glow
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFFF2A6D).withOpacity(0.15 * _pulseController.value),
                            ),
                          ),
                          // Middle Neon Ring
                          Container(
                            width: 118,
                            height: 118,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFFF2A6D).withOpacity(0.4 + 0.3 * _pulseController.value),
                                width: 2,
                              ),
                            ),
                          ),
                          // Inner Core Logo Badge
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFD70F64), Color(0xFFFF2A6D), Color(0xFFFF8008)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFD70F64).withOpacity(0.6),
                                  blurRadius: 36,
                                  offset: const Offset(0, 10),
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
                                child: Icon(
                                  Icons.play_arrow_rounded,
                                  size: 54,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Metallic Gradient Brand Name
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Colors.white,
                            Color(0xFFFF7597),
                            Colors.white,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: const Text(
                          'TELSO WORLD',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Tagline Pill Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF00E676),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'CREATE • CONNECT • INSPIRE',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // 🚀 Bottom Progress Track & App Version
          Positioned(
            bottom: 44,
            left: 40,
            right: 40,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated Linear Progress Bar
                AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return Stack(
                      children: [
                        // Background track
                        Container(
                          height: 4,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        // Glowing Filled track
                        FractionallySizedBox(
                          widthFactor: _progressAnimation.value,
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFD70F64), Color(0xFFFF2A6D), Color(0xFF00E5FF)],
                              ),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF2A6D).withOpacity(0.8),
                                  blurRadius: 8,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Version & Made with Love
                Text(
                  'v1.0.0 • Short Video & Music Community',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 🎵 Equalizer Audio Frequency Bars
  Widget _buildEqualizerSoundBars() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final val = _pulseController.value;
        final heights = [
          14.0 + 16.0 * math.sin(val * math.pi),
          22.0 + 20.0 * math.cos(val * math.pi),
          12.0 + 18.0 * math.sin((val + 0.3) * math.pi),
          26.0 + 14.0 * math.cos((val + 0.5) * math.pi),
          18.0 + 22.0 * math.sin((val + 0.7) * math.pi),
          10.0 + 14.0 * math.cos((val + 0.9) * math.pi),
        ];

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: heights.map((h) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: 3.5,
              height: h.clamp(6.0, 36.0),
              decoration: BoxDecoration(
                color: const Color(0xFFFF2A6D).withOpacity(0.35),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
