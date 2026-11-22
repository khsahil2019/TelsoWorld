import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ---------------------------------------------------------------------------
/// 🌓 ThemeService (Dynamic Light & Dark Mode Manager)
/// ---------------------------------------------------------------------------
class ThemeService extends GetxService {
  static const String _key = 'is_dark_mode';
  final RxBool isDarkMode = true.obs;

  Future<ThemeService> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isDarkMode.value = prefs.getBool(_key) ?? true;
    } catch (_) {
      isDarkMode.value = true;
    }
    return this;
  }

  ThemeMode get themeMode =>
      isDarkMode.value ? ThemeMode.dark : ThemeMode.light;

  Future<void> toggleTheme() async {
    isDarkMode.value = !isDarkMode.value;
    Get.changeThemeMode(themeMode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, isDarkMode.value);
    } catch (_) {}
  }

  Future<void> setDarkMode(bool dark) async {
    isDarkMode.value = dark;
    Get.changeThemeMode(themeMode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, dark);
    } catch (_) {}
  }
}
