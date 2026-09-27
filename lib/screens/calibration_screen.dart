import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/app_state_provider.dart';
import '../providers/theme_provider.dart';
import '../services/platform_service.dart';
import 'main_screen.dart';

// ─── Diagnostics & Coaching Models ───────────────────────────────────────────

enum LogType { progress, success, warning, error, reset }

class DiagnosticLogEntry {
  final DateTime time;
  final LogType type;
  final String title;
  final String detail;

  DiagnosticLogEntry({
    required this.time,
    required this.type,
    required this.title,
    required this.detail,
  });
}

class CoachingFeedback {
  final String tag;
  final String title;
  final String message;
  final Color color;
  final IconData icon;

  const CoachingFeedback({
    required this.tag,
    required this.title,
    required this.message,
    required this.color,
    required this.icon,
  });
}

// ─── Calibration Screen ────────────────────────────────────────────────────────

class CalibrationScreen extends ConsumerStatefulWidget {
  /// If true, "Done" pops back to settings instead of replacing with MainScreen.
  final bool fromSettings;

  const CalibrationScreen({super.key, this.fromSettings = false});

  @override
  ConsumerState<CalibrationScreen> createState() => _CalibrationScreenState();
}

enum _TapStatus { idle, progress, success }

class _CalibrationScreenState extends ConsumerState<CalibrationScreen>
    with TickerProviderStateMixin {
  // ── back tap stream ──
  StreamSubscription<dynamic>? _tapSubscription;
  int _tapCount = 0;
  _TapStatus _status = _TapStatus.idle;
  bool _calibrationSucceeded = false;
  Timer? _resetTimer;

  // ── live metrics from detector ──
  double? _lastForce;
  double? _lastJerk;
  double? _lastGyroZ;
  int? _lastGapMs;

  // ── coaching feedback & logs ──
  late CoachingFeedback _currentFeedback;
  List<DiagnosticLogEntry> _logs = [];
  bool _showLogs = true;
  bool _showGuide = false;

  // ── sensitivity ──
  late double _sensitivityMs;

  // ── animations ──
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  late AnimationController _dotController;

  late AnimationController _rippleController;
  late Animation<double> _rippleAnim;

  @override
  void initState() {
    super.initState();
    _sensitivityMs = ref.read(tapSensitivityProvider).toDouble();

    _currentFeedback = CoachingFeedback(
      tag: 'READY TO TEST',
      title: 'Waiting for Triple Tap...',
      message:
          'Tap the back casing 3 times in a steady rhythm. Live coaching and sensor metrics will guide your technique.',
      color: TriplTheme.textGray,
      icon: Icons.touch_app_rounded,
    );

    // Enter calibration mode on the native side (suppresses popup)
    PlatformService.setCalibrationMode(true);

    // Subscribe to back tap & diagnostic events from the native EventChannel
    _tapSubscription = PlatformService.backTapEventChannel
        .receiveBroadcastStream()
        .listen(_onBackTapReceived);

    // Pulsing outer ring
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Dot pop
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Tap ripple wave
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _rippleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOutQuad),
    );
  }

  @override
  void dispose() {
    // Always exit calibration mode when leaving this screen
    PlatformService.setCalibrationMode(false);
    _tapSubscription?.cancel();
    _pulseController.dispose();
    _dotController.dispose();
    _rippleController.dispose();
    _resetTimer?.cancel();
    super.dispose();
  }

  // ── Safe State & Metric Formatter ──────────────────────────────────────────

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(fn);
      });
    } else {
      setState(fn);
    }
  }

  String _formatDouble(
    double? val, {
    String suffix = '',
    int decimals = 1,
    String fallback = '—',
  }) {
    if (val == null || !val.isFinite) return fallback;
    return '${val.toStringAsFixed(decimals)}$suffix';
  }

  // ── Back Tap & Diagnostic Event Handler ──────────────────────────────────────

  void _onBackTapReceived(dynamic event) {
    if (!mounted) return;
    if (event is! Map) return;

    try {
      final eventName = event['event'] as String? ?? 'tap';

      // Safe ripple animation trigger
      if (mounted) {
        try {
          _rippleController.forward(from: 0.0);
        } catch (_) {}
      }

      if (eventName == 'tap') {
        // ── TRIPLE TAP FULLY DETECTED ──
        final rawForce = (event['recommendedForce'] as num?)?.toDouble();
        final rawJerk = (event['recommendedJerk'] as num?)?.toDouble();
        final force = (rawForce != null && rawForce.isFinite) ? rawForce : 2.5;
        final jerk = (rawJerk != null && rawJerk.isFinite) ? rawJerk : 2.0;

        HapticFeedback.heavyImpact();
        try {
          _dotController.reset();
          _dotController.forward();
        } catch (_) {}

        _safeSetState(() {
          _tapCount = 3;
          _status = _TapStatus.success;
          _calibrationSucceeded = true;
          _lastForce = force;
          _lastJerk = jerk;

          _currentFeedback = CoachingFeedback(
            tag: 'CALIBRATED',
            title: 'Triple Tap Confirmed! 🏆',
            message:
                'Perfect rhythm and force! Recommended Force: ${_formatDouble(force, suffix: ' m/s²')}, Jerk: ${_formatDouble(jerk)}. Tap "Done" below to save or test again.',
            color: TriplTheme.primaryMint,
            icon: Icons.check_circle_rounded,
          );

          final newEntry = DiagnosticLogEntry(
            time: DateTime.now(),
            type: LogType.success,
            title: 'TRIPLE TAP TRIGGERED',
            detail:
                'Force: ${_formatDouble(force, suffix: ' m/s²')} | Jerk: ${_formatDouble(jerk)} | Calibrated successfully!',
          );
          _logs = [newEntry, ..._logs.take(49)];
        });

        // Auto-reset dots after 3.5s so user can re-test if they want
        _resetTimer?.cancel();
        _resetTimer = Timer(const Duration(milliseconds: 3500), () {
          if (mounted && _status == _TapStatus.success) {
            _safeSetState(() {
              _status = _TapStatus.idle;
              _tapCount = 0;
              _currentFeedback = CoachingFeedback(
                tag: 'READY TO TEST',
                title: 'Ready for Another Test',
                message:
                    'Triple tap again anytime to test your muscle memory or refine your technique.',
                color: TriplTheme.primaryMint,
                icon: Icons.touch_app_rounded,
              );
            });
          }
        });
      } else if (eventName == 'tap_progress') {
        // ── INDIVIDUAL TAP REGISTERED (Tap 1 or Tap 2) ──
        final count = (event['tapCount'] as num?)?.toInt() ?? 1;
        final forceVal = (event['force'] as num?)?.toDouble();
        final jerkVal = (event['jerk'] as num?)?.toDouble();
        final rawGap = (event['gapMs'] as num?)?.toInt();
        // Guard gap against uninitialized epoch milliseconds (must be <= 3000ms)
        final gapVal = (rawGap != null && rawGap > 0 && rawGap <= 3000) ? rawGap : null;

        HapticFeedback.mediumImpact();
        try {
          _dotController.reset();
          _dotController.forward();
        } catch (_) {}

        _safeSetState(() {
          _tapCount = count.clamp(0, 3);
          _status = _TapStatus.progress;
          if (forceVal != null && forceVal.isFinite) _lastForce = forceVal;
          if (jerkVal != null && jerkVal.isFinite) _lastJerk = jerkVal;
          if (gapVal != null && count > 1) _lastGapMs = gapVal;

          if (count == 1) {
            _currentFeedback = CoachingFeedback(
              tag: 'STEP 1 OF 3',
              title: 'Tap 1 Registered! ✓',
              message:
                  'Good crisp tap. Keep a steady rhythm and tap 2 more times.',
              color: TriplTheme.primaryMint,
              icon: Icons.touch_app_rounded,
            );
          } else if (count == 2) {
            _currentFeedback = CoachingFeedback(
              tag: 'STEP 2 OF 3',
              title: 'Tap 2 Registered! ✓✓',
              message:
                  'Pacing looks great (${gapVal ?? 200}ms). One more tap to complete!',
              color: TriplTheme.primaryMint,
              icon: Icons.touch_app_rounded,
            );
          }

          final newEntry = DiagnosticLogEntry(
            time: DateTime.now(),
            type: LogType.progress,
            title: 'TAP $count REGISTERED',
            detail:
                'Force: ${_formatDouble(forceVal, suffix: ' m/s²')}${gapVal != null && count > 1 ? ' | Gap: ${gapVal}ms' : ''} | Jerk: ${_formatDouble(jerkVal)}',
          );
          _logs = [newEntry, ..._logs.take(49)];
        });
      } else if (eventName == 'tap_feedback') {
        // ── COACHING FEEDBACK ON USER TECHNIQUE ERROR ──
        final type = event['type'] as String? ?? 'feedback';
        final title = event['title'] as String? ?? 'Technique Tip';
        final message = event['message'] as String? ?? '';
        final forceVal = (event['force'] as num?)?.toDouble();
        final jerkVal = (event['jerk'] as num?)?.toDouble();
        final gyroVal = (event['gyroZ'] as num?)?.toDouble();
        final rawGap = (event['gapMs'] as num?)?.toInt();
        final gapVal = (rawGap != null && rawGap > 0 && rawGap <= 3000) ? rawGap : null;

        HapticFeedback.selectionClick();

        _safeSetState(() {
          if (forceVal != null && forceVal.isFinite) _lastForce = forceVal;
          if (jerkVal != null && jerkVal.isFinite) _lastJerk = jerkVal;
          if (gyroVal != null && gyroVal.isFinite) _lastGyroZ = gyroVal;
          if (gapVal != null) _lastGapMs = gapVal;

          _currentFeedback = _resolveCoachingFeedback(
            type: type,
            title: title,
            message: message,
            force: forceVal,
            gyroZ: gyroVal,
            gapMs: gapVal,
          );

          final newEntry = DiagnosticLogEntry(
            time: DateTime.now(),
            type: (type == 'violent_impact' || type == 'too_hard')
                ? LogType.error
                : LogType.warning,
            title: title.toUpperCase(),
            detail: message,
          );
          _logs = [newEntry, ..._logs.take(49)];
        });
      } else if (eventName == 'tap_reset') {
        // ── CADENCE TIMED OUT / SEQUENCE RESET ──
        final reason = event['reason'] as String? ?? 'timeout';
        final message = event['message'] as String? ?? 'Sequence reset';

        if (_status != _TapStatus.success && _tapCount > 0) {
          _safeSetState(() {
            _tapCount = 0;
            _status = _TapStatus.idle;
            _currentFeedback = CoachingFeedback(
              tag: 'CADENCE TIMEOUT',
              title: 'Tapping Paused Too Long',
              message:
                  'Sequence timed out. Keep a steady 1-2-3 rhythm (knock-knock-knock) without long pauses.',
              color: const Color(0xFFF59E0B),
              icon: Icons.timer_outlined,
            );

            final newEntry = DiagnosticLogEntry(
              time: DateTime.now(),
              type: LogType.reset,
              title: 'SEQUENCE RESET ($reason)',
              detail: message,
            );
            _logs = [newEntry, ..._logs.take(49)];
          });
        }
      }
    } catch (e) {
      debugPrint('Error processing back tap event: $e');
    }
  }

  CoachingFeedback _resolveCoachingFeedback({
    required String type,
    required String title,
    required String message,
    double? force,
    double? gyroZ,
    int? gapMs,
  }) {
    switch (type) {
      case 'twist':
        return CoachingFeedback(
          tag: 'WRIST TWIST',
          title: 'Wrist Twist Detected',
          message:
              'The phone twisted in your hand (${_formatDouble(gyroZ?.abs(), fallback: '2.8+')} rad/s). Keep your wrist still and the phone flat while tapping.',
          color: const Color(0xFFF59E0B),
          icon: Icons.screen_rotation_rounded,
        );
      case 'too_fast':
        return CoachingFeedback(
          tag: 'TOO FAST',
          title: 'Tapping Too Fast',
          message:
              'Gap was only ${gapMs ?? 40}ms. Leave a slight pause (~150-250ms) between taps — don\'t flutter tap.',
          color: const Color(0xFFF59E0B),
          icon: Icons.speed_rounded,
        );
      case 'too_slow':
        return CoachingFeedback(
          tag: 'TOO SLOW',
          title: 'Tapping Too Slow',
          message:
              'Interval exceeded your ${_sensitivityMs.round()}ms window. Tap in a steady, quicker 1-2-3 rhythm.',
          color: const Color(0xFFF59E0B),
          icon: Icons.timer_outlined,
        );
      case 'too_soft':
        return CoachingFeedback(
          tag: 'TOO SOFT',
          title: 'Tap a Bit Firmer',
          message:
              'Impact (${_formatDouble(force, fallback: '1.1')} m/s²) was below threshold. Tap firmly with the pad or tip of your finger.',
          color: const Color(0xFFF59E0B),
          icon: Icons.touch_app_outlined,
        );
      case 'too_hard':
      case 'violent_impact':
        return CoachingFeedback(
          tag: 'TOO HARD',
          title: 'Tap More Lightly',
          message:
              'Impact force (${_formatDouble(force, fallback: '30+')} m/s²) was excessive. A brisk fingertip tap is plenty — do not slam the phone.',
          color: const Color(0xFFEF4444),
          icon: Icons.warning_amber_rounded,
        );
      case 'side_angle':
        return CoachingFeedback(
          tag: 'SIDE ANGLE',
          title: 'Slanted / Off-Angle Tap',
          message:
              'Energy deflected sideways. Tap flat and straight onto the back center cover, not the edges or corners.',
          color: const Color(0xFFF59E0B),
          icon: Icons.pan_tool_alt_rounded,
        );
      case 'low_jerk':
        return CoachingFeedback(
          tag: 'SLOW PUSH',
          title: 'Tap Was Too Slow / Pushed',
          message:
              'Tap was squeezed rather than snapped. Give a crisp, sudden mechanical tap with your fingertip.',
          color: const Color(0xFFF59E0B),
          icon: Icons.fingerprint_rounded,
        );
      case 'motion':
        return CoachingFeedback(
          tag: 'MOTION DETECTED',
          title: 'Phone is Moving',
          message:
              'Continuous body or hand movement active. Hold the phone steady in your palm while tapping.',
          color: const Color(0xFFF59E0B),
          icon: Icons.directions_walk_rounded,
        );
      case 'inconsistent_force':
        return CoachingFeedback(
          tag: 'UNEVEN FORCE',
          title: 'Inconsistent Tap Strength',
          message:
              'One tap was much harder or softer than the others. Deliver 3 taps with equal, balanced firmness.',
          color: const Color(0xFFF59E0B),
          icon: Icons.balance_rounded,
        );
      case 'screen_recoil':
        return CoachingFeedback(
          tag: 'SCREEN TAP',
          title: 'Screen Press Detected',
          message:
              'Front screen recoil detected. Tap firmly on the back casing instead.',
          color: const Color(0xFFF59E0B),
          icon: Icons.phone_android_rounded,
        );
      default:
        return CoachingFeedback(
          tag: 'COACHING TIP',
          title: title,
          message: message,
          color: const Color(0xFFF59E0B),
          icon: Icons.info_outline_rounded,
        );
    }
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  // ── Done / Skip ────────────────────────────────────────────────────────────

  void _onDone() async {
    HapticFeedback.heavyImpact();
    await ref.read(calibrationCompletedProvider.notifier).markCompleted();
    await ref
        .read(tapSensitivityProvider.notifier)
        .setSensitivity(_sensitivityMs.round());

    if (_lastForce != null && _lastJerk != null) {
      await ref.read(tapThresholdProvider.notifier).setThreshold(_lastForce!);
      await ref.read(jerkThresholdProvider.notifier).setThreshold(_lastJerk!);
    }
    await ref.read(backTapEnabledProvider.notifier).toggle(true);

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
    ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: TriplTheme.obsidianBg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),

              // ── Header ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: TriplTheme.primaryMint.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: TriplTheme.primaryMint.withOpacity(0.4),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: TriplTheme.primaryMint,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'CALIBRATION & LIVE COACHING',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: TriplTheme.primaryMint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Set Your Triple Back Tap',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: TriplTheme.textLight,
                  letterSpacing: -0.6,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Triple-tap the back casing of your phone.\nLive sensor feedback guides your pace and technique.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: TriplTheme.textGray.withOpacity(0.85),
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 24),

              // ── Interactive Phone Graphic with Tap Ripple ──
              _buildPhoneGraphic(),

              const SizedBox(height: 20),

              // ── Dot Indicators (Progressive 1-2-3) ──
              _buildDotRow(),

              const SizedBox(height: 20),

              // ── Live Coaching & Feedback Card ──
              _buildCoachingCard(),

              const SizedBox(height: 16),

              // ── Live Sensor Gauges Row ──
              _buildSensorMetricsRow(),

              const SizedBox(height: 16),

              // ── Live Detector Logs Console (Collapsible) ──
              _buildLogsConsole(),

              const SizedBox(height: 16),

              // ── Technique Pro-Tips (Collapsible) ──
              _buildTechniqueGuide(),

              const SizedBox(height: 20),

              // ── Back Tap Toggle ──
              _buildBackTapToggle(),

              const SizedBox(height: 14),

              // ── Sensitivity Slider ──
              _buildSensitivitySlider(),

              const SizedBox(height: 24),

              // ── Done Button ──
              AnimatedOpacity(
                opacity: _calibrationSucceeded ? 1.0 : 0.45,
                duration: const Duration(milliseconds: 300),
                child: ElevatedButton(
                  onPressed: _calibrationSucceeded ? _onDone : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TriplTheme.primaryMint,
                    foregroundColor: TriplTheme.isLight
                        ? Colors.white
                        : TriplTheme.obsidianBg,
                    disabledBackgroundColor:
                        TriplTheme.primaryMint.withOpacity(0.45),
                    disabledForegroundColor: (TriplTheme.isLight
                            ? Colors.white
                            : TriplTheme.obsidianBg)
                        .withOpacity(0.6),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
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
                      color: TriplTheme.textGray.withOpacity(0.55),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── Phone Back Graphic with Shockwave Ripple ──────────────────────────────

  Widget _buildPhoneGraphic() {
    final isSuccess = _status == _TapStatus.success;
    final isProgress = _status == _TapStatus.progress;
    final glowColor = isSuccess
        ? TriplTheme.primaryMint
        : (_currentFeedback.color == const Color(0xFFEF4444)
            ? const Color(0xFFEF4444)
            : TriplTheme.primaryMint);

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnim, _rippleAnim]),
      builder: (_, child) {
        return Transform.scale(
          scale: _status == _TapStatus.idle ? _pulseAnim.value : 1.0,
          child: child,
        );
      },
      child: Container(
        width: 145,
        height: 205,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: TriplTheme.obsidianCard,
          border: Border.all(
            color: glowColor.withOpacity(isSuccess ? 0.9 : 0.4),
            width: isSuccess ? 2.0 : 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: glowColor.withOpacity(isSuccess ? 0.35 : 0.12),
              blurRadius: isSuccess ? 30 : 14,
              spreadRadius: isSuccess ? 4 : 1,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Camera lenses
            Positioned(
              top: 18,
              left: 18,
              child: _buildCamera(),
            ),

            // Animated Tap Ripple Ring
            AnimatedBuilder(
              animation: _rippleAnim,
              builder: (context, child) {
                if (_rippleAnim.value == 0.0 || _rippleAnim.value == 1.0) {
                  return const SizedBox.shrink();
                }
                final size = 44.0 + (_rippleAnim.value * 70.0);
                final opacity = (1.0 - _rippleAnim.value).clamp(0.0, 1.0);
                return Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: glowColor.withOpacity(opacity * 0.7),
                      width: 1.5,
                    ),
                  ),
                );
              },
            ),

            // Center Tap Target
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: isSuccess ? 58 : 46,
                height: isSuccess ? 58 : 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: glowColor.withOpacity(isSuccess ? 0.18 : 0.08),
                  border: Border.all(
                    color: glowColor.withOpacity(isSuccess ? 0.9 : 0.5),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      isSuccess
                          ? Icons.check_rounded
                          : (isProgress
                              ? Icons.touch_app_rounded
                              : Icons.touch_app_outlined),
                      key: ValueKey('$_status-$_tapCount'),
                      color: glowColor,
                      size: isSuccess ? 28 : 22,
                    ),
                  ),
                ),
              ),
            ),

            // Tap count badge at bottom
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Text(
                isSuccess
                    ? '3 / 3 Complete!'
                    : (_tapCount > 0
                        ? '$_tapCount / 3 Registered'
                        : 'Tap back casing'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: glowColor.withOpacity(0.9),
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
      width: 28,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: TriplTheme.borderGreen, width: 1.0),
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
        width: 11,
        height: 11,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: TriplTheme.borderGreen, width: 1.0),
          color: TriplTheme.obsidianBg,
        ),
      );

  // ── Dot Row ────────────────────────────────────────────────────────────────

  Widget _buildDotRow() {
    final dotColor = TriplTheme.primaryMint;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final filled = i < _tapCount;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: filled ? 16 : 11,
              height: filled ? 16 : 11,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? dotColor : dotColor.withOpacity(0.18),
                border: Border.all(
                  color: filled ? dotColor : dotColor.withOpacity(0.4),
                  width: 1.2,
                ),
                boxShadow: filled
                    ? [
                        BoxShadow(
                          color: dotColor.withOpacity(0.65),
                          blurRadius: 10,
                          spreadRadius: 1.5,
                        ),
                      ]
                    : null,
              ),
              child: filled
                  ? Center(
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: TriplTheme.obsidianBg,
                        ),
                      ),
                    )
                  : null,
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          _status == _TapStatus.success
              ? 'Gesture Calibrated!'
              : (_tapCount == 0
                  ? 'Awaiting Tap 1'
                  : (_tapCount == 1
                      ? 'Tap 1 of 3 — tap twice more'
                      : 'Tap 2 of 3 — one final tap!')),
          style: TextStyle(
            fontSize: 11,
            color: TriplTheme.textGray.withOpacity(0.75),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ── Live Coaching & Feedback Card ──────────────────────────────────────────

  Widget _buildCoachingCard() {
    final feedback = _currentFeedback;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TriplTheme.obsidianCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: feedback.color.withOpacity(0.55),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: feedback.color.withOpacity(0.1),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: feedback.color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: feedback.color.withOpacity(0.4),
                    width: 0.8,
                  ),
                ),
                child: Icon(feedback.icon, color: feedback.color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: feedback.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        feedback.tag,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: feedback.color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      feedback.title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: TriplTheme.textLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            feedback.message,
            style: TextStyle(
              fontSize: 12,
              color: TriplTheme.textGray.withOpacity(0.95),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ── Sensor Metrics Row ─────────────────────────────────────────────────────

  Widget _buildSensorMetricsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double itemWidth = (constraints.maxWidth - 10) / 2;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            // 1. Force (Linear Z)
            _buildMetricTile(
              width: itemWidth,
              icon: Icons.compress_rounded,
              title: 'Force (Z)',
              value: _formatDouble(_lastForce, suffix: ' m/s²'),
              target: 'Target: 1.5 - 26',
              chipText: _lastForce == null
                  ? 'Waiting'
                  : (_lastForce! < 1.5
                      ? 'Soft'
                      : (_lastForce! > 26.0 ? 'Hard' : 'Good')),
              chipColor: _lastForce == null
                  ? TriplTheme.textGray
                  : (_lastForce! < 1.5
                      ? const Color(0xFFF59E0B)
                      : (_lastForce! > 26.0
                          ? const Color(0xFFEF4444)
                          : TriplTheme.primaryMint)),
            ),

            // 2. Cadence Interval
            _buildMetricTile(
              width: itemWidth,
              icon: Icons.timer_rounded,
              title: 'Cadence',
              value: _lastGapMs != null ? '${_lastGapMs}ms' : '—',
              target: 'Window: 70-${_sensitivityMs.round()}ms',
              chipText: _lastGapMs == null
                  ? 'Waiting'
                  : (_lastGapMs! < 70
                      ? 'Fast'
                      : (_lastGapMs! > _sensitivityMs
                          ? 'Slow'
                          : 'Good')),
              chipColor: _lastGapMs == null
                  ? TriplTheme.textGray
                  : (_lastGapMs! < 70 || _lastGapMs! > _sensitivityMs
                      ? const Color(0xFFF59E0B)
                      : TriplTheme.primaryMint),
            ),

            // 3. Wrist Twist (Gyro Yaw)
            _buildMetricTile(
              width: itemWidth,
              icon: Icons.screen_rotation_rounded,
              title: 'Twist',
              value: _formatDouble(_lastGyroZ?.abs(), suffix: ' rad/s'),
              target: 'Ceiling: < 2.8',
              chipText: _lastGyroZ == null
                  ? 'Waiting'
                  : (_lastGyroZ!.abs() > 2.8 ? 'Twist' : 'Steady'),
              chipColor: _lastGyroZ == null
                  ? TriplTheme.textGray
                  : (_lastGyroZ!.abs() > 2.8
                      ? const Color(0xFFF59E0B)
                      : TriplTheme.primaryMint),
            ),

            // 4. Snap Sharpness (Jerk)
            _buildMetricTile(
              width: itemWidth,
              icon: Icons.bolt_rounded,
              title: 'Sharpness',
              value: _formatDouble(_lastJerk),
              target: 'Target: > 1.5',
              chipText: _lastJerk == null
                  ? 'Waiting'
                  : (_lastJerk! < 1.5 ? 'Slow' : 'Crisp'),
              chipColor: _lastJerk == null
                  ? TriplTheme.textGray
                  : (_lastJerk! < 1.5
                      ? const Color(0xFFF59E0B)
                      : TriplTheme.primaryMint),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricTile({
    required double width,
    required IconData icon,
    required String title,
    required String value,
    required String target,
    required String chipText,
    required Color chipColor,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: TriplTheme.obsidianCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TriplTheme.borderGreen, width: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: TriplTheme.primaryMint, size: 13),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: TriplTheme.textLight,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: chipColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  chipText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: chipColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: TriplTheme.textLight,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            target,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              color: TriplTheme.textGray.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  // ── Live Logs Console ──────────────────────────────────────────────────────

  Widget _buildLogsConsole() {
    return Container(
      decoration: BoxDecoration(
        color: TriplTheme.obsidianCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TriplTheme.borderGreen, width: 0.8),
      ),
      child: Column(
        children: [
          // Header Row
          InkWell(
            onTap: () => setState(() => _showLogs = !_showLogs),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: TriplTheme.primaryMint,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: TriplTheme.primaryMint.withOpacity(0.8),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'LIVE SENSOR DIAGNOSTICS & LOGS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: TriplTheme.textLight,
                    ),
                  ),
                  const Spacer(),
                  if (_logs.isNotEmpty)
                    InkWell(
                      onTap: () => setState(() => _logs.clear()),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        child: Text(
                          'Clear',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: TriplTheme.textGray.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    _showLogs
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: TriplTheme.textGray,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),

          if (_showLogs) ...[
            const Divider(color: Color(0xFF1D2F28), height: 1),
            Container(
              height: 145,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: _logs.isEmpty
                  ? Center(
                      child: Text(
                        'Awaiting physical tap contact...\nTap the back casing to see raw real-time detection telemetry.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: TriplTheme.textGray.withOpacity(0.6),
                          height: 1.4,
                        ),
                      ),
                    )
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _logs.length,
                      separatorBuilder: (context, index) =>
                          const Divider(color: Color(0xFF16251F), height: 6),
                      itemBuilder: (context, index) {
                        if (index < 0 || index >= _logs.length) {
                          return const SizedBox.shrink();
                        }
                        final entry = _logs[index];
                        final Color badgeColor;
                        switch (entry.type) {
                          case LogType.success:
                            badgeColor = TriplTheme.primaryMint;
                            break;
                          case LogType.progress:
                            badgeColor = const Color(0xFF38BDF8);
                            break;
                          case LogType.warning:
                            badgeColor = const Color(0xFFF59E0B);
                            break;
                          case LogType.error:
                            badgeColor = const Color(0xFFEF4444);
                            break;
                          case LogType.reset:
                            badgeColor = TriplTheme.textGray;
                            break;
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _formatTime(entry.time),
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      color: TriplTheme.textGray.withOpacity(0.55),
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: badgeColor.withOpacity(0.14),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        entry.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w800,
                                          color: badgeColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                entry.detail,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: TriplTheme.textLight.withOpacity(0.85),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Technique Pro-Tips ─────────────────────────────────────────────────────

  Widget _buildTechniqueGuide() {
    return Container(
      decoration: BoxDecoration(
        color: TriplTheme.obsidianCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TriplTheme.borderGreen, width: 0.8),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _showGuide = !_showGuide),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded,
                      color: TriplTheme.primaryMint, size: 16),
                  const SizedBox(width: 10),
                  Text(
                    'Technique Guide: How to Trigger Reliably',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: TriplTheme.textLight,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _showGuide
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: TriplTheme.textGray,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (_showGuide) ...[
            const Divider(color: Color(0xFF1D2F28), height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildTipItem(
                    icon: Icons.location_on_outlined,
                    title: 'Target Upper-Center Back',
                    desc:
                        'Tap the upper third of the phone back (near camera). The sensor detects physical resonance strongest here.',
                  ),
                  const SizedBox(height: 10),
                  _buildTipItem(
                    icon: Icons.music_note_rounded,
                    title: 'Rhythm: Steady "Knock-Knock-Knock"',
                    desc:
                        'Think of knocking firmly on a wooden door. Don\'t flutter-tap too fast, and don\'t pause between taps.',
                  ),
                  const SizedBox(height: 10),
                  _buildTipItem(
                    icon: Icons.pan_tool_outlined,
                    title: 'Steady Grip — No Wrist Twisting',
                    desc:
                        'Rest phone naturally in your palm. Avoid rotating or tilting your wrist while tapping.',
                  ),
                  const SizedBox(height: 10),
                  _buildTipItem(
                    icon: Icons.touch_app_rounded,
                    title: 'Crisp Fingertip Snap',
                    desc:
                        'Deliver a quick snap with your index fingertip pad, rather than a slow soft push.',
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTipItem({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: TriplTheme.obsidianBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: TriplTheme.borderGreen, width: 0.5),
          ),
          child: Icon(icon, color: TriplTheme.primaryMint, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: TriplTheme.textLight,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 11,
                  color: TriplTheme.textGray,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Sensitivity Slider ─────────────────────────────────────────────────────

  Widget _buildSensitivitySlider() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TriplTheme.obsidianCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TriplTheme.borderGreen, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: TriplTheme.obsidianBg,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                      color: TriplTheme.borderGreen, width: 0.5),
                ),
                child: Icon(Icons.speed_rounded,
                    color: TriplTheme.primaryMint, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tap Sensitivity Window',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: TriplTheme.textLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Maximum allowed time between taps',
                      style: TextStyle(
                        fontSize: 11,
                        color: TriplTheme.textGray,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: TriplTheme.primaryMint.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: TriplTheme.primaryMint.withOpacity(0.4),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '${_sensitivityMs.round()}ms',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: TriplTheme.primaryMint,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3.0,
              activeTrackColor: TriplTheme.primaryMint,
              inactiveTrackColor:
                  TriplTheme.primaryMint.withOpacity(0.15),
              thumbColor: TriplTheme.primaryMint,
              overlayColor: TriplTheme.primaryMint.withOpacity(0.15),
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
                ref.read(tapSensitivityProvider.notifier).setSensitivity(val.round());
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Fast Cadence (300ms)',
                    style: TextStyle(
                        fontSize: 9.5,
                        color: TriplTheme.textGray.withOpacity(0.6),
                        fontWeight: FontWeight.w600)),
                Text('Relaxed Cadence (800ms)',
                    style: TextStyle(
                        fontSize: 9.5,
                        color: TriplTheme.textGray.withOpacity(0.6),
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: TriplTheme.obsidianCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TriplTheme.borderGreen, width: 0.8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: TriplTheme.obsidianBg,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                  color: TriplTheme.borderGreen, width: 0.5),
            ),
            child: Icon(Icons.gesture_rounded,
                color: TriplTheme.primaryMint, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Triple Back Tap Detection',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: TriplTheme.textLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Run listener service in background',
                  style: TextStyle(
                    fontSize: 11,
                    color: TriplTheme.textGray,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: isEnabled,
            activeColor: TriplTheme.primaryMint,
            activeTrackColor: TriplTheme.primaryMint.withOpacity(0.2),
            inactiveThumbColor: TriplTheme.textGray,
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
