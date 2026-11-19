import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:telsoworld/core/constants/api_endpoints.dart';
import 'package:telsoworld/core/services/session_token_store.dart';
import 'package:telsoworld/views/profile/profile_reels_viewer_screen.dart';

/// ---------------------------------------------------------------------------
/// 🔍 DiscoveryScreen (Instagram-Style Explore & Search Grid)
/// ---------------------------------------------------------------------------
/// - Top Search Bar with live creator and reel filtering
/// - 3-Column Explore Grid with real video thumbnails and reel badges
/// - Full-screen reel viewer on tap matching Instagram Explore
/// ---------------------------------------------------------------------------
class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _exploreVideos = [];
  List<Map<String, dynamic>> _allCreators = [];

  // Gradient fallbacks for tiles while loading
  final List<List<Color>> _tileGradients = const [
    [Color(0xFF8A2387), Color(0xFFE94057)],
    [Color(0xFF11998E), Color(0xFF38EF7D)],
    [Color(0xFFF2994A), Color(0xFFF2C94C)],
    [Color(0xFF2980B9), Color(0xFF6DD5FA)],
    [Color(0xFFED213A), Color(0xFF93291E)],
    [Color(0xFF654EA3), Color(0xFFEAAFC8)],
  ];

  @override
  void initState() {
    super.initState();
    _fetchExploreContent();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchExploreContent() async {
    try {
      final token = await SessionTokenStore.getToken();
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/reporter/dashboard');
      final res = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json is Map && json['videos'] is List) {
          final raw = (json['videos'] as List).whereType<Map<String, dynamic>>().toList();

          // Extract unique creators for search
          final Map<String, Map<String, dynamic>> creatorMap = {};
          for (final v in raw) {
            final u = (v['username'] ?? v['name'] ?? '').toString().trim();
            if (u.isNotEmpty && !creatorMap.containsKey(u)) {
              creatorMap[u] = {
                'username': u,
                'name': v['name'] ?? u,
                'profile_image': v['thumbnail_url'] ?? '',
                'likes': v['likes_count'] ?? 0,
              };
            }
          }

          if (mounted) {
            setState(() {
              _exploreVideos = raw;
              _allCreators = creatorMap.values.toList();
              _isLoading = false;
            });
          }
          return;
        }
      }
    } catch (_) {}

    if (mounted) setState(() => _isLoading = false);
  }

  String _formatCount(dynamic number) {
    final num n = (number is num) ? number : (num.tryParse(number?.toString() ?? '') ?? 0);
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toInt().toString();
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchQuery.trim().toLowerCase();

    // Filter videos matching query
    final filteredVideos = _exploreVideos.where((v) {
      if (q.isEmpty) return true;
      final title = (v['title'] ?? v['subject'] ?? '').toString().toLowerCase();
      final user = (v['username'] ?? v['name'] ?? '').toString().toLowerCase();
      return title.contains(q) || user.contains(q);
    }).toList();

    // Filter creators matching query
    final filteredCreators = _allCreators.where((c) {
      if (q.isEmpty) return false;
      final u = c['username'].toString().toLowerCase();
      final n = c['name'].toString().toLowerCase();
      return u.contains(q) || n.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // 🔍 Instagram-style Sleek Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF262626),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search creators, reels, sounds...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.white60, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: const Icon(Icons.cancel_rounded, color: Colors.white54, size: 18),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),

            // Main Content Area (Creator search suggestions or 3-column Explore Grid)
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFFD70F64), strokeWidth: 2),
                    )
                  : RefreshIndicator(
                      color: const Color(0xFFD70F64),
                      backgroundColor: const Color(0xFF161620),
                      onRefresh: _fetchExploreContent,
                      child: _searchQuery.isNotEmpty && filteredCreators.isNotEmpty
                          ? _buildSearchResults(filteredCreators, filteredVideos)
                          : _buildExploreGrid(filteredVideos),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 👥 Search Results with Creators and Matching Videos
  Widget _buildSearchResults(
    List<Map<String, dynamic>> creators,
    List<Map<String, dynamic>> videos,
  ) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      children: [
        const Text(
          'Creators',
          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...creators.map((c) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFF2E2E38),
                backgroundImage: (c['profile_image'] != null && c['profile_image'].toString().isNotEmpty)
                    ? NetworkImage(ApiEndpoints.mediaUrl(c['profile_image'].toString()))
                    : null,
                child: (c['profile_image'] == null || c['profile_image'].toString().isEmpty)
                    ? Text(
                        c['username'].toString().isNotEmpty ? c['username'][0].toUpperCase() : 'U',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              title: Row(
                children: [
                  Text(
                    '@${c['username']}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.verified, color: Color(0xFF3897F0), size: 14),
                ],
              ),
              subtitle: Text(
                c['name']?.toString() ?? '',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              trailing: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                ),
                child: const Text('Follow', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            )),
        const SizedBox(height: 16),
        const Text(
          'Reels & Videos',
          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildExploreGrid(videos, shrinkWrap: true),
      ],
    );
  }

  /// 📸 Instagram 3-Column Explore Grid
  Widget _buildExploreGrid(List<Map<String, dynamic>> items, {bool shrinkWrap = false}) {
    if (items.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.search_off_rounded, size: 48, color: Colors.white24),
              SizedBox(height: 12),
              Text(
                'No Reels Found',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                'Try searching another username or topic.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
      shrinkWrap: shrinkWrap,
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 0.65, // Elegant tall reel tile
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final video = items[index];
        final gradient = _tileGradients[index % _tileGradients.length];
        final rawThumb = (video['thumbnail_url']?.toString().trim().isNotEmpty == true ? video['thumbnail_url'] : null) ??
            (video['image']?.toString().trim().isNotEmpty == true ? video['image'] : null) ??
            (video['photo_url']?.toString().trim().isNotEmpty == true ? video['photo_url'] : null) ??
            (video['video_url']?.toString().trim().isNotEmpty == true ? video['video_url'] : null) ??
            (video['video_path']?.toString().trim().isNotEmpty == true ? video['video_path'] : null);
        final thumbUrl = (rawThumb != null && rawThumb.toString().trim().isNotEmpty)
            ? ApiEndpoints.mediaUrl(rawThumb.toString().trim())
            : '';
        final isVideo = video['media_type']?.toString().toLowerCase() != 'photo';
        final viewsCount = video['view_count'] ?? video['views'] ?? 0;

        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ProfileReelsViewerScreen(
                  videos: items,
                  initialIndex: index,
                  onLikedStateChanged: _fetchExploreContent,
                ),
              ),
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail Image or Artistic Gradient
              if (thumbUrl.isNotEmpty)
                Image.network(
                  thumbUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        isVideo ? Icons.movie_outlined : Icons.photo_outlined,
                        color: Colors.white38,
                        size: 28,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      isVideo ? Icons.movie_outlined : Icons.photo_outlined,
                      color: Colors.white38,
                      size: 28,
                    ),
                  ),
                ),

              // Bottom Vignette Gradient
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 40,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                ),
              ),

              // Top-Right: Instagram Reel / Carousel Icon
              if (isVideo)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3.5),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.movie_outlined,
                      color: Colors.white,
                      size: 13,
                    ),
                  ),
                ),

              // Bottom-Left: Views / Likes count
              Positioned(
                left: 6,
                bottom: 6,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 13),
                    const SizedBox(width: 2),
                    Text(
                      _formatCount(viewsCount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
