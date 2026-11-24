import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:telsoworld/controllers/main_nav_controller.dart';
import 'package:telsoworld/core/constants/api_endpoints.dart';
import 'package:telsoworld/core/services/session_token_store.dart';
import 'package:telsoworld/core/services/storage_service.dart';
import 'package:telsoworld/views/feed/feed_view.dart';
import 'package:telsoworld/views/inbox/inbox_view.dart';
import 'package:telsoworld/views/profile/profile_view.dart';
import 'package:telsoworld/views/search/search_view.dart';

/// ---------------------------------------------------------------------------
/// 📱 MainNavView (Instagram-Style 5-Tab Navigation Bar)
/// ---------------------------------------------------------------------------
/// 1. Home (Feed with Stories Tray & Posts)
/// 2. Reels (Immersive Vertical Fullscreen Video Swiper)
/// 3. Direct Messages (Inbox & 1-on-1 Requests)
/// 4. Search (Discovery & Trending Hub)
/// 5. Profile (Creator Studio, Highlights, Reels & Photos)
/// ---------------------------------------------------------------------------
class MainNavView extends StatefulWidget {
  const MainNavView({super.key});

  @override
  State<MainNavView> createState() => _MainNavViewState();
}

class _MainNavViewState extends State<MainNavView> {
  final MainNavController controller = Get.find<MainNavController>();
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    _fetchUserAvatar();
  }

  Future<void> _fetchUserAvatar() async {
    try {
      final token = await SessionTokenStore.getToken();
      if (token.isEmpty) return;
      final uri = Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.profile}');
      final res = await http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        final rawImg = j['data']?['profile_image']?.toString() ?? '';
        if (rawImg.isNotEmpty) {
          final cleanImg = ApiEndpoints.mediaUrl(rawImg);
          final storage = Get.isRegistered<StorageService>()
              ? Get.find<StorageService>()
              : null;
          storage?.setProfileImage(cleanImg);
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // If user is on another tab, back navigates to Home Tab (0) first
        if (controller.currentIndex.value != 0) {
          controller.changeTab(0);
          return;
        }

        // Home Tab double-tap back confirmation exits app
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          Get.snackbar(
            'Exit Telso World',
            'Press back again to exit',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: const Color(0xFF1E1E24),
            colorText: Colors.white,
            duration: const Duration(seconds: 2),
            margin: const EdgeInsets.all(16),
          );
          return;
        }

        // Safe exit
        SystemNavigator.pop();
      },
      child: Obx(() {
        final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
        final currentTab = controller.currentIndex.value;
        final isReels = currentTab == 1;
        final scaffoldBg = isReels ? Colors.black : (isDarkTheme ? Colors.black : Colors.white);

        return Scaffold(
          backgroundColor: scaffoldBg,
          body: IndexedStack(
            index: currentTab,
            children: [
              // 0: Home Feed (Top bar, Stories tray, Feed)
              FeedScreen(visible: currentTab == 0, isReelsOnly: false),
              // 1: Reels Tab (Immersive full-screen reels)
              FeedScreen(visible: currentTab == 1, isReelsOnly: true),
              // 2: Direct Messenger
              const InboxScreen(),
              // 3: Search / Explore
              const DiscoveryScreen(),
              // 4: Profile
              const ProfileScreen(),
            ],
          ),
          bottomNavigationBar: _buildCustomBottomBar(isDarkTheme, isReels),
        );
      }),
    );
  }

  /// 🌟 Instagram Exact 5-Icon Clean Bottom Navigation Bar
  Widget _buildCustomBottomBar(bool isDarkTheme, bool isReels) {
    final int current = controller.currentIndex.value;
    final storage = Get.isRegistered<StorageService>()
        ? Get.find<StorageService>()
        : null;
    final userAvatar = storage?.profileImage.value.isNotEmpty == true
        ? storage!.profileImage.value
        : (storage?.getProfileImage() ?? '');

    final barColor = isReels ? Colors.black : (isDarkTheme ? Colors.black : Colors.white);
    final borderColor = isReels
        ? Colors.white.withValues(alpha: 0.12)
        : (isDarkTheme ? const Color(0xFF262626) : const Color(0xFFDBDBDB));
    final activeIconColor = isReels ? Colors.white : (isDarkTheme ? Colors.white : Colors.black);
    final inactiveIconColor = isReels
        ? Colors.white.withValues(alpha: 0.72)
        : (isDarkTheme ? const Color(0xFF8E8E8E) : const Color(0xFF737373));

    return Container(
      decoration: BoxDecoration(
        color: barColor,
        border: Border(
          top: BorderSide(
            color: borderColor,
            width: 0.6,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. Home Icon
              _buildIconItem(
                index: 0,
                selectedIndex: current,
                icon: Icons.home_outlined,
                activeIcon: Icons.home_filled,
                activeColor: activeIconColor,
                inactiveColor: inactiveIconColor,
              ),

              // 2. Reels Icon
              _buildIconItem(
                index: 1,
                selectedIndex: current,
                icon: Icons.smart_display_outlined,
                activeIcon: Icons.smart_display_rounded,
                activeColor: activeIconColor,
                inactiveColor: inactiveIconColor,
              ),

              // 3. Direct Message / Messenger Icon
              _buildIconItem(
                index: 2,
                selectedIndex: current,
                icon: Icons.near_me_outlined,
                activeIcon: Icons.send_rounded,
                activeColor: activeIconColor,
                inactiveColor: inactiveIconColor,
              ),

              // 4. Search Icon
              _buildIconItem(
                index: 3,
                selectedIndex: current,
                icon: Icons.search_rounded,
                activeIcon: Icons.search,
                activeColor: activeIconColor,
                inactiveColor: inactiveIconColor,
              ),

              // 5. Profile Avatar Tab
              _buildProfileItem(
                index: 4,
                selectedIndex: current,
                avatarUrl: userAvatar,
                activeColor: activeIconColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🔘 Clean Icon Tab Item matching Instagram
  Widget _buildIconItem({
    required int index,
    required int selectedIndex,
    required IconData icon,
    required IconData activeIcon,
    required Color activeColor,
    required Color inactiveColor,
    int badgeCount = 0,
  }) {
    final bool isSelected = selectedIndex == index;

    return InkWell(
      onTap: () => controller.changeTab(index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? activeColor : inactiveColor,
                size: 28,
              ),
              if (badgeCount > 0 && !isSelected)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF2A6D),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 7,
                      minHeight: 7,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 👤 Profile Tab Item with circular avatar
  Widget _buildProfileItem({
    required int index,
    required int selectedIndex,
    required String avatarUrl,
    required Color activeColor,
  }) {
    final bool isSelected = selectedIndex == index;

    return InkWell(
      onTap: () => controller.changeTab(index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: Container(
            width: 30,
            height: 30,
            padding: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? activeColor : Colors.transparent,
                width: 1.8,
              ),
            ),
            child: ClipOval(
              child: avatarUrl.isNotEmpty
                  ? Image.network(
                      ApiEndpoints.mediaUrl(avatarUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF2E2E38),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    )
                  : Container(
                      color: const Color(0xFF2E2E38),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
