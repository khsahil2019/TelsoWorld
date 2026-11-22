import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:telsoworld/core/bindings/initial_binding.dart';
import 'package:telsoworld/core/constants/app_theme.dart';
import 'package:telsoworld/core/routes/app_pages.dart';
import 'package:telsoworld/core/routes/app_routes.dart';
import 'package:telsoworld/core/services/storage_service.dart';
import 'package:telsoworld/core/services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Get.putAsync(() => StorageService().init());
  final themeService = await Get.putAsync(() => ThemeService().init());
  runApp(TelsoWorldRootApp(themeService: themeService));
}

class TelsoWorldRootApp extends StatelessWidget {
  final ThemeService? themeService;
  const TelsoWorldRootApp({super.key, this.themeService});

  @override
  Widget build(BuildContext context) {
    final ThemeService theme = themeService ??
        (Get.isRegistered<ThemeService>()
            ? Get.find<ThemeService>()
            : Get.put<ThemeService>(ThemeService()));

    return Obx(() {
      final isDark = theme.isDarkMode.value;
      return GetMaterialApp(
        title: 'Telso World',
        debugShowCheckedModeBanner: false,
        initialBinding: InitialBinding(),
        initialRoute: AppRoutes.splash,
        getPages: AppPages.routes,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      );
    });
  }
}
