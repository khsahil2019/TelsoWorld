import 'dart:convert';
import 'package:get/get.dart';
import 'package:telsoworld/core/constants/api_endpoints.dart';
import 'package:telsoworld/core/services/api_service.dart';
import 'package:telsoworld/models/video_model.dart';

class AdsController extends GetxController {
  final ApiService _apiService = Get.find<ApiService>();

  final RxList<VideoModel> adsVideos = <VideoModel>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchAdsFeed();
  }

  Future<void> fetchAdsFeed() async {
    isLoading.value = true;
    try {
      final response = await _apiService.get(ApiEndpoints.adsVideos);
      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        if (json['data'] != null && json['data'] is List) {
          final List list = json['data'];
          adsVideos.assignAll(list.map((v) => VideoModel.fromJson(v)).toList());
        }
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load ads videos: $e', snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> likeAdsVideo(int videoId) async {
    final index = adsVideos.indexWhere((v) => v.id == videoId);
    if (index == -1) return;

    final current = adsVideos[index];
    final updatedIsLiked = !current.isLiked;
    final updatedLikes = updatedIsLiked ? current.likes + 1 : (current.likes > 0 ? current.likes - 1 : 0);

    adsVideos[index] = current.copyWith(isLiked: updatedIsLiked, likes: updatedLikes);

    try {
      await _apiService.post(
        ApiEndpoints.adsVideoLike,
        body: {'video_id': videoId.toString()},
      );
    } catch (_) {}
  }
}
