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
      datePickerTheme: DatePickerThemeData(
        backgroundColor: obsidianBg,
        headerBackgroundColor: obsidianBg,
        headerForegroundColor: primaryMint,
        surfaceTintColor: Colors.transparent,
        dividerColor: borderGreen,
        rangeSelectionBackgroundColor: primaryMint.withOpacity(0.15),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return obsidianBg;
          }
          if (states.contains(WidgetState.disabled)) {
            return textGray.withOpacity(0.3);
          }
          return textLight;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryMint;
          }
          return null;
        }),
        todayForegroundColor: WidgetStateProperty.all(primaryMint),
        todayBorder: const BorderSide(color: primaryMint, width: 1.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: borderGreen, width: 1.0),
        ),
      ),
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

  // Full palette of 20 visually distinct, curated colors used for auto-assignment
  static List<Color> get categoryPalette => _categoryPalette;

  static const List<Color> _categoryPalette = [
    Color(0xFF4EDEA3), // Mint
    Color(0xFF3A41C7), // Violet
    Color(0xFF9FB6DF), // Slate Blue
    Color(0xFFF59E0B), // Amber
    Color(0xFFEC4899), // Pink
    Color(0xFF8B5CF6), // Purple
    Color(0xFF06B6D4), // Cyan
    Color(0xFF10B981), // Emerald
    Color(0xFFEF4444), // Red
    Color(0xFF3B82F6), // Blue
    Color(0xFFF97316), // Orange
    Color(0xFF84CC16), // Lime
    Color(0xFF14B8A6), // Teal
    Color(0xFFD946EF), // Fuchsia
    Color(0xFFFBBF24), // Yellow
    Color(0xFF6366F1), // Indigo
    Color(0xFF22D3EE), // Sky
    Color(0xFFE879F9), // Orchid
    Color(0xFF34D399), // Sea Green
    Color(0xFFF43F5E), // Rose
  ];

  static Color getColorForCategory(String cat, [int index = 0]) {
    final trimmed = cat.trim();
    if (trimmed.toLowerCase() == 'transfer') {
      return const Color(0xFF94A3B8); // Slate color for transfer
    }
    if (customCategoryColors.containsKey(trimmed)) {
      return customCategoryColors[trimmed]!;
    }
    // Use a stable hash of the category name so every name always maps to
    // the same color regardless of order — no need for an index parameter.
    final hash = trimmed.codeUnits.fold(0, (h, c) => (h * 31 + c) & 0xFFFFFFFF);
    return _categoryPalette[hash % _categoryPalette.length];
  }

  static IconData getIconForCategory(String cat, [bool isIncome = false]) {
    final trimmed = cat.trim();
    if (customCategoryIcons.containsKey(trimmed)) {
      return customCategoryIcons[trimmed]!;
    }
    final clean = trimmed.toLowerCase();
    if (clean == 'transfer') {
      return Icons.swap_horiz_rounded;
    }
    if (clean.contains('dining') || clean.contains('food') || clean.contains('dinner') || clean.contains('restaurant')) {
      return Icons.local_cafe_outlined;
    } else if (clean.contains('commute') || clean.contains('transport') || clean.contains('car') || clean.contains('cab')) {
      return Icons.directions_transit_filled_outlined;
    } else if (clean.contains('sub') || clean.contains('subscriptions') || clean.contains('entertainment')) {
      return Icons.subscriptions_outlined;
    } else if (clean.contains('utility') || clean.contains('bill') || clean.contains('electricity')) {
      return Icons.bolt_outlined;
    } else if (clean.contains('salary') || clean.contains('income')) {
      return Icons.payments_outlined;
    } else if (clean.contains('bonus') || clean.contains('dividend') || clean.contains('invest')) {
      return Icons.trending_up_outlined;
    } else if (clean.contains('savings')) {
      return Icons.savings_outlined;
    } else if (clean.contains('gift')) {
      return Icons.card_giftcard_outlined;
    } else {
      return isIncome || clean == 'income' ? Icons.arrow_downward_rounded : Icons.local_mall_outlined;
    }
  }

  static Color getIconBgForCategory(String cat, [bool isIncome = false]) {
    final trimmed = cat.trim();
    if (customCategoryColors.containsKey(trimmed)) {
      return customCategoryColors[trimmed]!.withOpacity(0.15);
    }
    final clean = trimmed.toLowerCase();
    if (clean == 'transfer') {
      return const Color(0xFF1E293B); // Dark slate bg
    }
    if (clean.contains('dining') || clean.contains('food') || clean.contains('dinner') || clean.contains('restaurant')) {
      return const Color(0xFF261D4C);
    } else if (clean.contains('commute') || clean.contains('transport') || clean.contains('car') || clean.contains('cab')) {
      return const Color(0xFF1E284C);
    } else if (clean.contains('sub') || clean.contains('subscriptions') || clean.contains('entertainment')) {
      return const Color(0xFF1B2B3A);
    } else if (clean.contains('utility') || clean.contains('bill') || clean.contains('electricity')) {
      return const Color(0xFF332A15);
    } else if (clean.contains('salary') || clean.contains('income')) {
      return const Color(0xFF163321);
    } else if (clean.contains('bonus') || clean.contains('dividend') || clean.contains('invest')) {
      return const Color(0xFF332015);
    } else if (clean.contains('savings')) {
      return const Color(0xFF0F2B20);
    } else if (clean.contains('gift')) {
      return const Color(0xFF331526);
    } else {
      return isIncome || clean == 'income' ? const Color(0xFF0F2B20) : const Color(0xFF142B24);
    }
  }

  static Color getColorForSource(String src, [int index = 0]) {
    final trimmed = src.trim();
    if (customSourceColors.containsKey(trimmed)) {
      return customSourceColors[trimmed]!;
    }
    // Stable hash so every source name always maps to a distinct color
    final hash = trimmed.codeUnits.fold(0, (h, c) => (h * 31 + c) & 0xFFFFFFFF);
    return _categoryPalette[hash % _categoryPalette.length];
  }

  static IconData getIconForSource(String src) {
    final clean = src.trim().toLowerCase();
    if (clean.contains('cash') || clean.contains('wallet')) {
      return Icons.account_balance_wallet_outlined;
    } else if (clean.contains('bank') || clean.contains('account') || clean.contains('savings')) {
      return Icons.account_balance_outlined;
    } else if (clean.contains('credit') || clean.contains('card') || clean.contains('debit')) {
      return Icons.credit_card_outlined;
    } else if (clean.contains('paypal') || clean.contains('online') || clean.contains('digital')) {
      return Icons.language_outlined;
    } else if (clean.contains('upi') || clean.contains('gpay') || clean.contains('phonepe') || clean.contains('paytm')) {
      return Icons.qr_code_scanner_outlined;
    } else if (clean.contains('invest') || clean.contains('stock') || clean.contains('mutual')) {
      return Icons.trending_up_outlined;
    } else {
      return Icons.payments_outlined;
    }
  }

  static const List<IconData> availableIcons = [
    // Defaults & Fallbacks
    Icons.local_mall_outlined,
    Icons.arrow_downward_rounded,

    // Food & Drink
    Icons.local_cafe_outlined,
    Icons.restaurant_outlined,
    Icons.fastfood_outlined,
    Icons.lunch_dining_outlined,
    Icons.local_pizza_outlined,
    Icons.icecream_outlined,
    Icons.liquor_outlined,
    
    // Transport & Travel
    Icons.directions_transit_filled_outlined,
    Icons.directions_car_filled_outlined,
    Icons.flight_outlined,
    Icons.pedal_bike_outlined,
    Icons.directions_boat_outlined,
    Icons.luggage_outlined,

    // Shopping & Fashion
    Icons.local_grocery_store_outlined,
    Icons.shopping_bag_outlined,
    Icons.checkroom_outlined,
    Icons.watch_outlined,

    // Bills & Utilities
    Icons.bolt_outlined,
    Icons.water_drop_outlined,
    Icons.phone_android_outlined,
    Icons.wifi_rounded,
    Icons.home_outlined,

    // Health, Care & Fitness
    Icons.local_hospital_outlined,
    Icons.medication_outlined,
    Icons.fitness_center_outlined,
    Icons.spa_outlined,
    Icons.pets_outlined,

    // Entertainment, Hobby & Gifts
    Icons.subscriptions_outlined,
    Icons.sports_esports_outlined,
    Icons.music_note_outlined,
    Icons.movie_outlined,
    Icons.palette_outlined,
    Icons.camera_alt_outlined,
    Icons.card_giftcard_outlined,
    Icons.celebration_outlined,

    // Education, Work & Other
    Icons.school_outlined,
    Icons.work_outline_rounded,
    Icons.payments_outlined,
    Icons.handyman_outlined,
    Icons.star_outline_rounded,
    Icons.favorite_outline_rounded,
  ];
}
