import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme.dart';
import 'screens/main_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/calibration_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
