import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/return_code.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;
import 'package:telsoworld/controllers/main_nav_controller.dart';
import 'package:telsoworld/core/services/session_token_store.dart';
import 'package:video_editor/video_editor.dart';
import 'package:video_player/video_player.dart';
import 'package:video_trimmer/video_trimmer.dart';

const _kUploadPink = Color(0xFFD70F64);
const _kDefaultMaxReelDuration = Duration(seconds: 60);
const _kAvailableReelLimits = [
  Duration(seconds: 30),
  Duration(seconds: 60),
];

class ReelUploadScreen extends StatefulWidget {
  const ReelUploadScreen({super.key});

  @override
  State<ReelUploadScreen> createState() => _ReelUploadScreenState();
}

class _ReelUploadScreenState extends State<ReelUploadScreen> {
  final ImagePicker _picker = ImagePicker();
  final Trimmer _trimmer = Trimmer();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  File? _selectedVideoFile;
  Duration? _videoDuration;
  double _trimStart = 0;
  double _trimEnd = 0;
  bool _isVideoLoading = false;
  bool _isPlaying = false;
  bool _isTrimming = false;
  bool _isUploading = false;
  bool _isEditing = false;
  String? _selectedSourceLabel;
  Duration _maxReelDuration = _kDefaultMaxReelDuration;
  int _lastHapticSecond = -1;

  @override
  void dispose() {
    _subjectController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final pickedVideo = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 10),
      );
      if (pickedVideo == null) {
        return;
      }

      final originalFile = File(pickedVideo.path);
      final editedFile = await _openVideoEditor(originalFile);
      if (editedFile == null) {
        return;
      }

      await _loadVideo(editedFile, source: source);
    } catch (error) {
      _showSnackBar('Unable to open video picker.\n$error');
    }
  }

  Future<File?> _openVideoEditor(File sourceFile) async {
    if (!mounted) {
      return null;
    }

    setState(() {
      _isEditing = true;
    });

    try {
      final result = await Navigator.of(context).push<File>(
        MaterialPageRoute<File>(
          builder: (_) => _ReelVideoEditorScreen(
            sourceFile: sourceFile,
            maxDuration: _maxReelDuration,
          ),
        ),
      );

      if (result == null) {
        return null;
      }

      if (!await result.exists()) {
        _showSnackBar('Edited reel file was not found.');
        return null;
      }

      return result;
    } finally {
      if (mounted) {
        setState(() {
          _isEditing = false;
        });
      }
    }
  }

  Future<void> _loadVideo(File file, {required ImageSource source}) async {
    setState(() {
      _isVideoLoading = true;
      _selectedVideoFile = null;
      _videoDuration = null;
      _trimStart = 0;
      _trimEnd = 0;
      _isPlaying = false;
    });

    try {
      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      final duration = controller.value.duration;
      await controller.dispose();

      if (duration == Duration.zero) {
        throw Exception('The selected video has no playable duration.');
      }

      await _trimmer.loadVideo(videoFile: file);

      if (!mounted) {
        return;
      }

      final trimmedEndInSeconds = math.min(
        duration.inMilliseconds / 1000,
        _maxReelDuration.inSeconds.toDouble(),
      );

      setState(() {
        _selectedVideoFile = file;
        _videoDuration = duration;
        _trimStart = 0;
        _trimEnd = trimmedEndInSeconds;
        _selectedSourceLabel = source == ImageSource.camera
            ? 'Camera'
            : 'Gallery';
      });

      if (duration > _maxReelDuration) {
        _showSnackBar(
          'This video is longer than ${_maxReelDuration.inSeconds} seconds. Trim it before posting.',
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showSnackBar('Unable to load the selected video.\n$error');
    } finally {
      if (mounted) {
        setState(() {
          _isVideoLoading = false;
        });
      }
    }
  }

  Future<void> _openSourcePicker() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Create reel',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose a source for your short video reel.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 20),
                _SourceActionTile(
                  icon: Icons.video_library_rounded,
                  title: 'Upload from gallery',
                  subtitle: 'Pick an existing video and trim it.',
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickVideo(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 12),
                _SourceActionTile(
                  icon: Icons.videocam_rounded,
                  title: 'Record with camera',
                  subtitle: 'Capture a reel and trim before posting.',
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickVideo(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool get _needsTrimmedExport {
    if (_selectedVideoFile == null || _videoDuration == null) {
      return false;
    }

    final totalSeconds = _videoDuration!.inMilliseconds / 1000;
    return _trimStart > 0.05 ||
        _trimEnd < totalSeconds - 0.05 ||
        totalSeconds > _maxReelDuration.inSeconds;
  }

  Duration get _selectedDuration {
    final seconds = (_trimEnd - _trimStart).clamp(
      0,
      _maxReelDuration.inSeconds.toDouble(),
    );
    return Duration(milliseconds: (seconds * 1000).round());
  }

  Duration get _trimStartDuration => Duration(
        milliseconds: (_trimStart * 1000).round(),
      );

  Duration get _trimEndDuration => Duration(
        milliseconds: (_trimEnd * 1000).round(),
      );

  Future<File?> _prepareUploadFile() async {
    if (_selectedVideoFile == null) {
      return null;
    }

    if (!_needsTrimmedExport) {
      return _selectedVideoFile;
    }

    setState(() {
      _isTrimming = true;
      _isPlaying = false;
    });

    try {
      String? outputPath;
      await _trimmer.saveTrimmedVideo(
        startValue: _trimStart,
        endValue: _trimEnd,
        videoFolderName: 'TelsoWorldReels',
        videoFileName: 'reel_${DateTime.now().millisecondsSinceEpoch}',
        onSave: (value) {
          outputPath = value;
        },
      );

      if (outputPath == null || outputPath!.isEmpty) {
        throw Exception('Trim export did not produce a file.');
      }

      return File(outputPath!);
    } catch (error) {
      _showSnackBar('Unable to trim the reel.\n$error');
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _isTrimming = false;
        });
      }
    }
  }

  Future<void> _uploadReel() async {
    if (_selectedVideoFile == null || _videoDuration == null) {
      _showSnackBar('Select a video reel first.');
      return;
    }

    if (_subjectController.text.trim().isEmpty) {
      _showSnackBar('Enter a reel subject before uploading.');
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Enter your display name before uploading.');
      return;
    }

    if (_selectedDuration > _maxReelDuration) {
      _showSnackBar(
        'Reels must be ${_maxReelDuration.inSeconds} seconds or shorter.',
      );
      return;
    }

    final token = await SessionTokenStore.getToken();

    if (token.isEmpty) {
      _showSnackBar('Login is required before uploading a reel.');
      return;
    }

    setState(() {
      _isUploading = true;
      _isPlaying = false;
    });

    try {
      final uploadFile = await _prepareUploadFile();
      if (uploadFile == null) {
        return;
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://telsoworld.com/api/reporter/upload-video'),
      );

      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });
      request.fields['subject'] = _subjectController.text.trim();
      request.fields['name'] = _nameController.text.trim();
      request.files.add(
        await http.MultipartFile.fromPath(
          'video',
          uploadFile.path,
          filename: path.basename(uploadFile.path),
        ),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final response = await http.Response.fromStream(streamedResponse);

      Map<String, dynamic>? responseJson;
      try {
        responseJson = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        responseJson = null;
      }

      final message =
          responseJson?['message']?.toString() ??
          'Upload failed with status ${response.statusCode}.';

      if (!mounted) {
        return;
      }

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          (responseJson == null || responseJson['status'] != false)) {
        Navigator.of(context).pop(true);
        return;
      }

      _showSnackBar(message);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showSnackBar('Unable to upload reel.\n$error');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _togglePlayback() async {
    if (_selectedVideoFile == null || _isVideoLoading || _isTrimming) {
      return;
    }

    final playbackState = await _trimmer.videoPlaybackControl(
      startValue: _trimStart,
      endValue: _trimEnd,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isPlaying = playbackState;
    });
  }

  void _clearSelectedVideo() {
    setState(() {
      _selectedVideoFile = null;
      _videoDuration = null;
      _trimStart = 0;
      _trimEnd = 0;
      _isPlaying = false;
      _selectedSourceLabel = null;
    });
  }

  void _updateMaxDuration(Duration duration) {
    if (_maxReelDuration == duration) {
      return;
    }

    setState(() {
      _maxReelDuration = duration;

      if (_videoDuration != null) {
        final maxTrimEnd = math.min(
          _videoDuration!.inMilliseconds / 1000,
          _maxReelDuration.inSeconds.toDouble(),
        );

        _trimEnd = _trimEnd == 0 ? maxTrimEnd : _trimEnd.clamp(0, maxTrimEnd);
        _trimStart = _trimStart.clamp(0, _trimEnd);
      }

      _isPlaying = false;
    });

    if (_videoDuration != null && _videoDuration! > _maxReelDuration) {
      _showSnackBar(
        'Trim limit changed to ${_maxReelDuration.inSeconds} seconds.',
      );
    }
  }

  void _onTrimChanged({
    required double start,
    required double end,
  }) {
    final boundedEnd = math.min(
      end,
      _maxReelDuration.inSeconds.toDouble(),
    ).toDouble();
    final boundedStart = start.clamp(0, boundedEnd).toDouble();

    setState(() {
      _trimStart = boundedStart;
      _trimEnd = boundedEnd;
      _isPlaying = false;
    });

    final secondMarker = _selectedDuration.inSeconds;
    if (secondMarker != _lastHapticSecond) {
      _lastHapticSecond = secondMarker;
      HapticFeedback.selectionClick();
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF242424),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final canInteract =
        !_isUploading && !_isTrimming && !_isVideoLoading && !_isEditing;
    final hasSelectedVideo = _selectedVideoFile != null;
    final canPost = canInteract && hasSelectedVideo;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _isUploading
                        ? null
                        : () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            } else {
                              try {
                                Get.find<MainNavController>().changeTab(0);
                              } catch (_) {}
                            }
                          },
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  const Expanded(
                    child: Text(
                      'Create reel',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: canPost ? _uploadReel : null,
                    child: _isUploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Post',
                            style: TextStyle(
                              color: canPost ? Colors.white : Colors.white38,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroSection(),
                    const SizedBox(height: 18),
                    _buildInfoCards(),
                    const SizedBox(height: 18),
                    _buildDetailsCard(),
                    const SizedBox(height: 18),
                    _buildPostCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: !canInteract
                  ? null
                  : hasSelectedVideo
                  ? _uploadReel
                  : _openSourcePicker,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kUploadPink,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _kUploadPink.withValues(alpha: 0.55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isTrimming
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Preparing reel...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    )
                  : _isEditing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Opening editor...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      hasSelectedVideo ? 'Upload reel' : 'Choose reel video',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    if (_selectedVideoFile == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _kUploadPink.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_display_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Upload a short reel',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Select a video, trim it to ${_maxReelDuration.inSeconds} seconds or less, then upload it as a reel.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isVideoLoading
                        ? null
                        : () => _pickVideo(ImageSource.gallery),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.video_library_outlined),
                    label: const Text('Gallery'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isVideoLoading
                        ? null
                        : () => _pickVideo(ImageSource.camera),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kUploadPink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.videocam_outlined),
                    label: const Text('Camera'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              width: double.infinity,
              height: 360,
              child: ColoredBox(
                color: Colors.black,
                child: _isVideoLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: _kUploadPink),
                      )
                    : VideoViewer(trimmer: _trimmer),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  path.basename(_selectedVideoFile!.path),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: _isUploading ? null : _clearSelectedVideo,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Remove'),
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Trim reel',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Keep the most important part of the clip. Reels cannot exceed ${_maxReelDuration.inSeconds} seconds.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          _DurationLimitSelector(
            selectedLimit: _maxReelDuration,
            onChanged: _isUploading || _isVideoLoading || _isTrimming
                ? null
                : _updateMaxDuration,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _TimelineInfoPill(
                  label: 'Start',
                  value: _formatDuration(_trimStartDuration),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TimelineInfoPill(
                  label: 'End',
                  value: _formatDuration(_trimEndDuration),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TimelineInfoPill(
                  label: 'Clip',
                  value: _formatDuration(_selectedDuration),
                  highlight: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SelectedDurationProgress(
            selected: _selectedDuration,
            maxAllowed: _maxReelDuration,
          ),
          const SizedBox(height: 12),
          Padding(
            // Extra left breathing space makes grabbing the start handle easier.
            padding: const EdgeInsets.only(left: 14),
            child: TrimViewer(
              trimmer: _trimmer,
              viewerHeight: 64,
              viewerWidth: MediaQuery.of(context).size.width - 86,
              maxVideoLength: _maxReelDuration,
              onChangeStart: (value) {
                _onTrimChanged(start: value, end: _trimEnd);
              },
              onChangeEnd: (value) {
                _onTrimChanged(start: _trimStart, end: value);
              },
              onChangePlaybackState: (value) {
                setState(() {
                  _isPlaying = value;
                });
              },
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: IconButton.filled(
              onPressed: _isUploading || _isVideoLoading
                  ? null
                  : _togglePlayback,
              style: IconButton.styleFrom(
                backgroundColor: _kUploadPink,
                foregroundColor: Colors.white,
                fixedSize: const Size(56, 56),
              ),
              icon: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCards() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _InfoChip(label: 'Source', value: _selectedSourceLabel ?? 'No video'),
        _InfoChip(
          label: 'Original',
          value: _videoDuration == null
              ? '--:--'
              : _formatDuration(_videoDuration!),
        ),
        _InfoChip(
          label: 'Selected',
          value: _selectedVideoFile == null
              ? '--:--'
              : _formatDuration(_selectedDuration),
          highlight: _selectedVideoFile != null,
        ),
        _InfoChip(
          label: 'Limit',
          value: _formatDuration(_maxReelDuration),
        ),
      ],
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reel details',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'These fields map directly to the multipart form-data API payload.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          _UploadField(
            controller: _subjectController,
            label: 'Subject',
            hintText: 'Describe the reel topic',
            maxLines: 2,
          ),
          const SizedBox(height: 14),
          _UploadField(
            controller: _nameController,
            label: 'Name',
            hintText: 'Enter reporter or creator name',
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Posting rules',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _RuleRow(
            text: 'Only video files can be selected for reels.',
            isActive: true,
          ),
          _RuleRow(
            text:
                'Trim selection is capped by the chosen 30 or 60 second limit.',
            isActive: true,
          ),
          _RuleRow(
            text:
                'Upload uses multipart/form-data with subject, name, and video.',
            isActive: true,
          ),
        ],
      ),
    );
  }
}

class _UploadField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final int maxLines;

  const _UploadField({
    required this.controller,
    required this.label,
    required this.hintText,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.38)),
            filled: true,
            fillColor: const Color(0xFF1C1C1C),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _InfoChip({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 154,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: highlight
            ? _kUploadPink.withValues(alpha: 0.12)
            : const Color(0xFF111111),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlight
              ? _kUploadPink.withValues(alpha: 0.35)
              : Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.64),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineInfoPill extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _TimelineInfoPill({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlight
            ? _kUploadPink.withValues(alpha: 0.14)
            : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight
              ? _kUploadPink.withValues(alpha: 0.40)
              : Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.60),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DurationLimitSelector extends StatelessWidget {
  final Duration selectedLimit;
  final ValueChanged<Duration>? onChanged;

  const _DurationLimitSelector({
    required this.selectedLimit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _kAvailableReelLimits.map((limit) {
        final isSelected = limit == selectedLimit;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: limit == _kAvailableReelLimits.last ? 0 : 10,
            ),
            child: InkWell(
              onTap: onChanged == null ? null : () => onChanged!(limit),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _kUploadPink.withValues(alpha: 0.18)
                      : const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? _kUploadPink.withValues(alpha: 0.60)
                        : Colors.white10,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.timelapse_rounded,
                      size: 18,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${limit.inSeconds}s max',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SelectedDurationProgress extends StatelessWidget {
  final Duration selected;
  final Duration maxAllowed;

  const _SelectedDurationProgress({
    required this.selected,
    required this.maxAllowed,
  });

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final maxMs = maxAllowed.inMilliseconds == 0 ? 1 : maxAllowed.inMilliseconds;
    final ratio = (selected.inMilliseconds / maxMs).clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Selected ${_formatDuration(selected)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Max ${_formatDuration(maxAllowed)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.66),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(_kUploadPink),
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  final String text;
  final bool isActive;

  const _RuleRow({required this.text, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isActive
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked,
            color: isActive ? _kUploadPink : Colors.white24,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SourceActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _kUploadPink.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right_rounded, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}

class _ReelVideoEditorScreen extends StatefulWidget {
  final File sourceFile;
  final Duration maxDuration;

  const _ReelVideoEditorScreen({
    required this.sourceFile,
    required this.maxDuration,
  });

  @override
  State<_ReelVideoEditorScreen> createState() => _ReelVideoEditorScreenState();
}

class _ReelVideoEditorScreenState extends State<_ReelVideoEditorScreen> {
  late final VideoEditorController _controller = VideoEditorController.file(
    widget.sourceFile,
    minDuration: const Duration(seconds: 1),
    maxDuration: widget.maxDuration,
  );

  bool _isInitializing = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _initEditor();
  }

  Future<void> _initEditor() async {
    try {
      await _controller.initialize(aspectRatio: 9 / 16);
      _controller.cropAspectRatio(9 / 16);
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
      });
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open video editor.\n$error'),
          backgroundColor: const Color(0xFF242424),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _togglePlayback() async {
    if (_isInitializing || _isExporting) return;

    if (_controller.isPlaying) {
      await _controller.video.pause();
      return;
    }

    await _controller.video.play();
  }

  Future<void> _exportEditedVideo() async {
    if (_isInitializing || _isExporting) return;

    setState(() {
      _isExporting = true;
    });

    try {
      final config = VideoFFmpegVideoEditorConfig(
        _controller,
        name: 'reel_${DateTime.now().millisecondsSinceEpoch}',
      );
      final execute = await config.getExecuteConfig();
      final session = await FFmpegKit.execute(execute.command);
      final returnCode = await session.getReturnCode();

      if (!mounted) return;

      if (ReturnCode.isSuccess(returnCode)) {
        Navigator.of(context).pop(File(execute.outputPath));
        return;
      }

      final logs = await session.getOutput();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to export edited video.\n${logs ?? 'Unknown export error.'}',
          ),
          backgroundColor: const Color(0xFF242424),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export edited video.\n$error'),
          backgroundColor: const Color(0xFF242424),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Widget _buildRatioButton({
    required String label,
    required double ratio,
  }) {
    final selected = (_controller.preferredCropAspectRatio ?? 0) == ratio;
    return Expanded(
      child: OutlinedButton(
        onPressed: _isExporting
            ? null
            : () {
                _controller.cropAspectRatio(ratio);
                setState(() {});
              },
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: selected ? _kUploadPink : Colors.white24,
          ),
          foregroundColor: Colors.white,
        ),
        child: Text(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Edit reel'),
        actions: [
          TextButton(
            onPressed: _isExporting ? null : _exportEditedVideo,
            child: _isExporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Done',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator(color: _kUploadPink))
          : Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: CropGridViewer.edit(controller: _controller),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Start ${_formatDuration(_controller.startTrim)}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                      Text(
                        'Clip ${_formatDuration(_controller.trimmedDuration)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'End ${_formatDuration(_controller.endTrim)}',
                          textAlign: TextAlign.end,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  // Keep a little more left-side space near 00:00 handle.
                  padding: const EdgeInsets.fromLTRB(18, 0, 12, 0),
                  child: TrimSlider(
                    controller: _controller,
                    height: 64,
                    horizontalMargin: 24,
                    child: TrimTimeline(
                      controller: _controller,
                      padding: const EdgeInsets.fromLTRB(16, 10, 10, 0),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                  child: Row(
                    children: [
                      _buildRatioButton(label: '9:16', ratio: 9 / 16),
                      const SizedBox(width: 10),
                      _buildRatioButton(label: '4:5', ratio: 4 / 5),
                      const SizedBox(width: 10),
                      _buildRatioButton(label: '1:1', ratio: 1),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isExporting
                              ? null
                              : () => _controller.rotate90Degrees(
                                    RotateDirection.left,
                                  ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.rotate_left),
                          label: const Text('Rotate'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isExporting ? null : _togglePlayback,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kUploadPink,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: Icon(
                            _controller.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                          label: Text(
                            _controller.isPlaying ? 'Pause' : 'Play',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
