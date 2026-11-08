import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:telsoworld/controllers/main_nav_controller.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:telsoworld/core/routes/app_route_observer.dart';
import 'package:telsoworld/views/ads/ads_view.dart';
import 'package:telsoworld/core/services/session_token_store.dart';
import 'package:share_plus/share_plus.dart';
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

// ─────────────────────────────────────────
// Data Model
// ─────────────────────────────────────────
class VideoItem {
  final int id;
  final String subject;
  final String name;
  final String videoPath;
  final int likesCount;
  final int sharesCount;
  /// API: `"normal"` | `"ads"` (dashboard `video_type`).
  final String videoType;
  /// API: true => liked, false => not liked.
  final bool liked;

  const VideoItem({
    required this.id,
    required this.subject,
    required this.name,
    required this.videoPath,
    required this.likesCount,
    required this.sharesCount,
    required this.videoType,
    required this.liked,
  });

  factory VideoItem.fromJson(Map<String, dynamic> json) => VideoItem(
    id: json['id'] as int? ?? 0,
    subject: json['subject']?.toString() ?? '',
    name: json['name']?.toString() ?? 'Unknown',
    videoPath: _normalizeVideoUrl(
      json['video_url']?.toString() ?? json['video_path']?.toString() ?? '',
    ),
    likesCount: _toInt(json['likes_count']),
    sharesCount: _toInt(json['shares_count']),
    videoType: json['video_type']?.toString() ?? 'normal',
    liked: _toBool(json['liked']),
  );
}

class DashboardSetting {
  final int id;
  final String name;
  final String fileUploaded;
  final String? value;
  final String updatedAt;

  const DashboardSetting({
    required this.id,
    required this.name,
    required this.fileUploaded,
    required this.value,
    required this.updatedAt,
  });

  factory DashboardSetting.fromJson(Map<String, dynamic> json) =>
      DashboardSetting(
        id: _toInt(json['id']),
        name: json['name']?.toString() ?? '',
        fileUploaded: json['file_uploaded']?.toString() ?? '',
        value: json['value']?.toString(),
        updatedAt: json['updated_at']?.toString() ?? '',
      );
}

class CommentItem {
  final int id;
  final String comment;
  final String user;
  final int userId;
  final String profileImage;
  final int likes;
  final bool isLiked;
  final int replyCount;
  final String createdAt;

  const CommentItem({
    required this.id,
    required this.comment,
    required this.user,
    required this.userId,
    required this.profileImage,
    required this.likes,
    required this.isLiked,
    required this.replyCount,
    required this.createdAt,
  });

  factory CommentItem.fromJson(Map<String, dynamic> json) => CommentItem(
    id: _toInt(json['id']),
    comment: json['comment']?.toString() ?? '',
    user: json['user']?.toString() ?? 'Unknown',
    userId: _toInt(json['user_id']),
    profileImage: json['profile_image']?.toString() ?? '',
    likes: _toInt(json['likes']),
    isLiked: _toBool(json['is_liked']),
    replyCount: _toInt(json['reply_count']),
    createdAt: json['created_at']?.toString() ?? '',
  );

  CommentItem copyWith({
    int? likes,
    bool? isLiked,
  }) {
    return CommentItem(
      id: id,
      comment: comment,
      user: user,
      userId: userId,
      profileImage: profileImage,
      likes: likes ?? this.likes,
      isLiked: isLiked ?? this.isLiked,
      replyCount: replyCount,
      createdAt: createdAt,
    );
  }
}

// ─────────────────────────────────────────
// FeedScreen — root widget (used by main.dart)
// ─────────────────────────────────────────
class FeedScreen extends StatefulWidget {
  /// When false (e.g. another bottom tab is selected), feed videos pause.
  const FeedScreen({super.key, this.visible = true});

  final bool visible;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with RouteAware {
  final Logger _logger = Logger();

  bool _routeCovered = false;
  bool _routeObserverSubscribed = false;

  bool get _playbackActive => widget.visible && !_routeCovered;

  bool _isLoading = true;
  String? _error;
  List<VideoItem> _videos = [];
  String? _referralCode;
  DashboardSetting? _setting;

  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    _fetchDashboard();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeObserverSubscribed) return;
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) {
      telsoRouteObserver.subscribe(this, route);
      _routeObserverSubscribed = true;
    }
  }

  @override
  void dispose() {
    telsoRouteObserver.unsubscribe(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didPushNext() {
    if (mounted) setState(() => _routeCovered = true);
  }

  @override
  void didPopNext() {
    if (mounted) setState(() => _routeCovered = false);
  }

  void _openAdsVideos() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AdsVideoScreen()));
  }

  // ── API call ──────────────────────────────────────────────
  /// [isRefresh]: keep the feed visible, reload data, then jump back to the
  /// same video index (clamped if the list shrinks).
  Future<void> _fetchDashboard({bool isRefresh = false}) async {
    final int restoreIndex = _currentPage;

    if (!isRefresh) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final token = await SessionTokenStore.getToken();

      _logger.i('Dashboard fetch → token: $token');

      final uri = Uri.parse('https://telsoworld.com/api/reporter/dashboard');
      final response = await http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 25));

      debugPrint('=== DASHBOARD API RESPONSE ===');
      debugPrint('Status Code : ${response.statusCode}');
      debugPrint('Body        : ${response.body}');
      debugPrint('==============================');
      _logger.i('Dashboard [${response.statusCode}]: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> json =
            jsonDecode(response.body) as Map<String, dynamic>;

        final bool status = json['status'] == true;
        if (status) {
          final settingJson = json['setting'];
          final List<dynamic> rawVideos =
              json['videos'] as List<dynamic>? ?? [];
          final newVideos = rawVideos
              .map((v) => VideoItem.fromJson(v as Map<String, dynamic>))
              .where((v) => v.videoPath.isNotEmpty)
              .toList();

          int targetPage = 0;
          if (isRefresh && newVideos.isNotEmpty) {
            targetPage = restoreIndex.clamp(0, newVideos.length - 1);
          }

          setState(() {
            _referralCode = json['referral_code']?.toString();
            _setting = settingJson is Map<String, dynamic>
                ? DashboardSetting.fromJson(settingJson)
                : null;
            _videos = newVideos;
            _isLoading = false;
            if (isRefresh && newVideos.isNotEmpty) {
              _currentPage = targetPage;
            }
          });

          if (isRefresh && newVideos.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              if (_pageController.hasClients) {
                _pageController.jumpToPage(targetPage);
              }
            });
          }
        } else {
          setState(() {
            if (!isRefresh) {
              _error = json['message']?.toString() ?? 'Failed to load feed.';
            }
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          if (!isRefresh) {
            _error =
                'Server error (${response.statusCode}). Pull down to retry.';
          }
          _isLoading = false;
        });
      }
    } catch (e, st) {
      _logger.e('Dashboard error', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() {
        if (!isRefresh) {
          _error = 'Network error. Pull down to retry.\n$e';
        }
        _isLoading = false;
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── Main content ──
          if (_isLoading)
            const _LoadingView()
          else if (_error != null)
            _ErrorView(message: _error!, onRetry: _fetchDashboard)
          else if (_videos.isEmpty)
            const _EmptyView()
          else
            RefreshIndicator(
              onRefresh: () => _fetchDashboard(isRefresh: true),
              color: const Color(0xFFD70F64),
              child: PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: _videos.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (ctx, i) => _VideoPage(
                  video: _videos[i],
                  isActive: i == _currentPage && _playbackActive,
                  onLikeSync: () => _fetchDashboard(isRefresh: true),
                ),
              ),
            ),

          // ── Top bar always visible ──
          SafeArea(
            bottom: false,
            child: _TopBar(
              referralCode: _referralCode,
              onAdsTap: _openAdsVideos,
              hasSettingVideo: (_setting?.fileUploaded ?? '').isNotEmpty,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Loading / Error / Empty States
// ─────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Color(0xFFD70F64)),
          SizedBox(height: 16),
          Text(
            'Loading feed…',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white54, size: 56),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD70F64),
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No videos available',
        style: TextStyle(color: Colors.white54, fontSize: 16),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Full-screen Video Page
// ─────────────────────────────────────────
class _VideoPage extends StatefulWidget {
  final VideoItem video;
  final bool isActive;
  final Future<void> Function() onLikeSync;

  const _VideoPage({
    required this.video,
    required this.isActive,
    required this.onLikeSync,
  });

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage>
    with SingleTickerProviderStateMixin {
  final Logger _logger = Logger();
  VideoPlayerController? _controller;
  File? _cachedVideoFile;
  late AnimationController _heartController;
  late Animation<double> _heartScale;
  late Animation<double> _heartOpacity;
  bool _initialized = false;
  bool _hasError = false;
  bool _isLiked = false;
  bool _isLiking = false;
  int _likesCount = 0;
  int _heartAnimationRun = 0;

  @override
  void initState() {
    super.initState();
    _likesCount = widget.video.likesCount;
    _isLiked = widget.video.liked;
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 220),
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

  Future<void> _initVideo() async {
    final uriCandidates = _videoUriCandidates(widget.video.videoPath);
    if (uriCandidates.isEmpty) {
      debugPrint(
        'Video init error [id=${widget.video.id}]: invalid url ${widget.video.videoPath}',
      );
      if (mounted) setState(() => _hasError = true);
      return;
    }

    for (final uri in uriCandidates) {
      try {
        final controller = await _buildNetworkController(uri);
        if (!mounted) {
          await controller.dispose();
          return;
        }
        _controller = controller;
        setState(() => _initialized = true);
        if (widget.isActive) {
          controller.play();
          _callViewApi();
        }
        return;
      } catch (networkError) {
        debugPrint(
          'Video network init failed [id=${widget.video.id}] url=$uri error=$networkError',
        );
      }
    }

    for (final uri in uriCandidates) {
      try {
        final controller = await _buildDownloadedController(uri);
        if (!mounted) {
          await controller.dispose();
          return;
        }
        _controller = controller;
        setState(() => _initialized = true);
        if (widget.isActive) {
          controller.play();
          _callViewApi();
        }
        return;
      } catch (fallbackError) {
        debugPrint(
          'Video fallback init failed [id=${widget.video.id}] url=$uri error=$fallbackError',
        );
      }
    }

    if (mounted) {
      setState(() => _hasError = true);
    }
  }

  Future<VideoPlayerController> _buildNetworkController(Uri uri) async {
    final controller = VideoPlayerController.networkUrl(
      uri,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );
    await controller.initialize();
    await controller.setLooping(true);
    return controller;
  }

  Future<VideoPlayerController> _buildDownloadedController(Uri uri) async {
    final response = await http
        .get(uri, headers: const {'Accept': 'video/mp4,*/*'})
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw Exception(
        'Download failed: status=${response.statusCode}, bytes=${response.bodyBytes.length}',
      );
    }

    final tempPath =
        '${Directory.systemTemp.path}/telso_video_${widget.video.id}_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final file = File(tempPath);
    await file.writeAsBytes(response.bodyBytes, flush: true);
    _cachedVideoFile = file;

    final controller = VideoPlayerController.file(file);
    await controller.initialize();
    await controller.setLooping(true);
    return controller;
  }

  @override
  void didUpdateWidget(covariant _VideoPage oldWidget) {
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

  bool get _isAdsVideo =>
      widget.video.videoType.toLowerCase().trim() == 'ads';

  // Calls the correct view API based on video type.
  // Normal video  → /api/reporter/normal-video/view
  // Ads video     → /api/reporter/adsvideo/view
  // Errors are silently ignored — view count is best-effort.
  Future<void> _callViewApi() async {
    try {
      final token = await SessionTokenStore.getToken();
      final endpoint = _isAdsVideo
          ? 'https://telsoworld.com/api/reporter/adsvideo/view'
          : 'https://telsoworld.com/api/reporter/normal-video/view';
      await http
          .post(
            Uri.parse(endpoint),
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

  Future<void> _runHeartAnimation() async {
    final int runId = ++_heartAnimationRun;
    await _heartController.forward(from: 0);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted || runId != _heartAnimationRun) return;
    await _heartController.reverse();
  }

  Future<void> _toggleLike({
    bool animateHeart = false,
    bool forceLike = false,
  }) async {
    if (_isLiking) return;
    if (forceLike && _isLiked) {
      if (animateHeart) {
        await _runHeartAnimation();
      }
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
      final uri = _isAdsVideo
          ? Uri.parse('https://telsoworld.com/api/reporter/adsvideo/like')
          : Uri.parse('https://telsoworld.com/api/reporter/normal-video/like');
      final response = await http
          .post(
            uri,
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
      final apiLikeCount = (json['likes_count'] as num?)?.toInt();
      if (!mounted) return;

      setState(() {
        if (_isAdsVideo) {
          final apiStatus = json['status']?.toString().toLowerCase();
          if (apiStatus == 'liked') {
            _isLiked = true;
          } else if (apiStatus == 'unliked') {
            _isLiked = false;
          }
        } else {
          final action = json['action']?.toString().toLowerCase();
          if (action == 'liked') {
            _isLiked = true;
          } else if (action == 'unliked') {
            _isLiked = false;
          }
        }
        if (apiLikeCount != null) {
          _likesCount = apiLikeCount;
        }
      });

      if (animateHeart && _isLiked) await _runHeartAnimation();

      // Keep UI always in sync with server-side likes.
      await widget.onLikeSync();
    } catch (e, st) {
      _logger.e('Like toggle error', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() {
        _isLiked = previousLiked;
        _likesCount = previousLikes;
      });
    } finally {
      if (mounted) {
        setState(() => _isLiking = false);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    final cachedFile = _cachedVideoFile;
    if (cachedFile != null) {
      Future<void>(() async {
        try {
          await cachedFile.delete();
        } catch (_) {
          // Ignore temp file cleanup failure.
        }
      });
    }
    _heartController.dispose();
    super.dispose();
  }

  Future<void> _onVideoTapLike() async {
    if (!_initialized || _controller == null) return;
    await _toggleLike(animateHeart: true, forceLike: true);
  }

  Future<void> _openCommentsSheet() async {
    final type = _isAdsVideo ? 'ads' : 'normal';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsBottomSheet(
        videoId: widget.video.id,
        videoType: type,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onVideoTapLike,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Video / loading / error ──
          if (_hasError)
            _VideoErrorPlaceholder(subject: widget.video.subject)
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

          // ── Gradient overlay ──
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.18, 0.58, 0.80, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: 0.40),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.50),
                    Colors.black.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),

          // ── Double-tap like heart ──
          IgnorePointer(
            child: Center(
              child: FadeTransition(
                opacity: _heartOpacity,
                child: ScaleTransition(
                  scale: _heartScale,
                  child: Icon(
                    Icons.favorite_rounded,
                    color: const Color(0xFFFF2D55).withValues(alpha: 0.95),
                    size: 108,
                    shadows: const [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 22,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Right action buttons ──
          Positioned(
            right: 10,
            bottom: 28,
            child: _RightActions(
              isLiked: _isLiked,
              likesCount: _likesCount,
              sharesCount: widget.video.sharesCount,
              videoTitle: widget.video.subject,
              onLikeTap: () => _toggleLike(),
              onCommentTap: _openCommentsSheet,
            ),
          ),

          // ── Bottom info (caption, creator & audio) ──
          Positioned(
            left: 14,
            right: 88,
            bottom: 20,
            child: _BottomInfo(video: widget.video),
          ),

          // ── Scrubbable progress bar at the very bottom ──
          if (_initialized)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
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

class _VideoErrorPlaceholder extends StatelessWidget {
  final String subject;
  const _VideoErrorPlaceholder({required this.subject});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF241020), Color(0xFF0F0F14), Color(0xFF141926)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ambient gradient circles
          Positioned(
            top: 140,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD70F64).withOpacity(0.12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD70F64).withOpacity(0.25),
                    blurRadius: 90,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),

          // Central Music Vinyl & Visualizer Art
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glowing Music Disc Art
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD70F64), Color(0xFF8A2387), Color(0xFFFF8008)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD70F64).withOpacity(0.45),
                        blurRadius: 28,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF161622),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.music_note_rounded,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Reel Title / Subject
                Text(
                  subject.isNotEmpty ? subject : 'Telso Creator Performance',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),

                // Track tag badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.graphic_eq_rounded, color: Color(0xFF00E5FF), size: 14),
                      SizedBox(width: 6),
                      Text(
                        'Original Music Track • Live',
                        style: TextStyle(color: Color(0xFF80D8FF), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
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

// ─────────────────────────────────────────
// Top Bar
// ─────────────────────────────────────────
class _TopBar extends StatefulWidget {
  final String? referralCode;
  final VoidCallback onAdsTap;
  final bool hasSettingVideo;

  const _TopBar({
    this.referralCode,
    required this.onAdsTap,
    required this.hasSettingVideo,
  });

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  int _selectedTab = 1; // 0: Following, 1: For You

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          // Live Pulsing Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00E676),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Feed Segmented Tabs (Following | For You)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => setState(() => _selectedTab = 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Following',
                      style: TextStyle(
                        color: _selectedTab == 0 ? Colors.white : Colors.white54,
                        fontSize: _selectedTab == 0 ? 15 : 14,
                        fontWeight: _selectedTab == 0 ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      width: 24,
                      height: 2.5,
                      decoration: BoxDecoration(
                        color: _selectedTab == 0 ? const Color(0xFFD70F64) : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => setState(() => _selectedTab = 1),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'For You',
                      style: TextStyle(
                        color: _selectedTab == 1 ? Colors.white : Colors.white54,
                        fontSize: _selectedTab == 1 ? 16 : 14,
                        fontWeight: _selectedTab == 1 ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      width: 24,
                      height: 2.5,
                      decoration: BoxDecoration(
                        color: _selectedTab == 1 ? const Color(0xFFD70F64) : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Spacer(),

          // Ads Video button
          GestureDetector(
            onTap: widget.onAdsTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFD70F64), Color(0xFFFF2A6D)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD70F64).withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.campaign_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Ads',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Search Button (Switches to Discovery tab)
          GestureDetector(
            onTap: () {
              try {
                Get.find<MainNavController>().changeTab(1);
              } catch (_) {}
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white12),
              ),
              child: const Icon(Icons.search_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Right Action Buttons
// ─────────────────────────────────────────
class _RightActions extends StatefulWidget {
  final bool isLiked;
  final int likesCount;
  final int sharesCount;
  final String videoTitle;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;

  const _RightActions({
    required this.isLiked,
    required this.likesCount,
    required this.sharesCount,
    this.videoTitle = 'Telso Reel',
    required this.onLikeTap,
    required this.onCommentTap,
  });

  @override
  State<_RightActions> createState() => _RightActionsState();
}

class _RightActionsState extends State<_RightActions>
    with SingleTickerProviderStateMixin {
  late AnimationController _heartCtrl;
  late Animation<double> _heartScale;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _heartScale = Tween<double>(
      begin: 1.0,
      end: 1.45,
    ).animate(CurvedAnimation(parent: _heartCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    super.dispose();
  }

  String _fmt(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '$count';
  }

  void _shareVideo() {
    Share.share(
      'Watch this trending reel on Telso World! 🔥 https://telsoworld.com',
      subject: widget.videoTitle,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar with Follow + Badge
        _Avatar(
          isFollowing: _isFollowing,
          onFollowTap: () {
            setState(() => _isFollowing = !_isFollowing);
            Get.snackbar(
              _isFollowing ? 'Following ✨' : 'Unfollowed',
              _isFollowing ? 'You are now following this creator' : 'Unfollowed creator',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: const Color(0xFF1E1E24),
              colorText: Colors.white,
              duration: const Duration(seconds: 1),
            );
          },
        ),
        const SizedBox(height: 20),

        // Like
        GestureDetector(
          onTap: () {
            widget.onLikeTap();
            _heartCtrl.forward().then((_) => _heartCtrl.reverse());
          },
          child: ScaleTransition(
            scale: _heartScale,
            child: _ActionButton(
              icon: widget.isLiked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              label: _fmt(widget.likesCount),
              iconColor: widget.isLiked
                  ? const Color(0xFFFF2A6D)
                  : Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Comment
        GestureDetector(
          onTap: widget.onCommentTap,
          child: const _ActionButton(
            icon: Icons.chat_bubble_rounded,
            label: 'Comment',
          ),
        ),
        const SizedBox(height: 18),

        // Share
        GestureDetector(
          onTap: _shareVideo,
          child: _ActionButton(
            icon: Icons.reply_rounded,
            label: _fmt(widget.sharesCount),
            flipHorizontal: true,
          ),
        ),
        const SizedBox(height: 18),

        // Spinning vinyl disc
        _SpinningDisc(),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final bool isFollowing;
  final VoidCallback onFollowTap;

  const _Avatar({
    this.isFollowing = false,
    required this.onFollowTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            gradient: const LinearGradient(
              colors: [Color(0xFFD70F64), Color(0xFFFF8008)],
            ),
          ),
          child: const ClipOval(
            child: Icon(Icons.person, color: Colors.white, size: 28),
          ),
        ),
        Positioned(
          bottom: -8,
          child: GestureDetector(
            onTap: onFollowTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFollowing ? const Color(0xFF00E676) : const Color(0xFFD70F64),
                border: Border.all(color: Colors.black, width: 1.5),
              ),
              child: Icon(
                isFollowing ? Icons.check : Icons.add,
                color: Colors.white,
                size: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor;
  final bool flipHorizontal;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.iconColor,
    this.flipHorizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(
      icon,
      color: iconColor ?? Colors.white,
      size: 32,
      shadows: const [Shadow(blurRadius: 6, color: Colors.black54)],
    );
    return Column(
      children: [
        flipHorizontal
            ? Transform(
                alignment: Alignment.center,
                transform: Matrix4.rotationY(3.14159),
                child: iconWidget,
              )
            : iconWidget,
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
          ),
        ),
      ],
    );
  }
}

class _SpinningDisc extends StatefulWidget {
  @override
  State<_SpinningDisc> createState() => _SpinningDiscState();
}

class _SpinningDiscState extends State<_SpinningDisc>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _ctrl,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF2A2A2A),
          border: Border.all(color: const Color(0xFF444444), width: 6),
        ),
        child: const Icon(Icons.music_note, color: Colors.white, size: 16),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Comments Bottom Sheet
// ─────────────────────────────────────────

class _CommentsBottomSheet extends StatefulWidget {
  final int videoId;
  final String videoType; // normal | ads

  const _CommentsBottomSheet({
    required this.videoId,
    required this.videoType,
  });

  @override
  State<_CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<_CommentsBottomSheet> {
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isSending = false;
  String? _error;
  List<CommentItem> _comments = [];
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
      final uri = Uri.parse('https://telsoworld.com/api/comments');
      final response = await http
          .post(
            uri,
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
      final List<CommentItem> fetched = data
          .map((e) => CommentItem.fromJson(e as Map<String, dynamic>))
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
      final uri = Uri.parse('https://telsoworld.com/api/comments/add');
      final response = await http
          .post(
            uri,
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

      // Refresh from server so list stays accurate with backend ordering/user.
      await _loadComments(page: 1, reset: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comment added'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFFD70F64),
          duration: Duration(milliseconds: 1200),
        ),
      );
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

  Future<void> _toggleCommentLike(CommentItem comment) async {
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

  Future<void> _confirmDeleteComment(CommentItem comment) async {
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

    final previousComments = List<CommentItem>.from(_comments);
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
              Expanded(
                child: _buildBody(controller),
              ),
              _buildComposer(),
            ],
          ),
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
            backgroundImage: item.profileImage.isNotEmpty
                ? NetworkImage(item.profileImage)
                : null,
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

  Future<void> _openRepliesSheet(CommentItem comment) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RepliesBottomSheet(
        commentId: comment.id,
        parentUser: comment.user,
      ),
    );
  }
}

class _RepliesBottomSheet extends StatefulWidget {
  final int commentId;
  final String parentUser;

  const _RepliesBottomSheet({
    required this.commentId,
    required this.parentUser,
  });

  @override
  State<_RepliesBottomSheet> createState() => _RepliesBottomSheetState();
}

class _RepliesBottomSheetState extends State<_RepliesBottomSheet> {
  bool _isLoading = true;
  String? _error;
  List<CommentItem> _replies = [];

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
          .map(CommentItem.fromJson)
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

// ─────────────────────────────────────────
// Side Slide Menu
// ─────────────────────────────────────────
// Bottom Info  (subject + creator name)
// ─────────────────────────────────────────
class _BottomInfo extends StatelessWidget {
  final VideoItem video;
  const _BottomInfo({required this.video});

  @override
  Widget build(BuildContext context) {
    final creatorName = video.name.isNotEmpty ? video.name : 'telso_creator';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Creator Handle + Verified Badge
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '@$creatorName',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                shadows: [Shadow(blurRadius: 8, color: Colors.black87)],
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFD70F64),
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 10),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Video Caption / Subject
        Text(
          video.subject.isNotEmpty ? video.subject : 'Watch trending reels on Telso World! 🌟',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withOpacity(0.95),
            fontSize: 14,
            height: 1.35,
            shadows: const [Shadow(blurRadius: 8, color: Colors.black87)],
          ),
        ),
        const SizedBox(height: 4),

        // Hashtags Row
        Row(
          children: const [
            Text(
              '#Bhojpuri #Viral #Trending #Reels',
              style: TextStyle(
                color: Color(0xFFFF6584),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(blurRadius: 6, color: Colors.black)],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Audio Marquee Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.music_note_rounded, color: Color(0xFF00E5FF), size: 14),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Original Audio • @$creatorName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
