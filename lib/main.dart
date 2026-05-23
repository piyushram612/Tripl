import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'screens/main_screen.dart';

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
      theme: TallyTapTheme.lightTheme,
      darkTheme: TallyTapTheme.darkTheme,
      themeMode: ThemeMode.system, // Dynamically sync with user's system preferences
      home: const MainScreen(),
    );
  }
}
