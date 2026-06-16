import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../services/biometric_service.dart';
import '../providers/biometric_provider.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseGlow;
  bool _authFailed = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _pulseGlow = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _pulseController.repeat(reverse: true);

    // Auto-trigger biometric prompt on mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerBiometricAuth();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _triggerBiometricAuth() async {
    // Prevent overlapping biometric requests
    if (ref.read(isAuthenticatingProvider)) return;

    ref.read(isAuthenticatingProvider.notifier).state = true;
    setState(() => _authFailed = false);

    try {
      final success = await BiometricService.authenticate(
        reason: 'Please authenticate to unlock Tripl.',
      );

      if (success) {
        HapticFeedback.mediumImpact();
        ref.read(appUnlockedProvider.notifier).unlock();
      } else {
        HapticFeedback.vibrate();
        setState(() => _authFailed = true);
      }
    } finally {
      ref.read(isAuthenticatingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TallyTapTheme.obsidianBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background ambient gradient glowing effect
          Positioned(
            top: -100,
            left: -100,
            right: -100,
            height: 350,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    TallyTapTheme.primaryMint.withOpacity(0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main Center Content
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Icon & Glowing lock frame
                  AnimatedBuilder(
                    animation: _pulseGlow,
                    builder: (context, child) {
                      return Container(
                        width: 110,
                        height: 110,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _authFailed
                                  ? Colors.redAccent.withOpacity(0.15 * _pulseGlow.value)
                                  : TallyTapTheme.primaryMint.withOpacity(0.15 * _pulseGlow.value),
                              blurRadius: 32 * _pulseGlow.value,
                              spreadRadius: 2 * _pulseGlow.value,
                            ),
                          ],
                        ),
                        child: child,
                      );
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipOval(
                          child: Image.asset(
                            'assets/icon/app_icon.png',
                            width: 105,
                            height: 105,
                            fit: BoxFit.cover,
                          ),
                        ),
                        // Dark overlay with lock icon
                        Container(
                          width: 105,
                          height: 105,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withOpacity(0.6),
                          ),
                          child: Icon(
                            _authFailed ? Icons.lock_open_outlined : Icons.lock_outline_rounded,
                            color: _authFailed ? Colors.redAccent : TallyTapTheme.primaryMint,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Heading
                  const Text(
                    'TRIPL LOCKED',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      color: TallyTapTheme.textLight,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    _authFailed
                        ? 'Authentication failed. Please try again.'
                        : 'Unlock with biometric sensor or device passcode.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _authFailed ? Colors.redAccent.withOpacity(0.8) : TallyTapTheme.textGray,
                    ),
                  ),
                  const SizedBox(height: 56),

                  // Tap to unlock button
                  ElevatedButton(
                    onPressed: _triggerBiometricAuth,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _authFailed ? Colors.redAccent : TallyTapTheme.primaryMint,
                      foregroundColor: TallyTapTheme.obsidianBg,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _authFailed ? Icons.refresh_rounded : Icons.fingerprint_rounded,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _authFailed ? 'Try Again' : 'Tap to Unlock',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
