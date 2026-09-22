import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/app_theme.dart';
import 'core/theme.dart';
import 'screens/main_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/calibration_screen.dart';
import 'services/notification_service.dart';
import 'services/transaction_service.dart';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'providers/recurring_transaction_provider.dart';
import 'screens/splash_screen.dart';
import 'providers/biometric_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/lock_screen.dart';
import 'services/migration_service.dart';

final ProviderContainer appContainer = ProviderContainer();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MigrationService.runMigrationIfNeeded();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  final ReceivePort port = ReceivePort();
  IsolateNameServer.removePortNameMapping('notification_action_port');
  IsolateNameServer.registerPortWithName(port.sendPort, 'notification_action_port');
  port.listen((dynamic message) {
    if (message is Map<String, dynamic>) {
      final response = NotificationResponse(
        id: message['id'],
        actionId: message['actionId'],
        input: message['input'],
        payload: message['payload'],
        notificationResponseType: NotificationResponseType.values[message['notificationResponseType']],
      );
      NotificationService.handleForegroundAction(response);
    }
  });

  NotificationService.initialize(appContainer);
  runApp(
    UncontrolledProviderScope(
      container: appContainer,
      child: const TriplApp(),
    ),
  );
}

class TriplApp extends ConsumerStatefulWidget {
  const TriplApp({super.key});

  @override
  ConsumerState<TriplApp> createState() => _TriplAppState();
}

class _TriplAppState extends ConsumerState<TriplApp> with WidgetsBindingObserver {
  // Store the future so it's not recreated on every rebuild
  late final Future<_AppStartState> _startStateFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startStateFuture = _resolveStartState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh providers when returning from background (since background isolate may have modified data)
      ref.read(transactionListProvider.notifier).loadTransactions();
      ref.read(recurringTransactionsProvider.notifier).checkDueTransactions();
    }

    // Lock the app when backgrounded (paused)
    final isLockEnabled = ref.read(biometricsEnabledProvider);
    final isPromptActive = ref.read(isAuthenticatingProvider);
    if (isLockEnabled && !isPromptActive) {
      if (state == AppLifecycleState.paused) {
        ref.read(appUnlockedProvider.notifier).lock();
      }
    }
  }

  static Future<_AppStartState> _resolveStartState() async {
    final prefs = await SharedPreferences.getInstance();

    // Proactively load custom category colors/icons and source colors
    final catColorsStr = prefs.getString('custom_category_colors') ?? '{}';
    try {
      final Map<String, dynamic> decoded = json.decode(catColorsStr);
      TriplTheme.customCategoryColors = decoded.map((k, v) => MapEntry(k, Color(v as int)));
    } catch (_) {}

    final catIconsStr = prefs.getString('custom_category_icons') ?? '{}';
    try {
      final Map<String, dynamic> decoded = json.decode(catIconsStr);
      final instantiateIcon = IconData.new;
      TriplTheme.customCategoryIcons = decoded.map((k, v) => MapEntry(k, instantiateIcon(v as int, fontFamily: 'MaterialIcons')));
    } catch (_) {}

    final srcColorsStr = prefs.getString('custom_source_colors') ?? '{}';
    try {
      final Map<String, dynamic> decoded = json.decode(srcColorsStr);
      TriplTheme.customSourceColors = decoded.map((k, v) => MapEntry(k, Color(v as int)));
    } catch (_) {}

    final onboarded = prefs.getBool('has_completed_onboarding') ?? false;
    final calibrated = prefs.getBool('calibration_completed') ?? false;


    if (!onboarded) return _AppStartState.onboardingPending;
    if (!calibrated) return _AppStartState.calibrationPending;
    return _AppStartState.ready;
  }

  @override
  Widget build(BuildContext context) {
    final themeConfig = ref.watch(themeProvider);
    final themeData = themeConfig.toThemeData();

    return MaterialApp(
      title: 'Tripl',
      debugShowCheckedModeBanner: false,
      theme: themeData,
      darkTheme: themeData,
      themeMode: themeConfig.brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      home: FutureBuilder<_AppStartState>(
        future: _startStateFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const TriplSplashScreen();
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
      builder: (context, child) {
        return ThemeAppScope(
          child: Consumer(
            builder: (context, ref, _) {
              final isUnlocked = ref.watch(appUnlockedProvider);
              final mediaQueryData = MediaQuery.of(context);
              return MediaQuery(
                data: mediaQueryData.copyWith(
                  textScaler: mediaQueryData.textScaler.clamp(minScaleFactor: 0.8, maxScaleFactor: 1.22),
                ),
                child: Stack(
                  children: [
                    if (child != null)
                      ExcludeSemantics(
                        excluding: !isUnlocked,
                        child: AbsorbPointer(
                          absorbing: !isUnlocked,
                          child: child,
                        ),
                      ),
                    if (!isUnlocked)
                      const LockScreen(),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class ThemeAppScope extends ConsumerStatefulWidget {
  final Widget child;
  const ThemeAppScope({super.key, required this.child});

  @override
  ConsumerState<ThemeAppScope> createState() => _ThemeAppScopeState();
}

class _ThemeAppScopeState extends ConsumerState<ThemeAppScope> {
  @override
  Widget build(BuildContext context) {
    ref.listen<AppThemeConfig>(themeProvider, (previous, next) {
      if (previous != next) {
        TriplTheme.obsidianBg = next.bgBase;
        TriplTheme.obsidianCard = next.cardBg;
        TriplTheme.primaryMint = next.primaryAccent;
        TriplTheme.borderGreen = next.cardBorder;
        TriplTheme.textLight = next.textPrimary;
        TriplTheme.textGray = next.textMuted;

        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: next.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness: next.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
          ),
        );

        if (mounted) {
          _markAllDirty(context as Element);
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _markAllDirty(context as Element);
          }
        });
      }
    });

    return widget.child;
  }

  void _markAllDirty(Element element) {
    element.markNeedsBuild();
    element.visitChildren(_markAllDirty);
  }
}

enum _AppStartState { onboardingPending, calibrationPending, ready }
