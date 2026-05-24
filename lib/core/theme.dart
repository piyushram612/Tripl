import 'package:flutter/material.dart';

class TallyTapTheme {
  // Mockup forest-obsidian dark theme colors
  static const Color obsidianBg = Color(0xFF08100E);
  static const Color obsidianCard = Color(0xFF111C18);
  static const Color primaryMint = Color(0xFF4EDEA3); // Vibrant mint green accent
  static const Color primaryViolet = Color(0xFF3A41C7); // Commute deep violet accent
  static const Color primarySlate = Color(0xFF9FB6DF); // Subscriptions slate blue accent
  
  static const Color textLight = Color(0xFFF3F4F6);
  static const Color textGray = Color(0xFF9CA3AF);
  static const Color borderGreen = Color(0xFF1D2F28);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        background: obsidianBg,
        primary: primaryMint,
        onPrimary: obsidianBg,
        secondary: primaryMint,
        onSecondary: obsidianBg,
        surface: obsidianCard,
        onSurface: textLight,
        outline: borderGreen,
      ),
      scaffoldBackgroundColor: obsidianBg,
      cardTheme: CardThemeData(
        color: obsidianCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: borderGreen, width: 1.0),
        ),
        elevation: 0,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.5,
          color: textLight,
          fontFamily: 'Outfit',
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
          color: textLight,
          fontFamily: 'Outfit',
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: textLight,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: textGray,
        ),
      ),
    );
  }

  // Define lightTheme fallback that looks standard but clean
  static ThemeData get lightTheme => darkTheme; // Enforce obsidian mode as default for ultimate premium styling
}
