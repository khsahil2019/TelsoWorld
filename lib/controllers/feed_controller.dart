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
        final Map<String, dynamic> json = jsonDecode(response.body);
        if (json['videos'] != null && json['videos'] is List) {
          final List list = json['videos'];
          videos.assignAll(list.map((v) => VideoModel.fromJson(v)).toList());
        }
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load video feed: $e', snackPosition: SnackPosition.BOTTOM);
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
      await _apiService.post(
        ApiEndpoints.normalVideoLike,
        body: {'video_id': videoId.toString()},
      );
    } catch (_) {}
  }

  Future<void> recordView(int videoId) async {
    try {
      await _apiService.post(
        ApiEndpoints.normalVideoView,
        body: {'video_id': videoId.toString()},
      );
    } catch (_) {}
  }
}
