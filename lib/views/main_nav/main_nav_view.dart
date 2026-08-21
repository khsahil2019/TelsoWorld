import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:telsoworld/controllers/main_nav_controller.dart';
import 'package:telsoworld/views/feed/feed_view.dart';
import 'package:telsoworld/views/inbox/inbox_view.dart';
import 'package:telsoworld/views/profile/profile_view.dart';
import 'package:telsoworld/views/search/search_view.dart';
import 'package:telsoworld/views/upload/reel_upload_view.dart';

class MainNavView extends GetView<MainNavController> {
  const MainNavView({super.key});

  static final List<Widget> _screens = [
    const FeedScreen(),
    const DiscoveryScreen(),
    const ReelUploadScreen(),
    const InboxScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() => IndexedStack(
            index: controller.currentIndex.value,
            children: _screens,
          )),
      bottomNavigationBar: Obx(() => Container(
            decoration: const BoxDecoration(
              color: Colors.black,
              border: Border(top: BorderSide(color: Colors.white12, width: 0.5)),
            ),
            child: BottomNavigationBar(
              currentIndex: controller.currentIndex.value,
              onTap: controller.changeTab,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.black,
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
                  icon: Icon(Icons.add_circle_outline, size: 32),
                  activeIcon: Icon(Icons.add_circle, size: 32),
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
    );
  }
}
