import 'package:get/get.dart';
import 'package:telsoworld/core/services/storage_service.dart';

/// ---------------------------------------------------------------------------
/// 🌉 SessionTokenStore (Static Bridge for Token Access)
/// ---------------------------------------------------------------------------
/// Yeh class legacy screens ya static functions ke liye ek Bridge/Helper ka kaam
/// karti hai, taaki bina direct GetX controller inject kiye kisi bhi jagah se
/// `SessionTokenStore.getToken()` call karke Auth Token liya ja sake.
///
/// New Developer ke liye zaroori baatein:
/// 1. Yeh internal calls ko direct `StorageService` par delegate karti hai.
/// 2. Raw HTTP calls (jaise `http.get`, `http.post`) me Authorization header
///    bhejne ke liye iska use kiya jata hai.
/// ---------------------------------------------------------------------------
class SessionTokenStore {
  /// 🔑 Current active Auth Token fetch karta hai
  static Future<String> getToken() async {
    if (Get.isRegistered<StorageService>()) {
      return Get.find<StorageService>().getToken();
    }
    return '';
  }

  /// 💾 Auth Token ko save/update karta hai
  static Future<void> setToken(String token) async {
    if (Get.isRegistered<StorageService>()) {
      await Get.find<StorageService>().setToken(token);
    }
  }

  /// 🗑️ Auth Token ko delete/clear karta hai
  static Future<void> clearToken() async {
    if (Get.isRegistered<StorageService>()) {
      await Get.find<StorageService>().clearToken();
    }
  }
}
