import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:telsoworld/session_token_store.dart';

import 'login_screen.dart';
import 'wallet_screen.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Telso Profile',
      debugShowCheckedModeBanner: false,
      home: const ProfileScreen(),
    );
  }
}

const kPink = Color(0xFFD70F64);

// Fake view counts for the grid
final _videos = [
  _VideoItem(views: '23.4K', bgColor: Color(0xFF2A4A3A)),
  _VideoItem(views: '105K', bgColor: Color(0xFF6A6A5A)),
  _VideoItem(views: '8,202', bgColor: Color(0xFF3A3020)),
  _VideoItem(views: '45.1K', bgColor: Color(0xFFF0EDE0)),
  _VideoItem(views: '12.9K', bgColor: Color(0xFF2A4A3A)),
  _VideoItem(views: '500K', bgColor: Color(0xFFE8E0D0)),
];

class _VideoItem {
  final String views;
  final Color bgColor;
  const _VideoItem({required this.views, required this.bgColor});
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _confirmLogout() async {
    if (_isLoggingOut) return;

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Do you want to logout from your account?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await _logout();
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;

    setState(() {
      _isLoggingOut = true;
    });

    final token = await SessionTokenStore.getToken();

    try {
      if (token.isNotEmpty) {
        final response = await http
            .post(
              Uri.parse('https://telsoworld.com/api/reporter/logout'),
              headers: {
                'Authorization': 'Bearer $token',
                'Accept': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 25));

        debugPrint('=== LOGOUT API RESPONSE ===');
        debugPrint('Status Code : ${response.statusCode}');
        debugPrint('Body        : ${response.body}');
        debugPrint('===========================');
      }
    } catch (e) {
      debugPrint('Logout API error: $e');
    } finally {
      await SessionTokenStore.clearToken();

      if (!mounted) return;

      setState(() {
        _isLoggingOut = false;
      });

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  /// Opens the system share sheet. If the app was hot-reloaded after adding
  /// `share_plus`, native code may be missing — then we copy the link instead.
  Future<void> _shareReferralUrl(String link) async {
    try {
      await Share.share(
        link,
        subject: 'Join me on Telso World',
      );
    } on MissingPluginException {
      await Clipboard.setData(ClipboardData(text: link));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Link copied. Paste it in WhatsApp or another app.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      debugPrint(
        'share_plus: stop the app and run a full rebuild (not hot reload) '
        'so the native share sheet can register.',
      );
    } catch (e) {
      final s = e.toString();
      if (s.contains('MissingPluginException') ||
          s.contains('dev.fluttercommunity.plus/share')) {
        await Clipboard.setData(ClipboardData(text: link));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Link copied. Paste it in WhatsApp or another app.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        debugPrint(
          'share_plus MissingPluginException: do a full app restart / '
          'flutter run after flutter pub get.',
        );
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not share: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _fetchAndShareReferralLink() async {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(color: kPink),
          ),
        ),
      ),
    );

    var loaderDismissed = false;
    void dismissLoader() {
      if (loaderDismissed || !mounted) return;
      final nav = Navigator.of(context, rootNavigator: true);
      if (nav.canPop()) {
        nav.pop();
        loaderDismissed = true;
      }
    }

    try {
      final token = await SessionTokenStore.getToken();
      final response = await http
          .get(
            Uri.parse('https://telsoworld.com/api/reporter/referral'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 25));

      if (!mounted) return;

      if (response.statusCode != 200) {
        dismissLoader();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load referral link (${response.statusCode}).'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final Map<String, dynamic> json =
          jsonDecode(response.body) as Map<String, dynamic>;
      if (json['status'] != true) {
        dismissLoader();
        final msg = json['message']?.toString() ?? 'Referral request failed.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
        );
        return;
      }

      final link = json['referral_link']?.toString().trim() ?? '';
      if (link.isEmpty) {
        dismissLoader();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No referral link returned.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      dismissLoader();
      if (!mounted) return;
      await _shareReferralUrl(link);
    } catch (e) {
      dismissLoader();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load referral link: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPink,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(child: _buildHeader()),
        ],
        body: Column(
          children: [
            // Tab bar
            Container(
              color: kPink,
              child: TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                indicatorWeight: 2.5,
                dividerColor: Colors.white.withOpacity(0.2),
                tabs: [
                  Tab(
                    icon: Icon(
                      Icons.grid_view_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  Tab(
                    icon: Icon(
                      Icons.favorite_border_rounded,
                      color: Colors.white.withOpacity(0.6),
                      size: 22,
                    ),
                  ),
                  Tab(
                    icon: Icon(
                      Icons.lock_outline_rounded,
                      color: Colors.white.withOpacity(0.6),
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),

            // Video grid
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _VideoGrid(videos: _videos),
                  _VideoGrid(videos: _videos.reversed.toList()),
                  _VideoGrid(videos: _videos),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // ── Top bar ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.chevron_left, color: Colors.white, size: 30),
                const Text(
                  '@alex_telsoworld',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                _isLoggingOut
                    ? const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'logout') {
                            _confirmLogout();
                          } else if (value == 'wallet') {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const WalletScreen(),
                              ),
                            );
                          } else if (value == 'referral') {
                            _fetchAndShareReferralLink();
                          }
                        },
                        icon: const Icon(
                          Icons.menu_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                        itemBuilder: (context) => const [
                          PopupMenuItem<String>(
                            value: 'referral',
                            child: Row(
                              children: [
                                Icon(Icons.share_rounded, size: 20),
                                SizedBox(width: 10),
                                Text('Referral link'),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'wallet',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.account_balance_wallet_rounded,
                                  size: 20,
                                ),
                                SizedBox(width: 10),
                                Text('Wallet'),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'logout',
                            child: Row(
                              children: [
                                Icon(Icons.logout_rounded, size: 20),
                                SizedBox(width: 10),
                                Text('Logout'),
                              ],
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Avatar ──
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              color: const Color(0xFFD0D8C8),
            ),
            child: ClipOval(child: CustomPaint(painter: _AvatarPainter())),
          ),

          const SizedBox(height: 14),

          // ── Name & bio ──
          const Text(
            'Alex Telso',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Travel Enthusiast & Foodie',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),

          const SizedBox(height: 24),

          // ── Stats row ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              _StatItem(value: '1.2K', label: 'FOLLOWING'),
              _StatDivider(),
              _StatItem(value: '45.8K', label: 'FOLLOWERS'),
              _StatDivider(),
              _StatItem(value: '890K', label: 'LIKES'),
            ],
          ),

          const SizedBox(height: 22),

          // ── Action buttons ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // Edit Profile
                Expanded(
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'Edit Profile',
                        style: TextStyle(
                          color: kPink,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Bookmark button
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.4),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.bookmark_border_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Stats
// ─────────────────────────────────────────
class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: Colors.white.withOpacity(0.3),
    );
  }
}

// ─────────────────────────────────────────
// Video Grid
// ─────────────────────────────────────────
class _VideoGrid extends StatelessWidget {
  final List<_VideoItem> videos;

  const _VideoGrid({required this.videos});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: videos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 0.75,
      ),
      itemBuilder: (context, index) {
        final v = videos[index];
        return _VideoThumbnail(item: v);
      },
    );
  }
}

class _VideoThumbnail extends StatelessWidget {
  final _VideoItem item;

  const _VideoThumbnail({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: item.bgColor,
      child: Stack(
        children: [
          // Play icon
          Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),

          // View count bottom-left
          Positioned(
            left: 6,
            bottom: 6,
            child: Row(
              children: [
                const Icon(Icons.play_arrow, color: Colors.white, size: 12),
                const SizedBox(width: 2),
                Text(
                  item.views,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 4,
                        offset: Offset(0, 1),
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
// Avatar Painter (anime-style face)
// ─────────────────────────────────────────
class _AvatarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFFCDD5C0),
    );

    // Face
    canvas.drawOval(
      Rect.fromLTWH(w * 0.22, h * 0.18, w * 0.56, h * 0.58),
      Paint()..color = const Color(0xFFE8C8A0),
    );

    // Hair
    final hairPaint = Paint()..color = const Color(0xFF1A1A2E);
    final hairPath = Path()
      ..moveTo(w * 0.18, h * 0.38)
      ..quadraticBezierTo(w * 0.15, h * 0.10, w * 0.50, h * 0.10)
      ..quadraticBezierTo(w * 0.85, h * 0.10, w * 0.82, h * 0.38)
      ..quadraticBezierTo(w * 0.78, h * 0.20, w * 0.50, h * 0.18)
      ..quadraticBezierTo(w * 0.22, h * 0.20, w * 0.18, h * 0.38)
      ..close();
    canvas.drawPath(hairPath, hairPaint);

    // Eyes
    final eyePaint = Paint()..color = const Color(0xFF2A2A3E);
    canvas.drawOval(
      Rect.fromLTWH(w * 0.30, h * 0.42, w * 0.12, h * 0.08),
      eyePaint,
    );
    canvas.drawOval(
      Rect.fromLTWH(w * 0.58, h * 0.42, w * 0.12, h * 0.08),
      eyePaint,
    );

    // Collar / shirt
    final shirtPaint = Paint()..color = const Color(0xFF5A8A8A);
    final shirtPath = Path()
      ..moveTo(w * 0.10, h)
      ..lineTo(w * 0.30, h * 0.78)
      ..lineTo(w * 0.50, h * 0.82)
      ..lineTo(w * 0.70, h * 0.78)
      ..lineTo(w * 0.90, h)
      ..close();
    canvas.drawPath(shirtPath, shirtPaint);
  }

  @override
  bool shouldRepaint(_) => false;
}
