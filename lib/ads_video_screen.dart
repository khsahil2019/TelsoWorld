import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
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

class AdVideoItem {
  final int id;
  final String name;
  final String videoUrl;
  final int likesCount;
  final String createdAt;

  const AdVideoItem({
    required this.id,
    required this.name,
    required this.videoUrl,
    required this.likesCount,
    required this.createdAt,
  });

  factory AdVideoItem.fromJson(Map<String, dynamic> json) {
    return AdVideoItem(
      id: (json['video_id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString().trim().isNotEmpty == true
          ? json['name'].toString().trim()
          : 'Ads Video',
      videoUrl: _normalizeVideoUrl(json['video_url']?.toString() ?? ''),
      likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at']?.toString() ?? '',
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

  Future<void> _fetchAdsVideos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

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

      if (!mounted) return;
      setState(() {
        _referralCode = json['referral_code']?.toString();
        _videos = parsed;
        _isLoading = false;
      });
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

  const _AdsVideoPage({required this.video, required this.isActive});

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

  Future<void> _toggleLike({bool animateHeart = false}) async {
    if (_isLiking) return;

    final previousLiked = _isLiked;
    final previousLikes = _likesCount;
    final nextLiked = !previousLiked;
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

      if (animateHeart && _isLiked) {
        final runId = ++_heartAnimationRun;
        await _heartController.forward(from: 0);
        await Future<void>.delayed(const Duration(milliseconds: 650));
        if (!mounted || runId != _heartAnimationRun) return;
        await _heartController.reverse();
      }
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

  Future<void> _onDoubleTap() async {
    await _toggleLike(animateHeart: true);
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
      onDoubleTap: _onDoubleTap,
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
                    color: Colors.pinkAccent.withValues(alpha: 0.96),
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
