import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:telsoworld/controllers/main_nav_controller.dart';
import 'package:telsoworld/core/constants/app_colors.dart';
import 'package:telsoworld/views/feed/feed_view.dart';
import 'package:telsoworld/views/inbox/inbox_view.dart';
import 'package:telsoworld/views/profile/profile_view.dart';
import 'package:telsoworld/views/search/search_view.dart';
import 'package:telsoworld/views/upload/reel_upload_view.dart';

/// ---------------------------------------------------------------------------
/// 📱 MainNavView (Modern Glassmorphic Bottom Navigation Bar)
/// ---------------------------------------------------------------------------
/// Yeh class app ka main container shell hai jisme 5 screens load hoti hain:
/// 1. Home (Reels Feed)
/// 2. Discovery (Explore & Trending Hub)
/// 3. Upload (Create Reel with TikTok-style glowing center button)
/// 4. Inbox (Messages & Notifications with unread badge)
/// 5. Profile (Creator Studio & Account Hub)
/// ---------------------------------------------------------------------------
class MainNavView extends StatefulWidget {
  const MainNavView({super.key});

  @override
  State<MainNavView> createState() => _MainNavViewState();
}

class _MainNavViewState extends State<MainNavView> {
  final MainNavController controller = Get.find<MainNavController>();
  DateTime? _lastBackPressTime;

  static final List<Widget> _screens = [
    const FeedScreen(),
    const DiscoveryScreen(),
    const ReelUploadScreen(),
    const InboxScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // Agar user kisi aur tab par hai toh pehle Home Tab (0) par le aao
        if (controller.currentIndex.value != 0) {
          controller.changeTab(0);
          return;
        }

        // Home Tab par double-tap back confirmation se hi app exit hogi
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
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Obx(() => IndexedStack(
              index: controller.currentIndex.value,
              children: _screens,
            )),
        bottomNavigationBar: Obx(() => _buildCustomBottomBar()),
      ),
    );
  }

  /// 🌟 Custom TikTok/Instagram Luxury Glassmorphic Bottom Navigation Bar
  Widget _buildCustomBottomBar() {
    final int current = controller.currentIndex.value;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D14).withOpacity(0.96),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.08), width: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // 1. Home Tab
              _buildNavItem(
                index: 0,
                selectedIndex: current,
                label: 'Home',
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
              ),

              // 2. Discovery Tab
              _buildNavItem(
                index: 1,
                selectedIndex: current,
                label: 'Discover',
                icon: Icons.explore_outlined,
                activeIcon: Icons.explore_rounded,
              ),

              // 3. Center Create Reel Floating Button
              _buildCenterUploadButton(isSelected: current == 2),

              // 4. Inbox Tab
              _buildNavItem(
                index: 3,
                selectedIndex: current,
                label: 'Inbox',
                icon: Icons.chat_bubble_outline_rounded,
                activeIcon: Icons.chat_bubble_rounded,
                badgeCount: 3,
              ),

              // 5. Profile Tab
              _buildNavItem(
                index: 4,
                selectedIndex: current,
                label: 'Profile',
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🔘 Regular Navigation Tab Item with Animated Scaling & Glow
  Widget _buildNavItem({
    required int index,
    required int selectedIndex,
    required String label,
    required IconData icon,
    required IconData activeIcon,
    int badgeCount = 0,
  }) {
    final bool isSelected = selectedIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => controller.changeTab(index),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: isSelected
                        ? AppColors.primaryPink.withOpacity(0.15)
                        : Colors.transparent,
                  ),
                  child: Icon(
                    isSelected ? activeIcon : icon,
                    color: isSelected ? const Color(0xFFFF2A6D) : Colors.white60,
                    size: 22,
                  ),
                ),
                if (badgeCount > 0 && !isSelected)
                  Positioned(
                    right: 4,
                    top: 2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF2A6D),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🌟 Distinct TikTok-style Center Upload Button with Neon Borders & Gradient
  Widget _buildCenterUploadButton({required bool isSelected}) {
    return GestureDetector(
      onTap: () => controller.changeTab(2),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 48,
        height: 34,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Left Cyan Accent
            Positioned(
              left: 0,
              child: Container(
                width: 38,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFF00E5FF),
                ),
              ),
            ),
            // Right Pink Accent
            Positioned(
              right: 0,
              child: Container(
                width: 38,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFFD70F64),
                ),
              ),
            ),
            // Center White/Dark Core with + Icon
            Container(
              width: 40,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.add_rounded,
                  color: Colors.black,
                  size: 24,
                  weight: 800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
