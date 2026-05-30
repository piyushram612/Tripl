import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme.dart';
import 'screens/main_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/calibration_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  NotificationService.initialize();
  runApp(
    const ProviderScope(
      child: TallyTapApp(),
    ),
  );
}

class TallyTapApp extends StatefulWidget {
  const TallyTapApp({super.key});

  @override
  State<TallyTapApp> createState() => _TallyTapAppState();
}

class _TallyTapAppState extends State<TallyTapApp> {
  // Store the future so it's not recreated on every rebuild
  late final Future<_AppStartState> _startStateFuture;

  @override
  void initState() {
    super.initState();
    _startStateFuture = _resolveStartState();
  }

  static Future<_AppStartState> _resolveStartState() async {
    final prefs = await SharedPreferences.getInstance();

    // Proactively load custom category colors/icons and source colors
    final catColorsStr = prefs.getString('custom_category_colors') ?? '{}';
    try {
      final Map<String, dynamic> decoded = json.decode(catColorsStr);
      TallyTapTheme.customCategoryColors = decoded.map((k, v) => MapEntry(k, Color(v as int)));
    } catch (_) {}

    final catIconsStr = prefs.getString('custom_category_icons') ?? '{}';
    try {
      final Map<String, dynamic> decoded = json.decode(catIconsStr);
      TallyTapTheme.customCategoryIcons = decoded.map((k, v) => MapEntry(k, IconData(v as int, fontFamily: 'MaterialIcons')));
    } catch (_) {}

    final srcColorsStr = prefs.getString('custom_source_colors') ?? '{}';
    try {
      final Map<String, dynamic> decoded = json.decode(srcColorsStr);
      TallyTapTheme.customSourceColors = decoded.map((k, v) => MapEntry(k, Color(v as int)));
    } catch (_) {}

    final onboarded = prefs.getBool('has_completed_onboarding') ?? false;
    final calibrated = prefs.getBool('calibration_completed') ?? false;

    if (!onboarded) return _AppStartState.onboardingPending;
    if (!calibrated) return _AppStartState.calibrationPending;
    return _AppStartState.ready;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TallyTap',
      debugShowCheckedModeBanner: false,
      theme: TallyTapTheme.darkTheme,
      darkTheme: TallyTapTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: FutureBuilder<_AppStartState>(
        future: _startStateFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: TallyTapTheme.obsidianBg,
              body: Center(
                child: CircularProgressIndicator(
                  color: TallyTapTheme.primaryMint,
                ),
              ),
            );
          }

          switch (snapshot.data) {
            case _AppStartState.calibrationPending:
              return const CalibrationScreen();
            case _AppStartState.onboardingPending:
              return const OnboardingScreen();
            case _AppStartState.ready:
            default:
              return const MainScreen();
          }
        },
      ),
    );
  }
}

enum _AppStartState { onboardingPending, calibrationPending, ready }
