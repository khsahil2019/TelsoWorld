import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:telsoworld/core/constants/api_endpoints.dart';
import 'package:telsoworld/core/routes/app_routes.dart';
import 'package:telsoworld/core/services/api_service.dart';
import 'package:telsoworld/core/services/storage_service.dart';
import 'package:telsoworld/models/user_model.dart';

/// ---------------------------------------------------------------------------
/// 🔐 AuthController (User Authentication & Session State)
/// ---------------------------------------------------------------------------
/// Yeh controller user ke login, registration, logout, aur active session state
/// ko manage karta hai.
///
/// New Developer ke liye zaroori baatein:
/// 1. `login(username, password)`: Backend API se verify karke Bearer Token ko
///    `StorageService` me save karta hai aur direct `AppRoutes.main` par redirect karta hai.
/// 2. `register(formData)`: New creator registration API call karta hai aur success
///    hone par `AppRoutes.registrationSuccess` par bhejta hai.
/// 3. `logout()`: Server ko logout call bhejkar local token delete karta hai aur
///    user ko `AppRoutes.login` par le aata hai.
/// ---------------------------------------------------------------------------
class AuthController extends GetxController {
  final ApiService _apiService = Get.find<ApiService>();
  final StorageService _storageService = Get.find<StorageService>();

  /// ⏳ Loading state (login ya register button par spinner dikhane ke liye)
  final RxBool isLoading = false.obs;

  /// 👤 Current logged-in user profile details (Observable state)
  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);

  /// ✅ Check karta hai ki active token saved hai ya nahi
  bool get isLoggedIn => _storageService.isLoggedIn;

  /// 🔑 User Login Function
  Future<void> login(String username, String password) async {
    if (username.trim().isEmpty || password.isEmpty) {
      Get.snackbar('Error', 'Please enter your username and password.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    isLoading.value = true;
    try {
      final response = await _apiService.post(
        ApiEndpoints.login,
        body: {'username': username.trim(), 'password': password},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        if (json['status'] == true) {
          // Token save karo SharedPreferences me
          final token = json['token']?.toString() ?? '';
          if (token.isNotEmpty) {
            await _storageService.setToken(token);
          }
          // User model parse karo
          if (json['user'] != null) {
            currentUser.value = UserModel.fromJson(json['user']);
          }
          // Main app dashboard par jao (Back stack clear karke)
          Get.offAllNamed(AppRoutes.main);
        } else {
          final msg = json['message']?.toString() ?? 'Invalid credentials.';
          Get.snackbar('Login Failed', msg, snackPosition: SnackPosition.BOTTOM);
        }
      } else {
        Get.snackbar('Error', 'Server returned status ${response.statusCode}',
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar('Login Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  /// 📝 User Registration Function
  Future<void> register(Map<String, dynamic> formData) async {
    isLoading.value = true;
    try {
      final response = await _apiService.post(
        ApiEndpoints.register,
        body: formData,
        isFormUrlEncoded: true,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['status'] == true) {
          Get.offAllNamed(AppRoutes.registrationSuccess);
        } else {
          Get.snackbar('Registration Failed', json['message']?.toString() ?? 'Error occurred',
              snackPosition: SnackPosition.BOTTOM);
        }
      } else {
        Get.snackbar('Error', 'Server error ${response.statusCode}',
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  /// 🚪 User Logout Function
  Future<void> logout() async {
    try {
      await _apiService.post(ApiEndpoints.logout);
    } catch (_) {}
    // Local storage se token delete karo
    await _storageService.clearToken();
    currentUser.value = null;
    // Login screen par redirect karo
    Get.offAllNamed(AppRoutes.login);
  }
}
