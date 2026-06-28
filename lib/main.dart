import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'screens/lock_screen.dart';


final ProviderContainer appContainer = ProviderContainer();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
      child: const TallyTapApp(),
    ),
  );
}

class TallyTapApp extends ConsumerStatefulWidget {
  const TallyTapApp({super.key});

  @override
  ConsumerState<TallyTapApp> createState() => _TallyTapAppState();
}

class _TallyTapAppState extends ConsumerState<TallyTapApp> with WidgetsBindingObserver {
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
      TallyTapTheme.customCategoryColors = decoded.map((k, v) => MapEntry(k, Color(v as int)));
    } catch (_) {}

    final catIconsStr = prefs.getString('custom_category_icons') ?? '{}';
    try {
      final Map<String, dynamic> decoded = json.decode(catIconsStr);
      final instantiateIcon = IconData.new;
      TallyTapTheme.customCategoryIcons = decoded.map((k, v) => MapEntry(k, instantiateIcon(v as int, fontFamily: 'MaterialIcons')));
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
      title: 'Tripl',
      debugShowCheckedModeBanner: false,
      theme: TallyTapTheme.darkTheme,
      darkTheme: TallyTapTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: FutureBuilder<_AppStartState>(
        future: _startStateFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const TallyTapSplashScreen();
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
        return Consumer(
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
        );
      },
    );
  }
}

enum _AppStartState { onboardingPending, calibrationPending, ready }
