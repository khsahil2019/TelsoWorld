import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import 'package:telsoworld/core/constants/api_endpoints.dart';
import 'package:telsoworld/core/constants/app_colors.dart';
import 'package:telsoworld/core/services/session_token_store.dart';
import 'package:telsoworld/core/services/storage_service.dart';

/// ---------------------------------------------------------------------------
/// 🎬 ProfileReelsViewerScreen
/// Full-Screen Instagram-style Vertical Reels Player for Profile Grids
/// ---------------------------------------------------------------------------
class ProfileReelsViewerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> videos;
  final int initialIndex;
  final VoidCallback? onLikedStateChanged;

  const ProfileReelsViewerScreen({
    super.key,
    required this.videos,
    this.initialIndex = 0,
    this.onLikedStateChanged,
  });

  @override
  State<ProfileReelsViewerScreen> createState() => _ProfileReelsViewerScreenState();
}

class _ProfileReelsViewerScreenState extends State<ProfileReelsViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.videos.isEmpty ? 0 : widget.videos.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videos.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Text('No reels found', style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.videos.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final isCurrent = index == _currentIndex;
          return _ProfileReelPageItem(
            video: widget.videos[index],
            isActive: isCurrent,
            onBack: () => Navigator.of(context).pop(),
            onLikedStateChanged: widget.onLikedStateChanged,
          );
        },
      ),
    );
  }
}

class _ProfileReelPageItem extends StatefulWidget {
  final Map<String, dynamic> video;
  final bool isActive;
  final VoidCallback onBack;
  final VoidCallback? onLikedStateChanged;

  const _ProfileReelPageItem({
    required this.video,
    required this.isActive,
    required this.onBack,
    this.onLikedStateChanged,
  });

  @override
  State<_ProfileReelPageItem> createState() => _ProfileReelPageItemState();
}

class _ProfileReelPageItemState extends State<_ProfileReelPageItem>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;
  bool _isManuallyPaused = false;
  bool _showPlayPauseIndicator = false;
  Timer? _indicatorTimer;

  bool _isLiked = false;
  int _likesCount = 0;
  int _viewsCount = 0;
  bool _likeAnimating = false;

  late AnimationController _heartAnimCtrl;
  late Animation<double> _heartScaleAnim;
  late Animation<double> _heartOpacityAnim;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.video['liked'] == true || widget.video['is_liked'] == true;
    _likesCount = int.tryParse(widget.video['likes_count']?.toString() ?? widget.video['likes']?.toString() ?? '') ?? 0;
    _viewsCount = int.tryParse(widget.video['view_count']?.toString() ?? widget.video['views']?.toString() ?? '') ?? 0;

    _heartAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _heartScaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3).chain(CurveTween(curve: Curves.easeOutBack)), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 50),
    ]).animate(_heartAnimCtrl);

    _heartOpacityAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_heartAnimCtrl);

    _initVideoPlayer();
  }

  bool get _isPhoto {
    final rawType = widget.video['media_type']?.toString().toLowerCase().trim() ?? '';
    final urlStr = _resolveVideoUrl().toLowerCase();
    final isExplicitVideo = rawType == 'video' ||
        urlStr.endsWith('.mp4') ||
        urlStr.endsWith('.mov') ||
        urlStr.endsWith('.m4v') ||
        urlStr.endsWith('.webm') ||
        urlStr.endsWith('.mkv');
    return rawType == 'photo' ||
        (!isExplicitVideo && (
            urlStr.endsWith('.jpg') ||
            urlStr.endsWith('.png') ||
            urlStr.endsWith('.jpeg') ||
            urlStr.endsWith('.webp') ||
            urlStr.endsWith('.gif')
        ));
  }

  String _resolvePhotoUrl() {
    final rawPhoto = (widget.video['photo_url'] ?? widget.video['image'] ?? widget.video['thumbnail_url'] ?? '').toString().trim();
    if (rawPhoto.isNotEmpty) return ApiEndpoints.mediaUrl(rawPhoto);
    return _resolveVideoUrl();
  }

  String _resolveVideoUrl() {
    final raw = widget.video['video_url'] ?? widget.video['video_path'] ?? widget.video['url'] ?? '';
    final str = raw.toString().trim();
    if (str.isEmpty) return '';
    return ApiEndpoints.mediaUrl(str);
  }

  Future<void> _initVideoPlayer() async {
    if (_isPhoto) {
      if (mounted) {
        setState(() => _initialized = true);
        if (widget.isActive) _recordView();
      }
      return;
    }

    final urlStr = _resolveVideoUrl();
    if (urlStr.isEmpty) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    try {
      final uri = Uri.parse(urlStr);
      _controller = VideoPlayerController.networkUrl(
        uri,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await _controller!.initialize();
      _controller!.setLooping(true);
      _controller!.setVolume(1.0);

      if (mounted) {
        setState(() {
          _initialized = true;
        });
        if (widget.isActive && !_isManuallyPaused) {
          _controller!.play();
          _recordView();
        }
      }
    } catch (e) {
      debugPrint('Reels player error: $e for $urlStr');
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void didUpdateWidget(covariant _ProfileReelPageItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isPhoto) {
      if (widget.isActive && !oldWidget.isActive) {
        _recordView();
      }
      return;
    }

    if (_controller == null || !_initialized) return;

    if (widget.isActive && !oldWidget.isActive) {
      if (!_isManuallyPaused) {
        _controller!.setVolume(1.0);
        _controller!.play();
        _recordView();
      }
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller!.setVolume(0.0);
      _controller!.pause();
      _controller!.seekTo(Duration.zero);
      _isManuallyPaused = false;
    }
  }

  @override
  void dispose() {
    _indicatorTimer?.cancel();
    _heartAnimCtrl.dispose();
    _controller?.pause();
    _controller?.dispose();
    super.dispose();
  }

  void _recordView() async {
    final vId = widget.video['id'];
    if (vId == null) return;
    try {
      final token = await SessionTokenStore.getToken();
      final storage = Get.isRegistered<StorageService>() ? Get.find<StorageService>() : null;
      final uId = storage?.getUserId() ?? 0;
      await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}/reporter/normal-video/view'),
        headers: {
          'Content-Type': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'video_id': vId,
          if (uId > 0) 'viewer_id': 'user_$uId',
        }),
      ).timeout(const Duration(seconds: 8));

      if (mounted) {
        setState(() => _viewsCount += 1);
      }
    } catch (_) {}
  }

  void _togglePlayPause() {
    if (_controller == null || !_initialized) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isManuallyPaused = true;
      } else {
        _controller!.play();
        _isManuallyPaused = false;
      }
      _showPlayPauseIndicator = true;
    });

    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showPlayPauseIndicator = false);
    });
  }

  Future<void> _toggleLike() async {
    final vId = widget.video['id'];
    if (vId == null) return;

    // Optimistic UI update
    final wasLiked = _isLiked;
    final nextLiked = !wasLiked;
    final nextLikes = nextLiked ? (_likesCount + 1) : (_likesCount > 0 ? _likesCount - 1 : 0);

    setState(() {
      _isLiked = nextLiked;
      _likesCount = nextLikes;
    });

    try {
      final token = await SessionTokenStore.getToken();
      final storage = Get.isRegistered<StorageService>() ? Get.find<StorageService>() : null;
      final uId = storage?.getUserId() ?? 0;

      final res = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}/reporter/video/like'),
        headers: {
          'Content-Type': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'video_id': vId,
          if (uId > 0) 'user_id': uId,
        }),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json is Map) {
          final serverLikes = int.tryParse(json['likes_count']?.toString() ?? '');
          final bool? serverIsLiked = json['liked'] is bool
              ? (json['liked'] as bool)
              : (json['is_liked'] is bool
                  ? (json['is_liked'] as bool)
                  : (json['action'] == 'liked' ? true : (json['action'] == 'unliked' ? false : null)));

          if (mounted) {
            setState(() {
              if (serverLikes != null) _likesCount = serverLikes;
              if (serverIsLiked != null) _isLiked = serverIsLiked;
            });
          }
        }
      }
      widget.onLikedStateChanged?.call();
    } catch (_) {
      // Revert if network failed
      if (mounted) {
        setState(() {
          _isLiked = wasLiked;
          _likesCount = wasLiked ? (_likesCount + 1) : (_likesCount > 0 ? _likesCount - 1 : 0);
        });
      }
    }
  }

  void _onDoubleTap() {
    if (!_isLiked) {
      _toggleLike();
    }
    setState(() => _likeAnimating = true);
    _heartAnimCtrl.forward(from: 0.0).then((_) {
      if (mounted) setState(() => _likeAnimating = false);
    });
  }

  void _shareReel() {
    final title = widget.video['title']?.toString() ?? 'Telso Reel';
    final url = _resolveVideoUrl();
    Share.share('Check out "$title" on Telso World! 🎵\n$url');
  }

  void _openComments() {
    final vId = widget.video['id'] is int
        ? widget.video['id'] as int
        : int.tryParse(widget.video['id']?.toString() ?? '') ?? 0;
    if (vId <= 0) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProfileCommentsSheet(videoId: vId),
    );
  }

  String _formatCount(int number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toString();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.video['title']?.toString() ?? 'Telso Reel';
    final subject = widget.video['subject']?.toString() ?? '';
    final creatorName = widget.video['name']?.toString() ?? widget.video['username']?.toString() ?? 'Creator';
    final creatorHandle = widget.video['username']?.toString() ?? 'creator';
    final audioTitle = widget.video['audio_title']?.toString() ?? 'Original Audio - $creatorName';

    return GestureDetector(
      onTap: _togglePlayPause,
      onDoubleTap: _onDoubleTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 🎥 Media View: Photo or Video Player
          if (_isPhoto)
            Center(
              child: Image.network(
                _resolvePhotoUrl(),
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF141418),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_rounded, color: Colors.white38, size: 48),
                        SizedBox(height: 10),
                        Text('Photo unavailable', style: TextStyle(color: Colors.white60, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
                loadingBuilder: (_, child, prog) => prog == null
                    ? child
                    : const Center(
                        child: CircularProgressIndicator(color: AppColors.primaryPink, strokeWidth: 2.5),
                      ),
              ),
            )
          else if (_initialized && _controller != null)
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio > 0 ? _controller!.value.aspectRatio : 9 / 16,
                child: VideoPlayer(_controller!),
              ),
            )
          else if (_hasError)
            Container(
              color: const Color(0xFF141418),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam_off_rounded, color: Colors.white38, size: 48),
                    SizedBox(height: 10),
                    Text('Video unavailable', style: TextStyle(color: Colors.white60, fontSize: 14)),
                  ],
                ),
              ),
            )
          else
            Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primaryPink, strokeWidth: 2.5),
              ),
            ),

          // 🎬 Gradient Overlays for contrast
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 220,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // 🔝 Top Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    InkWell(
                      onTap: widget.onBack,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'Reels',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 💓 Animated Heart on Double Tap
          if (_likeAnimating)
            Center(
              child: FadeTransition(
                opacity: _heartOpacityAnim,
                child: ScaleTransition(
                  scale: _heartScaleAnim,
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Color(0xFFFF2A6D),
                    size: 110,
                  ),
                ),
              ),
            ),

          // ⏸️ Center Play / Pause Indicator
          if (_showPlayPauseIndicator)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _controller != null && _controller!.value.isPlaying
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),
            ),

          // ⚡ Right Actions Column (Like, Share, Audio Disc)
          Positioned(
            right: 14,
            bottom: 30,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Like Button
                InkWell(
                  onTap: _toggleLike,
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Column(
                      children: [
                        Icon(
                          _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: _isLiked ? const Color(0xFFFF2A6D) : Colors.white,
                          size: 32,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatCount(_likesCount),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Comment Button
                InkWell(
                  onTap: _openComments,
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Column(
                      children: const [
                        Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 28),
                        SizedBox(height: 4),
                        Text(
                          'Comment',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Share Button (Authentic Paper Plane)
                InkWell(
                  onTap: _shareReel,
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Column(
                      children: const [
                        Icon(Icons.near_me_outlined, color: Colors.white, size: 28),
                        SizedBox(height: 4),
                        Text(
                          'Share',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 4. Audio Disc
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white38, width: 2),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8A2387), Color(0xFFE94057)],
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.music_note_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),

          // 📝 Bottom Info (Creator, Title, Audio, Views)
          Positioned(
            left: 16,
            right: 84,
            bottom: 26,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Creator Handle & Badge
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppColors.primaryPink, Color(0xFFFF6584)],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          creatorName.isNotEmpty ? creatorName[0].toUpperCase() : 'C',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '@${creatorHandle.replaceAll('@', '')}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Title / Subject
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subject.isNotEmpty && subject != title) ...[
                  const SizedBox(height: 4),
                  Text(
                    '#$subject',
                    style: const TextStyle(
                      color: Color(0xFFFF6584),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 10),

                // Audio & Views Row
                Row(
                  children: [
                    const Icon(Icons.music_note_rounded, color: Colors.white70, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        audioTitle,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.remove_red_eye_rounded, size: 12, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text(
                            _formatCount(_viewsCount),
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCommentsSheet extends StatefulWidget {
  final int videoId;
  const _ProfileCommentsSheet({required this.videoId});

  @override
  State<_ProfileCommentsSheet> createState() => _ProfileCommentsSheetState();
}

class _ProfileCommentsSheetState extends State<_ProfileCommentsSheet> {
  final TextEditingController _commentCtrl = TextEditingController();
  bool _isLoading = true;
  bool _isSending = false;
  List<dynamic> _comments = [];

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchComments() async {
    try {
      final token = await SessionTokenStore.getToken();
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/comments?video_id=${widget.videoId}');
      final res = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted && data is Map && data['data'] is List) {
          setState(() {
            _comments = data['data'] as List<dynamic>;
            _isLoading = false;
          });
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      final token = await SessionTokenStore.getToken();
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/comments/add');
      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'video_id': widget.videoId,
          'comment': text,
        }),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        _commentCtrl.clear();
        _fetchComments();
      }
    } catch (_) {}
    if (mounted) setState(() => _isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: Color(0xFF161622),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Comments',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          // Comments list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryPink,
                      strokeWidth: 2,
                    ),
                  )
                : _comments.isEmpty
                    ? const Center(
                        child: Text(
                          'No comments yet. Be the first to comment!',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _comments.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemBuilder: (context, index) {
                          final c = _comments[index];
                          final user = c['user']?.toString() ?? 'User';
                          final text = c['comment']?.toString() ?? '';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: const Color(0xFF2A2A38),
                                  child: Text(
                                    user.isNotEmpty ? user[0].toUpperCase() : 'U',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        text,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          // Input bar
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF101018),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                      filled: true,
                      fillColor: const Color(0xFF1E1E2C),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryPink,
                          ),
                        )
                      : const Icon(Icons.send_rounded, color: AppColors.primaryPink),
                  onPressed: _sendComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
