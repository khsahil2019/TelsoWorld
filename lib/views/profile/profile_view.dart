import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:telsoworld/core/constants/api_endpoints.dart';
import 'package:telsoworld/core/constants/app_colors.dart';
import 'package:telsoworld/core/routes/app_routes.dart';
import 'package:telsoworld/core/services/session_token_store.dart';
import 'package:telsoworld/core/services/storage_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:telsoworld/views/ads/ads_view.dart';
import 'package:telsoworld/views/profile/followers_following_screen.dart';
import 'package:telsoworld/views/profile/edit_profile_screen.dart';
import 'package:telsoworld/views/profile/profile_reels_viewer_screen.dart';
import 'package:telsoworld/views/upload/reel_upload_view.dart';
import 'package:telsoworld/views/upload/uploaded_video_view.dart';
import 'package:telsoworld/views/wallet/wallet_view.dart';
import 'package:telsoworld/views/web_link/updated_web_link_view.dart';

/// ---------------------------------------------------------------------------
/// 👤 ProfileScreen (Real-Time Creator Profile & Analytics Hub)
/// ---------------------------------------------------------------------------
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = true;
  bool _isLoggingOut = false;

  String _userName = 'Creator';
  String _userHandle = '@creator';
  String _bio = 'Official Creator on Telso World 🎵';
  String _walletBalance = '₹0.00';
  String _profileImageUrl = '';
  int _totalVideos = 0;
  int _followersCount = 0;
  int _followingCount = 0;
  int _totalLikes = 0;

  List<Map<String, dynamic>> _userReels = [];
  List<Map<String, dynamic>> _likedReels = [];
  List<Map<String, dynamic>> _highlights = [];

  void _openFollowersScreen(int tabIndex) {
    final storage = Get.isRegistered<StorageService>() ? Get.find<StorageService>() : null;
    final userId = storage?.getUserId() ?? 1;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FollowersFollowingScreen(
          userId: userId,
          username: _userHandle.replaceAll('@', ''),
          initialTab: tabIndex,
        ),
      ),
    ).then((_) => _loadProfileData());
  }

  void _openEditProfile() {
    final storage = Get.isRegistered<StorageService>() ? Get.find<StorageService>() : null;
    final activeAvatar = storage?.profileImage.value.isNotEmpty == true
        ? storage!.profileImage.value
        : _profileImageUrl;

    Navigator.of(context).push<dynamic>(
      MaterialPageRoute<dynamic>(
        builder: (_) => EditProfileScreen(
          currentName: _userName,
          currentUsername: _userHandle.replaceAll('@', ''),
          currentBio: _bio,
          currentAvatar: activeAvatar,
        ),
      ),
    ).then((updated) {
      if (updated != null) {
        if (updated is String && updated.isNotEmpty) {
          setState(() {
            _profileImageUrl = updated;
          });
        }
        _loadProfileData();
      }
    });
  }

  void _shareProfile() {
    final handle = _userHandle.replaceAll('@', '');
    Share.share(
      'Check out @$handle on Telso World! ✨\nhttps://telsoworld.com/profile/$handle',
      subject: 'Telso World Profile',
    );
  }

  final List<List<Color>> _gridGradients = const [
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
    _loadProfileData();
  }

  String _formatCount(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  String? _getThumbnailUrl(Map<String, dynamic> video) {
    final raw = (video['thumbnail_url']?.toString().trim().isNotEmpty == true ? video['thumbnail_url'] : null) ??
        (video['image']?.toString().trim().isNotEmpty == true ? video['image'] : null) ??
        (video['photo_url']?.toString().trim().isNotEmpty == true ? video['photo_url'] : null) ??
        (video['video_url']?.toString().trim().isNotEmpty == true ? video['video_url'] : null) ??
        (video['video_path']?.toString().trim().isNotEmpty == true ? video['video_path'] : null);
    if (raw == null) return null;
    final str = raw.toString().trim();
    if (str.isEmpty) return null;
    return ApiEndpoints.mediaUrl(str);
  }

  Future<void> _loadProfileData() async {
    try {
      final token = await SessionTokenStore.getToken();
      if (token.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final profileResponse = await http
          .get(
            Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.profile}'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (profileResponse.statusCode == 200) {
        final json = jsonDecode(profileResponse.body);
        if (mounted && json is Map && json['data'] is Map) {
          final d = json['data'] as Map<String, dynamic>;
          final rawVideos =
              (d['videos'] as List?)
                  ?.whereType<Map<String, dynamic>>()
                  .toList() ??
              [];
          final rawLiked =
              (d['liked_videos'] as List?)
                  ?.whereType<Map<String, dynamic>>()
                  .toList() ??
              [];

          setState(() {
            _userName = d['name']?.toString().trim().isNotEmpty == true
                ? d['name'].toString().trim()
                : (d['username']?.toString() ?? 'Creator');
            final rawHandle = d['username']?.toString() ?? 'creator';
            _userHandle = rawHandle.startsWith('@') ? rawHandle : '@$rawHandle';
            _bio = d['bio']?.toString().trim().isNotEmpty == true
                ? d['bio'].toString().trim()
                : 'Official Creator on Telso World 🎵';
            _walletBalance = '₹${d['wallet_balance'] ?? '0.00'}';
            final img = d['profile_image']?.toString() ?? '';
            _profileImageUrl = img;
            if (img.isNotEmpty) {
              final storage = Get.isRegistered<StorageService>()
                  ? Get.find<StorageService>()
                  : null;
              storage?.setProfileImage(img);
            }
            _totalVideos =
                int.tryParse(d['total_videos']?.toString() ?? '') ??
                rawVideos.length;
            _followersCount =
                int.tryParse(d['followers_count']?.toString() ?? '') ?? 0;
            _followingCount =
                int.tryParse(d['following_count']?.toString() ?? '') ?? 0;
            _totalLikes = int.tryParse(d['total_likes']?.toString() ?? '') ?? 0;
            _userReels = rawVideos;
            _likedReels = rawLiked;
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Error loading real-time profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Logout',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to log out from Telso World?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white60),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPink,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Logout',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoggingOut = true);
    try {
      final token = await SessionTokenStore.getToken();
      if (token.isNotEmpty) {
        await http
            .post(
              Uri.parse('${ApiEndpoints.baseUrl}/reporter/logout'),
              headers: {
                'Authorization': 'Bearer $token',
                'Accept': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 15));
      }
    } catch (_) {}

    await SessionTokenStore.clearToken();
    if (mounted) {
      setState(() => _isLoggingOut = false);
      Get.offAllNamed(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFF0F0F12),
        endDrawer: _buildProfileDrawer(),
        body: RefreshIndicator(
          color: AppColors.primaryPink,
          backgroundColor: const Color(0xFF1E1E24),
          onRefresh: _loadProfileData,
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(child: _buildProfileHeader()),
            ],
            body: Column(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF141418),
                    border: Border(
                      bottom: BorderSide(color: Colors.white10, width: 1),
                    ),
                  ),
                  child: const TabBar(
                    indicatorColor: AppColors.primaryPink,
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    unselectedLabelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    tabs: [
                      Tab(
                        icon: Icon(Icons.grid_on_rounded, size: 18),
                        text: 'Posts',
                      ),
                      Tab(
                        icon: Icon(Icons.movie_outlined, size: 18),
                        text: 'Reels',
                      ),
                      Tab(
                        icon: Icon(Icons.photo_library_outlined, size: 18),
                        text: 'Photos',
                      ),
                      Tab(
                        icon: Icon(Icons.campaign_outlined, size: 18),
                        text: 'Ads',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryPink,
                            strokeWidth: 2,
                          ),
                        )
                      : TabBarView(
                          children: [
                            // 1. Posts (All media)
                            _buildReelsGrid(_userReels),
                            // 2. Reels (Only video reels)
                            _buildReelsGrid(
                              _userReels
                                  .where(
                                    (v) =>
                                        (v['media_type']
                                            ?.toString()
                                            .toLowerCase() !=
                                        'photo' &&
                                         v['video_type']
                                            ?.toString()
                                            .toLowerCase() !=
                                        'ads'),
                                  )
                                  .toList(),
                            ),
                            // 3. Photos (Only photos)
                            _buildPhotosGrid(
                              _userReels
                                  .where(
                                    (v) =>
                                        (v['media_type']
                                            ?.toString()
                                            .toLowerCase() ==
                                        'photo'),
                                  )
                                  .toList(),
                            ),
                            // 4. Ads (Only advertisements)
                            _buildReelsGrid(
                              _userReels
                                  .where(
                                    (v) =>
                                        (v['video_type']
                                            ?.toString()
                                            .toLowerCase() ==
                                        'ads'),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 🌟 Profile Header (Clean & Minimalist, Quick Tools Moved to Drawer)
  Widget _buildProfileHeader() {
    final avatarLetter = _userName.trim().isNotEmpty
        ? _userName.trim()[0].toUpperCase()
        : 'C';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primaryPink.withOpacity(0.35),
            const Color(0xFF0F0F12),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              // 🔝 Top Bar with Handle & Instagram-style Menu Drawer Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                  Text(
                    _userHandle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.menu_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                    tooltip: 'Creator Menu & Wallet',
                    onPressed: () {
                      _scaffoldKey.currentState?.openEndDrawer();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Avatar with Gradient Ring
              GestureDetector(
                onTap: _openEditProfile,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.primaryPink,
                            Color(0xFFFF6584),
                            Color(0xFFFFC371),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryPink.withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Obx(() {
                        final storage = Get.isRegistered<StorageService>() ? Get.find<StorageService>() : null;
                        final effectiveImg = storage?.profileImage.value.isNotEmpty == true
                            ? storage!.profileImage.value
                            : _profileImageUrl;

                        return Container(
                          width: 86,
                          height: 86,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF1E1E24),
                          ),
                          child: ClipOval(
                            child: effectiveImg.isNotEmpty
                                ? Image.network(
                                    ApiEndpoints.mediaUrl(effectiveImg),
                                    width: 86,
                                    height: 86,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Text(
                                        avatarLetter,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 36,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      avatarLetter,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                          ),
                        );
                      }),
                    ),
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryPink,
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Name & Badge
              Text(
                _userName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryPink.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primaryPink.withOpacity(0.5),
                  ),
                ),
                child: const Text(
                  'Verified Creator',
                  style: TextStyle(
                    color: Color(0xFFFF6584),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              if (_bio.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    _bio,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Real-Time Stats Row Card
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A22),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(_totalVideos.toString(), 'POSTS'),
                    _buildDivider(),
                    GestureDetector(
                      onTap: () => _openFollowersScreen(0),
                      behavior: HitTestBehavior.opaque,
                      child: _buildStatItem(_formatCount(_followersCount), 'FOLLOWERS'),
                    ),
                    _buildDivider(),
                    GestureDetector(
                      onTap: () => _openFollowersScreen(1),
                      behavior: HitTestBehavior.opaque,
                      child: _buildStatItem(_formatCount(_followingCount), 'FOLLOWING'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Edit Profile & Share Profile Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 34,
                        child: ElevatedButton(
                          onPressed: _openEditProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF262626),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          child: const Text(
                            'Edit profile',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 34,
                        child: ElevatedButton(
                          onPressed: _shareProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF262626),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          child: const Text(
                            'Share profile',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 🌟 Story Highlights Row
              _buildStoryHighlights(),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateHighlightDialog() {
    final titleCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('New highlight', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: titleCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Highlight name (e.g. Memories, Travel)',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryPink)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = titleCtrl.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(ctx).pop();
                setState(() {
                  _highlights.insert(0, {'title': name, 'cover_url': ''});
                });
                try {
                  final token = await SessionTokenStore.getToken();
                  final uri = Uri.parse('${ApiEndpoints.baseUrl}/reporter/highlights');
                  await http.post(
                    uri,
                    headers: {
                      'Authorization': 'Bearer $token',
                      'Accept': 'application/json',
                      'Content-Type': 'application/json',
                    },
                    body: jsonEncode({'title': name}),
                  );
                } catch (_) {}
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPink),
            child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// 🌟 Instagram Story Highlights Row (Dynamic + "New" Button)
  Widget _buildStoryHighlights() {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 1 + _highlights.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          if (index == 0) {
            return GestureDetector(
              onTap: _showCreateHighlightDialog,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white30, width: 1.5),
                      color: const Color(0xFF1A1A22),
                    ),
                    child: const Center(
                      child: Icon(Icons.add_rounded, color: Colors.white70, size: 28),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'New',
                    style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }

          final h = _highlights[index - 1];
          final title = h['title']?.toString() ?? 'Highlight';
          final cover = h['cover_url']?.toString() ?? '';

          return GestureDetector(
            onTap: () {
              Get.snackbar(
                title,
                'Playing highlight collection 🌟',
                backgroundColor: const Color(0xFF1E1E24),
                colorText: Colors.white,
                snackPosition: SnackPosition.BOTTOM,
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryPink, width: 1.5),
                    color: const Color(0xFF1A1A22),
                  ),
                  child: ClipOval(
                    child: cover.isNotEmpty
                        ? Image.network(
                            ApiEndpoints.mediaUrl(cover),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.star_rounded, color: Colors.white, size: 24),
                          )
                        : const Center(
                            child: Icon(Icons.star_rounded, color: Colors.white, size: 24),
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 60,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 📸 Photos Grid for Photos & Posts Tab
  Widget _buildPhotosGrid(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.photo_library_outlined,
                size: 44,
                color: Colors.white24,
              ),
              const SizedBox(height: 10),
              const Text(
                'No Photos Shared Yet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Share photos with or without sound to see them here!',
                style: TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const ReelUploadScreen(initialMode: 'photo'),
                        ),
                      )
                      .then((_) => _loadProfileData());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                icon: const Icon(Icons.add_a_photo_rounded, size: 16),
                label: const Text(
                  'Post Photo',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 1.0,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final photo = items[index];
        final photoUrl = _getThumbnailUrl(photo);
        final hasAudio =
            photo['has_audio'] != false && photo['has_audio'] != 'false';

        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ProfileReelsViewerScreen(
                  videos: items,
                  initialIndex: index,
                  onLikedStateChanged: _loadProfileData,
                ),
              ),
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (photoUrl != null)
                Image.network(
                  photoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildFallbackThumbnail(),
                )
              else
                _buildFallbackThumbnail(),
              if (hasAudio)
                const Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(
                    Icons.music_note_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 📂 Instagram-Style EndDrawer for Quick Access & Creator Hub
  Widget _buildProfileDrawer() {
    final avatarLetter = _userName.trim().isNotEmpty
        ? _userName.trim()[0].toUpperCase()
        : 'C';

    return Drawer(
      backgroundColor: const Color(0xFF141418),
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Top Profile Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryPink.withOpacity(0.25),
                    const Color(0xFF1A1A22),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: const Border(
                  bottom: BorderSide(color: Colors.white10, width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Obx(() {
                        final storage = Get.isRegistered<StorageService>() ? Get.find<StorageService>() : null;
                        final effectiveImg = storage?.profileImage.value.isNotEmpty == true
                            ? storage!.profileImage.value
                            : _profileImageUrl;

                        return Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [AppColors.primaryPink, Color(0xFFFF6584)],
                            ),
                            border: Border.all(color: Colors.white24, width: 1.5),
                          ),
                          child: ClipOval(
                            child: effectiveImg.isNotEmpty
                                ? Image.network(
                                    ApiEndpoints.mediaUrl(effectiveImg),
                                    fit: BoxFit.cover,
                                    width: 48,
                                    height: 48,
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Text(
                                        avatarLetter,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      avatarLetter,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                          ),
                        );
                      }),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _userName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _userHandle,
                              style: const TextStyle(
                                color: Color(0xFFFF6584),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Quick Wallet Card inside Drawer
                  InkWell(
                    onTap: () {
                      Navigator.of(context).pop(); // Close drawer
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute<void>(
                              builder: (_) => const WalletScreen(),
                            ),
                          )
                          .then((_) => _loadProfileData());
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF261822),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.primaryPink.withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppColors.primaryPink.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet_rounded,
                              color: AppColors.primaryPink,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Wallet Balance',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 10,
                                  ),
                                ),
                                Text(
                                  _walletBalance,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white38,
                            size: 13,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'CREATOR TOOLS',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  _buildDrawerTile(
                    icon: Icons.video_library_rounded,
                    iconColor: const Color(0xFFFF8008),
                    title: 'Video Studio',
                    subtitle: 'Manage & view all uploaded videos',
                    badge: _totalVideos > 0 ? '$_totalVideos' : null,
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute<void>(
                              builder: (_) => const UploadedVideoScreen(),
                            ),
                          )
                          .then((_) => _loadProfileData());
                    },
                  ),
                  _buildDrawerTile(
                    icon: Icons.add_circle_outline_rounded,
                    iconColor: AppColors.primaryPink,
                    title: 'Upload Reel',
                    subtitle: 'Publish music, reels & videos',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ReelUploadScreen(),
                            ),
                          )
                          .then((_) => _loadProfileData());
                    },
                  ),
                  _buildDrawerTile(
                    icon: Icons.link_rounded,
                    iconColor: const Color(0xFF00E5FF),
                    title: 'Web Links',
                    subtitle: 'Configure external bio links',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute<void>(
                              builder: (_) => const UpdatedWebLinkScreen(),
                            ),
                          )
                          .then((_) => _loadProfileData());
                    },
                  ),
                  _buildDrawerTile(
                    icon: Icons.campaign_rounded,
                    iconColor: const Color(0xFFB388FF),
                    title: 'Ads Promotion',
                    subtitle: 'Sponsored campaigns & ads',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute<void>(
                              builder: (_) => const AdsVideoScreen(),
                            ),
                          )
                          .then((_) => _loadProfileData());
                    },
                  ),
                  _buildDrawerTile(
                    icon: Icons.hub_rounded,
                    iconColor: const Color(0xFFFFD54F),
                    title: '5-Level Referral Network',
                    subtitle: 'Downline team, members & ₹0.05 rewards',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute<void>(
                              builder: (_) => const WalletScreen(initialTabIndex: 1),
                            ),
                          )
                          .then((_) => _loadProfileData());
                    },
                  ),
                ],
              ),
            ),

            // Drawer Footer (Logout)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white10, width: 1),
                ),
              ),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                tileColor: const Color(0xFF1E1E24),
                leading: _isLoggingOut
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.logout_rounded,
                        color: Color(0xFFFF5252),
                        size: 22,
                      ),
                title: const Text(
                  'Logout',
                  style: TextStyle(
                    color: Color(0xFFFF5252),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                onTap: _isLoggingOut ? null : _logout,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    String? badge,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Colors.white38, fontSize: 11),
      ),
      trailing: badge != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  color: iconColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white24,
              size: 20,
            ),
    );
  }

  Widget _buildStatItem(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 26, color: Colors.white12);
  }

  // ─────────────────────────────────────────
  // My Videos Upload Management Section
  // ─────────────────────────────────────────
  Widget _buildUploadedVideosSection(List<Map<String, dynamic>> videos) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Top Action Bar with Upload Reel Trigger
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Uploaded Videos (${videos.length})',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context)
                    .push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ReelUploadScreen(),
                      ),
                    )
                    .then((_) => _loadProfileData());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPink,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 18,
              ),
              label: const Text(
                'Upload Reel',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (videos.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF161620),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.04)),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.video_library_outlined,
                  size: 48,
                  color: Colors.white24,
                ),
                const SizedBox(height: 12),
                const Text(
                  'No Videos Uploaded Yet',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Upload your first video to start earning and gaining followers!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context)
                        .push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ReelUploadScreen(),
                          ),
                        )
                        .then((_) => _loadProfileData());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Upload Your First Video 🚀',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ...videos.map((video) => _buildUploadedVideoCard(video, videos)),
      ],
    );
  }

  Widget _buildUploadedVideoCard(
    Map<String, dynamic> video,
    List<Map<String, dynamic>> allVideos,
  ) {
    final statusStr = video['status']?.toString() ?? 'Approved';
    final bool isApproved = statusStr.toLowerCase() == 'approved';
    final titleStr = video['title']?.toString() ?? 'Untitled Reel';
    final subjectStr = video['subject']?.toString().isNotEmpty == true
        ? video['subject'].toString()
        : (video['category']?.toString() ?? 'Reel');
    final viewsCount =
        int.tryParse(
          video['view_count']?.toString() ?? video['views']?.toString() ?? '',
        ) ??
        0;
    final likesCount =
        int.tryParse(
          video['likes_count']?.toString() ?? video['likes']?.toString() ?? '',
        ) ??
        0;
    final createdStr = video['created_at']?.toString() ?? '';
    final thumbUrl = _getThumbnailUrl(video);

    String dateLabel = '';
    if (createdStr.isNotEmpty) {
      try {
        final d = DateTime.parse(createdStr).toLocal();
        dateLabel =
            '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      } catch (_) {
        dateLabel = createdStr.substring(0, 10.clamp(0, createdStr.length));
      }
    }

    return InkWell(
      onTap: () {
        final idx = allVideos.indexOf(video);
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ProfileReelsViewerScreen(
              videos: allVideos,
              initialIndex: idx >= 0 ? idx : 0,
              onLikedStateChanged: _loadProfileData,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF161620),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Row(
          children: [
            // Video Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 64,
                height: 64,
                color: const Color(0xFF261822),
                child: thumbUrl != null
                    ? Image.network(
                        thumbUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildFallbackThumbnail(),
                      )
                    : _buildFallbackThumbnail(),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          titleStr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isApproved
                              ? const Color(0xFF00E676).withOpacity(0.15)
                              : const Color(0xFFFF9100).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          statusStr,
                          style: TextStyle(
                            color: isApproved
                                ? const Color(0xFF00E676)
                                : const Color(0xFFFF9100),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subjectStr,
                    style: const TextStyle(
                      color: Color(0xFFFF6584),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.remove_red_eye_rounded,
                        size: 12,
                        color: Colors.white38,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatCount(viewsCount),
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Icon(
                        Icons.favorite_rounded,
                        size: 12,
                        color: Colors.white38,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatCount(likesCount),
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                      if (dateLabel.isNotEmpty) ...[
                        const Spacer(),
                        Text(
                          dateLabel,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                          ),
                        ),
                      ],
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

  Widget _buildFallbackThumbnail() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFD70F64), Color(0xFF8A2387)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.play_circle_fill_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  /// 🎬 Reels Grid with Real Video Thumbnails & Full-Screen Player on Tap
  Widget _buildReelsGrid(
    List<Map<String, dynamic>> items, {
    bool isLikedTab = false,
  }) {
    if (items.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isLikedTab
                    ? Icons.favorite_border_rounded
                    : Icons.grid_on_rounded,
                size: 44,
                color: Colors.white24,
              ),
              const SizedBox(height: 10),
              Text(
                isLikedTab ? 'No Liked Videos' : 'No Reels Uploaded',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isLikedTab
                    ? 'Double-tap any reel to like and see it here!'
                    : 'Your uploaded reels will appear here.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.72,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final video = items[index];
        final gradient = _gridGradients[index % _gridGradients.length];
        final viewsCount =
            int.tryParse(
              video['view_count']?.toString() ??
                  video['views']?.toString() ??
                  '',
            ) ??
            0;
        final likesCount =
            int.tryParse(
              video['likes_count']?.toString() ??
                  video['likes']?.toString() ??
                  '',
            ) ??
            0;
        final thumbUrl = _getThumbnailUrl(video);

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ProfileReelsViewerScreen(
                    videos: items,
                    initialIndex: index,
                    onLikedStateChanged: _loadProfileData,
                  ),
                ),
              );
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Thumbnail Image or Vibrant Gradient
                if (thumbUrl != null)
                  Image.network(
                    thumbUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _buildFallbackGradient(gradient),
                  )
                else
                  _buildFallbackGradient(gradient),

                // 2. Dark Vignette Overlay
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.4),
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),

                // 3. Center Play Icon
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.4),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),

                // 4. Top Reel Title
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Text(
                    video['title']?.toString() ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // 5. Bottom Views & Likes Stats
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.remove_red_eye_rounded,
                        size: 11,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _formatCount(viewsCount),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.favorite_rounded,
                        size: 11,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _formatCount(likesCount),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFallbackGradient(List<Color> gradient) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}
