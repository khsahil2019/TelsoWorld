import 'package:flutter/material.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.onContinue,
    this.autoRedirectDelay = const Duration(seconds: 2),
  });

  final VoidCallback onContinue;
  final Duration autoRedirectDelay;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _fadeController;
  late Animation<double> _progressAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  Timer? _redirectTimer;
  bool _hasTriggeredContinue = false;

  double _progressValue = 0.0;
  int _progressPercent = 0;

  @override
  void initState() {
    super.initState();

    // Fade + scale animation for logo and text
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutBack),
    );

    _fadeController.forward();

    // Progress bar animation
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 0.85).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    _progressAnimation.addListener(() {
      setState(() {
        _progressValue = _progressAnimation.value;
        _progressPercent = (_progressValue * 100).round();
      });
    });

    // Slight delay before progress starts
    Future.delayed(const Duration(milliseconds: 400), () {
      _progressController.forward();
    });

    _redirectTimer = Timer(widget.autoRedirectDelay, _handleContinue);
  }

  void _handleContinue() {
    if (_hasTriggeredContinue || !mounted) {
      return;
    }
    _hasTriggeredContinue = true;
    widget.onContinue();
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    _progressController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryPink = Color(0xFFD70F64);
    const logoGradientStart = Color(0xFFE87B6E);
    const logoGradientEnd = Color(0xFFF0A08A);

    return Scaffold(
      backgroundColor: primaryPink,
      body: SafeArea(
        child: Stack(
          children: [
            // Globe icon top-right
            Positioned(
              top: 12,
              right: 16,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.language_rounded,
                    color: Colors.black87,
                    size: 22,
                  ),
                ),
              ),
            ),

            // Main content
            Column(
              children: [
                // Logo section — takes upper portion
                Expanded(
                  flex: 5,
                  child: Center(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // App icon
                            Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(36),
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [logoGradientEnd, logoGradientStart],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.18),
                                    blurRadius: 30,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text(
                                  'T',
                                  style: TextStyle(
                                    fontFamily: 'serif',
                                    fontSize: 88,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w400,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 36),

                            // Brand name
                            const Text(
                              'Telso World',
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),

                            const SizedBox(height: 10),

                            // Tagline
                            Text(
                              'EXPERIENCE THE FUTURE',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.85),
                                letterSpacing: 2.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Progress section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Label + percentage row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Initialising experience...',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.2,
                              ),
                            ),
                            Text(
                              '$_progressPercent%',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _progressValue,
                            minHeight: 5,
                            backgroundColor: Colors.white.withOpacity(0.22),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // Get Started button + footer
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        // Get Started button
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton(
                            onPressed: _handleContinue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: primaryPink,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Get Started',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Icon(Icons.arrow_forward, size: 20),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Footer pills
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _FooterTag(label: 'Secure'),
                            _FooterDot(),
                            _FooterTag(label: 'Fast'),
                            _FooterDot(),
                            _FooterTag(label: 'Global'),
                          ],
                        ),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterTag extends StatelessWidget {
  final String label;
  const _FooterTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        color: Colors.white.withOpacity(0.75),
        fontWeight: FontWeight.w400,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _FooterDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        width: 4,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.55),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
