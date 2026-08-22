import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:telsoworld/core/bindings/initial_binding.dart';
import 'package:telsoworld/core/constants/app_colors.dart';
import 'package:telsoworld/core/routes/app_pages.dart';
import 'package:telsoworld/core/routes/app_routes.dart';

import 'package:telsoworld/core/services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Get.putAsync(() => StorageService().init());
  runApp(const TelsoWorldRootApp());
}

class TelsoWorldRootApp extends StatelessWidget {
  const TelsoWorldRootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Telso World',
      debugShowCheckedModeBanner: false,
      initialBinding: InitialBinding(),
      initialRoute: AppRoutes.splash,
      getPages: AppPages.routes,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryPink,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: AppColors.darkBackground,
        useMaterial3: true,
      ),
    );
  }
}
