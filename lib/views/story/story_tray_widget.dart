import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;
import 'package:telsoworld/core/constants/api_endpoints.dart';
import 'package:telsoworld/core/services/session_token_store.dart';
import 'package:telsoworld/core/services/storage_service.dart';
import 'package:telsoworld/models/story_model.dart';
import 'package:telsoworld/views/story/story_viewer_screen.dart';
import 'package:telsoworld/views/upload/reel_upload_view.dart';

class StoryTrayWidget extends StatefulWidget {
  const StoryTrayWidget({super.key});

  @override
  State<StoryTrayWidget> createState() => _StoryTrayWidgetState();
}

class _StoryTrayWidgetState extends State<StoryTrayWidget> {
  final ImagePicker _picker = ImagePicker();
  List<UserStoryGroup> _storyGroups = [];
  bool _isPostingStory = false;

  @override
  void initState() {
    super.initState();
    _fetchStories();
  }

  Future<void> _fetchStories() async {
    try {
      final token = await SessionTokenStore.getToken();
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/reporter/stories');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['data'] is List) {
          final groups = (data['data'] as List)
              .map((g) => UserStoryGroup.fromJson(g as Map<String, dynamic>))
              .where((g) => g.stories.isNotEmpty)
              .toList();

          if (mounted) {
            setState(() {
              _storyGroups = groups;
            });
          }
        }
      }
    } catch (_) {}
  }

  void _showAddStoryOrPostSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF161622),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Create & Share',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 18),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD70F64).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD70F64)),
                  ),
                  title: const Text('Add to Story', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Disappears after 24 hours', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _pickAndUploadStory();
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF8008).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.video_collection_rounded, color: Color(0xFFFF8008)),
                  ),
                  title: const Text('Create Reel Video', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Short vertical video with music', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const ReelUploadScreen(initialMode: 'video')),
                    );
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38EF7D).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: Color(0xFF38EF7D)),
                  ),
                  title: const Text('Post Photo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Photo with optional music/sound', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const ReelUploadScreen(initialMode: 'photo')),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadStory() async {
    String? pickedPath;
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 88);
      if (picked != null) {
        pickedPath = picked.path;
      }
    } catch (_) {
      try {
        final res = await FilePicker.platform.pickFiles(type: FileType.image);
        if (res != null && res.files.single.path != null) {
          pickedPath = res.files.single.path;
        }
      } catch (_) {}
    }

    if (pickedPath == null) return;

    final token = await SessionTokenStore.getToken();
    if (token.isEmpty) {
      Get.snackbar('Login Required', 'Please login to post stories', backgroundColor: const Color(0xFF1E1E24), colorText: Colors.white);
      return;
    }

    setState(() => _isPostingStory = true);

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiEndpoints.baseUrl}/reporter/stories'),
      );
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });
      request.fields['media_type'] = 'image';
      request.fields['caption'] = 'Telso Moment ✨';
      request.files.add(await http.MultipartFile.fromPath('file', pickedPath, filename: path.basename(pickedPath)));

      final streamed = await request.send().timeout(const Duration(seconds: 40));
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        Get.snackbar(
          'Story Added! ⏳',
          'Your 24-hour story is now active for your followers.',
          backgroundColor: const Color(0xFF161622),
          colorText: const Color(0xFF10B981),
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
        );
        _fetchStories();
      } else {
        Get.snackbar('Story Upload Failed', 'Please try again', backgroundColor: const Color(0xFF1E1E24), colorText: Colors.redAccent);
      }
    } catch (e) {
      Get.snackbar('Error', 'Unable to upload story: $e', backgroundColor: const Color(0xFF1E1E24), colorText: Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isPostingStory = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 98,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: 1 + _storyGroups.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          if (index == 0) {
            // Your story button
            return GestureDetector(
              onTap: _isPostingStory ? null : _showAddStoryOrPostSheet,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      Obx(() {
                        final storage = Get.isRegistered<StorageService>() ? Get.find<StorageService>() : null;
                        final myAvatar = storage?.profileImage.value ?? '';

                        return Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24, width: 1.5),
                            color: const Color(0xFF22222E),
                          ),
                          child: ClipOval(
                            child: _isPostingStory
                                ? const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD70F64)),
                                  )
                                : (myAvatar.isNotEmpty
                                    ? Image.network(
                                        ApiEndpoints.mediaUrl(myAvatar),
                                        fit: BoxFit.cover,
                                        width: 60,
                                        height: 60,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.person, color: Colors.white70, size: 30),
                                      )
                                    : const Icon(Icons.person, color: Colors.white70, size: 30)),
                          ),
                        );
                      }),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: Color(0xFFD70F64),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add, color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Your story',
                    style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }

          final groupIndex = index - 1;
          final group = _storyGroups[groupIndex];

          return GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => StoryViewerScreen(
                    storyGroups: _storyGroups,
                    initialGroupIndex: groupIndex,
                  ),
                ),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Instagram story gradient ring
                Container(
                  width: 62,
                  height: 62,
                  padding: const EdgeInsets.all(2.5),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        Color(0xFFFBAA47),
                        Color(0xFFD91A46),
                        Color(0xFFA60F93),
                      ],
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black,
                    ),
                    child: CircleAvatar(
                      backgroundImage: group.profileImage.isNotEmpty
                          ? NetworkImage(ApiEndpoints.mediaUrl(group.profileImage))
                          : null,
                      backgroundColor: const Color(0xFF2A2A38),
                      child: group.profileImage.isEmpty
                          ? Text(
                              group.name.isNotEmpty ? group.name[0].toUpperCase() : 'U',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                SizedBox(
                  width: 64,
                  child: Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
