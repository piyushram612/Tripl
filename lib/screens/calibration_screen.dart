import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/app_state_provider.dart';
import '../services/platform_service.dart';
import 'main_screen.dart';

// ─── Calibration Screen ────────────────────────────────────────────────────────

class CalibrationScreen extends ConsumerStatefulWidget {
  /// If true, "Done" pops back to settings instead of replacing with MainScreen.
  final bool fromSettings;

  const CalibrationScreen({super.key, this.fromSettings = false});

  @override
  ConsumerState<CalibrationScreen> createState() => _CalibrationScreenState();
}

enum _TapStatus { idle, success, failure }

class _CalibrationScreenState extends ConsumerState<CalibrationScreen>
    with TickerProviderStateMixin {
  // ── back tap stream ──
  StreamSubscription<dynamic>? _tapSubscription;
  int _tapCount = 0;
  _TapStatus _status = _TapStatus.idle;
  bool _calibrationSucceeded = false;
  Timer? _resetTimer;

  // ── sensitivity ──
  late double _sensitivityMs;

  // ── animations ──
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  late AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _sensitivityMs = ref.read(tapSensitivityProvider).toDouble();

    // Enter calibration mode on the native side (suppresses popup)
    PlatformService.setCalibrationMode(true);

    // Subscribe to back tap events from the native EventChannel
    _tapSubscription = PlatformService.backTapEventChannel
        .receiveBroadcastStream()
        .listen(_onBackTapReceived);

    // Pulsing outer ring
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Dot pop
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    // Always exit calibration mode when leaving this screen
    PlatformService.setCalibrationMode(false);
    _tapSubscription?.cancel();
    _pulseController.dispose();
    _dotController.dispose();
    _resetTimer?.cancel();
    super.dispose();
  }

  // ── Back Tap Handler ───────────────────────────────────────────────────────

  void _onBackTapReceived(dynamic event) {
    if (_status == _TapStatus.success) return; // locked after success

    double? force;
    double? jerk;
    
    if (event is Map) {
      force = event['recommendedForce']?.toDouble();
      jerk = event['recommendedJerk']?.toDouble();
    }

    // Each event from native = one complete triple tap (BackTapDetector already
    // counted to 3 internally). So one event = success.
    HapticFeedback.heavyImpact();
    _dotController.reset();
    _dotController.forward();

    setState(() {
      _tapCount = 3; // fill all dots
      _status = _TapStatus.success;
      _calibrationSucceeded = true;
    });

    // Save thresholds on success
    if (force != null && jerk != null) {
      ref.read(tapThresholdProvider.notifier).setThreshold(force);
      ref.read(jerkThresholdProvider.notifier).setThreshold(jerk);
    }

    // Save sensitivity on success
    ref
        .read(tapSensitivityProvider.notifier)
        .setSensitivity(_sensitivityMs.round());

    // Auto-enable back tap service on success immediately
    ref.read(backTapEnabledProvider.notifier).toggle(true);

    // Auto-reset dots after 2.5s so user can re-test if they want
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _status = _TapStatus.idle;
          _tapCount = 0;
        });
      }
    });
  }

  // ── Done / Skip ────────────────────────────────────────────────────────────

  void _onDone() async {
    HapticFeedback.heavyImpact();
    await ref.read(calibrationCompletedProvider.notifier).markCompleted();
    await ref
        .read(tapSensitivityProvider.notifier)
        .setSensitivity(_sensitivityMs.round());

    if (!mounted) return;
    if (widget.fromSettings) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    }
  }

  void _onSkip() async {
    HapticFeedback.lightImpact();
    // Mark calibration as completed even when skipping so the app doesn't
    // loop back to this screen on every launch.
    await ref.read(calibrationCompletedProvider.notifier).markCompleted();
    if (!mounted) return;
    if (widget.fromSettings) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TallyTapTheme.obsidianBg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),

              // ── Header ──
              Text(
                'CALIBRATION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.5,
                  color: TallyTapTheme.primaryMint.withOpacity(0.85),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Set Your Triple Back Tap',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: TallyTapTheme.textLight,
                  letterSpacing: -0.8,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Triple-tap the back of your phone.\nThe app will confirm when it registers.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: TallyTapTheme.textGray.withOpacity(0.85),
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 28),

              // ── Phone Back Graphic ──
              _buildPhoneGraphic(),

              const SizedBox(height: 28),

              // ── Dot Indicators ──
              _buildDotRow(),

              const SizedBox(height: 20),

              // ── Status Message ──
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _buildStatusMessage(),
              ),

              const SizedBox(height: 28),

              // ── Back Tap Toggle ──
              _buildBackTapToggle(),

              const SizedBox(height: 16),

              // ── Sensitivity Slider ──
              _buildSensitivitySlider(),

              const SizedBox(height: 24),

              // ── Done Button ──
              AnimatedOpacity(
                opacity: _calibrationSucceeded ? 1.0 : 0.38,
                duration: const Duration(milliseconds: 300),
                child: ElevatedButton(
                  onPressed: _calibrationSucceeded ? _onDone : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TallyTapTheme.primaryMint,
                    foregroundColor: TallyTapTheme.obsidianBg,
                    disabledBackgroundColor:
                        TallyTapTheme.primaryMint.withOpacity(0.45),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.check_circle_rounded, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Done — Save & Continue',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // ── Skip Link ──
              if (!widget.fromSettings)
                TextButton(
                  onPressed: _onSkip,
                  child: Text(
                    'Skip for now',
                    style: TextStyle(
                      fontSize: 13,
                      color: TallyTapTheme.textGray.withOpacity(0.55),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── Phone Back Graphic ─────────────────────────────────────────────────────

  Widget _buildPhoneGraphic() {
    final isSuccess = _status == _TapStatus.success;
    final glowColor =
        isSuccess ? const Color(0xFF22C55E) : TallyTapTheme.primaryMint;

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, child) {
        return Transform.scale(
          scale: _status == _TapStatus.idle ? _pulseAnim.value : 1.0,
          child: child,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        width: 150,
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          color: const Color(0xFF0D1A14),
          border: Border.all(
            color: glowColor.withOpacity(isSuccess ? 0.9 : 0.35),
            width: isSuccess ? 2.0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: glowColor.withOpacity(isSuccess ? 0.3 : 0.1),
              blurRadius: isSuccess ? 32 : 16,
              spreadRadius: isSuccess ? 4 : 2,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Camera lenses
            Positioned(
              top: 20,
              left: 20,
              child: _buildCamera(),
            ),
            // Tap ripple indicator
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: isSuccess ? 56 : 44,
                height: isSuccess ? 56 : 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: glowColor.withOpacity(isSuccess ? 0.15 : 0.05),
                  border: Border.all(
                    color: glowColor.withOpacity(isSuccess ? 0.9 : 0.4),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      isSuccess
                          ? Icons.check_rounded
                          : Icons.touch_app_outlined,
                      key: ValueKey(isSuccess),
                      color: glowColor,
                      size: isSuccess ? 28 : 22,
                    ),
                  ),
                ),
              ),
            ),
            // "Tap back" label at bottom
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Text(
                isSuccess ? 'Registered!' : 'Tap back of phone',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: glowColor.withOpacity(0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCamera() {
    return Container(
      width: 30,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1D2F28), width: 1.2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _lens(),
          _lens(),
        ],
      ),
    );
  }

  Widget _lens() => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF1D2F28), width: 1.2),
          color: const Color(0xFF0A0F0D),
        ),
      );

  // ── Dot Row ────────────────────────────────────────────────────────────────

  Widget _buildDotRow() {
    final isSuccess = _status == _TapStatus.success;
    final dotColor = isSuccess
        ? const Color(0xFF22C55E)
        : TallyTapTheme.primaryMint;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final filled = i < _tapCount;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: filled ? 14 : 10,
          height: filled ? 14 : 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? dotColor : dotColor.withOpacity(0.2),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: dotColor.withOpacity(0.55),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }

  // ── Status Message ─────────────────────────────────────────────────────────

  Widget _buildStatusMessage() {
    String text;
    Color color;

    switch (_status) {
      case _TapStatus.success:
        text = 'Perfect! Triple back tap registered ✓';
        color = const Color(0xFF22C55E);
        break;
      case _TapStatus.failure:
        text = 'Not detected — try again';
        color = const Color(0xFFEF4444);
        break;
      case _TapStatus.idle:
        text = 'Waiting for triple back tap...';
        color = TallyTapTheme.textGray;
        break;
    }

    return Padding(
      key: ValueKey(_status),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // ── Sensitivity Slider ─────────────────────────────────────────────────────

  Widget _buildSensitivitySlider() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1A14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TallyTapTheme.borderGreen, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1B17),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                      color: TallyTapTheme.borderGreen, width: 0.5),
                ),
                child: const Icon(Icons.speed_rounded,
                    color: TallyTapTheme.primaryMint, size: 16),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tap Sensitivity',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: TallyTapTheme.textLight,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Adjust how quickly you need to tap',
                      style: TextStyle(
                        fontSize: 11,
                        color: TallyTapTheme.textGray,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: TallyTapTheme.primaryMint.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: TallyTapTheme.primaryMint.withOpacity(0.4),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '${_sensitivityMs.round()}ms',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: TallyTapTheme.primaryMint,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3.0,
              activeTrackColor: TallyTapTheme.primaryMint,
              inactiveTrackColor:
                  TallyTapTheme.primaryMint.withOpacity(0.15),
              thumbColor: TallyTapTheme.primaryMint,
              overlayColor: TallyTapTheme.primaryMint.withOpacity(0.15),
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: _sensitivityMs,
              min: 300,
              max: 800,
              divisions: 25,
              onChanged: (val) {
                HapticFeedback.selectionClick();
                setState(() => _sensitivityMs = val);
                // Push to native detector immediately so user can feel the difference
                PlatformService.setSensitivity(val.round());
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Fast tap',
                    style: TextStyle(
                        fontSize: 10,
                        color: TallyTapTheme.textGray.withOpacity(0.6),
                        fontWeight: FontWeight.w600)),
                Text('Relaxed tap',
                    style: TextStyle(
                        fontSize: 10,
                        color: TallyTapTheme.textGray.withOpacity(0.6),
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackTapToggle() {
    final isEnabled = ref.watch(backTapEnabledProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1A14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TallyTapTheme.borderGreen, width: 0.8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1B17),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                  color: TallyTapTheme.borderGreen, width: 0.5),
            ),
            child: const Icon(Icons.gesture_rounded,
                color: TallyTapTheme.primaryMint, size: 16),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enable Triple Back Tap',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: TallyTapTheme.textLight,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Run gesture detector in the background',
                  style: TextStyle(
                    fontSize: 11,
                    color: TallyTapTheme.textGray,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: isEnabled,
            activeColor: TallyTapTheme.primaryMint,
            activeTrackColor: TallyTapTheme.primaryMint.withOpacity(0.2),
            inactiveThumbColor: TallyTapTheme.textGray,
            inactiveTrackColor: Colors.transparent,
            onChanged: (val) async {
              HapticFeedback.lightImpact();
              await ref.read(backTapEnabledProvider.notifier).toggle(val);
            },
          ),
        ],
      ),
    );
  }
}
