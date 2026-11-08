import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:telsoworld/core/services/session_token_store.dart';
import 'package:video_player/video_player.dart';

const String _kApiHost = 'telsoworld.com';

String _normalizeVideoUrl(String rawPath) {
  final trimmed = rawPath.trim();
  if (trimmed.isEmpty) return '';

  final normalizedSlashes = trimmed.replaceAll(r'\/', '/');
  final encoded = Uri.encodeFull(normalizedSlashes);
  final uri = Uri.tryParse(encoded);
  if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
    return uri.toString();
  }

  String safePath = encoded.startsWith('/') ? encoded : '/$encoded';
  if (!safePath.startsWith('/storage/') &&
      (safePath.startsWith('/videos/') || safePath.startsWith('/ad-videos/'))) {
    safePath = '/storage$safePath';
  }
  return Uri.https(_kApiHost, safePath).toString();
}

List<Uri> _videoUriCandidates(String rawUrl) {
  final normalized = _normalizeVideoUrl(rawUrl);
  if (normalized.isEmpty) return const <Uri>[];

  final parsed = Uri.tryParse(normalized);
  if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
    return const <Uri>[];
  }

  final candidates = <Uri>[parsed];
  final scheme = parsed.scheme.toLowerCase();
  if (scheme == 'http') {
    candidates.add(parsed.replace(scheme: 'https'));
  } else if (scheme == 'https') {
    candidates.add(parsed.replace(scheme: 'http'));
  }
  return candidates;
}

int _toInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

bool _toBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().trim().toLowerCase();
  if (normalized == 'true' || normalized == '1' || normalized == 'liked') {
    return true;
  }
  if (normalized == 'false' || normalized == '0' || normalized == 'unliked') {
    return false;
  }
  return fallback;
}

class AdVideoItem {
  final int id;
  final String name;
  final String videoUrl;
  final int likesCount;
  final String createdAt;
  final bool liked;

  const AdVideoItem({
    required this.id,
    required this.name,
    required this.videoUrl,
    required this.likesCount,
    required this.createdAt,
    required this.liked,
  });

  factory AdVideoItem.fromJson(Map<String, dynamic> json) {
    return AdVideoItem(
      id: _toInt(json['video_id'] ?? json['id']),
      name: json['name']?.toString().trim().isNotEmpty == true
          ? json['name'].toString().trim()
          : 'Ads Video',
      videoUrl: _normalizeVideoUrl(
        json['video_url']?.toString() ?? json['video_path']?.toString() ?? '',
      ),
      likesCount: _toInt(json['likes_count']),
      createdAt: json['created_at']?.toString() ?? '',
      liked: _toBool(json['liked']),
    );
  }
}

class _CommentItem {
  final int id;
  final String comment;
  final String user;
  final String profileImage;
  final int likes;
  final bool isLiked;
  final int replyCount;
  final String createdAt;

  const _CommentItem({
    required this.id,
    required this.comment,
    required this.user,
    required this.profileImage,
    required this.likes,
    required this.isLiked,
    required this.replyCount,
    required this.createdAt,
  });

  factory _CommentItem.fromJson(Map<String, dynamic> json) => _CommentItem(
    id: _toInt(json['id']),
    comment: json['comment']?.toString() ?? '',
    user: json['user']?.toString() ?? 'Unknown',
    profileImage: json['profile_image']?.toString() ?? '',
    likes: _toInt(json['likes']),
    isLiked: _toBool(json['is_liked']),
    replyCount: _toInt(json['reply_count']),
    createdAt: json['created_at']?.toString() ?? '',
  );

  _CommentItem copyWith({
    int? likes,
    bool? isLiked,
  }) {
    return _CommentItem(
      id: id,
      comment: comment,
      user: user,
      profileImage: profileImage,
      likes: likes ?? this.likes,
      isLiked: isLiked ?? this.isLiked,
      replyCount: replyCount,
      createdAt: createdAt,
    );
  }
}

class AdsVideoScreen extends StatefulWidget {
  const AdsVideoScreen({super.key});

  @override
  State<AdsVideoScreen> createState() => _AdsVideoScreenState();
}

class _AdsVideoScreenState extends State<AdsVideoScreen> {
  final Logger _logger = Logger();
  final PageController _pageController = PageController();

  bool _isLoading = true;
  String? _error;
  String? _referralCode;
  List<AdVideoItem> _videos = [];
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchAdsVideos();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchAdsVideos({bool isRefresh = false}) async {
    final restoreIndex = _currentIndex;
    if (!isRefresh) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final token = await SessionTokenStore.getToken();
      final response = await http
          .get(
            Uri.parse('https://telsoworld.com/api/reporter/ads-all-videos'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode != 200) {
        throw Exception('Server error (${response.statusCode}).');
      }

      final Map<String, dynamic> json =
          jsonDecode(response.body) as Map<String, dynamic>;
      if (json['status'] != true) {
        throw Exception(json['message']?.toString() ?? 'Failed to load ads.');
      }

      final List<dynamic> rawList =
          (json['data'] as List<dynamic>?) ??
          (json['videos'] as List<dynamic>?) ??
          <dynamic>[];

      final parsed = rawList
          .whereType<Map<String, dynamic>>()
          .map(AdVideoItem.fromJson)
          .where((v) => v.videoUrl.isNotEmpty)
          .toList();

      int targetIndex = 0;
      if (isRefresh && parsed.isNotEmpty) {
        targetIndex = restoreIndex.clamp(0, parsed.length - 1);
      }

      if (!mounted) return;
      setState(() {
        _referralCode = json['referral_code']?.toString();
        _videos = parsed;
        _isLoading = false;
        if (isRefresh && parsed.isNotEmpty) {
          _currentIndex = targetIndex;
        }
      });

      if (isRefresh && parsed.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_pageController.hasClients) return;
          _pageController.jumpToPage(targetIndex);
        });
      }
    } catch (e, st) {
      _logger.e('Ads videos fetch error', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFD70F64),
                strokeWidth: 2,
              ),
            )
          else if (_error != null)
            _AdsErrorView(message: _error!, onRetry: _fetchAdsVideos)
          else if (_videos.isEmpty)
            const Center(
              child: Text(
                'No ads videos available',
                style: TextStyle(color: Colors.white54, fontSize: 15),
              ),
            )
          else
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: _videos.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (_, index) => _AdsVideoPage(
                video: _videos[index],
                isActive: index == _currentIndex,
                onLikeSync: () => _fetchAdsVideos(isRefresh: true),
              ),
            ),
          SafeArea(
            bottom: false,
            child: _AdsTopBar(referralCode: _referralCode),
          ),
        ],
      ),
    );
  }
}

class _AdsTopBar extends StatelessWidget {
  final String? referralCode;

  const _AdsTopBar({this.referralCode});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          ),
          if (referralCode != null && referralCode!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFD70F64).withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                referralCode!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          const Spacer(),
          const Text(
            'Ads Videos',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _AdsVideoPage extends StatefulWidget {
  final AdVideoItem video;
  final bool isActive;
  final Future<void> Function() onLikeSync;

  const _AdsVideoPage({
    required this.video,
    required this.isActive,
    required this.onLikeSync,
  });

  @override
  State<_AdsVideoPage> createState() => _AdsVideoPageState();
}

class _AdsVideoPageState extends State<_AdsVideoPage>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  File? _cachedVideoFile;
  bool _initialized = false;
  bool _hasError = false;
  bool _isLiked = false;
  bool _isLiking = false;
  int _likesCount = 0;
  int _heartAnimationRun = 0;
  late final AnimationController _heartController;
  late final Animation<double> _heartScale;
  late final Animation<double> _heartOpacity;

  @override
  void initState() {
    super.initState();
    _likesCount = widget.video.likesCount;
    _isLiked = widget.video.liked;
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 210),
    );
    _heartScale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.easeOutBack),
    );
    _heartOpacity = CurvedAnimation(
      parent: _heartController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _initVideo();
  }

  Future<void> _runHeartAnimation() async {
    final runId = ++_heartAnimationRun;
    await _heartController.forward(from: 0);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted || runId != _heartAnimationRun) return;
    await _heartController.reverse();
  }

  // Calls the ads video view API once when this video becomes visible.
  // Errors are silently ignored — view count is best-effort.
  Future<void> _callViewApi() async {
    try {
      final token = await SessionTokenStore.getToken();
      await http
          .post(
            Uri.parse('https://telsoworld.com/api/reporter/adsvideo/view'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'video_id': widget.video.id}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      // View tracking is best-effort; do not disrupt playback on failure.
    }
  }

  Future<void> _toggleLike({
    bool animateHeart = false,
    bool forceLike = false,
  }) async {
    if (_isLiking) return;
    if (forceLike && _isLiked) {
      if (animateHeart) await _runHeartAnimation();
      return;
    }

    final previousLiked = _isLiked;
    final previousLikes = _likesCount;
    final nextLiked = forceLike ? true : !previousLiked;
    setState(() {
      _isLiked = nextLiked;
      _isLiking = true;
      _likesCount = nextLiked
          ? previousLikes + 1
          : (previousLikes > 0 ? previousLikes - 1 : 0);
    });

    try {
      final token = await SessionTokenStore.getToken();
      final response = await http
          .post(
            Uri.parse('https://telsoworld.com/api/reporter/adsvideo/like'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'video_id': widget.video.id}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw Exception('Like failed with status ${response.statusCode}');
      }

      final Map<String, dynamic> json =
          jsonDecode(response.body) as Map<String, dynamic>;
      final apiStatus = json['status']?.toString().toLowerCase();
      final apiLikeCount = (json['likes_count'] as num?)?.toInt();
      if (!mounted) return;

      setState(() {
        if (apiStatus == 'liked') {
          _isLiked = true;
        } else if (apiStatus == 'unliked') {
          _isLiked = false;
        }
        if (apiLikeCount != null) {
          _likesCount = apiLikeCount;
        }
      });

      if (animateHeart && _isLiked) await _runHeartAnimation();
      await widget.onLikeSync();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLiked = previousLiked;
        _likesCount = previousLikes;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLiking = false;
        });
      }
    }
  }

  Future<void> _onVideoTapLike() async {
    if (!_initialized || _controller == null) return;
    await _toggleLike(animateHeart: true, forceLike: true);
  }

  Future<void> _openCommentsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _AdsCommentsBottomSheet(videoId: widget.video.id, videoType: 'ads'),
    );
  }

  Future<void> _initVideo() async {
    final uriCandidates = _videoUriCandidates(widget.video.videoUrl);
    if (uriCandidates.isEmpty) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    for (final uri in uriCandidates) {
      try {
        final networkController = VideoPlayerController.networkUrl(
          uri,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
        );
        await networkController.initialize();
        await networkController.setLooping(true);
        if (!mounted) {
          await networkController.dispose();
          return;
        }
        _controller = networkController;
        setState(() => _initialized = true);
        if (widget.isActive) {
          networkController.play();
          _callViewApi();
        }
        return;
      } catch (_) {
        // Try next candidate URL/scheme.
      }
    }

    for (final uri in uriCandidates) {
      try {
        final response = await http
            .get(uri, headers: const {'Accept': 'video/mp4,*/*'})
            .timeout(const Duration(seconds: 30));
        if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
          throw Exception('Download failed');
        }

        final tempPath =
            '${Directory.systemTemp.path}/telso_ad_${widget.video.id}_${DateTime.now().millisecondsSinceEpoch}.mp4';
        final file = File(tempPath);
        await file.writeAsBytes(response.bodyBytes, flush: true);
        _cachedVideoFile = file;

        final fileController = VideoPlayerController.file(file);
        await fileController.initialize();
        await fileController.setLooping(true);
        if (!mounted) {
          await fileController.dispose();
          return;
        }
        _controller = fileController;
        setState(() => _initialized = true);
        if (widget.isActive) {
          fileController.play();
          _callViewApi();
        }
        return;
      } catch (_) {
        // Try next candidate URL/scheme.
      }
    }

    if (mounted) setState(() => _hasError = true);
  }

  @override
  void didUpdateWidget(covariant _AdsVideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.id != widget.video.id) {
      _likesCount = widget.video.likesCount;
      _isLiked = widget.video.liked;
    } else if (oldWidget.video.likesCount != widget.video.likesCount ||
        oldWidget.video.liked != widget.video.liked) {
      _likesCount = widget.video.likesCount;
      _isLiked = widget.video.liked;
    }
    final controller = _controller;
    if (!_initialized || controller == null) return;

    if (widget.isActive) {
      controller.play();
      // Call view API only when the video first becomes visible (not on every rebuild).
      if (!oldWidget.isActive) _callViewApi();
    } else {
      controller.pause();
      controller.seekTo(Duration.zero);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _heartController.dispose();
    final file = _cachedVideoFile;
    if (file != null) {
      Future<void>(() async {
        try {
          await file.delete();
        } catch (_) {}
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onVideoTapLike,
      child: Stack(
        fit: StackFit.expand,
        children: [
        if (_hasError)
          const ColoredBox(
            color: Color(0xFF111111),
            child: Center(
              child: Text(
                'Video unavailable',
                style: TextStyle(color: Colors.white38),
              ),
            ),
          )
        else if (_initialized && _controller != null)
          Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),
          )
        else
          const ColoredBox(
            color: Colors.black,
            child: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFD70F64),
                strokeWidth: 2,
              ),
            ),
          ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.25, 0.60, 0.82, 1.0],
                colors: [
                  Colors.black.withValues(alpha: 0.38),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.50),
                  Colors.black.withValues(alpha: 0.82),
                ],
              ),
            ),
          ),
        ),
          Positioned(
            right: 14,
            bottom: 120,
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.campaign_rounded, color: Colors.white),
                ),
                const SizedBox(height: 18),
                _Metric(
                  icon: _isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  iconColor: _isLiked ? const Color(0xFFD70F64) : Colors.white,
                  value: _likesCount,
                  onTap: _toggleLike,
                ),
                const SizedBox(height: 18),
                _Metric(
                  icon: Icons.chat_bubble_rounded,
                  value: 0,
                  onTap: _openCommentsSheet,
                ),
                const SizedBox(height: 18),
                const _Metric(icon: Icons.reply_rounded, value: 0),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 90,
            bottom: 105,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '@${widget.video.name}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.video.name,
                  style: const TextStyle(color: Colors.white70, fontSize: 18),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.video.createdAt,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
          IgnorePointer(
            child: Center(
              child: FadeTransition(
                opacity: _heartOpacity,
                child: ScaleTransition(
                  scale: _heartScale,
                  child: Icon(
                    Icons.favorite_rounded,
                    color: const Color(0xFFFF2D55).withValues(alpha: 0.95),
                    size: 120,
                    shadows: const [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_initialized && _controller != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 82,
              child: VideoProgressIndicator(
                _controller!,
                allowScrubbing: true,
                padding: EdgeInsets.zero,
                colors: const VideoProgressColors(
                  playedColor: Color(0xFFD70F64),
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.white10,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AdsCommentsBottomSheet extends StatefulWidget {
  final int videoId;
  final String videoType;

  const _AdsCommentsBottomSheet({
    required this.videoId,
    required this.videoType,
  });

  @override
  State<_AdsCommentsBottomSheet> createState() => _AdsCommentsBottomSheetState();
}

class _AdsCommentsBottomSheetState extends State<_AdsCommentsBottomSheet> {
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isSending = false;
  String? _error;
  List<_CommentItem> _comments = [];
  int _currentPage = 1;
  int _lastPage = 1;
  final Set<int> _likingCommentIds = <int>{};
  final Set<int> _deletingCommentIds = <int>{};
  final TextEditingController _commentCtrl = TextEditingController();
  final FocusNode _commentFocus = FocusNode();

  bool get _hasMore => _currentPage < _lastPage;

  @override
  void initState() {
    super.initState();
    _loadComments(page: 1, reset: true);
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  Future<void> _loadComments({required int page, required bool reset}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final token = await SessionTokenStore.getToken();
      final response = await http
          .post(
            Uri.parse('https://telsoworld.com/api/comments'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'video_id': widget.videoId,
              'video_type': widget.videoType,
              'page': page,
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode != 200) {
        throw Exception('Comments failed (${response.statusCode})');
      }

      final Map<String, dynamic> json =
          jsonDecode(response.body) as Map<String, dynamic>;
      if (json['status'] != true) {
        throw Exception(json['message']?.toString() ?? 'Failed to fetch comments');
      }

      final List<dynamic> data = json['data'] as List<dynamic>? ?? [];
      final fetched = data
          .whereType<Map<String, dynamic>>()
          .map(_CommentItem.fromJson)
          .toList();

      final pagination = json['pagination'] as Map<String, dynamic>? ?? {};
      final fetchedCurrentPage = _toInt(pagination['current_page'], fallback: page);
      final fetchedLastPage = _toInt(pagination['last_page'], fallback: page);

      if (!mounted) return;
      setState(() {
        _currentPage = fetchedCurrentPage;
        _lastPage = fetchedLastPage < 1 ? 1 : fetchedLastPage;
        _comments = reset ? fetched : [..._comments, ...fetched];
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _submitComment() async {
    final raw = _commentCtrl.text.trim();
    if (raw.isEmpty || _isSending) return;
    setState(() => _isSending = true);

    try {
      final token = await SessionTokenStore.getToken();
      final response = await http
          .post(
            Uri.parse('https://telsoworld.com/api/comments/add'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'comment': raw,
              'video_id': widget.videoId,
              'video_type': widget.videoType,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw Exception('Add comment failed (${response.statusCode})');
      }
      final Map<String, dynamic> json =
          jsonDecode(response.body) as Map<String, dynamic>;
      if (json['status'] != true) {
        throw Exception(json['message']?.toString() ?? 'Failed to add comment');
      }

      if (!mounted) return;
      _commentCtrl.clear();
      _commentFocus.unfocus();
      await _loadComments(page: 1, reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _toggleCommentLike(_CommentItem comment) async {
    if (_likingCommentIds.contains(comment.id)) return;

    final previousLiked = comment.isLiked;
    final previousLikes = comment.likes;
    final optimisticLiked = !previousLiked;
    final optimisticLikes = optimisticLiked
        ? previousLikes + 1
        : (previousLikes > 0 ? previousLikes - 1 : 0);

    setState(() {
      _likingCommentIds.add(comment.id);
      _comments = _comments
          .map((c) => c.id == comment.id
              ? c.copyWith(isLiked: optimisticLiked, likes: optimisticLikes)
              : c)
          .toList();
    });

    try {
      final token = await SessionTokenStore.getToken();
      final response = await http
          .post(
            Uri.parse('https://telsoworld.com/api/comments/like'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'comment_id': comment.id}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw Exception('Comment like failed (${response.statusCode})');
      }

      final Map<String, dynamic> json =
          jsonDecode(response.body) as Map<String, dynamic>;
      if (json['status'] != true) {
        throw Exception(json['message']?.toString() ?? 'Failed to update like');
      }

      final message = json['message']?.toString().toLowerCase() ?? '';
      final bool? serverLiked = message.contains('unliked')
          ? false
          : message.contains('liked')
              ? true
              : null;

      if (!mounted) return;
      if (serverLiked != null && serverLiked != optimisticLiked) {
        final correctedLikes = serverLiked
            ? optimisticLikes + 1
            : (optimisticLikes > 0 ? optimisticLikes - 1 : 0);
        setState(() {
          _comments = _comments
              .map((c) => c.id == comment.id
                  ? c.copyWith(isLiked: serverLiked, likes: correctedLikes)
                  : c)
              .toList();
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _comments = _comments
            .map((c) => c.id == comment.id
                ? c.copyWith(isLiked: previousLiked, likes: previousLikes)
                : c)
            .toList();
      });
    } finally {
      if (mounted) {
        setState(() => _likingCommentIds.remove(comment.id));
      }
    }
  }

  Future<void> _confirmDeleteComment(_CommentItem comment) async {
    if (_deletingCommentIds.contains(comment.id)) return;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Do you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    final previousComments = List<_CommentItem>.from(_comments);
    setState(() {
      _deletingCommentIds.add(comment.id);
      _comments = _comments.where((c) => c.id != comment.id).toList();
    });

    try {
      final token = await SessionTokenStore.getToken();
      final response = await http
          .delete(
            Uri.parse('https://telsoworld.com/api/comments/${comment.id}'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw Exception('Delete failed (${response.statusCode})');
      }

      final Map<String, dynamic> json =
          jsonDecode(response.body) as Map<String, dynamic>;
      if (json['status'] != true) {
        throw Exception(json['message']?.toString() ?? 'Failed to delete comment');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _comments = previousComments;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _deletingCommentIds.remove(comment.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF121212),
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 46,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text(
                      'Comments',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_comments.length}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Divider(color: Colors.white12, height: 1),
              Expanded(child: _buildBody(controller)),
              _buildComposer(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(ScrollController controller) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFD70F64)),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white54, size: 42),
              const SizedBox(height: 10),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () => _loadComments(page: 1, reset: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD70F64),
                ),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }
    if (_comments.isEmpty) {
      return const Center(
        child: Text(
          'No comments yet',
          style: TextStyle(color: Colors.white60, fontSize: 15),
        ),
      );
    }

    return ListView.builder(
      controller: controller,
      itemCount: _comments.length + 1,
      itemBuilder: (context, index) {
        if (index == _comments.length) {
          if (!_hasMore) return const SizedBox(height: 10);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: TextButton(
                onPressed: _isLoadingMore
                    ? null
                    : () => _loadComments(page: _currentPage + 1, reset: false),
                child: _isLoadingMore
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFD70F64),
                        ),
                      )
                    : const Text(
                        'Load more',
                        style: TextStyle(color: Color(0xFFD70F64)),
                      ),
              ),
            ),
          );
        }

        final item = _comments[index];
        return ListTile(
          leading: CircleAvatar(
            radius: 19,
            backgroundColor: Colors.white12,
            backgroundImage:
                item.profileImage.isNotEmpty ? NetworkImage(item.profileImage) : null,
            child: item.profileImage.isEmpty
                ? const Icon(Icons.person, color: Colors.white70, size: 18)
                : null,
          ),
          title: Text(
            item.user,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(
                item.comment,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    item.createdAt,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: _likingCommentIds.contains(item.id)
                        ? null
                        : () => _toggleCommentLike(item),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                      child: _likingCommentIds.contains(item.id)
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFD70F64),
                              ),
                            )
                          : Icon(
                              item.isLiked ? Icons.favorite : Icons.favorite_border,
                              size: 14,
                              color: item.isLiked
                                  ? const Color(0xFFD70F64)
                                  : Colors.white38,
                            ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${item.likes}',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () => _openRepliesSheet(item),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                      child: Text(
                        '${item.replyCount} replies',
                        style: const TextStyle(
                          color: Color(0xFFD70F64),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          trailing: _deletingCommentIds.contains(item.id)
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFD70F64),
                  ),
                )
              : IconButton(
                  onPressed: () => _confirmDeleteComment(item),
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.white54),
                  tooltip: 'Delete comment',
                ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        );
      },
    );
  }

  Widget _buildComposer() {
    final hasText = _commentCtrl.text.trim().isNotEmpty;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Colors.white12)),
            color: Color(0xFF121212),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentCtrl,
                  focusNode: _commentFocus,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _submitComment(),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white10,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: (!_isSending && hasText) ? _submitComment : null,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (!_isSending && hasText)
                        ? const Color(0xFFD70F64)
                        : Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: _isSending
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openRepliesSheet(_CommentItem comment) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdsRepliesBottomSheet(
        commentId: comment.id,
        parentUser: comment.user,
      ),
    );
  }
}

class _AdsRepliesBottomSheet extends StatefulWidget {
  final int commentId;
  final String parentUser;

  const _AdsRepliesBottomSheet({
    required this.commentId,
    required this.parentUser,
  });

  @override
  State<_AdsRepliesBottomSheet> createState() => _AdsRepliesBottomSheetState();
}

class _AdsRepliesBottomSheetState extends State<_AdsRepliesBottomSheet> {
  bool _isLoading = true;
  String? _error;
  List<_CommentItem> _replies = [];

  @override
  void initState() {
    super.initState();
    _fetchReplies();
  }

  Future<void> _fetchReplies() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await SessionTokenStore.getToken();
      final response = await http
          .get(
            Uri.parse('https://telsoworld.com/api/comments/${widget.commentId}/replies'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw Exception('Replies failed (${response.statusCode})');
      }

      final Map<String, dynamic> json =
          jsonDecode(response.body) as Map<String, dynamic>;
      if (json['status'] != true) {
        throw Exception(json['message']?.toString() ?? 'Failed to fetch replies');
      }

      final data = json['data'] as List<dynamic>? ?? [];
      final replies = data
          .whereType<Map<String, dynamic>>()
          .map(_CommentItem.fromJson)
          .toList();

      if (!mounted) return;
      setState(() {
        _replies = replies;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF121212),
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 46,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text(
                      'Replies',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '@${widget.parentUser}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                    Text(
                      '${_replies.length}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Divider(color: Colors.white12, height: 1),
              Expanded(child: _buildBody(controller)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(ScrollController controller) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFD70F64)),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white54, size: 42),
              const SizedBox(height: 10),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _fetchReplies,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD70F64),
                ),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }
    if (_replies.isEmpty) {
      return const Center(
        child: Text(
          'No replies yet',
          style: TextStyle(color: Colors.white60, fontSize: 15),
        ),
      );
    }

    return ListView.builder(
      controller: controller,
      itemCount: _replies.length,
      itemBuilder: (context, index) {
        final item = _replies[index];
        return ListTile(
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white12,
            backgroundImage:
                item.profileImage.isNotEmpty ? NetworkImage(item.profileImage) : null,
            child: item.profileImage.isEmpty
                ? const Icon(Icons.person, color: Colors.white70, size: 17)
                : null,
          ),
          title: Text(
            item.user,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(
                item.comment,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                item.createdAt,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final int value;
  final Color iconColor;
  final VoidCallback? onTap;

  const _Metric({
    required this.icon,
    required this.value,
    this.iconColor = Colors.white,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Icon(icon, color: iconColor, size: 33),
        const SizedBox(height: 6),
        Text(
          '$value',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }
}

class _AdsErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _AdsErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white54, size: 56),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD70F64),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
