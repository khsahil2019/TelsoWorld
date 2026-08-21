import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:telsoworld/core/constants/api_endpoints.dart';
import 'package:telsoworld/core/routes/app_routes.dart';
import 'package:telsoworld/core/services/api_service.dart';
import 'package:telsoworld/core/services/storage_service.dart';
import 'package:telsoworld/models/user_model.dart';

class AuthController extends GetxController {
  final ApiService _apiService = Get.find<ApiService>();
  final StorageService _storageService = Get.find<StorageService>();

  final RxBool isLoading = false.obs;
  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);

  bool get isLoggedIn => _storageService.isLoggedIn;

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
          final token = json['token']?.toString() ?? '';
          if (token.isNotEmpty) {
            await _storageService.setToken(token);
          }
          if (json['user'] != null) {
            currentUser.value = UserModel.fromJson(json['user']);
          }
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

  Future<void> logout() async {
    try {
      await _apiService.post(ApiEndpoints.logout);
    } catch (_) {}
    await _storageService.clearToken();
    currentUser.value = null;
    Get.offAllNamed(AppRoutes.login);
  }
}
