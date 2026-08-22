/// ---------------------------------------------------------------------------
/// 🧭 AppRoutes (Central Route Name Constants)
/// ---------------------------------------------------------------------------
/// Yeh class app me navigate karne ke liye named routes ke strings define karti hai.
/// Hardcoded string use karne ke bajaye `AppRoutes.main` ya `AppRoutes.login` use karein.
///
/// Example:
/// `Get.toNamed(AppRoutes.main);`
/// `Get.offAllNamed(AppRoutes.login);`
/// ---------------------------------------------------------------------------
abstract class AppRoutes {
  /// 🌟 App startup screen (Token check & navigation decision)
  static const splash = '/splash';

  /// 📱 Main app shell (Bottom navigation: Home, Discovery, Upload, Inbox, Profile)
  static const main = '/main';

  /// 🔐 User Login Screen
  static const login = '/login';

  /// 📝 User Registration Screen
  static const register = '/register';

  /// 🎉 Registration Complete / Verification Success Screen
  static const registrationSuccess = '/registration-success';
}
