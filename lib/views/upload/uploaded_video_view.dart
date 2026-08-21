import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:telsoworld/session_token_store.dart';

// Reuse the same pink colour from dashboard
const Color kDashPink = Color(0xFFD70F64);

// ── Data model ────────────────────────────────────────────────────────────────

class VideoEntry {
  final int id;
  final String subject;
  final String title;
  final String previewLabel;
  final String uploadedAt;
  final String status; // 'Pending' | 'Approved'

  const VideoEntry({
    required this.id,
    required this.subject,
    required this.title,
    required this.previewLabel,
    required this.uploadedAt,
    required this.status,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

class UploadedVideoScreen extends StatefulWidget {
  const UploadedVideoScreen({super.key});

  @override
  State<UploadedVideoScreen> createState() => _UploadedVideoScreenState();
}

class _UploadedVideoScreenState extends State<UploadedVideoScreen> {
  final List<VideoEntry> _videos = [
    const VideoEntry(
      id: 1,
      subject: 'good',
      title: 'good',
      previewLabel: 'video_1.mp4',
      uploadedAt: '20/03/2026 05:40 AM',
      status: 'Pending',
    ),
    const VideoEntry(
      id: 2,
      subject: 'Test Video',
      title: 'RK',
      previewLabel: 'video_2.mp4',
      uploadedAt: '19/03/2026 10:15 AM',
      status: 'Pending',
    ),
    const VideoEntry(
      id: 3,
      subject: 'Test Video',
      title: 'RK',
      previewLabel: 'video_3.mp4',
      uploadedAt: '19/03/2026 10:04 AM',
      status: 'Pending',
    ),
    const VideoEntry(
      id: 4,
      subject: 'Test Video',
      title: 'RK',
      previewLabel: 'video_4.mp4',
      uploadedAt: '19/03/2026 10:03 AM',
      status: 'Pending',
    ),
    const VideoEntry(
      id: 5,
      subject: 'Test Video',
      title: 'RK',
      previewLabel: 'video_5.mp4',
      uploadedAt: '19/03/2026 10:01 AM',
      status: 'Pending',
    ),
    const VideoEntry(
      id: 6,
      subject: 'Test Video',
      title: 'RK',
      previewLabel: 'video_6.mp4',
      uploadedAt: '19/03/2026 10:00 AM',
      status: 'Pending',
    ),
    const VideoEntry(
      id: 7,
      subject: 'Test Video',
      title: 'RK',
      previewLabel: 'video_7.mp4',
      uploadedAt: '07/03/2026 12:17 PM',
      status: 'Approved',
    ),
    const VideoEntry(
      id: 8,
      subject: 'Test Video',
      title: 'RK',
      previewLabel: 'video_8.mp4',
      uploadedAt: '07/03/2026 12:02 PM',
      status: 'Approved',
    ),
  ];

  Future<void> _openUploadDialog() async {
    final newEntry = await showDialog<VideoEntry>(
      context: context,
      builder: (_) => const _UploadVideoDialog(),
    );
    if (newEntry == null || !mounted) return;
    setState(() => _videos.insert(0, newEntry));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(context),
      body: _videos.isEmpty ? _buildEmptyState() : _buildVideoList(),
    );
  }

  // ── App Bar ─────────────────────────────────────────────────────────────────

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: kDashPink,
      elevation: 0,
      leading: const Icon(Icons.video_library_outlined, color: Colors.white),
      title: const Text(
        'My Videos',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: OutlinedButton.icon(
            onPressed: _openUploadDialog,
            icon: const Icon(Icons.add_circle_outline, size: 18, color: Colors.white),
            label: const Text(
              'Upload Video',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            ),
          ),
        ),
      ],
    );
  }

  // ── Video List ───────────────────────────────────────────────────────────────

  Widget _buildVideoList() {
    return Column(
      children: [
        _buildTableHeader(),
        Expanded(
          child: ListView.separated(
            itemCount: _videos.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEEEEEE)),
            itemBuilder: (context, index) => _buildVideoRow(_videos[index]),
          ),
        ),
      ],
    );
  }

  // ── Table Header ─────────────────────────────────────────────────────────────

  Widget _buildTableHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: const Row(
        children: [
          _HeaderCell('#',        flex: 1),
          _HeaderCell('Subject',  flex: 3),
          _HeaderCell('Title',    flex: 2),
          _HeaderCell('Preview',  flex: 3),
          _HeaderCell('Status',   flex: 3),
          _HeaderCell('Uploaded', flex: 4),
          _HeaderCell('Actions',  flex: 3),
        ],
      ),
    );
  }

  // ── Single Row ───────────────────────────────────────────────────────────────

  Widget _buildVideoRow(VideoEntry video) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // # serial number
          Expanded(
            flex: 1,
            child: Text(
              '${video.id}',
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),

          // Subject
          Expanded(
            flex: 3,
            child: Text(
              video.subject,
              style: TextStyle(
                fontSize: 13,
                color: video.id == 1 ? kDashPink : Colors.black87,
                decoration: video.id == 1 ? TextDecoration.underline : TextDecoration.none,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Title
          Expanded(
            flex: 2,
            child: Text(
              video.title,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Preview thumbnail
          Expanded(
            flex: 3,
            child: _VideoThumbnail(label: video.previewLabel),
          ),

          // Status badge
          Expanded(
            flex: 3,
            child: _StatusBadge(status: video.status),
          ),

          // Uploaded date
          Expanded(
            flex: 4,
            child: Text(
              video.uploadedAt,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ),

          // Actions
          Expanded(
            flex: 3,
            child: Row(
              children: [
                _ActionButton(
                  icon: Icons.edit_outlined,
                  color: Colors.orange,
                  onTap: () => _onEdit(video),
                ),
                const SizedBox(width: 6),
                _ActionButton(
                  icon: Icons.delete_outline,
                  color: Colors.red,
                  onTap: () => _onDelete(video),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty State ──────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_library_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No videos uploaded yet',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _openUploadDialog,
            icon: const Icon(Icons.upload, color: Colors.white),
            label: const Text('Upload Video', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: kDashPink,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────────

  void _onEdit(VideoEntry video) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Edit: ${video.subject}'),
        backgroundColor: kDashPink,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onDelete(VideoEntry video) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Video'),
        content: Text('Are you sure you want to delete "${video.subject}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _videos.removeWhere((v) => v.id == video.id));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Video deleted.'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── Reusable Widgets ──────────────────────────────────────────────────────────

class _HeaderCell extends StatelessWidget {
  final String text;
  final int flex;

  const _HeaderCell(this.text, {required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.black54,
        ),
      ),
    );
  }
}

class _VideoThumbnail extends StatelessWidget {
  final String label;

  const _VideoThumbnail({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      width: 80,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 18),
          ),
          const Positioned(
            top: 4,
            right: 4,
            child: Icon(Icons.more_vert, color: Colors.white60, size: 14),
          ),
          Positioned(
            bottom: 4,
            left: 6,
            right: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 8),
                ),
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: const LinearProgressIndicator(
                    value: 0.3,
                    backgroundColor: Colors.white24,
                    color: kDashPink,
                    minHeight: 2,
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

class _UploadVideoDialog extends StatefulWidget {
  const _UploadVideoDialog();

  @override
  State<_UploadVideoDialog> createState() => _UploadVideoDialogState();
}

class _UploadVideoDialogState extends State<_UploadVideoDialog> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();

  String? _selectedVideoPath;
  bool _isUploading = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result == null || result.files.isEmpty) return;
    setState(() => _selectedVideoPath = result.files.single.path);
  }

  Future<void> _uploadVideo() async {
    final subject = _subjectController.text.trim();
    final title = _titleController.text.trim();
    final selectedPath = _selectedVideoPath;

    if (subject.isEmpty) {
      _showSnack('Enter subject');
      return;
    }
    if (title.isEmpty) {
      _showSnack('Enter title');
      return;
    }
    if (selectedPath == null || selectedPath.isEmpty || !File(selectedPath).existsSync()) {
      _showSnack('Select a valid video file');
      return;
    }

    final token = await SessionTokenStore.getToken();
    if (token.isEmpty) {
      _showSnack('Login is required before uploading');
      return;
    }

    setState(() => _isUploading = true);
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://telsoworld.com/api/reporter/upload-video'),
      );
      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });
      request.fields['subject'] = subject;
      request.fields['name'] = title;
      request.files.add(
        await http.MultipartFile.fromPath(
          'video',
          selectedPath,
          filename: path.basename(selectedPath),
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

      final isSuccess =
          response.statusCode >= 200 &&
          response.statusCode < 300 &&
          (responseJson == null || responseJson['status'] != false);
      final message =
          responseJson?['message']?.toString() ??
          'Upload failed with status ${response.statusCode}.';

      if (!mounted) return;
      if (!isSuccess) {
        _showSnack(message);
        return;
      }

      final uploadedId = (responseJson?['data']?['id'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch;
      Navigator.of(context).pop(
        VideoEntry(
          id: uploadedId,
          subject: subject,
          title: title,
          previewLabel: path.basename(selectedPath),
          uploadedAt: DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now()),
          status: 'Pending',
        ),
      );
    } catch (error) {
      _showSnack('Unable to upload video.\n$error');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Upload Video'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _subjectController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Subject',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Title / Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _isUploading ? null : _pickVideo,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.video_library_outlined, color: kDashPink),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _selectedVideoPath == null
                            ? 'Select video file'
                            : path.basename(_selectedVideoPath!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isUploading ? null : _uploadVideo,
          icon: _isUploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.cloud_upload_rounded),
          label: Text(_isUploading ? 'Uploading...' : 'Upload'),
          style: ElevatedButton.styleFrom(
            backgroundColor: kDashPink,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final bool isApproved = status == 'Approved';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isApproved ? Colors.green : Colors.orange,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}
