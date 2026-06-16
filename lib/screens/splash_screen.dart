import 'package:flutter/material.dart';
import '../core/theme.dart';

class TallyTapSplashScreen extends StatefulWidget {
  const TallyTapSplashScreen({super.key});

  @override
  State<TallyTapSplashScreen> createState() => _TallyTapSplashScreenState();
}

class _TallyTapSplashScreenState extends State<TallyTapSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _fadeController;
  late final AnimationController _pulseController;
  late final AnimationController _loadingController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoRotation;
  late final Animation<double> _textFade;
  late final Animation<double> _pulseGlow;
  late final Animation<double> _loadingProgress;

  @override
  void initState() {
    super.initState();

    // 1. Logo Scale and Rotation (0ms - 800ms)
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _logoScale = CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack),
    );

    _logoRotation = CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
    );

    // 2. Text Fade-in (400ms - 1200ms)
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _textFade = CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0.33, 1.0, curve: Curves.easeIn),
    );

    // 3. Pulse Glow (800ms - infinite loop)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _pulseGlow = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // 4. Loading Bar Sweep (0ms - 1800ms)
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _loadingProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _loadingController,
        curve: Curves.easeInOutSine,
      ),
    );

    // Start animations in sequence
    _logoController.forward().then((_) {
      _pulseController.repeat(reverse: true);
    });
    _fadeController.forward();
    _loadingController.forward();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _fadeController.dispose();
    _pulseController.dispose();
    _loadingController.dispose();
    super.dispose();
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
                    TallyTapTheme.primaryMint.withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          
          // Main Center Content (Logo and Title)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo animation
                ScaleTransition(
                  scale: _logoScale,
                  child: RotationTransition(
                    turns: Tween<double>(begin: -0.05, end: 0.0).animate(_logoRotation),
                    child: AnimatedBuilder(
                      animation: _pulseGlow,
                      builder: (context, child) {
                        return Container(
                          width: 105,
                          height: 105,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: TallyTapTheme.primaryMint.withOpacity(0.25 * _pulseGlow.value),
                                blurRadius: 32 * _pulseGlow.value,
                                spreadRadius: 2 * _pulseGlow.value,
                              ),
                            ],
                          ),
                          child: child,
                        );
                      },
                      child: ClipOval(
                        child: Image.asset(
                          'assets/icon/app_icon.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Text animations
                FadeTransition(
                  opacity: _textFade,
                  child: Column(
                    children: [
                      const Text(
                        'TRIPL',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                          color: TallyTapTheme.textLight,
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to Track. Tailored for You.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.8,
                          color: TallyTapTheme.textGray.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Footer loading bar
          Positioned(
            bottom: 64,
            left: 48,
            right: 48,
            child: FadeTransition(
              opacity: _textFade,
              child: Column(
                children: [
                  // Glowing loading bar container
                  Container(
                    height: 3,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: TallyTapTheme.borderGreen.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: AnimatedBuilder(
                      animation: _loadingProgress,
                      builder: (context, child) {
                        return FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _loadingProgress.value,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: LinearGradient(
                                colors: [
                                  TallyTapTheme.primaryMint.withOpacity(0.5),
                                  TallyTapTheme.primaryMint,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: TallyTapTheme.primaryMint.withOpacity(0.4),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
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
