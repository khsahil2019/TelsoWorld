import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:telsoworld/controllers/main_nav_controller.dart';
import 'package:telsoworld/views/feed/feed_view.dart';
import 'package:telsoworld/views/inbox/inbox_view.dart';
import 'package:telsoworld/views/profile/profile_view.dart';
import 'package:telsoworld/views/search/search_view.dart';
import 'package:telsoworld/views/upload/reel_upload_view.dart';

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

        // If user is on any other tab (Discovery, Upload, Inbox, Profile), switch to Home
        if (controller.currentIndex.value != 0) {
          controller.changeTab(0);
          return;
        }

        // On Home Tab, require double tap to exit app
        final now = DateTime.now();
        if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
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

        // User confirmed exit
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Obx(() => IndexedStack(
              index: controller.currentIndex.value,
              children: _screens,
            )),
        bottomNavigationBar: Obx(() => Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0F0F14),
                border: Border(top: BorderSide(color: Colors.white12, width: 0.5)),
              ),
              child: BottomNavigationBar(
                currentIndex: controller.currentIndex.value,
                onTap: controller.changeTab,
                type: BottomNavigationBarType.fixed,
                backgroundColor: const Color(0xFF0F0F14),
                selectedItemColor: const Color(0xFFD70F64),
                unselectedItemColor: Colors.white60,
                showSelectedLabels: true,
                showUnselectedLabels: true,
                selectedFontSize: 10,
                unselectedFontSize: 10,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    activeIcon: Icon(Icons.home_rounded),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.explore_outlined),
                    activeIcon: Icon(Icons.explore),
                    label: 'Discovery',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.add_circle_outline, size: 30),
                    activeIcon: Icon(Icons.add_circle, size: 30),
                    label: 'Upload',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.chat_bubble_outline),
                    activeIcon: Icon(Icons.chat_bubble),
                    label: 'Inbox',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline),
                    activeIcon: Icon(Icons.person),
                    label: 'Profile',
                  ),
                ],
              ),
            )),
      ),
    );
  }
}
