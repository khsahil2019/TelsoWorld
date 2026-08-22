import 'package:get/get.dart';
import 'package:telsoworld/controllers/auth_controller.dart';
import 'package:telsoworld/controllers/main_nav_controller.dart';
import 'package:telsoworld/core/services/api_service.dart';
import 'package:telsoworld/core/services/storage_service.dart';

/// ---------------------------------------------------------------------------
/// 🚀 InitialBinding (App Startup Dependencies)
/// ---------------------------------------------------------------------------
/// Yeh class app start hote hi globally saare zaroori Services aur Controllers
/// ko GetX dependency injection container me register karti hai.
///
/// New Developer ke liye zaroori baatein:
/// 1. `permanent: true` ka matlab hai yeh memory se dispose nahi honge aur
///    pure app lifecycle me har jagah `Get.find<T>()` se access ho sakte hain.
/// 2. Pehle `StorageService` check hota hai taaki local token reading me error na aaye.
/// 3. Phir `ApiService`, `AuthController`, aur `MainNavController` initialize hote hain.
/// ---------------------------------------------------------------------------
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // 💾 1. Local Storage Service (SharedPreferences / Auth Token manage karne ke liye)
    if (!Get.isRegistered<StorageService>()) {
      Get.put<StorageService>(StorageService(), permanent: true);
    }

    // 🌐 2. Central API Service (HTTP requests, headers, aur error handling ke liye)
    Get.put<ApiService>(ApiService(), permanent: true);

    // 🔐 3. Authentication Controller (Login, Register, Logout aur User Session ke liye)
    Get.put<AuthController>(AuthController(), permanent: true);

    // 📱 4. Bottom Navigation Controller (Home, Discovery, Upload, Inbox, Profile tabs ke liye)
    Get.put<MainNavController>(MainNavController(), permanent: true);
  }
}
