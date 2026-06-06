import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final usernameProvider = StateNotifierProvider<UsernameNotifier, String>((ref) {
  return UsernameNotifier();
});

class UsernameNotifier extends StateNotifier<String> {
  UsernameNotifier() : super('User') {
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    state = prefs.getString('user_profile_name') ?? 'User';
  }

  Future<void> setUsername(String name) async {
    if (name.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_profile_name', name.trim());
    state = name.trim();
  }
}
