import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:telsoworld/core/constants/api_endpoints.dart';
import 'package:telsoworld/core/services/storage_service.dart';

class UploadController extends GetxController {
  final StorageService _storageService = Get.find<StorageService>();
  final ImagePicker _picker = ImagePicker();

  final Rx<File?> selectedVideo = Rx<File?>(null);
  final RxBool isUploading = false.obs;
  final RxDouble uploadProgress = 0.0.obs;

  final titleController = TextEditingController();
  final descriptionController = TextEditingController();

  Future<void> pickVideo() async {
    final XFile? file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file != null) {
      selectedVideo.value = File(file.path);
    }
  }

  Future<void> uploadVideo() async {
    if (selectedVideo.value == null) {
      Get.snackbar('Error', 'Please select a video first.', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (titleController.text.trim().isEmpty) {
      Get.snackbar('Error', 'Please enter a video title.', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    isUploading.value = true;
    uploadProgress.value = 0.1;

    try {
      final uri = Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.uploadVideo}');
      final request = http.MultipartRequest('POST', uri);

      final token = _storageService.getToken();
      if (token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['title'] = titleController.text.trim();
      request.fields['description'] = descriptionController.text.trim();
      request.files.add(await http.MultipartFile.fromPath('video', selectedVideo.value!.path));

      uploadProgress.value = 0.5;
      final response = await request.send();

      if (response.statusCode == 200) {
        uploadProgress.value = 1.0;
        Get.snackbar('Success', 'Video uploaded successfully!', snackPosition: SnackPosition.BOTTOM);
        selectedVideo.value = null;
        titleController.clear();
        descriptionController.clear();
      } else {
        Get.snackbar('Upload Failed', 'Status code: ${response.statusCode}', snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar('Upload Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
    } finally {
      isUploading.value = false;
    }
  }

  @override
  void onClose() {
    titleController.dispose();
    descriptionController.dispose();
    super.onClose();
  }
}
