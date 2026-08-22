import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:telsoworld/core/constants/app_colors.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'Trending';

  final List<String> _categories = [
    'Trending',
    'Music 🎵',
    'Dance 💃',
    'Comedy 😂',
    'Folk Hits 🌟',
    'News 📰',
    'Bhojpuri 🎤',
  ];

  final List<Map<String, dynamic>> _trendingReels = [
    {
      'id': 1,
      'title': 'Bhojpuri Hits Folk Dance',
      'creator': 'Sarah Jenkins',
      'views': '125K',
      'likes': '12.4K',
      'category': 'Dance 💃',
      'gradient': [Color(0xFF8A2387), Color(0xFFE94057), Color(0xFFF27121)],
    },
    {
      'id': 2,
      'title': 'Harmonium Solo Classical',
      'creator': 'Alex Telso',
      'views': '540K',
      'likes': '45.1K',
      'category': 'Music 🎵',
      'gradient': [Color(0xFF11998E), Color(0xFF38EF7D)],
    },
    {
      'id': 3,
      'title': 'Street Comedy Vines Part 2',
      'creator': 'Rahul Mishra',
      'views': '89.2K',
      'likes': '7.8K',
      'category': 'Comedy 😂',
      'gradient': [Color(0xFFFF8008), Color(0xFFFFC837)],
    },
    {
      'id': 4,
      'title': 'Live Concert Acoustic Beats',
      'creator': 'Pooja Roy',
      'views': '320K',
      'likes': '28.9K',
      'category': 'Music 🎵',
      'gradient': [Color(0xFF2980B9), Color(0xFF6DD5FA)],
    },
    {
      'id': 5,
      'title': 'Patna Ground Report News',
      'creator': 'Telso Reporter',
      'views': '98.5K',
      'likes': '5.2K',
      'category': 'News 📰',
      'gradient': [Color(0xFFED213A), Color(0xFF93291E)],
    },
    {
      'id': 6,
      'title': 'Superhit Bhojpuri Song Track',
      'creator': 'Vikram Kumar',
      'views': '670K',
      'likes': '61.4K',
      'category': 'Bhojpuri 🎤',
      'gradient': [Color(0xFF654EA3), Color(0xFFEAAFC8)],
    },
  ];

  final List<Map<String, dynamic>> _topCreators = [
    {'name': 'Sarah Jenkins', 'handle': '@sarah_j', 'followers': '145K', 'avatar': 'SJ', 'color': Color(0xFF8A2387), 'isFollowing': false},
    {'name': 'Alex Telso', 'handle': '@alex_t', 'followers': '520K', 'avatar': 'AT', 'color': Color(0xFFE94057), 'isFollowing': true},
    {'name': 'Rahul Mishra', 'handle': '@rahul_m', 'followers': '89K', 'avatar': 'RM', 'color': Color(0xFF11998E), 'isFollowing': false},
    {'name': 'Pooja Roy', 'handle': '@pooja_r', 'followers': '310K', 'avatar': 'PR', 'color': Color(0xFFF27121), 'isFollowing': false},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredReels = _trendingReels.where((reel) {
      if (_selectedCategory != 'Trending' && reel['category'] != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return reel['title'].toString().toLowerCase().contains(q) ||
          reel['creator'].toString().toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D12),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Discover',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.white70),
            onPressed: () {
              Get.snackbar(
                'Filters',
                'Filter by location, views, and upload date.',
                snackPosition: SnackPosition.TOP,
                backgroundColor: const Color(0xFF1E1E24),
                colorText: Colors.white,
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // 🔍 Interactive Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF181822),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                decoration: InputDecoration(
                  hintText: 'Search reels, creators, hashtags...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryPink, size: 22),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Colors.white60, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 🏷️ Category Pills Row
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFFD70F64), Color(0xFFFF2A6D)],
                            )
                          : null,
                      color: isSelected ? null : const Color(0xFF181822),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? Colors.transparent : Colors.white10,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFFD70F64).withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),

          // 🌟 Spotlight Featured Banner (When not searching)
          if (_searchQuery.isEmpty) ...[
            _buildSpotlightBanner(),
            const SizedBox(height: 22),

            // 👥 Top Creators Carousel
            _buildTopCreatorsSection(),
            const SizedBox(height: 22),
          ],

          // 🎬 Trending Grid Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedCategory == 'Trending' ? '🔥 Trending Reels' : '🎬 $_selectedCategory',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${filteredReels.length} Reels',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 🎬 Reels Staggered Grid
          if (filteredReels.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              alignment: Alignment.center,
              child: const Text('No reels found', style: TextStyle(color: Colors.white38)),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
                itemCount: filteredReels.length,
                itemBuilder: (context, index) => _buildReelCard(filteredReels[index]),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSpotlightBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFFD70F64), Color(0xFF8A2387), Color(0xFF1E1E28)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryPink.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'CREATOR SPOTLIGHT',
                      style: TextStyle(color: Color(0xFFFFD700), fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Telso Viral Star 2026',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Win cash prizes & creator badges!',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.18),
              ),
              child: const Icon(Icons.star_rounded, color: Colors.white, size: 36),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCreatorsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '🌟 Featured Creators',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _topCreators.length,
            itemBuilder: (context, index) {
              final creator = _topCreators[index];
              return Container(
                width: 110,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF161620),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: creator['color'] as Color,
                      ),
                      child: Center(
                        child: Text(
                          creator['avatar'] as String,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      creator['name'] as String,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      creator['followers'] as String,
                      style: const TextStyle(color: Color(0xFFFF6584), fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReelCard(Map<String, dynamic> reel) {
    final colors = reel['gradient'] as List<Color>;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.35),
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.remove_red_eye_rounded, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      reel['views'] as String,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              left: 10,
              right: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reel['title'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        reel['creator'] as String,
                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      const Icon(Icons.favorite_rounded, color: Color(0xFFFF2A6D), size: 12),
                      const SizedBox(width: 2),
                      Text(
                        reel['likes'] as String,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
