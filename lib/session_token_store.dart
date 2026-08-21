import 'dart:async';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionTokenStore {
  static String _memoryToken = '';

  static Future<String> getToken() async {
    if (_memoryToken.isNotEmpty) {
      return _memoryToken;
    }

    final prefs = await _getPrefsSafe();
    if (prefs == null) {
      return '';
    }

    final token = prefs.getString('token')?.trim() ?? '';
    if (token.isNotEmpty) {
      _memoryToken = token;
    }
    return token;
  }

  static Future<void> setToken(String token) async {
    final normalized = token.trim();
    _memoryToken = normalized;
    if (normalized.isEmpty) {
      await clearToken();
      return;
    }

    final prefs = await _getPrefsSafe();
    if (prefs == null) {
      return;
    }

    try {
      await prefs.setString('token', normalized);
    } catch (_) {
      // Keep in-memory token as fallback for this app session.
    }
  }

  static Future<void> clearToken() async {
    _memoryToken = '';
    final prefs = await _getPrefsSafe();
    if (prefs == null) {
      return;
    }

    try {
      await prefs.remove('token');
    } catch (_) {
      // Ignore persistence errors.
    }
  }

  static Future<SharedPreferences?> _getPrefsSafe() async {
    const maxAttempts = 3;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        return await SharedPreferences.getInstance();
      } on PlatformException {
        if (attempt == maxAttempts - 1) {
          return null;
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
