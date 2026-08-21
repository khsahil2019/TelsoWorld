import 'package:flutter/material.dart';
import 'package:telsoworld/app_routes.dart';
import 'package:telsoworld/login_screen.dart';
import 'package:telsoworld/ragistraton_screen.dart';
import 'package:telsoworld/registration_success_screen.dart';
import 'package:telsoworld/session_token_store.dart';

import 'splash_screen.dart' show SplashScreen;
import 'app_route_observer.dart';
import 'bottom_nav_bar.dart';
import 'home_screen.dart' show FeedScreen;
import 'search_screen.dart' show DiscoveryScreen;
import 'inbox_screen.dart' show InboxScreen;
import 'profile_screen.dart' show ProfileScreen;
import 'reel_upload_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TelsoWorldRootApp());
}

// AppRoutes is defined in app_routes.dart

class TelsoWorldRootApp extends StatelessWidget {
  const TelsoWorldRootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Telso World',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [telsoRouteObserver],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD70F64)),
        useMaterial3: true,
      ),
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (_) => const SplashToNavWrapper(),
        AppRoutes.main: (_) => const RootBottomNavScreen(),
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.register: (_) => const MusicianRegistrationScreen(),
        AppRoutes.registrationSuccess: (_) =>
            const RegistrationSuccessScreen(),
      },
    );
  }
}

class SplashToNavWrapper extends StatefulWidget {
  const SplashToNavWrapper({super.key});

  @override
  State<SplashToNavWrapper> createState() => _SplashToNavWrapperState();
}

class _SplashToNavWrapperState extends State<SplashToNavWrapper> {
  bool _isRedirecting = false;
  bool _hasNavigated = false;

  Future<void> _redirectAfterSplash() async {
    if (_isRedirecting || !mounted) return;
    _isRedirecting = true;
    String targetRoute = AppRoutes.login;

    try {
      final token = await SessionTokenStore.getToken();
      targetRoute = token.isNotEmpty ? AppRoutes.main : AppRoutes.login;
    } catch (_) {
      // If local storage is unavailable, keep app usable by opening login.
      targetRoute = AppRoutes.login;
    }

    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    Navigator.of(context).pushReplacementNamed(targetRoute);
  }

  @override
  Widget build(BuildContext context) {
    return SplashScreen(
      onContinue: _redirectAfterSplash,
      autoRedirectDelay: const Duration(seconds: 2),
    );
  }
}

class RootBottomNavScreen extends StatefulWidget {
  const RootBottomNavScreen({super.key});

  @override
  State<RootBottomNavScreen> createState() => _RootBottomNavScreenState();
}

class _RootBottomNavScreenState extends State<RootBottomNavScreen> {
  int _selectedIndex = 0;

  void _onNavTap(int index) {
    if (index == 2) {
      _openReelUploadScreen();
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _openReelUploadScreen() async {
    final didUpload = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const ReelUploadScreen(),
        fullscreenDialog: true,
      ),
    );

    if (!mounted || didUpload != true) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reel uploaded successfully.'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    setState(() {
      _selectedIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          FeedScreen(
            key: const ValueKey<Object>('telso_feed'),
            visible: _selectedIndex == 0,
          ),
          const DiscoveryScreen(),
          const SizedBox.shrink(),
          const InboxScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: TelsoBottomNavBar(
        selectedIndex: _selectedIndex,
        onTap: _onNavTap,
      ),
    );
  }
}
