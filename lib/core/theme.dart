import 'package:flutter/material.dart';

class TallyTapTheme {
  // Ultra-modern Dark Theme (Primary Mode)
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        background: Color(0xFF060B08),
        primary: Color(0xFF10B981), // Midnight Emerald
        onPrimary: Colors.white,
        secondary: Color(0xFF10B981), // Emerald
        onSecondary: Colors.white,
        surface: Color(0xFF0F1A15), // Midnight Emerald Card
        onSurface: Color(0xFFF3F4F6),
        surfaceVariant: Color(0xFF1F2A25),
        outline: Color(0xFF4B5563),
      ),
      scaffoldBackgroundColor: const Color(0xFF060B08),
      cardTheme: CardThemeData(
        color: const Color(0xFF0F1A15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
          color: Colors.white,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
          color: Colors.white,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: Color(0xFFD1D5DB),
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: Color(0xFF9CA3AF),
        ),
      ),
    );
  }

  // Premium Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        background: Color(0xFFF9FAFB),
        primary: Color(0xFF7C3AED), // Warm Violet
        onPrimary: Colors.white,
        secondary: Color(0xFF059669),
        onSecondary: Colors.white,
        surface: Colors.white,
        onSurface: Color(0xFF111827),
        surfaceVariant: Color(0xFFF3F4F6),
        outline: Color(0xFFE5E7EB),
      ),
      scaffoldBackgroundColor: const Color(0xFFF9FAFB),
      cardTheme: CardThemeData(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.05),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
          color: Color(0xFF111827),
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
          color: Color(0xFF111827),
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: Color(0xFF374151),
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: Color(0xFF6B7280),
        ),
      ),
    );
  }
}
