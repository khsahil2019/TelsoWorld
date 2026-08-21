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

class AppPages {
  static const initial = AppRoutes.splash;

  static final routes = [
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashView(),
    ),
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginView(),
    ),
    GetPage(
      name: AppRoutes.register,
      page: () => const MusicianRegistrationScreen(),
    ),
    GetPage(
      name: AppRoutes.registrationSuccess,
      page: () => const RegistrationSuccessView(),
    ),
    GetPage(
      name: AppRoutes.main,
      page: () => const MainNavView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<FeedController>(() => FeedController());
        Get.lazyPut<AdsController>(() => AdsController());
        Get.lazyPut<UploadController>(() => UploadController());
        Get.lazyPut<WalletController>(() => WalletController());
        Get.lazyPut<ProfileController>(() => ProfileController());
      }),
    ),
  ];
}
