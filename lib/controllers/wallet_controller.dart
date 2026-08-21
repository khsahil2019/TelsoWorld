import 'dart:convert';
import 'package:get/get.dart';
import 'package:telsoworld/core/constants/api_endpoints.dart';
import 'package:telsoworld/core/services/api_service.dart';
import 'package:telsoworld/models/wallet_model.dart';

class WalletController extends GetxController {
  final ApiService _apiService = Get.find<ApiService>();

  final Rx<WalletModel?> walletData = Rx<WalletModel?>(null);
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchWallet();
  }

  Future<void> fetchWallet() async {
    isLoading.value = true;
    try {
      final response = await _apiService.get(ApiEndpoints.wallet);
      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        walletData.value = WalletModel.fromJson(json);
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load wallet: $e', snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }
}
