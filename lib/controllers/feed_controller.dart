import 'dart:convert';
import 'package:get/get.dart';
import 'package:telsoworld/core/constants/api_endpoints.dart';
import 'package:telsoworld/core/services/api_service.dart';
import 'package:telsoworld/models/video_model.dart';

class FeedController extends GetxController {
  final ApiService _apiService = Get.find<ApiService>();

  final RxList<VideoModel> videos = <VideoModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxInt activeIndex = 0.obs;

  @override
  void onInit() {
    super.onInit();
    fetchDashboardFeed();
  }

  Future<void> fetchDashboardFeed() async {
    isLoading.value = true;
    try {
      final response = await _apiService.get(ApiEndpoints.dashboard);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List list = [];
        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map<String, dynamic>) {
          if (decoded['videos'] is List) {
            list = decoded['videos'];
          } else if (decoded['data'] is List) {
            list = decoded['data'];
          }
        }
        videos.assignAll(
          list
              .whereType<Map<String, dynamic>>()
              .map((v) => VideoModel.fromJson(v))
              .toList(),
        );
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load dashboard feed: $e',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> likeVideo(int videoId) async {
    final index = videos.indexWhere((v) => v.id == videoId);
    if (index == -1) return;

    final current = videos[index];
    final updatedIsLiked = !current.isLiked;
    final updatedLikes = updatedIsLiked ? current.likes + 1 : (current.likes > 0 ? current.likes - 1 : 0);

    videos[index] = current.copyWith(isLiked: updatedIsLiked, likes: updatedLikes);

    try {
      final isAd = current.videoType == 'ads';
      final endpoint = isAd ? ApiEndpoints.adsVideoLike : ApiEndpoints.normalVideoLike;
      await _apiService.post(
        endpoint,
        body: {'video_id': videoId.toString()},
      );
    } catch (_) {}
  }

  Future<void> recordView(int videoId) async {
    final index = videos.indexWhere((v) => v.id == videoId);
    if (index == -1) return;

    final current = videos[index];
    try {
      final isAd = current.videoType == 'ads';
      final endpoint = isAd ? ApiEndpoints.adsVideoView : ApiEndpoints.normalVideoView;
      await _apiService.post(
        endpoint,
        body: {'video_id': videoId.toString()},
      );
    } catch (_) {}
  }
}
