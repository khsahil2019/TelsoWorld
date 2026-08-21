import 'dart:convert';
import 'package:get/get.dart';
import 'package:telsoworld/core/constants/api_endpoints.dart';
import 'package:telsoworld/core/services/api_service.dart';
import 'package:telsoworld/models/comment_model.dart';

class CommentController extends GetxController {
  final ApiService _apiService = Get.find<ApiService>();

  final RxList<CommentModel> comments = <CommentModel>[].obs;
  final RxBool isLoading = false.obs;

  Future<void> fetchComments(int videoId) async {
    isLoading.value = true;
    try {
      final response = await _apiService.get(
        ApiEndpoints.comments,
        queryParams: {'video_id': videoId.toString()},
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['data'] != null && json['data'] is List) {
          final List list = json['data'];
          comments.assignAll(list.map((c) => CommentModel.fromJson(c)).toList());
        }
      }
    } catch (_) {
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> addComment(int videoId, String text) async {
    if (text.trim().isEmpty) return;
    try {
      final response = await _apiService.post(
        ApiEndpoints.addComment,
        body: {'video_id': videoId.toString(), 'comment': text.trim()},
      );
      if (response.statusCode == 200) {
        fetchComments(videoId);
      }
    } catch (_) {}
  }
}
