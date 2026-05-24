import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme.dart';
import 'screens/main_screen.dart';
import 'screens/onboarding_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: TallyTapApp(),
    ),
  );
}

class TallyTapApp extends StatelessWidget {
  const TallyTapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TallyTap',
      debugShowCheckedModeBanner: false,
      theme: TallyTapTheme.darkTheme, // Premium dark-obsidian default
      darkTheme: TallyTapTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: FutureBuilder<bool>(
        future: SharedPreferences.getInstance().then((prefs) => prefs.getBool('has_completed_onboarding') ?? false),
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
          
          if (snapshot.data == true) {
            return const MainScreen();
          }
          
          return const OnboardingScreen();
        },
      ),
    );
  }
}
