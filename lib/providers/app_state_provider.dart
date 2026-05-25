import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/platform_service.dart';

// State Provider to manage active bottom navigation tab
final activeTabProvider = StateProvider<int>((ref) => 0);

// State Provider for the Double Back Tap Gesture toggle
final backTapEnabledProvider = StateNotifierProvider<BackTapNotifier, bool>((ref) {
  return BackTapNotifier();
});

class BackTapNotifier extends StateNotifier<bool> {
  BackTapNotifier() : super(false) {
    _init();
  }

  Future<void> _init() async {
    state = await PlatformService.isBackTapEnabled();
  }

  Future<void> toggle(bool val) async {
    state = val;
    await PlatformService.setBackTapEnabled(val);
  }
}
