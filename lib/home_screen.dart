import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:telsoworld/ads_video_screen.dart';
import 'package:telsoworld/session_token_store.dart';
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

  final safePath = encoded.startsWith('/') ? encoded : '/$encoded';
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

  const VideoItem({
    required this.id,
    required this.subject,
    required this.name,
    required this.videoPath,
    required this.likesCount,
    required this.sharesCount,
  });

  factory VideoItem.fromJson(Map<String, dynamic> json) => VideoItem(
    id: json['id'] as int? ?? 0,
    subject: json['subject']?.toString() ?? '',
    name: json['name']?.toString() ?? 'Unknown',
    videoPath: _normalizeVideoUrl(json['video_path']?.toString() ?? ''),
    likesCount: json['likes_count'] as int? ?? 0,
    sharesCount: json['shares_count'] as int? ?? 0,
  );
}

// ─────────────────────────────────────────
// FeedScreen — root widget (used by main.dart)
// ─────────────────────────────────────────
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final Logger _logger = Logger();

  bool _isLoading = true;
  String? _error;
  List<VideoItem> _videos = [];
  String? _referralCode;

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
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openAdsVideos() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AdsVideoScreen()));
  }

  // ── API call ──────────────────────────────────────────────
  Future<void> _fetchDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

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
          final List<dynamic> rawVideos =
              json['videos'] as List<dynamic>? ?? [];
          setState(() {
            _referralCode = json['referral_code']?.toString();
            _videos = rawVideos
                .map((v) => VideoItem.fromJson(v as Map<String, dynamic>))
                .where((v) => v.videoPath.isNotEmpty)
                .toList();
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = json['message']?.toString() ?? 'Failed to load feed.';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = 'Server error (${response.statusCode}). Pull down to retry.';
          _isLoading = false;
        });
      }
    } catch (e, st) {
      _logger.e('Dashboard error', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() {
        _error = 'Network error. Pull down to retry.\n$e';
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
              onRefresh: _fetchDashboard,
              color: const Color(0xFFD70F64),
              child: PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: _videos.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (ctx, i) =>
                    _VideoPage(video: _videos[i], isActive: i == _currentPage),
              ),
            ),

          // ── Top bar always visible ──
          SafeArea(
            bottom: false,
            child: _TopBar(
              referralCode: _referralCode,
              onAdsTap: _openAdsVideos,
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

  const _VideoPage({required this.video, required this.isActive});

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  File? _cachedVideoFile;
  late AnimationController _heartController;
  late Animation<double> _heartScale;
  late Animation<double> _heartOpacity;
  bool _initialized = false;
  bool _hasError = false;
  bool _isLiked = false;
  bool _showPlayIcon = false;
  int _heartAnimationRun = 0;

  @override
  void initState() {
    super.initState();
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
        if (widget.isActive) controller.play();
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
        if (widget.isActive) controller.play();
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
    final controller = _controller;
    if (!_initialized || controller == null) return;
    if (widget.isActive) {
      controller.play();
    } else {
      controller.pause();
      controller.seekTo(Duration.zero);
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

  void _onTap() {
    final controller = _controller;
    if (!_initialized || controller == null) return;
    setState(() => _showPlayIcon = true);
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showPlayIcon = false);
    });
  }

  Future<void> _onDoubleTap() async {
    if (!_isLiked && mounted) {
      setState(() => _isLiked = true);
    }

    final int runId = ++_heartAnimationRun;
    await _heartController.forward(from: 0);
    await Future<void>.delayed(const Duration(milliseconds: 650));

    if (!mounted || runId != _heartAnimationRun) return;
    await _heartController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      onDoubleTap: _onDoubleTap,
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

          // ── Play/Pause icon flash ──
          if (_showPlayIcon)
            Center(
              child: AnimatedOpacity(
                opacity: _showPlayIcon ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 180),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    (_initialized &&
                            _controller != null &&
                            _controller!.value.isPlaying)
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    color: Colors.white,
                    size: 40,
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
                    color: Colors.white.withValues(alpha: 0.96),
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
            bottom: 110,
            child: _RightActions(
              isLiked: _isLiked,
              likesCount: widget.video.likesCount,
              sharesCount: widget.video.sharesCount,
              onLikeTap: () => setState(() => _isLiked = !_isLiked),
            ),
          ),

          // ── Bottom info ──
          Positioned(
            left: 16,
            right: 90,
            bottom: 100,
            child: _BottomInfo(video: widget.video),
          ),

          // ── Scrubbable progress bar ──
          if (_initialized)
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

class _VideoErrorPlaceholder extends StatelessWidget {
  final String subject;
  const _VideoErrorPlaceholder({required this.subject});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111111),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.videocam_off_rounded,
              color: Colors.white24,
              size: 56,
            ),
            const SizedBox(height: 10),
            Text(
              subject,
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              'Video unavailable',
              style: TextStyle(color: Colors.white24, fontSize: 12),
            ),
          ],
        ),
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
  const _TopBar({this.referralCode, required this.onAdsTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // Referral code badge
          if (referralCode != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFD70F64).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                referralCode!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            )
          else
            const SizedBox(width: 8),
          const Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // _TabItem(label: 'Following', isActive: false),
                // SizedBox(width: 28),
                // _TabItem(label: 'For You', isActive: true),
                const SizedBox(width: 28),
              ],
            ),
          ),
          GestureDetector(
            onTap: onAdsTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFD70F64).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'Ads Video',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.search, color: Colors.white, size: 26),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final bool isActive;

  const _TabItem({required this.label, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isActive
                ? Colors.white
                : Colors.white.withValues(alpha: 0.55),
            fontSize: isActive ? 17 : 15,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        const SizedBox(height: 4),
        if (isActive)
          Container(
            width: 24,
            height: 2.5,
            decoration: BoxDecoration(
              color: const Color(0xFFD70F64),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
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
  final VoidCallback onLikeTap;

  const _RightActions({
    required this.isLiked,
    required this.likesCount,
    required this.sharesCount,
    required this.onLikeTap,
  });

  @override
  State<_RightActions> createState() => _RightActionsState();
}

class _RightActionsState extends State<_RightActions>
    with SingleTickerProviderStateMixin {
  late AnimationController _heartCtrl;
  late Animation<double> _heartScale;

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

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar
        _Avatar(),
        const SizedBox(height: 22),

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
              label: _fmt(
                widget.isLiked ? widget.likesCount + 1 : widget.likesCount,
              ),
              iconColor: widget.isLiked
                  ? const Color(0xFFD70F64)
                  : Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Comment
        const _ActionButton(icon: Icons.chat_bubble_rounded, label: '—'),
        const SizedBox(height: 20),

        // Share
        _ActionButton(
          icon: Icons.reply_rounded,
          label: _fmt(widget.sharesCount),
          flipHorizontal: true,
        ),
        const SizedBox(height: 20),

        // Spinning disc
        _SpinningDisc(),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
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
            color: const Color(0xFF4A7A6A),
          ),
          child: const ClipOval(
            child: Icon(Icons.person, color: Colors.white70, size: 30),
          ),
        ),
        Positioned(
          bottom: -10,
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFD70F64),
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 14),
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
// Bottom Info  (subject + creator name)
// ─────────────────────────────────────────
class _BottomInfo extends StatelessWidget {
  final VideoItem video;
  const _BottomInfo({required this.video});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '@${video.name}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            shadows: [Shadow(blurRadius: 6, color: Colors.black)],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          video.subject,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 14,
            height: 1.4,
            shadows: const [Shadow(blurRadius: 6, color: Colors.black)],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.music_note, color: Colors.white70, size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Telso World — ${video.subject}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
