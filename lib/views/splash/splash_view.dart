import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:telsoworld/controllers/auth_controller.dart';
import 'package:telsoworld/core/constants/app_colors.dart';
import 'package:telsoworld/core/routes/app_routes.dart';

/// ---------------------------------------------------------------------------
/// 🌟 SplashView (App Launch & Auto-Login Routing)
/// ---------------------------------------------------------------------------
/// Yeh app ka entry point screen hai.
///
/// New Developer ke liye zaroori baatein:
/// 1. App start hote hi 2 seconds ka branding splash animation dikhata hai.
/// 2. `_navigateNext()` function local storage me Auth Token check karta hai:
///    - Agar token mila (`isLoggedIn == true`) -> Seedhe `AppRoutes.main` (Home) par le jata hai.
///    - Agar token nahi mila -> `AppRoutes.login` par redirect karta hai.
/// 3. Try-catch safe wrapper laga hai taaki storage delay hone par bhi app splash
///    par kabhi freeze na ho.
/// ---------------------------------------------------------------------------
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  @override
  void initState() {
    super.initState();
    _navigateNext();
  }

  /// ⏳ 2 seconds baad auth status check karke next screen decide karta hai
  Future<void> _navigateNext() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    try {
      final authController = Get.find<AuthController>();
      if (authController.isLoggedIn) {
        // User logged in hai -> Main Dashboard par bhej do
        Get.offAllNamed(AppRoutes.main);
      } else {
        // User logged out hai -> Login screen par bhej do
        Get.offAllNamed(AppRoutes.login);
      }
    } catch (_) {
      // Fallback: Koi error aaye toh safely Login screen par bhej do
      Get.offAllNamed(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryPink,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            // Telso Brand Icon
            Icon(Icons.play_circle_fill, size: 96, color: Colors.white),
            SizedBox(height: 24),
            // Telso App Name
            Text(
              'TELSO WORLD',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 32),
            // Loading Spinner
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
