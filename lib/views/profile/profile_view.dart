import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:telsoworld/core/constants/app_colors.dart';
import 'package:telsoworld/core/routes/app_routes.dart';
import 'package:telsoworld/core/services/session_token_store.dart';
import 'package:telsoworld/views/ads/ads_view.dart';
import 'package:telsoworld/views/auth/login_view.dart';
import 'package:telsoworld/views/upload/reel_upload_view.dart';
import 'package:telsoworld/views/upload/uploaded_video_view.dart';
import 'package:telsoworld/views/wallet/wallet_view.dart';
import 'package:telsoworld/views/web_link/updated_web_link_view.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoggingOut = false;
  bool _isLoadingReferral = false;

  final String _userName = 'Telso Creator';
  final String _userHandle = '@reporter';
  String _referralCode = '—';
  String _referralLink = '';
  String _walletBalance = '₹0.00';

  final List<Map<String, dynamic>> _myVideos = [
    {'title': 'Stage Live Performance', 'views': '24.5K', 'likes': '1.2K', 'gradient': [Color(0xFF8A2387), Color(0xFFE94057)]},
    {'title': 'Bhojpuri Hits Folk', 'views': '105K', 'likes': '8.4K', 'gradient': [Color(0xFF11998E), Color(0xFF38EF7D)]},
    {'title': 'Acoustic Guitar Cover', 'views': '8.2K', 'likes': '920', 'gradient': [Color(0xFFF2994A), Color(0xFFF2C94C)]},
    {'title': 'Classical Beats', 'views': '45.1K', 'likes': '3.1K', 'gradient': [Color(0xFF2980B9), Color(0xFF6DD5FA)]},
    {'title': 'Street Vibe Music', 'views': '12.9K', 'likes': '780', 'gradient': [Color(0xFFED213A), Color(0xFF93291E)]},
    {'title': 'Harmonium Solo', 'views': '500K', 'likes': '42K', 'gradient': [Color(0xFF654EA3), Color(0xFFEAAFC8)]},
  ];

  final List<Map<String, dynamic>> _uploadedManagementVideos = [
    {
      'id': 1,
      'subject': 'Bhojpuri Song',
      'title': 'Avela Niyra Buta Dele Diyra',
      'uploadedAt': '20/03/2026 05:40 AM',
      'status': 'Approved',
      'views': '24.5K',
      'likes': 1240,
    },
    {
      'id': 2,
      'subject': 'Stage Dance',
      'title': 'Live Folk Performance in Patna',
      'uploadedAt': '19/03/2026 10:15 AM',
      'status': 'Approved',
      'views': '12.8K',
      'likes': 890,
    },
    {
      'id': 3,
      'subject': 'Harmonium Track',
      'title': 'Classical Solo Raga Session',
      'uploadedAt': '19/03/2026 10:03 AM',
      'status': 'Approved',
      'views': '45.1K',
      'likes': 3100,
    },
    {
      'id': 4,
      'subject': 'Reporter Ground Story',
      'title': 'Public Reaction on New Schemes',
      'uploadedAt': '19/03/2026 10:04 AM',
      'status': 'Pending',
      'views': '0',
      'likes': 0,
    },
    {
      'id': 5,
      'subject': 'Comedy Short',
      'title': 'Funny Behind The Scenes Bloopers',
      'uploadedAt': '19/03/2026 10:01 AM',
      'status': 'Approved',
      'views': '89.4K',
      'likes': 5400,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final token = await SessionTokenStore.getToken();
      if (token.isEmpty) return;

      // Load Referral Data
      final refResponse = await http.get(
        Uri.parse('https://telsoworld.com/api/reporter/referral'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (refResponse.statusCode == 200) {
        final json = jsonDecode(refResponse.body);
        if (mounted && json is Map) {
          setState(() {
            _referralCode = json['referral_code']?.toString() ?? 'TELSO2026';
            _referralLink = json['referral_link']?.toString() ?? '';
          });
        }
      }

      // Load Wallet Balance Preview
      final walletResponse = await http.get(
        Uri.parse('https://telsoworld.com/api/reporter/wallet'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (walletResponse.statusCode == 200) {
        final json = jsonDecode(walletResponse.body);
        if (mounted && json is Map) {
          final bal = json['balance'] ?? json['total_balance'] ?? '0.00';
          setState(() {
            _walletBalance = '₹$bal';
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _shareReferral() async {
    if (_referralLink.isNotEmpty) {
      await Share.share(_referralLink, subject: 'Join Telso World with my referral code $_referralCode');
      return;
    }

    setState(() => _isLoadingReferral = true);
    try {
      final token = await SessionTokenStore.getToken();
      final response = await http.get(
        Uri.parse('https://telsoworld.com/api/reporter/referral'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final link = json['referral_link']?.toString() ?? '';
        final code = json['referral_code']?.toString() ?? _referralCode;
        if (link.isNotEmpty) {
          _referralLink = link;
          _referralCode = code;
          await Share.share(link, subject: 'Join Telso World with my code $code');
        } else {
          _copyCodeToClipboard(_referralCode);
        }
      } else {
        _copyCodeToClipboard(_referralCode);
      }
    } catch (_) {
      _copyCodeToClipboard(_referralCode);
    } finally {
      if (mounted) setState(() => _isLoadingReferral = false);
    }
  }

  void _copyCodeToClipboard(String code) {
    Clipboard.setData(ClipboardData(text: code));
    Get.snackbar(
      'Copied!',
      'Referral code copied to clipboard.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.white,
      colorText: AppColors.primaryPink,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out from Telso World?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPink),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Logout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoggingOut = true);
    try {
      final token = await SessionTokenStore.getToken();
      if (token.isNotEmpty) {
        await http.post(
          Uri.parse('https://telsoworld.com/api/reporter/logout'),
          headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 15));
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
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F12),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(child: _buildProfileHeader()),
          ],
          body: Column(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF141418),
                  border: Border(bottom: BorderSide(color: Colors.white10, width: 1)),
                ),
                child: const TabBar(
                  indicatorColor: AppColors.primaryPink,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  tabs: [
                    Tab(icon: Icon(Icons.grid_on_rounded, size: 18), text: 'Reels'),
                    Tab(icon: Icon(Icons.video_library_rounded, size: 18), text: 'My Videos'),
                    Tab(icon: Icon(Icons.favorite_rounded, size: 18), text: 'Liked'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildVideoGrid(_myVideos),
                    _buildUploadedVideosSection(),
                    _buildVideoGrid(_myVideos.reversed.toList()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
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
              // Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_outline_rounded, color: Colors.white70, size: 20),
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
                  _isLoggingOut
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : IconButton(
                          icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 22),
                          onPressed: _logout,
                        ),
                ],
              ),
              const SizedBox(height: 12),

              // Avatar with Gradient Ring
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryPink, Color(0xFFFF6584), Color(0xFFFFC371)],
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
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF1E1E24),
                      ),
                      child: const Center(
                        child: Icon(Icons.person_rounded, size: 48, color: Colors.white),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryPink,
                    ),
                    child: const Icon(Icons.verified_rounded, color: Colors.white, size: 15),
                  ),
                ],
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryPink.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primaryPink.withOpacity(0.5)),
                ),
                child: const Text(
                  'Verified Reporter',
                  style: TextStyle(
                    color: Color(0xFFFF6584),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Stats Row Card
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A22),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('7', 'VIDEOS'),
                    _buildDivider(),
                    _buildStatItem('45.2K', 'FOLLOWERS'),
                    _buildDivider(),
                    _buildStatItem('187K', 'VIEWS'),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 🌟 Creator Services Hub (Drawer tools integrated directly here!)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF161622),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          '⚡ Creator Services & Tools',
                          style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Quick Access',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Row 1
                    Row(
                      children: [
                        // 1. Wallet Card
                        Expanded(
                          child: _buildActionTile(
                            icon: Icons.account_balance_wallet_rounded,
                            iconColor: AppColors.primaryPink,
                            bgColor: const Color(0xFF2A1522),
                            borderColor: AppColors.primaryPink.withOpacity(0.35),
                            title: 'Wallet Balance',
                            value: _walletBalance,
                            valueColor: Colors.white,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(builder: (_) => const WalletScreen()),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // 2. Video Studio
                        Expanded(
                          child: _buildActionTile(
                            icon: Icons.video_library_rounded,
                            iconColor: const Color(0xFFFF8008),
                            bgColor: const Color(0xFF2A1F15),
                            borderColor: const Color(0xFFFF8008).withOpacity(0.35),
                            title: 'Video Studio',
                            value: 'My Videos',
                            valueColor: const Color(0xFFFFC837),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(builder: (_) => const UploadedVideoScreen()),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Row 2
                    Row(
                      children: [
                        // 3. Web Link
                        Expanded(
                          child: _buildActionTile(
                            icon: Icons.link_rounded,
                            iconColor: const Color(0xFF00E5FF),
                            bgColor: const Color(0xFF132228),
                            borderColor: const Color(0xFF00E5FF).withOpacity(0.35),
                            title: 'Web Link',
                            value: 'Portals',
                            valueColor: const Color(0xFF80D8FF),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(builder: (_) => const UpdatedWebLinkScreen()),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // 4. Ads Promotion
                        Expanded(
                          child: _buildActionTile(
                            icon: Icons.campaign_rounded,
                            iconColor: const Color(0xFFB388FF),
                            bgColor: const Color(0xFF1F1728),
                            borderColor: const Color(0xFFB388FF).withOpacity(0.35),
                            title: 'Promotion',
                            value: 'Ads Reels',
                            valueColor: const Color(0xFFD1C4E9),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(builder: (_) => const AdsVideoScreen()),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    required String title,
    required String value,
    required Color valueColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(height: 3),
            Text(title, style: const TextStyle(color: Colors.white60, fontSize: 10), maxLines: 1),
            const SizedBox(height: 1),
            Text(
              value,
              style: TextStyle(color: valueColor, fontSize: 11, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8),
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
  Widget _buildUploadedVideosSection() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Top Action Bar with Upload Reel Trigger
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Uploaded Videos (5)',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const ReelUploadScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPink,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
              label: const Text('Upload Reel', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Video Rows
        ..._uploadedManagementVideos.map((video) => _buildUploadedVideoCard(video)),
      ],
    );
  }

  Widget _buildUploadedVideoCard(Map<String, dynamic> video) {
    final bool isApproved = video['status'] == 'Approved';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161620),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          // Video Thumbnail Placeholder
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFD70F64), Color(0xFF8A2387)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(
                child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 28),
              ),
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
                        video['title'] as String,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isApproved ? const Color(0xFF00E676).withOpacity(0.15) : const Color(0xFFFF9100).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        video['status'] as String,
                        style: TextStyle(
                          color: isApproved ? const Color(0xFF00E676) : const Color(0xFFFF9100),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  video['subject'] as String,
                  style: const TextStyle(color: Color(0xFFFF6584), fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.remove_red_eye_rounded, size: 12, color: Colors.white38),
                    const SizedBox(width: 4),
                    Text(video['views'].toString(), style: const TextStyle(color: Colors.white60, fontSize: 11)),
                    const SizedBox(width: 14),
                    const Icon(Icons.favorite_rounded, size: 12, color: Colors.white38),
                    const SizedBox(width: 4),
                    Text(video['likes'].toString(), style: const TextStyle(color: Colors.white60, fontSize: 11)),
                    const Spacer(),
                    Text(
                      video['uploadedAt'] as String,
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
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

  Widget _buildVideoGrid(List<Map<String, dynamic>> items) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.75,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final video = items[index];
        final List<Color> colors = video['gradient'] as List<Color>;

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.3),
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Row(
                    children: [
                      const Icon(Icons.remove_red_eye_rounded, size: 12, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        video['views'].toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      const Icon(Icons.favorite_rounded, size: 12, color: Colors.white70),
                      const SizedBox(width: 3),
                      Text(
                        video['likes'].toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
}
