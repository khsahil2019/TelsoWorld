import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:telsoworld/core/constants/api_endpoints.dart';
import 'package:telsoworld/core/services/session_token_store.dart';
import 'package:telsoworld/models/story_model.dart';

class StoryViewerScreen extends StatefulWidget {
  final List<UserStoryGroup> storyGroups;
  final int initialGroupIndex;

  const StoryViewerScreen({
    super.key,
    required this.storyGroups,
    this.initialGroupIndex = 0,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late int _currentGroupIndex;
  late int _currentStoryIndex;

  AnimationController? _animController;
  VideoPlayerController? _videoController;
  bool _isVideoLoading = false;

  UserStoryGroup get _currentGroup => widget.storyGroups[_currentGroupIndex];
  StoryItem get _currentStory => _currentGroup.stories[_currentStoryIndex];

  @override
  void initState() {
    super.initState();
    _currentGroupIndex = widget.initialGroupIndex.clamp(0, widget.storyGroups.length - 1);
    _currentStoryIndex = 0;
    _startStory();
  }

  void _startStory() {
    _animController?.stop();
    _animController?.dispose();
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;

    final story = _currentStory;
    _recordView(story.id);

    if (story.mediaType == 'video') {
      setState(() => _isVideoLoading = true);
      final videoUri = Uri.parse(ApiEndpoints.mediaUrl(story.mediaUrl));
      _videoController = VideoPlayerController.networkUrl(
        videoUri,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      )..initialize().then((_) {
          if (!mounted) return;
          setState(() => _isVideoLoading = false);
          final duration = _videoController!.value.duration;
          _videoController!.play();
          _videoController!.setVolume(1.0);
          _setupAnimation(duration.inMilliseconds > 0 ? duration : const Duration(seconds: 7));
        }).catchError((_) {
          if (mounted) {
            setState(() => _isVideoLoading = false);
            _setupAnimation(const Duration(seconds: 5));
          }
        });
    } else {
      setState(() => _isVideoLoading = false);
      _setupAnimation(const Duration(seconds: 5));
    }
  }

  void _setupAnimation(Duration duration) {
    _animController = AnimationController(
      vsync: this,
      duration: duration,
    );

    _animController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });

    _animController!.forward();
    if (mounted) setState(() {});
  }

  void _nextStory() {
    if (_currentStoryIndex < _currentGroup.stories.length - 1) {
      setState(() {
        _currentStoryIndex++;
      });
      _startStory();
    } else if (_currentGroupIndex < widget.storyGroups.length - 1) {
      setState(() {
        _currentGroupIndex++;
        _currentStoryIndex = 0;
      });
      _startStory();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _previousStory() {
    if (_currentStoryIndex > 0) {
      setState(() {
        _currentStoryIndex--;
      });
      _startStory();
    } else if (_currentGroupIndex > 0) {
      setState(() {
        _currentGroupIndex--;
        _currentStoryIndex = widget.storyGroups[_currentGroupIndex].stories.length - 1;
      });
      _startStory();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _pauseStory() {
    _animController?.stop();
    _videoController?.pause();
  }

  void _resumeStory() {
    _animController?.forward();
    _videoController?.play();
  }

  Future<void> _recordView(int storyId) async {
    try {
      final token = await SessionTokenStore.getToken();
      await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}/reporter/stories/$storyId/view'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
    } catch (_) {}
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    return '1d ago';
  }

  @override
  void dispose() {
    _animController?.stop();
    _animController?.dispose();
    _videoController?.pause();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final group = _currentGroup;
    final story = _currentStory;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onLongPressStart: (_) => _pauseStory(),
        onLongPressEnd: (_) => _resumeStory(),
        onTapUp: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width * 0.35) {
            _previousStory();
          } else {
            _nextStory();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Media Background
            if (story.mediaType == 'video')
              !_isVideoLoading && _videoController != null && _videoController!.value.isInitialized
                  ? Center(
                      child: AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!),
                      ),
                    )
                  : const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFD70F64),
                      ),
                    )
            else
              Image.network(
                ApiEndpoints.mediaUrl(story.mediaUrl),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
                ),
                loadingBuilder: (_, child, prog) {
                  if (prog == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFD70F64)),
                  );
                },
              ),

            // Top gradient overlay for contrast
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 140,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
              ),
            ),

            // Top Progress Bars & Header
            SafeArea(
              child: Column(
                children: [
                  // Progress bars for all stories in group
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      children: List.generate(group.stories.length, (index) {
                        return Expanded(
                          child: Container(
                            height: 3,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: AnimatedBuilder(
                              animation: _animController ?? const AlwaysStoppedAnimation(0),
                              builder: (context, _) {
                                double value = 0.0;
                                if (index < _currentStoryIndex) {
                                  value = 1.0;
                                } else if (index == _currentStoryIndex) {
                                  value = _animController?.value ?? 0.0;
                                }
                                return FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: value,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  // User Info Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFD70F64),
                          backgroundImage: group.profileImage.isNotEmpty
                              ? NetworkImage(ApiEndpoints.mediaUrl(group.profileImage))
                              : null,
                          child: group.profileImage.isEmpty
                              ? Text(
                                  group.name.isNotEmpty ? group.name[0].toUpperCase() : 'U',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              _formatTimeAgo(story.createdAt),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Text(
                            '24h Story ⏳',
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 24),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Caption & Quick Action
            if (story.caption.isNotEmpty)
              Positioned(
                bottom: 40,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    story.caption,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
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
