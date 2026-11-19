import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:telsoworld/core/constants/api_endpoints.dart';
import 'package:telsoworld/core/services/session_token_store.dart';
import 'package:telsoworld/core/services/storage_service.dart';
import 'package:telsoworld/core/constants/app_colors.dart';

class EditProfileScreen extends StatefulWidget {
  final String currentName;
  final String currentUsername;
  final String currentBio;
  final String currentAvatar;

  const EditProfileScreen({
    super.key,
    required this.currentName,
    required this.currentUsername,
    required this.currentBio,
    required this.currentAvatar,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;

  File? _pickedImage;
  bool _isSaving = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _usernameController = TextEditingController(text: widget.currentUsername);
    _bioController = TextEditingController(text: widget.currentBio);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 88);
      if (x != null) {
        setState(() => _pickedImage = File(x.path));
      }
    } catch (e) {
      Get.snackbar('Image Picker', 'Unable to pick image: $e',
          backgroundColor: const Color(0xFF1E1E24), colorText: Colors.white);
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final bio = _bioController.text.trim();

    if (name.isEmpty) {
      Get.snackbar('Error', 'Name cannot be empty',
          backgroundColor: const Color(0xFF1E1E24), colorText: Colors.redAccent);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final token = await SessionTokenStore.getToken();
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/reporter/profile');

      final request = http.MultipartRequest('PUT', uri);
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });
      request.fields['name'] = name;
      request.fields['username'] = username;
      request.fields['bio'] = bio;

      if (_pickedImage != null) {
        request.files.add(await http.MultipartFile.fromPath('avatar', _pickedImage!.path));
      }

      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        final profileImage = data['data']?['profile_image']?.toString() ?? '';

        if (Get.isRegistered<StorageService>()) {
          final storage = Get.find<StorageService>();
          if (profileImage.isNotEmpty) {
            storage.setProfileImage(profileImage);
          }
        }

        Get.snackbar(
          'Profile Updated! ✨',
          'Your profile information has been saved successfully.',
          backgroundColor: const Color(0xFF161622),
          colorText: const Color(0xFF10B981),
          snackPosition: SnackPosition.TOP,
        );

        if (mounted) Navigator.of(context).pop(true);
      } else {
        Get.snackbar('Error', 'Failed to update profile (${res.statusCode})',
            backgroundColor: const Color(0xFF1E1E24), colorText: Colors.redAccent);
      }
    } catch (e) {
      Get.snackbar('Error', 'Network error: $e',
          backgroundColor: const Color(0xFF1E1E24), colorText: Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Edit profile',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          _isSaving
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: AppColors.primaryPink, strokeWidth: 2),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.check_rounded, color: AppColors.primaryPink, size: 28),
                  onPressed: _saveProfile,
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // Avatar picker
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 46,
                          backgroundColor: const Color(0xFF1E1E24),
                          backgroundImage: _pickedImage != null
                              ? FileImage(_pickedImage!) as ImageProvider
                              : (widget.currentAvatar.isNotEmpty ? NetworkImage(widget.currentAvatar) : null),
                          child: (_pickedImage == null && widget.currentAvatar.isEmpty)
                              ? const Icon(Icons.person, color: Colors.white54, size: 48)
                              : null,
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryPink,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Change profile photo',
                      style: TextStyle(
                        color: Color(0xFF3897F0),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Name Field
            _buildTextField('Name', _nameController, Icons.badge_outlined),
            const SizedBox(height: 18),

            // Username Field
            _buildTextField('Username', _usernameController, Icons.alternate_email_rounded),
            const SizedBox(height: 18),

            // Bio Field
            _buildTextField('Bio', _bioController, Icons.info_outline_rounded, maxLines: 3),
            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPink,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.white38, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}
