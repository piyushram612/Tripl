import 'package:flutter/material.dart';

class TallyTapTheme {
  // Mappings for user customizations
  static Map<String, Color> customCategoryColors = {};
  static Map<String, IconData> customCategoryIcons = {};
  static Map<String, Color> customSourceColors = {};

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

  static Color getColorForCategory(String cat, [int index = 0]) {
    final trimmed = cat.trim();
    if (customCategoryColors.containsKey(trimmed)) {
      return customCategoryColors[trimmed]!;
    }
    final clean = trimmed.toLowerCase();
    if (clean.contains('dining') || clean.contains('food') || clean.contains('dinner')) {
      return primaryMint; // #4EDEA3
    } else if (clean.contains('commute') || clean.contains('transport')) {
      return primaryViolet; // #3A41C7
    } else if (clean.contains('sub') || clean.contains('entertainment')) {
      return primarySlate; // #9FB6DF
    } else if (clean.contains('utility') || clean.contains('bill')) {
      return const Color(0xFFF59E0B); // Amber
    } else if (clean.contains('grocer')) {
      return const Color(0xFF10B981); // Emerald Green
    } else if (clean.contains('shop')) {
      return const Color(0xFFEC4899); // Pink
    } else if (clean.contains('house') || clean.contains('rent')) {
      return const Color(0xFF8B5CF6); // Purple
    } else if (clean.contains('health') || clean.contains('medical')) {
      return const Color(0xFFEF4444); // Red
    } else if (clean.contains('travel') || clean.contains('flight')) {
      return const Color(0xFF06B6D4); // Cyan
    } else if (clean.contains('salary') || clean.contains('income')) {
      return const Color(0xFF22C55E); // Green
    }
    final colors = [
      primaryMint,
      primaryViolet,
      primarySlate,
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899),
      const Color(0xFF8B5CF6),
      const Color(0xFF06B6D4),
      const Color(0xFF10B981),
    ];
    return colors[index % colors.length];
  }

  static IconData getIconForCategory(String cat, [bool isIncome = false]) {
    final trimmed = cat.trim();
    if (customCategoryIcons.containsKey(trimmed)) {
      return customCategoryIcons[trimmed]!;
    }
    if (isIncome || trimmed.toLowerCase() == 'income') return Icons.arrow_downward_rounded;
    final clean = trimmed.toLowerCase();
    if (clean.contains('dining') || clean.contains('food') || clean.contains('dinner') || clean.contains('restaurant')) {
      return Icons.local_cafe_outlined;
    } else if (clean.contains('commute') || clean.contains('transport') || clean.contains('car') || clean.contains('cab')) {
      return Icons.directions_transit_filled_outlined;
    } else if (clean.contains('sub') || clean.contains('subscriptions') || clean.contains('entertainment')) {
      return Icons.subscriptions_outlined;
    } else if (clean.contains('utility') || clean.contains('bill') || clean.contains('electricity')) {
      return Icons.bolt_outlined;
    } else {
      return Icons.local_mall_outlined;
    }
  }

  static Color getIconBgForCategory(String cat, [bool isIncome = false]) {
    final trimmed = cat.trim();
    if (customCategoryColors.containsKey(trimmed)) {
      return customCategoryColors[trimmed]!.withOpacity(0.15);
    }
    if (isIncome || trimmed.toLowerCase() == 'income') return const Color(0xFF0F2B20); // Green tint
    final clean = trimmed.toLowerCase();
    if (clean.contains('dining') || clean.contains('food') || clean.contains('dinner') || clean.contains('restaurant')) {
      return const Color(0xFF261D4C);
    } else if (clean.contains('commute') || clean.contains('transport') || clean.contains('car') || clean.contains('cab')) {
      return const Color(0xFF1E284C);
    } else if (clean.contains('sub') || clean.contains('subscriptions') || clean.contains('entertainment')) {
      return const Color(0xFF1B2B3A);
    } else if (clean.contains('utility') || clean.contains('bill') || clean.contains('electricity')) {
      return const Color(0xFF332A15);
    } else {
      return const Color(0xFF142B24);
    }
  }

  static Color getColorForSource(String src, [int index = 0]) {
    final trimmed = src.trim();
    if (customSourceColors.containsKey(trimmed)) {
      return customSourceColors[trimmed]!;
    }
    final colors = [
      primaryMint,
      primaryViolet,
      primarySlate,
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899),
      const Color(0xFF8B5CF6),
      const Color(0xFF06B6D4),
      const Color(0xFF10B981),
    ];
    return colors[index % colors.length];
  }
}
