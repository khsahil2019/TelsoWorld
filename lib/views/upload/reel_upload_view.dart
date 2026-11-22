import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:telsoworld/controllers/main_nav_controller.dart';
import 'package:telsoworld/core/constants/api_endpoints.dart';
import 'package:telsoworld/core/services/session_token_store.dart';
import 'package:video_player/video_player.dart';

const _kUploadPink = Color(0xFFD70F64);

/// ---------------------------------------------------------------------------
/// 📸 ReelUploadScreen (Instagram-Style Step-by-Step Creator Studio)
/// ---------------------------------------------------------------------------
/// Modes:
/// - POST       (Photo post with optional audio)
/// - STORY      (24-Hour disappearing Story)
/// - REEL       (Short video reel)
/// - AD / PROMO (Sponsored promotion with Budget & Target Web Link)
///
/// Flow:
/// - Step 1: Media Select & Preview (Auto-opens gallery on launch)
/// - Step 2: Add Details (Caption, Audio title, Ad settings & Share)
/// ---------------------------------------------------------------------------
class ReelUploadScreen extends StatefulWidget {
  final String initialMode; // 'reel' | 'post' | 'story' | 'ad'

  const ReelUploadScreen({
    super.key,
    this.initialMode = 'reel',
  });

  @override
  State<ReelUploadScreen> createState() => _ReelUploadScreenState();
}

class _ReelUploadScreenState extends State<ReelUploadScreen> {
  final ImagePicker _picker = ImagePicker();

  // Mode: 'reel', 'post', 'story', 'ad'
  late String _activeMode;

  // Step: 1 = Media Preview & Trim, 2 = Caption, Details & Share
  int _currentStep = 1;

  File? _selectedFile;
  VideoPlayerController? _videoController;
  bool _isVideo = false;
  bool _isPlaying = false;
  bool _isUploading = false;
  bool _autoPickerLaunched = false;

  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _audioTitleController = TextEditingController();
  final TextEditingController _targetUrlController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();

  final List<String> _modes = ['POST', 'STORY', 'REEL', 'AD'];

  @override
  void initState() {
    super.initState();
    final modeNormalized = widget.initialMode.toLowerCase().trim();
    if (modeNormalized == 'photo' || modeNormalized == 'post') {
      _activeMode = 'POST';
    } else if (modeNormalized == 'story') {
      _activeMode = 'STORY';
    } else if (modeNormalized == 'ad' || modeNormalized == 'ads') {
      _activeMode = 'AD';
    } else {
      _activeMode = 'REEL';
    }

    // Auto-launch gallery picker on opening if no media selected
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_autoPickerLaunched && _selectedFile == null) {
        _autoPickerLaunched = true;
        _pickMediaFromGallery();
      }
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _captionController.dispose();
    _audioTitleController.dispose();
    _targetUrlController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  void _onModeChanged(String newMode) {
    if (_selectedFile != null) {
      if (_isVideo && newMode == 'POST') {
        Get.snackbar(
          'Video Selected',
          'POST is disabled for videos. Choose REEL, STORY, or AD.',
          backgroundColor: const Color(0xFF1E1E24),
          colorText: const Color(0xFFFF9100),
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
        return;
      }
      if (!_isVideo && (newMode == 'REEL' || newMode == 'AD')) {
        Get.snackbar(
          'Photo Selected',
          '$newMode is disabled for photos. Choose POST or STORY.',
          backgroundColor: const Color(0xFF1E1E24),
          colorText: const Color(0xFFFF9100),
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
        return;
      }
    }

    if (_activeMode == newMode) return;
    setState(() {
      _activeMode = newMode;
    });
  }

  /// 📥 Pick Media with resilient ImagePicker + FilePicker fallback
  Future<void> _pickMediaFromGallery() async {
    final bool wantsVideo = (_activeMode == 'REEL' || _activeMode == 'AD');

    File? chosen;

    try {
      if (wantsVideo) {
        final x = await _picker.pickVideo(source: ImageSource.gallery);
        if (x != null) chosen = File(x.path);
      } else {
        final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
        if (x != null) chosen = File(x.path);
      }
    } catch (_) {
      // Fallback silently without throwing unhandled platform exception
    }

    if (chosen == null) {
      try {
        final res = await FilePicker.platform.pickFiles(
          type: wantsVideo ? FileType.video : FileType.image,
          allowMultiple: false,
        );
        if (res != null && res.files.isNotEmpty && res.files.single.path != null) {
          chosen = File(res.files.single.path!);
        }
      } catch (_) {}
    }

    if (chosen != null) {
      await _loadSelectedFile(chosen);
    }
  }

  /// 📸 Capture from Camera
  Future<void> _pickMediaFromCamera() async {
    final bool wantsVideo = (_activeMode == 'REEL' || _activeMode == 'AD');
    File? chosen;

    try {
      if (wantsVideo) {
        final x = await _picker.pickVideo(source: ImageSource.camera);
        if (x != null) chosen = File(x.path);
      } else {
        final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 92);
        if (x != null) chosen = File(x.path);
      }
    } catch (_) {}

    if (chosen != null) {
      await _loadSelectedFile(chosen);
    }
  }

  Future<void> _loadSelectedFile(File file) async {
    _videoController?.dispose();
    _videoController = null;

    final ext = path.extension(file.path).toLowerCase();
    final isVid = ext.contains('mp4') ||
        ext.contains('mov') ||
        ext.contains('mkv') ||
        ext.contains('webm') ||
        ext.contains('avi') ||
        ext.contains('3gp');

    if (isVid) {
      final ctrl = VideoPlayerController.file(file);
      await ctrl.initialize();
      await ctrl.setLooping(true);
      ctrl.play();

      setState(() {
        _selectedFile = file;
        _isVideo = true;
        _videoController = ctrl;
        _isPlaying = true;
        _currentStep = 1;
        // Point 3: If video is selected, POST is disabled -> auto-switch to REEL
        if (_activeMode == 'POST') {
          _activeMode = 'REEL';
        }
      });
    } else {
      setState(() {
        _selectedFile = file;
        _isVideo = false;
        _isPlaying = false;
        _currentStep = 1;
        // Point 3: If photo is selected, REEL & AD are disabled -> auto-switch to POST
        if (_activeMode == 'REEL' || _activeMode == 'AD') {
          _activeMode = 'POST';
        }
      });
    }
  }

  /// 🚀 Upload to backend based on active mode
  Future<void> _shareContent() async {
    if (_selectedFile == null) {
      Get.snackbar('Select Media', 'Please select a video or photo to upload.',
          backgroundColor: const Color(0xFF1E1E24), colorText: Colors.white);
      return;
    }

    final token = await SessionTokenStore.getToken();
    if (token.isEmpty) {
      Get.snackbar('Login Required', 'Please log in to upload content.',
          backgroundColor: const Color(0xFF1E1E24), colorText: Colors.white);
      return;
    }

    setState(() => _isUploading = true);

    try {
      if (_activeMode == 'STORY') {
        // ── Upload 24-hr Story ──
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('${ApiEndpoints.baseUrl}/reporter/stories'),
        );
        request.headers.addAll({
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        });
        request.fields['media_type'] = _isVideo ? 'video' : 'image';
        request.fields['caption'] = _captionController.text.trim().isNotEmpty
            ? _captionController.text.trim()
            : 'Telso Story ✨';
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            _selectedFile!.path,
            filename: path.basename(_selectedFile!.path),
          ),
        );

        final res = await request.send().timeout(const Duration(seconds: 45));
        if (res.statusCode >= 200 && res.statusCode < 300) {
          Get.snackbar(
            'Story Shared! 🌟',
            'Your story is now live for 24 hours!',
            backgroundColor: const Color(0xFF161622),
            colorText: const Color(0xFF10B981),
            snackPosition: SnackPosition.BOTTOM,
          );
          _finishAndNavigate();
          return;
        }
      } else {
        // ── Upload Reel, Post, or Ad ──
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('${ApiEndpoints.baseUrl}/reporter/upload-video'),
        );
        request.headers.addAll({
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        });

        final caption = _captionController.text.trim().isNotEmpty
            ? _captionController.text.trim()
            : (_activeMode == 'AD' ? 'Sponsored Promotion' : 'New Post');

        request.fields['title'] = caption;
        request.fields['subject'] = caption;
        request.fields['name'] = caption;
        request.fields['video_type'] = (_activeMode == 'AD') ? 'ads' : 'normal';
        request.fields['media_type'] = (_activeMode == 'POST' && !_isVideo) ? 'photo' : 'video';

        if (_audioTitleController.text.trim().isNotEmpty) {
          request.fields['audio_title'] = _audioTitleController.text.trim();
        }

        if (_activeMode == 'AD') {
          request.fields['target_url'] = _targetUrlController.text.trim();
          request.fields['budget'] = _budgetController.text.trim().isNotEmpty
              ? _budgetController.text.trim()
              : '500';
        }

        final fieldName = _isVideo ? 'video' : 'photo';
        request.files.add(
          await http.MultipartFile.fromPath(
            fieldName,
            _selectedFile!.path,
            filename: path.basename(_selectedFile!.path),
          ),
        );

        final streamed = await request.send().timeout(const Duration(seconds: 60));
        final response = await http.Response.fromStream(streamed);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final resBody = jsonDecode(response.body);
          final isPending = resBody['status_code'] == 'Pending' ||
              resBody['video']?['status'] == 'Pending' ||
              resBody['data']?['status'] == 'Pending';

          Get.snackbar(
            isPending ? 'Submitted for Approval ⏳' : 'Shared Successfully! 🚀',
            isPending
                ? 'Your post was submitted and is awaiting admin approval before going live.'
                : 'Your post is now published and live on the feed!',
            backgroundColor: const Color(0xFF161622),
            colorText: isPending ? const Color(0xFFFFB800) : const Color(0xFF10B981),
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 4),
          );
          _finishAndNavigate();
          return;
        } else if (response.statusCode == 403) {
          final errBody = jsonDecode(response.body);
          Get.snackbar(
            'Upload Not Permitted 🔒',
            errBody['message'] ?? 'Admin permission is required to upload reels.',
            backgroundColor: const Color(0xFF1E1E24),
            colorText: const Color(0xFFFFB800),
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 4),
          );
        } else {
          final errBody = jsonDecode(response.body);
          Get.snackbar('Upload Failed', errBody['message'] ?? 'Please try again',
              backgroundColor: const Color(0xFF1E1E24), colorText: Colors.redAccent);
        }
      }
    } catch (e) {
      Get.snackbar('Error', 'Unable to upload: $e',
          backgroundColor: const Color(0xFF1E1E24), colorText: Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _finishAndNavigate() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    } else {
      try {
        Get.find<MainNavController>().changeTab(0);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // 🔝 Top Navigation Bar (Close, Title, Next / Share)
            _buildTopBar(),

            // 📱 Step Content
            Expanded(
              child: _currentStep == 1
                  ? _buildStepOneMediaPreview()
                  : _buildStepTwoDetails(),
            ),

            // 🎛️ Bottom Instagram-Style Mode Selector (Only on Step 1)
            if (_currentStep == 1) _buildBottomModeSelector(),
          ],
        ),
      ),
    );
  }

  /// 🔝 Clean Top Bar matching Instagram Camera
  Widget _buildTopBar() {
    final bool hasMedia = _selectedFile != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(
              _currentStep == 2 ? Icons.arrow_back_ios_new_rounded : Icons.close_rounded,
              color: Colors.white,
              size: 24,
            ),
            onPressed: () {
              if (_currentStep == 2) {
                setState(() => _currentStep = 1);
              } else {
                _finishAndNavigate();
              }
            },
          ),
          Text(
            _currentStep == 1 ? 'New $_activeMode' : 'Share',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          if (_currentStep == 1)
            TextButton(
              onPressed: hasMedia ? () => setState(() => _currentStep = 2) : null,
              child: Text(
                'Next',
                style: TextStyle(
                  color: hasMedia ? const Color(0xFF3897F0) : Colors.white24,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            TextButton(
              onPressed: _isUploading ? null : _shareContent,
              child: _isUploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3897F0)),
                    )
                  : const Text(
                      'Share',
                      style: TextStyle(
                        color: Color(0xFF3897F0),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  /// 🎬 Step 1: Media Preview & Change Options
  Widget _buildStepOneMediaPreview() {
    return Column(
      children: [
        // Media Preview Container (Square / 4:5 Instagram aspect)
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF121214),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _selectedFile == null
                  ? _buildEmptyMediaCard()
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_isVideo && _videoController != null && _videoController!.value.isInitialized)
                          Center(
                            child: AspectRatio(
                              aspectRatio: _videoController!.value.aspectRatio,
                              child: VideoPlayer(_videoController!),
                            ),
                          )
                        else if (!_isVideo && _selectedFile != null)
                          Image.file(
                            _selectedFile!,
                            fit: BoxFit.contain,
                          )
                        else
                          const Center(
                            child: CircularProgressIndicator(color: _kUploadPink),
                          ),

                        // Play/Pause Overlay for Videos
                        if (_isVideo)
                          Center(
                            child: GestureDetector(
                              onTap: () {
                                if (_videoController == null) return;
                                setState(() {
                                  if (_videoController!.value.isPlaying) {
                                    _videoController!.pause();
                                    _isPlaying = false;
                                  } else {
                                    _videoController!.play();
                                    _isPlaying = true;
                                  }
                                });
                              },
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.55),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 36,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ),

        // Quick Gallery / Camera Switcher Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickMediaFromGallery,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pickMediaFromCamera,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF262626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 📭 Empty state when no media is chosen yet
  Widget _buildEmptyMediaCard() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _kUploadPink.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              (_activeMode == 'POST') ? Icons.photo_outlined : Icons.videocam_outlined,
              color: _kUploadPink,
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Select $_activeMode Media',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap Gallery or Camera to select content',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// 📝 Step 2: Instagram-style Caption & Share Details
  Widget _buildStepTwoDetails() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // Media Thumbnail + Caption Input Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white24),
                color: const Color(0xFF1E1E24),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _selectedFile != null
                    ? (_isVideo
                        ? const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 30))
                        : Image.file(_selectedFile!, fit: BoxFit.cover))
                    : const SizedBox(),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextField(
                controller: _captionController,
                maxLines: 4,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Write a caption...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
        const Divider(color: Colors.white12, height: 32),

        // Audio Track Input
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.music_note_rounded, color: Colors.white70),
          title: TextField(
            controller: _audioTitleController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Add music / sound title...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              border: InputBorder.none,
            ),
          ),
        ),
        const Divider(color: Colors.white12, height: 24),

        // If AD Mode: Budget and Target URL Settings
        if (_activeMode == 'AD') ...[
          const Text(
            'Promotion Settings 📢',
            style: TextStyle(color: _kUploadPink, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _targetUrlController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF1E1E24),
              prefixIcon: const Icon(Icons.link_rounded, color: Colors.white60),
              hintText: 'Target Website Link (https://...)',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _budgetController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF1E1E24),
              prefixIcon: const Icon(Icons.currency_rupee_rounded, color: Colors.white60),
              hintText: 'Daily Budget (e.g. 500)',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),
        ],

        const SizedBox(height: 24),
        // Big Gradient Share Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isUploading ? null : _shareContent,
            style: ElevatedButton.styleFrom(
              backgroundColor: _activeMode == 'STORY' ? const Color(0xFFFBAA47) : _kUploadPink,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isUploading
                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                : Text(
                    _activeMode == 'STORY'
                        ? 'Share to Your Story 🌟'
                        : (_activeMode == 'AD' ? 'Launch Promotion 📢' : 'Share Post 🚀'),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  /// 🎛️ Bottom Mode Selector matching Instagram Camera UI (POST | STORY | REEL | AD)
  Widget _buildBottomModeSelector() {
    return Container(
      height: 52,
      color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _modes.map((mode) {
          final isSelected = _activeMode == mode;
          bool isDisabled = false;
          if (_selectedFile != null) {
            if (_isVideo && mode == 'POST') isDisabled = true;
            if (!_isVideo && (mode == 'REEL' || mode == 'AD')) isDisabled = true;
          }

          return GestureDetector(
            onTap: () => _onModeChanged(mode),
            child: Opacity(
              opacity: isDisabled ? 0.28 : 1.0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  mode,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white38,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: 0.8,
                    decoration: isDisabled ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
