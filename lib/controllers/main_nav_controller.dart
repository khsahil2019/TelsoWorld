import 'package:get/get.dart';

/// ---------------------------------------------------------------------------
/// 📱 MainNavController (Bottom Navigation Tab State Controller)
/// ---------------------------------------------------------------------------
/// Yeh controller app ke 5 main bottom navigation tabs ki state manage karta hai:
/// - Tab 0: Home (Reels Feed)
/// - Tab 1: Discovery (Search & Trending Hub)
/// - Tab 2: Upload (Create Reel)
/// - Tab 3: Inbox (Messages & Notifications)
/// - Tab 4: Profile (Account & Creator Services)
///
/// New Developer ke liye zaroori baatein:
/// 1. Kisi bhi screen se agar kisi tab par switch karna ho (jaise search button se
///    Discovery par ya reel upload hone ke baad Home par), toh simple call karein:
///    `Get.find<MainNavController>().changeTab(1);`
/// ---------------------------------------------------------------------------
class MainNavController extends GetxController {
  /// 🎯 Current active bottom tab index (Observable reactive state)
  final RxInt currentIndex = 0.obs;

  /// 🔄 Tab switch karne ka function
  void changeTab(int index) {
    currentIndex.value = index;
  }
}
