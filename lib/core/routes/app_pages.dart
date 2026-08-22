import 'package:get/get.dart';
import 'package:telsoworld/controllers/ads_controller.dart';
import 'package:telsoworld/controllers/feed_controller.dart';
import 'package:telsoworld/controllers/profile_controller.dart';
import 'package:telsoworld/controllers/upload_controller.dart';
import 'package:telsoworld/controllers/wallet_controller.dart';
import 'package:telsoworld/core/routes/app_routes.dart';
import 'package:telsoworld/views/auth/registration_view.dart';
import 'package:telsoworld/views/auth/login_view.dart';
import 'package:telsoworld/views/auth/registration_success_view.dart';
import 'package:telsoworld/views/main_nav/main_nav_view.dart';
import 'package:telsoworld/views/splash/splash_view.dart';

/// ---------------------------------------------------------------------------
/// 🗺️ AppPages (GetX Routing & Lazy Bindings Registry)
/// ---------------------------------------------------------------------------
/// Yeh class define karti hai ki kaunse Route Name par kaunsi Screen khulegi
/// aur us screen ke liye kaunse Controllers lazily inject honge.
///
/// New Developer ke liye zaroori baatein:
/// 1. `initial: AppRoutes.splash`: App hamesha Splash Screen se start hota hai.
/// 2. `Get.lazyPut`: Controller tabhi memory me banta hai jab user us feature ko
///    first time access karta hai (Performance optimization).
/// ---------------------------------------------------------------------------
class AppPages {
  /// 🏁 Starting route of the app
  static const initial = AppRoutes.splash;

  /// 📋 List of all application screens & lazy bindings
  static final routes = [
    // 1. Splash Screen
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashView(),
    ),

    // 2. Authentication: Login Screen
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginView(),
    ),

    // 3. Authentication: Musician / Reporter Registration
    GetPage(
      name: AppRoutes.register,
      page: () => const MusicianRegistrationScreen(),
    ),

    // 4. Registration Success Confirmation
    GetPage(
      name: AppRoutes.registrationSuccess,
      page: () => const RegistrationSuccessView(),
    ),

    // 5. Main App Shell (5 Bottom Navigation Tabs)
    GetPage(
      name: AppRoutes.main,
      page: () => const MainNavView(),
      binding: BindingsBuilder(() {
        // Feed video and likes controller
        Get.lazyPut<FeedController>(() => FeedController());
        // Ads reels and promotion controller
        Get.lazyPut<AdsController>(() => AdsController());
        // Reel upload and trimming controller
        Get.lazyPut<UploadController>(() => UploadController());
        // Wallet balance and transactions controller
        Get.lazyPut<WalletController>(() => WalletController());
        // User profile and referrals controller
        Get.lazyPut<ProfileController>(() => ProfileController());
      }),
    ),
  ];
}
