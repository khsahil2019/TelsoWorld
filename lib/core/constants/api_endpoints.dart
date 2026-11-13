import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// ---------------------------------------------------------------------------
/// 🌐 ApiEndpoints
/// ---------------------------------------------------------------------------
/// Central configuration for all REST API routes and host endpoints.
/// Automatically selects the correct local loopback according to platform:
/// - Android Emulator : 10.0.2.2:5050
/// - iOS Simulator / Web / macOS : localhost:5050
/// - Physical Phone : set customHost or your Wi-Fi LAN IP (e.g. 192.168.x.x:5050)
/// ---------------------------------------------------------------------------
class ApiEndpoints {
  /// Default server port
  static const int port = 5050;

  /// Production Domain URL
  static const String productionDomain = 'telsoworld.com';

  /// Toggle this to false if you want to test against local machine IP
  static const bool useProductionServer = true;

  /// Wi-Fi LAN IP of host machine for local wireless debugging
  static const String currentLanIp = '10.146.210.61';

  /// Custom host override (e.g. 'telsoworld.com' or '10.146.210.61:5050')
  static String? customHost;

  /// Dynamic host resolution
  static String get host {
    if (customHost != null && customHost!.isNotEmpty) {
      return customHost!;
    }
    if (useProductionServer) {
      return productionDomain;
    }
    if (kIsWeb) return 'localhost:$port';
    try {
      if (Platform.isAndroid) {
        return '$currentLanIp:$port';
      }
    } catch (_) {}
    return 'localhost:$port';
  }

  /// Dynamic API Base URL
  static String get baseUrl {
    if (useProductionServer && (customHost == null || customHost!.isEmpty)) {
      return 'https://$productionDomain/api';
    }
    return 'http://$host/api';
  }

  /// Helper to build full URL from path
  static String url(String path) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$baseUrl$cleanPath';
  }

  // Auth
  static const String login = '/reporter/login';
  static const String register = '/reporter/register';
  static const String logout = '/reporter/logout';

  // Feed & Videos
  static const String dashboard = '/reporter/dashboard';
  static const String adsVideos = '/reporter/ads-all-videos';
  static const String normalVideoView = '/reporter/normal-video/view';
  static const String adsVideoView = '/reporter/adsvideo/view';
  static const String normalVideoLike = '/reporter/normal-video/like';
  static const String adsVideoLike = '/reporter/adsvideo/like';
  static const String uploadVideo = '/reporter/upload-video';

  // Comments
  static const String comments = '/comments';
  static const String addComment = '/comments/add';
  static const String likeComment = '/comments/like';

  // Wallet & Referral
  static const String wallet = '/reporter/wallet';
  static const String referral = '/reporter/referral';
}
