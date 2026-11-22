import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:telsoworld/core/constants/app_colors.dart';

class AppTheme {
  // ── Dark Theme (Default) ──────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F0F14),
      cardColor: const Color(0xFF16161E),
      canvasColor: const Color(0xFF0F0F14),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryPink,
        secondary: Color(0xFFFF4081),
        surface: Color(0xFF16161E),
        onPrimary: Colors.white,
        onSurface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F0F14),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      dividerColor: Colors.white10,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData.dark().textTheme,
      ),
    );
  }

  // ── Light Theme ───────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF6F7FB),
      cardColor: Colors.white,
      canvasColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryPink,
        secondary: Color(0xFFFF4081),
        surface: Colors.white,
        onPrimary: Colors.white,
        onSurface: Color(0xFF14141E),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF14141E),
        elevation: 0.5,
        centerTitle: true,
        iconTheme: IconThemeData(color: Color(0xFF14141E)),
      ),
      dividerColor: const Color(0xFFE5E7EB),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData.light().textTheme,
      ),
    );
  }
}
