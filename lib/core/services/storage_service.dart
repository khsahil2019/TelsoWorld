import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService extends GetxService {
  late SharedPreferences _prefs;

  Future<StorageService> init() async {
    _prefs = await SharedPreferences.getInstance();
    return this;
  }

  String getToken() {
    return _prefs.getString('token')?.trim() ?? '';
  }

  Future<bool> setToken(String token) async {
    return await _prefs.setString('token', token.trim());
  }

  Future<bool> clearToken() async {
    return await _prefs.remove('token');
  }

  bool get isLoggedIn => getToken().isNotEmpty;
}
