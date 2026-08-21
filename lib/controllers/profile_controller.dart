import 'dart:convert';
import 'package:get/get.dart';
import 'package:telsoworld/core/constants/api_endpoints.dart';
import 'package:telsoworld/core/services/api_service.dart';
import 'package:telsoworld/models/referral_model.dart';

class ProfileController extends GetxController {
  final ApiService _apiService = Get.find<ApiService>();

  final Rx<ReferralModel?> referralData = Rx<ReferralModel?>(null);
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchReferralData();
  }

  Future<void> fetchReferralData() async {
    isLoading.value = true;
    try {
      final response = await _apiService.get(ApiEndpoints.referral);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        referralData.value = ReferralModel.fromJson(json);
      }
    } catch (_) {
    } finally {
      isLoading.value = false;
    }
  }
}
