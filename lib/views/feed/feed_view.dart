import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:telsoworld/controllers/main_nav_controller.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:telsoworld/core/constants/api_endpoints.dart';
import 'package:telsoworld/core/routes/app_route_observer.dart';
import 'package:telsoworld/views/ads/ads_view.dart';
import 'package:telsoworld/views/story/story_tray_widget.dart';
import 'package:telsoworld/views/inbox/inbox_view.dart';
import 'package:telsoworld/views/notifications/notifications_view.dart';
import 'package:telsoworld/views/upload/reel_upload_view.dart';
import 'package:telsoworld/core/services/session_token_store.dart';
import 'package:telsoworld/core/services/storage_service.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

String _normalizeVideoUrl(String rawPath) {
  return ApiEndpoints.mediaUrl(rawPath);
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
  final int userId;
  final String username;
  final String subject;
  final String name;
  final String userProfileImage;
  final String videoPath;
  final String photoUrl;
  final String mediaType; // 'video' | 'photo'
  final bool hasAudio;
  final String audioTitle;
  final int likesCount;
  final int sharesCount;
  final int viewCount;
  final int commentsCount;
  final String createdAt;

  /// API: `"normal"` | `"ads"` (dashboard `video_type`).
  final String videoType;

  /// API: true => liked, false => not liked.
  final bool liked;

  const VideoItem({
    required this.id,
    required this.userId,
    required this.username,
    required this.subject,
    required this.name,
    this.userProfileImage = '',
    required this.videoPath,
    this.photoUrl = '',
    this.mediaType = 'video',
    this.hasAudio = false,
    this.audioTitle = '',
    required this.likesCount,
    required this.sharesCount,
    this.viewCount = 0,
    this.commentsCount = 0,
    this.createdAt = '',
    required this.videoType,
    required this.liked,
  });

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    final rawType = json['media_type']?.toString().toLowerCase().trim() ?? '';
    final rawVideoUrl =
        (json['video_url'] ?? json['video_path'] ?? json['url'] ?? '')
            .toString()
            .trim();
    final rawPhotoUrl =
        (json['photo_url'] ?? json['image'] ?? json['thumbnail_url'] ?? '')
            .toString()
            .trim();

    final isExplicitVideo =
        rawType == 'video' ||
        rawVideoUrl.toLowerCase().endsWith('.mp4') ||
        rawVideoUrl.toLowerCase().endsWith('.mov') ||
        rawVideoUrl.toLowerCase().endsWith('.m4v') ||
        rawVideoUrl.toLowerCase().endsWith('.webm') ||
        rawVideoUrl.toLowerCase().endsWith('.mkv');

    final isPhoto =
        rawType == 'photo' ||
        (!isExplicitVideo &&
            (rawVideoUrl.toLowerCase().endsWith('.jpg') ||
                rawVideoUrl.toLowerCase().endsWith('.png') ||
                rawVideoUrl.toLowerCase().endsWith('.jpeg') ||
                rawVideoUrl.toLowerCase().endsWith('.webp') ||
                rawVideoUrl.toLowerCase().endsWith('.gif')));

    String photo = '';
    if (rawPhotoUrl.isNotEmpty) {
      photo = _normalizeVideoUrl(rawPhotoUrl);
    } else if (isPhoto && rawVideoUrl.isNotEmpty) {
      photo = _normalizeVideoUrl(rawVideoUrl);
    }

    final rawAvatar =
        (json['user_profile_image'] ?? json['profile_image'] ?? '')
            .toString()
            .trim();

    return VideoItem(
      id: json['id'] as int? ?? 0,
      userId: _toInt(json['user_id']),
      username: json['username']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown',
      userProfileImage: rawAvatar.isNotEmpty
          ? _normalizeVideoUrl(rawAvatar)
          : '',
      videoPath: _normalizeVideoUrl(rawVideoUrl),
      photoUrl: photo,
      mediaType: isPhoto ? 'photo' : 'video',
      hasAudio: _toBool(json['has_audio'], fallback: true),
      audioTitle: json['audio_title']?.toString() ?? '',
      likesCount: _toInt(json['likes_count']),
      sharesCount: _toInt(json['shares_count']),
      viewCount: _toInt(json['view_count'] ?? json['views_count']),
      commentsCount: _toInt(json['comments_count']),
      createdAt: json['created_at']?.toString() ?? '',
      videoType: json['video_type']?.toString() ?? 'normal',
      liked: _toBool(json['liked'] ?? json['is_liked']),
    );
  }
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

  CommentItem copyWith({String? comment, int? likes, bool? isLiked}) {
    return CommentItem(
      id: id,
      comment: comment ?? this.comment,
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
  const FeedScreen({super.key, this.visible = true, this.isReelsOnly = false});

  final bool visible;
  final bool isReelsOnly;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen>
    with RouteAware, WidgetsBindingObserver {
  final Logger _logger = Logger();

  bool _routeCovered = false;
  bool _routeObserverSubscribed = false;
  bool _appInBackground = false;

  bool get _playbackActive =>
      widget.visible && !_routeCovered && !_appInBackground;

  List<VideoItem> get _displayVideos {
    return _videos;
  }

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
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.removeObserver(this);
    telsoRouteObserver.unsubscribe(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final inBackground = state != AppLifecycleState.resumed;
    if (_appInBackground != inBackground) {
      if (mounted) setState(() => _appInBackground = inBackground);
    }
  }

  @override
  void didUpdateWidget(covariant FeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) {
      if (mounted) setState(() {});
    }
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

      final uri = Uri.parse('${ApiEndpoints.baseUrl}/reporter/dashboard');
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
    if (widget.isReelsOnly) {
      // 🎬 REELS TAB: Fullscreen Immersive Reels Swiper
      final videos = _displayVideos;
      return Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        body: _isLoading
            ? const _LoadingView()
            : _error != null
            ? _ErrorView(message: _error!, onRetry: _fetchDashboard)
            : videos.isEmpty
            ? const _EmptyView()
            : RefreshIndicator(
                onRefresh: () => _fetchDashboard(isRefresh: true),
                color: const Color(0xFFD70F64),
                notificationPredicate: (notification) =>
                    notification.depth == 0 && _currentPage == 0,
                child: PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  physics: const PageScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  itemCount: videos.length,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (ctx, i) => _VideoPage(
                    video: videos[i],
                    isActive: i == _currentPage && _playbackActive,
                    isReelsOnly: true,
                    onLikeSync: () => _fetchDashboard(isRefresh: true),
                  ),
                ),
              ),
      );
    }

    // 📱 HOME TAB: Clean Instagram Feed (Starts strictly below stories!)
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 🔝 Top Bar: App Logo + "Telso World" | Create [+] | Heart & Chat
            _TopBar(
              referralCode: _referralCode,
              onAdsTap: _openAdsVideos,
              hasSettingVideo: (_setting?.fileUploaded ?? '').isNotEmpty,
              onTitleTap: () {
                if (_pageController.hasClients) {
                  _pageController.animateToPage(
                    0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                  );
                }
              },
            ),

            // 🌟 Instagram Stories Tray (Horizontal swiper)
            const StoryTrayWidget(),

            const SizedBox(height: 4),

            // 🎬 Posts & Reels Feed: Starts strictly below the stories tray!
            Expanded(
              child: _isLoading
                  ? const _LoadingView()
                  : _error != null
                  ? _ErrorView(message: _error!, onRetry: _fetchDashboard)
                  : _videos.isEmpty
                  ? const _EmptyView()
                  : RefreshIndicator(
                      onRefresh: () => _fetchDashboard(isRefresh: true),
                      color: const Color(0xFFD70F64),
                      notificationPredicate: (notification) =>
                          notification.depth == 0 && _currentPage == 0,
                      child: PageView.builder(
                        controller: _pageController,
                        scrollDirection: Axis.vertical,
                        physics: const PageScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        itemCount: _videos.length,
                        onPageChanged: (i) => setState(() => _currentPage = i),
                        itemBuilder: (ctx, i) => _VideoPage(
                          video: _videos[i],
                          isActive: i == _currentPage && _playbackActive,
                          isReelsOnly: false,
                          onLikeSync: () => _fetchDashboard(isRefresh: true),
                        ),
                      ),
                    ),
            ),
          ],
        ),
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
  final bool isReelsOnly;
  final Future<void> Function() onLikeSync;

  const _VideoPage({
    required this.video,
    required this.isActive,
    this.isReelsOnly = false,
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
  bool _isMuted = false;
  int _likesCount = 0;
  int _commentsCount = 0;
  int _viewCount = 0;
  int _heartAnimationRun = 0;

  @override
  void initState() {
    super.initState();
    _likesCount = widget.video.likesCount;
    _commentsCount = widget.video.commentsCount;
    _viewCount = widget.video.viewCount;
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
    if (widget.video.mediaType == 'photo') {
      if (mounted) {
        setState(() {
          _initialized = true;
          _hasError = false;
        });
        if (widget.isActive) _callViewApi();
      }
      return;
    }

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
        if (widget.isActive && !_isManuallyPaused) {
          await controller.setVolume(_isMuted ? 0.0 : 1.0);
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
        if (widget.isActive && !_isManuallyPaused) {
          await controller.setVolume(_isMuted ? 0.0 : 1.0);
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
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    await controller.initialize();
    await controller.setLooping(true);
    await controller.setVolume(_isMuted ? 0.0 : 1.0);
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

    final controller = VideoPlayerController.file(
      file,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    await controller.initialize();
    await controller.setLooping(true);
    await controller.setVolume(_isMuted ? 0.0 : 1.0);
    return controller;
  }

  void _toggleMute() {
    final nextMuted = !_isMuted;
    setState(() => _isMuted = nextMuted);
    _controller?.setVolume(nextMuted ? 0.0 : 1.0);
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
      if (!_isManuallyPaused) {
        controller.setVolume(_isMuted ? 0.0 : 1.0);
        controller.play();
      }
      // Call view API only when the video first becomes visible (not on every rebuild).
      if (!oldWidget.isActive) _callViewApi();
    } else {
      controller.setVolume(0.0);
      controller.pause();
      controller.seekTo(Duration.zero);
    }
  }

  bool get _isAdsVideo => widget.video.videoType.toLowerCase().trim() == 'ads';

  // Calls the correct view API based on video type.
  // Normal video  → /api/reporter/normal-video/view
  // Ads video     → /api/reporter/adsvideo/view
  // Errors are silently ignored — view count is best-effort.
  Future<void> _callViewApi() async {
    try {
      final token = await SessionTokenStore.getToken();
      final endpoint = _isAdsVideo
          ? '${ApiEndpoints.baseUrl}/reporter/adsvideo/view'
          : '${ApiEndpoints.baseUrl}/reporter/normal-video/view';
      final response = await http
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

      if (response.statusCode == 200 && mounted) {
        final Map<String, dynamic> json =
            jsonDecode(response.body) as Map<String, dynamic>;
        final newViews = (json['views_count'] as num?)?.toInt();
        if (newViews != null && newViews > 0) {
          setState(() => _viewCount = newViews);
        }
      }
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
          ? Uri.parse('${ApiEndpoints.baseUrl}/reporter/adsvideo/like')
          : Uri.parse('${ApiEndpoints.baseUrl}/reporter/normal-video/like');
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
      final bool? isLikedResp = json['liked'] is bool
          ? (json['liked'] as bool)
          : (json['is_liked'] is bool
                ? (json['is_liked'] as bool)
                : (json['action'] == 'liked'
                      ? true
                      : (json['action'] == 'unliked' ? false : null)));

      if (!mounted) return;

      setState(() {
        if (isLikedResp != null) {
          _isLiked = isLikedResp;
        }
        if (apiLikeCount != null) {
          _likesCount = apiLikeCount;
        }
      });

      if (animateHeart && _isLiked) await _runHeartAnimation();

      if (json['reward_info'] != null && json['reward_info'] is Map) {
        final reward = json['reward_info']['reward'];
        final numVal = (reward is num)
            ? reward.toDouble()
            : double.tryParse(reward?.toString() ?? '0') ?? 0.0;
        if (numVal > 0) {
          Get.snackbar(
            '🎉 ₹0.10 Credited!',
            'You earned ₹0.10 for liking this sponsored Ad Reel. Uplines rewarded!',
            backgroundColor: const Color(0xFF1E1E24),
            colorText: const Color(0xFF00E676),
            icon: const Icon(Icons.monetization_on_rounded, color: Color(0xFF00E676)),
            duration: const Duration(seconds: 4),
            snackPosition: SnackPosition.TOP,
          );
        }
      }

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

  bool _isManuallyPaused = false;

  void _onSingleTapVideo() {
    final c = _controller;
    if (c == null || !_initialized) return;
    setState(() {
      if (c.value.isPlaying) {
        c.pause();
        _isManuallyPaused = true;
      } else {
        c.play();
        _isManuallyPaused = false;
      }
    });
  }

  Future<void> _onDoubleTapVideo() async {
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
        onCommentAdded: () {
          if (mounted) setState(() => _commentsCount++);
        },
      ),
    );
  }

  String _fmt(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '$count';
  }

  String _formatTimestamp(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w';
      return DateFormat('d MMM').format(dt);
    } catch (_) {
      return '';
    }
  }

  bool get _isSelfVideo {
    final storage = Get.isRegistered<StorageService>()
        ? Get.find<StorageService>()
        : null;
    final currentUserId = storage?.getUserId() ?? 0;
    final currentUsername = storage?.getUsername().toLowerCase().trim() ?? '';
    if (widget.video.userId > 0 &&
        currentUserId > 0 &&
        widget.video.userId == currentUserId) {
      return true;
    }
    if (currentUsername.isNotEmpty &&
        widget.video.username.toLowerCase().trim() == currentUsername) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isReelsOnly) {
      return _buildInstagramHomeCard();
    }
    return _buildReelsImmersivePage();
  }

  /// 📱 Instagram Home Feed Card (Starts below stories, full width, sleek header & footer)
  Widget _buildInstagramHomeCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Post Header (Avatar, Username with verified check, Audio info, Options)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Obx(() {
                final storage = Get.isRegistered<StorageService>()
                    ? Get.find<StorageService>()
                    : null;
                final myAvatar = storage?.profileImage.value ?? '';
                final effectiveAvatar = (_isSelfVideo && myAvatar.isNotEmpty)
                    ? ApiEndpoints.mediaUrl(myAvatar)
                    : widget.video.userProfileImage;

                return CircleAvatar(
                  radius: 17,
                  backgroundColor: const Color(0xFF23232E),
                  backgroundImage: effectiveAvatar.isNotEmpty
                      ? NetworkImage(effectiveAvatar)
                      : null,
                  child: effectiveAvatar.isEmpty
                      ? Text(
                          (widget.video.username.isNotEmpty
                                  ? widget.video.username
                                  : widget.video.name)[0]
                              .toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        )
                      : null,
                );
              }),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.video.username.isNotEmpty
                                ? widget.video.username
                                : widget.video.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          color: Color(0xFF3897F0),
                          size: 13,
                        ),
                        if (_formatTimestamp(widget.video.createdAt).isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            '• ${_formatTimestamp(widget.video.createdAt)}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        if (_isAdsVideo) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB300).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFFFFB300),
                                width: 0.7,
                              ),
                            ),
                            child: const Text(
                              'AD • Earn ₹0.10',
                              style: TextStyle(
                                color: Color(0xFFFFB300),
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.music_note,
                          color: Colors.white60,
                          size: 11,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            widget.video.audioTitle.isNotEmpty
                                ? widget.video.audioTitle
                                : 'Original audio • Telso World',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.more_vert,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: () {
                  Get.bottomSheet(
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: const BoxDecoration(
                        color: Color(0xFF161622),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(
                              Icons.share,
                              color: Colors.white,
                            ),
                            title: const Text(
                              'Share',
                              style: TextStyle(color: Colors.white),
                            ),
                            onTap: () {
                              Get.back();
                              Share.share(
                                'Watch this on Telso World! 🔥 https://telsoworld.com/reel/${widget.video.id}',
                                subject: widget.video.subject,
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(
                              Icons.link,
                              color: Colors.white,
                            ),
                            title: const Text(
                              'Copy link',
                              style: TextStyle(color: Colors.white),
                            ),
                            onTap: () {
                              Get.back();
                              Clipboard.setData(
                                ClipboardData(
                                  text:
                                      'https://telsoworld.com/reel/${widget.video.id}',
                                ),
                              );
                              Get.snackbar(
                                'Link Copied',
                                'Reel link copied to clipboard!',
                                backgroundColor: const Color(0xFF1E1E24),
                                colorText: Colors.white,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // 2. Media View: Takes available height below stories and 100% full screen width!
        Expanded(
          child: GestureDetector(
            onTap: _onSingleTapVideo,
            onDoubleTap: _onDoubleTapVideo,
            child: Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: widget.video.mediaType == 'photo'
                      ? Image.network(
                          widget.video.photoUrl.isNotEmpty
                              ? widget.video.photoUrl
                              : widget.video.videoPath,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (_, __, ___) => _VideoErrorPlaceholder(
                            subject: widget.video.subject,
                          ),
                          loadingBuilder: (_, child, prog) => prog == null
                              ? child
                              : const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFFD70F64),
                                    strokeWidth: 2,
                                  ),
                                ),
                        )
                      : _hasError
                      ? _VideoErrorPlaceholder(subject: widget.video.subject)
                      : (_initialized && _controller != null)
                      ? SizedBox.expand(
                          child: FittedBox(
                            fit: BoxFit.cover,
                            clipBehavior: Clip.hardEdge,
                            child: SizedBox(
                              width: (_controller!.value.size.width > 0)
                                  ? _controller!.value.size.width
                                  : 720,
                              height: (_controller!.value.size.height > 0)
                                  ? _controller!.value.size.height
                                  : 1280,
                              child: VideoPlayer(_controller!),
                            ),
                          ),
                        )
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            if (widget.video.photoUrl.isNotEmpty)
                              Image.network(
                                widget.video.photoUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (_, __, ___) =>
                                    const ColoredBox(color: Colors.black),
                              )
                            else
                              const ColoredBox(color: Colors.black),
                            const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFD70F64),
                                strokeWidth: 2,
                              ),
                            ),
                          ],
                        ),
                ),

                // Play icon overlay when paused
                if (_initialized &&
                    _controller != null &&
                    (_isManuallyPaused || !_controller!.value.isPlaying))
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),

                // Double tap Heart Animation
                IgnorePointer(
                  child: Center(
                    child: FadeTransition(
                      opacity: _heartOpacity,
                      child: ScaleTransition(
                        scale: _heartScale,
                        child: Icon(
                          Icons.favorite_rounded,
                          color: const Color(0xFFFF2D55).withOpacity(0.95),
                          size: 96,
                        ),
                      ),
                    ),
                  ),
                ),

                // Floating audio badge on photo if hasAudio
                if (widget.video.mediaType == 'photo' && widget.video.hasAudio)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.music_note_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.video.audioTitle.isNotEmpty
                                ? widget.video.audioTitle
                                : 'Original audio',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // 3. Post Footer (Heart, Comment, Share, Bookmark, Mute, Real Likes, Caption)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _toggleLike(animateHeart: true),
                    child: Icon(
                      _isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: _isLiked ? const Color(0xFFFF2A6D) : Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _openCommentsSheet,
                    child: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () {
                      Share.share(
                        'Watch this trending post on Telso World! 🔥 https://telsoworld.com/reel/${widget.video.id}',
                        subject: widget.video.subject,
                      );
                    },
                    child: const Icon(
                      Icons.near_me_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  if (_viewCount > 0) ...[
                    const SizedBox(width: 14),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.visibility_outlined,
                          color: Colors.white54,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _fmt(_viewCount),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Spacer(),
                  if (widget.video.mediaType != 'photo')
                    GestureDetector(
                      onTap: _toggleMute,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Colors.white12,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isMuted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.bookmark_border_rounded,
                    color: Colors.white,
                    size: 25,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Real Likes Count
              Text(
                '$_likesCount ${_likesCount == 1 ? "like" : "likes"}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 3),
              // Caption
              RichText(
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  children: [
                    TextSpan(
                      text:
                          '${widget.video.username.isNotEmpty ? widget.video.username : widget.video.name} ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: widget.video.subject),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: _openCommentsSheet,
                child: Text(
                  _commentsCount > 0
                      ? 'View all $_commentsCount comments'
                      : 'View comments',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ],
    );
  }

  /// 🎬 Reels Immersive Full-Screen Page (Reels Tab)
  Widget _buildReelsImmersivePage() {
    return GestureDetector(
      onTap: _onSingleTapVideo,
      onDoubleTap: _onDoubleTapVideo,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Video / Photo / loading / error (Covers full screen width & height edge-to-edge) ──
          Positioned.fill(
            child: widget.video.mediaType == 'photo'
                ? Image.network(
                    widget.video.photoUrl.isNotEmpty
                        ? widget.video.photoUrl
                        : widget.video.videoPath,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (_, __, ___) =>
                        _VideoErrorPlaceholder(subject: widget.video.subject),
                    loadingBuilder: (_, child, prog) => prog == null
                        ? child
                        : const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFD70F64),
                              strokeWidth: 2,
                            ),
                          ),
                  )
                : _hasError
                ? _VideoErrorPlaceholder(subject: widget.video.subject)
                : (_initialized && _controller != null)
                ? SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(
                        width: (_controller!.value.size.width > 0)
                            ? _controller!.value.size.width
                            : 720,
                        height: (_controller!.value.size.height > 0)
                            ? _controller!.value.size.height
                            : 1280,
                        child: VideoPlayer(_controller!),
                      ),
                    ),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      if (widget.video.photoUrl.isNotEmpty)
                        Image.network(
                          widget.video.photoUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (_, __, ___) =>
                              const ColoredBox(color: Colors.black),
                        )
                      else
                        const ColoredBox(color: Colors.black),
                      const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFD70F64),
                          strokeWidth: 2,
                        ),
                      ),
                    ],
                  ),
          ),

          // ── Play/Pause Icon overlay when video is paused by user ──
          if (_initialized &&
              _controller != null &&
              (_isManuallyPaused || !_controller!.value.isPlaying))
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 1.5),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 46,
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

          // ── Sound Mute / Unmute button ──
          if (_initialized &&
              _controller != null &&
              widget.video.mediaType != 'photo')
            Positioned(
              right: 14,
              bottom: 300,
              child: GestureDetector(
                onTap: _toggleMute,
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Icon(
                    _isMuted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    color: _isMuted ? Colors.white70 : Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),

          // ── Right action buttons ──
          Positioned(
            right: 10,
            bottom: 28,
            child: Obx(() {
              final storage = Get.isRegistered<StorageService>()
                  ? Get.find<StorageService>()
                  : null;
              final myAvatar = storage?.profileImage.value ?? '';
              final effectiveAvatar = (_isSelfVideo && myAvatar.isNotEmpty)
                  ? ApiEndpoints.mediaUrl(myAvatar)
                  : widget.video.userProfileImage;

              return _RightActions(
                isLiked: _isLiked,
                likesCount: _likesCount,
                sharesCount: widget.video.sharesCount,
                commentsCount: _commentsCount,
                videoTitle: widget.video.subject,
                videoId: widget.video.id,
                profileImage: effectiveAvatar,
                showFollowButton: !_isSelfVideo,
                onLikeTap: () => _toggleLike(),
                onCommentTap: _openCommentsSheet,
              );
            }),
          ),

          // ── Bottom info (caption, creator & audio) ──
          Positioned(
            left: 14,
            right: 88,
            bottom: 20,
            child: _BottomInfo(video: widget.video),
          ),

          // ── Scrubbable progress bar at the very bottom ──
          if (_initialized &&
              _controller != null &&
              widget.video.mediaType != 'photo')
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
                      colors: [
                        Color(0xFFD70F64),
                        Color(0xFF8A2387),
                        Color(0xFFFF8008),
                      ],
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.graphic_eq_rounded,
                        color: Color(0xFF00E5FF),
                        size: 14,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Original Music Track • Live',
                        style: TextStyle(
                          color: Color(0xFF80D8FF),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
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
class _TopBar extends StatelessWidget {
  final String? referralCode;
  final VoidCallback onAdsTap;
  final bool hasSettingVideo;
  final VoidCallback? onTitleTap;

  const _TopBar({
    this.referralCode,
    required this.onAdsTap,
    required this.hasSettingVideo,
    this.onTitleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 🌟 Left: App Icon + "Telso World" Branding (Instagram font style)
          GestureDetector(
            onTap: onTitleTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 8),

                Text(
                  'Telso World',
                  style: GoogleFonts.lobster(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),

          // 💬 Right: Create [+] | Heart [Activity/Notifications] | Direct Message [Messenger]
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ➕ Create Post / Reel [+]
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ReelUploadScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  color: Colors.transparent,
                  child: const Icon(
                    Icons.add_box_outlined,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Point 10: Like button / Heart icon on top opens Activity / Notifications screen
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  color: Colors.transparent,
                  child: const Icon(
                    Icons.favorite_border_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Direct Messenger
              GestureDetector(
                onTap: () {
                  try {
                    Get.find<MainNavController>().changeTab(2);
                  } catch (_) {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const InboxScreen(),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  color: Colors.transparent,
                  child: const Icon(
                    Icons.near_me_outlined,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ],
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
  final int commentsCount;
  final String videoTitle;
  final int videoId;
  final String profileImage;
  final bool showFollowButton;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;

  const _RightActions({
    required this.isLiked,
    required this.likesCount,
    required this.sharesCount,
    this.commentsCount = 0,
    this.videoTitle = 'Telso Reel',
    this.videoId = 0,
    this.profileImage = '',
    this.showFollowButton = true,
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
    final link = widget.videoId > 0
        ? 'https://telsoworld.com/reel/${widget.videoId}'
        : 'https://telsoworld.com';
    Share.share(
      'Watch this trending reel on Telso World! 🔥 $link',
      subject: widget.videoTitle,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar with Follow + Badge (Only shown if not own video)
        _Avatar(
          profileImage: widget.profileImage,
          showFollowButton: widget.showFollowButton,
          isFollowing: _isFollowing,
          onFollowTap: () {
            setState(() => _isFollowing = !_isFollowing);
            Get.snackbar(
              _isFollowing ? 'Following ✨' : 'Unfollowed',
              _isFollowing
                  ? 'You are now following this creator'
                  : 'Unfollowed creator',
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
          child: _ActionButton(
            icon: Icons.chat_bubble_outline_rounded,
            label: widget.commentsCount > 0
                ? _fmt(widget.commentsCount)
                : 'Comment',
          ),
        ),
        const SizedBox(height: 18),

        // Share (Authentic Instagram Paper Plane)
        GestureDetector(
          onTap: _shareVideo,
          child: _ActionButton(
            icon: Icons.near_me_outlined,
            label: widget.sharesCount > 0 ? _fmt(widget.sharesCount) : 'Share',
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
  final String profileImage;
  final bool isFollowing;
  final bool showFollowButton;
  final VoidCallback onFollowTap;

  const _Avatar({
    this.profileImage = '',
    this.isFollowing = false,
    this.showFollowButton = true,
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
          child: ClipOval(
            child: profileImage.isNotEmpty
                ? Image.network(
                    profileImage,
                    fit: BoxFit.cover,
                    width: 48,
                    height: 48,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.person, color: Colors.white, size: 28),
                  )
                : const Icon(Icons.person, color: Colors.white, size: 28),
          ),
        ),
        if (showFollowButton)
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
                  color: isFollowing
                      ? const Color(0xFF00E676)
                      : const Color(0xFFD70F64),
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
  final VoidCallback? onCommentAdded;

  const _CommentsBottomSheet({
    required this.videoId,
    required this.videoType,
    this.onCommentAdded,
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
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/comments');
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
        throw Exception(
          json['message']?.toString() ?? 'Failed to fetch comments',
        );
      }

      final List<dynamic> data = json['data'] as List<dynamic>? ?? [];
      final List<CommentItem> fetched = data
          .map((e) => CommentItem.fromJson(e as Map<String, dynamic>))
          .toList();

      final pagination = json['pagination'] as Map<String, dynamic>? ?? {};
      final fetchedCurrentPage = _toInt(
        pagination['current_page'],
        fallback: page,
      );
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
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/comments/add');
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
      widget.onCommentAdded?.call();

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
          .map(
            (c) => c.id == comment.id
                ? c.copyWith(isLiked: optimisticLiked, likes: optimisticLikes)
                : c,
          )
          .toList();
    });

    try {
      final token = await SessionTokenStore.getToken();
      final response = await http
          .post(
            Uri.parse('${ApiEndpoints.baseUrl}/comments/like'),
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
              .map(
                (c) => c.id == comment.id
                    ? c.copyWith(isLiked: serverLiked, likes: correctedLikes)
                    : c,
              )
              .toList();
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _comments = _comments
            .map(
              (c) => c.id == comment.id
                  ? c.copyWith(isLiked: previousLiked, likes: previousLikes)
                  : c,
            )
            .toList();
      });
    } finally {
      if (mounted) {
        setState(() => _likingCommentIds.remove(comment.id));
      }
    }
  }

  Future<void> _editCommentDialog(CommentItem comment) async {
    final textController = TextEditingController(text: comment.comment);
    final editedText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: const Text(
          'Edit Comment',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Edit your comment...',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFD70F64)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFD70F64)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(textController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD70F64),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (editedText == null ||
        editedText.isEmpty ||
        editedText == comment.comment)
      return;

    try {
      final token = await SessionTokenStore.getToken();
      final response = await http
          .put(
            Uri.parse('${ApiEndpoints.baseUrl}/comments/${comment.id}'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'comment': editedText}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _comments = _comments
              .map(
                (c) => c.id == comment.id ? c.copyWith(comment: editedText) : c,
              )
              .toList();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment updated! ✨'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception('Failed to update comment (${response.statusCode})');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
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
            Uri.parse('${ApiEndpoints.baseUrl}/comments/${comment.id}'),
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
        throw Exception(
          json['message']?.toString() ?? 'Failed to delete comment',
        );
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
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
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
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white),
                ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 2,
                      ),
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
                              item.isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 2,
                      ),
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
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _editCommentDialog(item),
                icon: const Icon(
                  Icons.edit_outlined,
                  color: Colors.white54,
                  size: 18,
                ),
                tooltip: 'Edit comment',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              _deletingCommentIds.contains(item.id)
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
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white54,
                        size: 18,
                      ),
                      tooltip: 'Delete comment',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
            ],
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
        );
      },
    );
  }

  Future<void> _openRepliesSheet(CommentItem comment) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _RepliesBottomSheet(commentId: comment.id, parentUser: comment.user),
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
            Uri.parse(
              '${ApiEndpoints.baseUrl}/comments/${widget.commentId}/replies',
            ),
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
        throw Exception(
          json['message']?.toString() ?? 'Failed to fetch replies',
        );
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
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
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
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white),
                ),
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
            backgroundImage: item.profileImage.isNotEmpty
                ? NetworkImage(item.profileImage)
                : null,
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
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
String _formatVideoTimestamp(String? isoString) {
  if (isoString == null || isoString.isEmpty) return '';
  try {
    final dt = DateTime.parse(isoString).toLocal();
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w';
    return DateFormat('d MMM').format(dt);
  } catch (_) {
    return '';
  }
}

class _BottomInfo extends StatelessWidget {
  final VideoItem video;
  const _BottomInfo({required this.video});

  @override
  Widget build(BuildContext context) {
    final creatorName = video.name.isNotEmpty ? video.name : 'telso_creator';
    final isAd = video.videoType.toLowerCase().trim() == 'ads';
    final formattedTime = _formatVideoTimestamp(video.createdAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Creator Handle + Verified Badge + Timestamp + Ad Badge
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                '@$creatorName',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black87)],
                ),
                overflow: TextOverflow.ellipsis,
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
            if (formattedTime.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                '• $formattedTime',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black87)],
                ),
              ),
            ],
            if (isAd) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFB300), Color(0xFFFF6D00)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.monetization_on_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                    SizedBox(width: 3),
                    Text(
                      'AD • ₹0.10',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),

        // Video Caption / Subject
        Text(
          video.subject.isNotEmpty
              ? video.subject
              : 'Watch trending reels on Telso World! 🌟',
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
              const Icon(
                Icons.music_note_rounded,
                color: Color(0xFF00E5FF),
                size: 14,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  video.audioTitle.isNotEmpty
                      ? video.audioTitle
                      : 'Original Audio • @$creatorName',
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
