import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:telsoworld/core/constants/app_colors.dart';

/// ---------------------------------------------------------------------------
/// 🎨 AppTheme (Instagram-Style Dark & Light Themes)
/// ---------------------------------------------------------------------------
/// Dark Mode: True OLED Black (#000000), #121212 cards, #262626 borders
/// Light Mode: Pure White (#FFFFFF), #FAFAFA cards, #EFEFEF borders
/// ---------------------------------------------------------------------------
class AppTheme {
  // ── Instagram Dark Theme ────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      cardColor: const Color(0xFF121212),
      canvasColor: Colors.black,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryPink,
        secondary: Color(0xFFFF2A6D),
        surface: Color(0xFF121212),
        onPrimary: Colors.white,
        onSurface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.white,
        unselectedItemColor: Color(0xFF8E8E8E),
      ),
      dividerColor: const Color(0xFF262626),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData.dark().textTheme,
      ),
    );
  }

  // ── Instagram Light Theme ───────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      cardColor: Colors.white,
      canvasColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryPink,
        secondary: Color(0xFFFF2A6D),
        surface: Color(0xFFFAFAFA),
        onPrimary: Colors.white,
        onSurface: Color(0xFF121212),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF121212),
        elevation: 0.5,
        centerTitle: true,
        iconTheme: IconThemeData(color: Color(0xFF121212)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.black,
        unselectedItemColor: Color(0xFF737373),
      ),
      dividerColor: const Color(0xFFEFEFEF),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData.light().textTheme,
      ),
    );
  }
}
