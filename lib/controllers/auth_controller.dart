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
      _showLoginErrorDialog('Please enter your username/email and password.');
      return;
    }

    isLoading.value = true;
    try {
      final response = await _apiService.post(
        ApiEndpoints.login,
        body: {'username': username.trim(), 'password': password},
      );

      Map<String, dynamic>? json;
      try {
        if (response.body.isNotEmpty) {
          json = jsonDecode(response.body) as Map<String, dynamic>?;
        }
      } catch (_) {}

      if (response.statusCode == 200 && json != null && json['status'] == true) {
        // Token save karo SharedPreferences me
        final token = json['token']?.toString() ?? '';
        if (token.isNotEmpty) {
          await _storageService.setToken(token);
        }
        // User model parse karo
        if (json['user'] != null) {
          currentUser.value = UserModel.fromJson(json['user']);
          if (currentUser.value?.id != null) {
            await _storageService.setUserId(currentUser.value!.id!);
          }
          if (currentUser.value?.username.isNotEmpty == true) {
            await _storageService.setUsername(currentUser.value!.username);
          }
          if (currentUser.value?.profileImage?.isNotEmpty == true) {
            await _storageService.setProfileImage(currentUser.value!.profileImage!);
          }
        }
        // Main app dashboard par jao (Back stack clear karke)
        Get.offAllNamed(AppRoutes.main);
      } else {
        final serverMessage = json?['message']?.toString() ?? json?['error']?.toString();
        String errorMsg;
        if (serverMessage != null && serverMessage.isNotEmpty) {
          errorMsg = serverMessage;
        } else if (response.statusCode == 401) {
          errorMsg = 'Incorrect username or password. Please try again.';
        } else if (response.statusCode == 422) {
          errorMsg = 'Please enter valid login credentials.';
        } else if (response.statusCode == 403) {
          errorMsg = 'Account suspended. Contact support@telsoworld.com.';
        } else {
          errorMsg = 'Unable to sign in at the moment. Please try again.';
        }
        _showLoginErrorDialog(errorMsg);
      }
    } catch (e) {
      _showLoginErrorDialog('Network connection error. Please check your internet and try again.');
    } finally {
      isLoading.value = false;
    }
  }

  void _showLoginErrorDialog(String message) {
    if (Get.context != null && Get.isDialogOpen != true) {
      Get.dialog(
        Dialog(
          backgroundColor: const Color(0xFF161622),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF2A6D).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.lock_outline_rounded,
                      color: Color(0xFFFF2A6D),
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Login Failed',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Get.back(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD70F64),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Try Again',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        barrierDismissible: true,
      );
    }

    Get.snackbar(
      'Login Failed',
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: const Color(0xFF1E1E2C),
      colorText: Colors.white,
      icon: const Icon(Icons.error_outline_rounded, color: Color(0xFFFF2A6D), size: 24),
      borderRadius: 14,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      duration: const Duration(seconds: 4),
      borderWidth: 1,
      borderColor: const Color(0xFFFF2A6D).withValues(alpha: 0.35),
    );
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
