import 'package:get/get.dart';
import 'package:telsoworld/controllers/auth_controller.dart';
import 'package:telsoworld/controllers/main_nav_controller.dart';
import 'package:telsoworld/core/services/api_service.dart';
import 'package:telsoworld/core/services/storage_service.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<StorageService>(StorageService(), permanent: true);
    Get.put<ApiService>(ApiService(), permanent: true);
    Get.put<AuthController>(AuthController(), permanent: true);
    Get.put<MainNavController>(MainNavController(), permanent: true);
  }
}
