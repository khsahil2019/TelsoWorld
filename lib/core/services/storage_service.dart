import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ---------------------------------------------------------------------------
/// 💾 StorageService (Local Storage & Token Manager)
/// ---------------------------------------------------------------------------
/// Yeh service device ke local memory (SharedPreferences) me user ka Auth Token
/// store aur retrieve karti hai.
///
/// New Developer ke liye zaroori baatein:
/// 1. `_memoryToken` ek in-memory fallback cache hai, taaki agar `_prefs` delay ho
///    toh bhi app crash na ho aur instantly token mil sake.
/// 2. `main.dart` me `await Get.putAsync(() => StorageService().init());` se yeh
///    app launch se pehle hi ready ho jata hai.
/// 3. `isLoggedIn` getter check karta hai ki user logged in hai ya nahi.
/// ---------------------------------------------------------------------------
class StorageService extends GetxService {
  SharedPreferences? _prefs;
  String _memoryToken = '';

  /// 🚀 Service initialization: SharedPreferences instance load karke token cache karta hai
  Future<StorageService> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _memoryToken = _prefs?.getString('token')?.trim() ?? '';
    } catch (_) {}
    return this;
  }

  /// 🔑 Saved Auth Token get karta hai (Pehle memory se, fir SharedPreferences se)
  String getToken() {
    if (_memoryToken.isNotEmpty) return _memoryToken;
    return _prefs?.getString('token')?.trim() ?? '';
  }

  /// 💾 Login ke baad naya Auth Token save karta hai
  Future<bool> setToken(String token) async {
    final normalized = token.trim();
    _memoryToken = normalized;
    if (_prefs == null) {
      try {
        _prefs = await SharedPreferences.getInstance();
      } catch (_) {}
    }
    if (_prefs != null) {
      return await _prefs!.setString('token', normalized);
    }
    return true;
  }

  /// 🚪 Logout ke time token delete karke session clear karta hai
  Future<bool> clearToken() async {
    _memoryToken = '';
    if (_prefs == null) {
      try {
        _prefs = await SharedPreferences.getInstance();
      } catch (_) {}
    }
    if (_prefs != null) {
      return await _prefs!.remove('token');
    }
    return true;
  }

  /// ✅ Check karta hai ki token available hai ya nahi (User logged in hai ya nahi)
  bool get isLoggedIn => getToken().isNotEmpty;
}
