import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

import '../core/theme.dart';
import '../providers/app_state_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/category_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/source_provider.dart';
import '../providers/recurring_transaction_provider.dart';
import '../services/transaction_service.dart';

import 'home_screen.dart';
import 'budgets_screen.dart';
import 'insights_screen.dart';
import 'timeline_screen.dart';
import 'toolkit_screen.dart';
import 'create_transaction_screen.dart';
import 'create_recurring_transaction_screen.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/tutorial_service.dart';
import '../providers/tutorial_provider.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> with WidgetsBindingObserver {
  TutorialCoachMark? tutorialCoachMark;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Listen for native requests
    const MethodChannel('com.waypointlattice.tripl/popup').setMethodCallHandler((call) async {
      if (call.method == 'navigate' && call.arguments == 'create_transaction') {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateTransactionScreen(),
            ),
          );
        }
      } else if (call.method == 'onBackTapStateChanged') {
        final enabled = call.arguments as bool;
        ref.read(backTapEnabledProvider.notifier).updateState(enabled);
      }
    });

    // Initial data load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(transactionListProvider.notifier).loadTransactions();
      ref.read(categoriesListProvider.notifier).loadCategories();
      ref.read(sourcesListProvider.notifier).loadSources();
      ref.read(budgetLimitsProvider.notifier).loadLimits();
      ref.read(globalBudgetProvider.notifier).loadGlobalBudget();
      ref.read(currencyProvider.notifier).loadCurrency();
      ref.read(recurringTransactionsProvider); // Force initialization of recurring transactions engine
      _checkTutorialStatus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(transactionListProvider.notifier).loadTransactions();
      ref.read(categoriesListProvider.notifier).loadCategories();
      ref.read(sourcesListProvider.notifier).loadSources();
      ref.read(budgetLimitsProvider.notifier).loadLimits();
      ref.read(globalBudgetProvider.notifier).loadGlobalBudget();
      ref.read(recurringTransactionsProvider.notifier).checkDueTransactions();
      ref.read(backTapEnabledProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<TutorialFlags>(tutorialProvider, (previous, next) {
      if (previous != null && previous.primary == true && next.primary == false) {
        // Automatically switch to Home tab
        ref.read(activeTabProvider.notifier).state = 0;
        // Wait a short moment for the UI to update, then show the prompt
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _showTutorialPrompt();
          }
        });
      }
    });

    final currentIndex = ref.watch(activeTabProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: TallyTapTheme.obsidianBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: currentIndex,
          children: const [
            HomeScreen(),
            BudgetsScreen(),
            InsightsScreen(),
            TimelineScreen(),
            ToolkitScreen(),
          ],
        ),
      ),
      floatingActionButton: Container(
        key: TutorialService.mainFabKey,
        height: 56,
        width: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [TallyTapTheme.primaryMint, Color(0xFF33C28A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: TallyTapTheme.primaryMint.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateTransactionScreen(),
                ),
              );
            },
            onLongPress: () {
              HapticFeedback.heavyImpact();
              _showFabMenu(context);
            },
            child: const Icon(Icons.add_rounded, color: TallyTapTheme.obsidianBg, size: 28),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    final currentIndex = ref.watch(activeTabProvider);
    final double screenWidth = MediaQuery.of(context).size.width;
    
    final double horizontalMargin = 12.0;
    final double navBarHeight = 72.0;
    final double paddingHorizontal = 22.0;
    final double activeWidth = screenWidth - (horizontalMargin * 2) - (paddingHorizontal * 2);
    final double itemWidth = activeWidth / 5;
    
    final double pillWidth = 56.0;
    final double pillHeight = 48.0;
    
    double pillLeftPosition = (currentIndex * itemWidth) + (itemWidth - pillWidth) / 2;
    if (currentIndex == 4) {
      pillLeftPosition -= 2.0;
    } else if (currentIndex == 2) {
      pillLeftPosition -= 1.0;
    }

    return SafeArea(
      top: false,
      child: Container(
        margin: EdgeInsets.only(
          left: horizontalMargin,
          right: horizontalMargin,
          bottom: MediaQuery.of(context).padding.bottom > 0 ? 10.0 : 20.0,
        ),
        height: navBarHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: paddingHorizontal),
              decoration: BoxDecoration(
                color: TallyTapTheme.obsidianCard.withOpacity(0.10),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: TallyTapTheme.borderGreen.withOpacity(0.8),
                  width: 1.2,
                ),
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.fastOutSlowIn,
                    left: pillLeftPosition,
                    top: (navBarHeight - pillHeight) / 2 - 1,
                    child: Container(
                      width: pillWidth,
                      height: pillHeight,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [
                            TallyTapTheme.primaryMint.withOpacity(0.24),
                            TallyTapTheme.primaryMint.withOpacity(0.04),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: TallyTapTheme.primaryMint.withOpacity(0.25),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: TallyTapTheme.primaryMint.withOpacity(0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNavBarItem(0, Icons.home_filled, 'Home', currentIndex == 0),
                        _buildNavBarItem(1, Icons.account_balance_wallet, 'Budgets', currentIndex == 1),
                        _buildNavBarItem(2, Icons.analytics_outlined, 'Insights', currentIndex == 2),
                        _buildNavBarItem(3, Icons.history_toggle_off, 'Timeline', currentIndex == 3),
                        _buildNavBarItem(4, Icons.handyman_rounded, 'Toolkit', currentIndex == 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavBarItem(int index, IconData icon, String label, bool isActive) {
    GlobalKey? key;
    if (index == 0) key = TutorialService.mainNavHomeKey;
    if (index == 1) key = TutorialService.mainNavBudgetsKey;
    if (index == 2) key = TutorialService.mainNavInsightsKey;
    if (index == 3) key = TutorialService.mainNavTimelineKey;
    if (index == 4) key = TutorialService.mainNavToolkitKey;

    return Expanded(
      key: key,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          ref.read(activeTabProvider.notifier).state = index;
        },
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 280),
              curve: Curves.fastOutSlowIn,
              top: isActive ? 13 : 25,
              child: Icon(
                icon,
                color: isActive ? TallyTapTheme.primaryMint : TallyTapTheme.textGray,
                size: 22,
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 280),
              curve: Curves.fastOutSlowIn,
              bottom: isActive ? 12 : 2,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isActive ? 1.0 : 0.0,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: isActive ? FontWeight.w900 : FontWeight.w500,
                    color: isActive ? TallyTapTheme.primaryMint : TallyTapTheme.textGray,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFabMenu(BuildContext context) {
    final RenderBox? fabBox = TutorialService.mainFabKey.currentContext?.findRenderObject() as RenderBox?;
    if (fabBox == null) return;
    
    final Offset fabPosition = fabBox.localToGlobal(Offset.zero);
    final Size fabSize = fabBox.size;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => const SizedBox(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  behavior: HitTestBehavior.opaque,
                  child: FadeTransition(
                    opacity: animation,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        color: TallyTapTheme.obsidianBg.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
              ),
              
              Positioned(
                bottom: MediaQuery.of(context).size.height - fabPosition.dy + 16,
                right: MediaQuery.of(context).size.width - fabPosition.dx - fabSize.width,
                child: Material(
                  color: Colors.transparent,
                  child: FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.2),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutBack,
                      )),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSpeedDialItem(
                            context,
                            icon: Icons.add_rounded,
                            label: 'New Transaction',
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CreateTransactionScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildSpeedDialItem(
                            context,
                            icon: Icons.autorenew_rounded,
                            label: 'Recurring Payments',
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CreateRecurringTransactionScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              Positioned(
                left: fabPosition.dx,
                top: fabPosition.dy,
                child: Material(
                  color: Colors.transparent,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: Container(
                      height: fabSize.height,
                      width: fabSize.width,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [TallyTapTheme.primaryMint, Color(0xFF33C28A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: TallyTapTheme.primaryMint.withOpacity(0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: RotationTransition(
                        turns: Tween<double>(begin: 0, end: 0.125).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutBack,
                          )
                        ),
                        child: const Icon(Icons.add_rounded, color: TallyTapTheme.obsidianBg, size: 28),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpeedDialItem(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: TallyTapTheme.primaryMint.withOpacity(0.15),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: TallyTapTheme.primaryMint.withOpacity(0.6),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: TallyTapTheme.primaryMint.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: TallyTapTheme.primaryMint, size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: TallyTapTheme.primaryMint,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkTutorialStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool(kPrefTutorialPrimary) ?? false;
    if (!hasSeen && mounted) {
      _showTutorialPrompt();
    }
  }

  void _showTutorialPrompt() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: TallyTapTheme.obsidianCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Welcome to Tripl!', style: TextStyle(color: TallyTapTheme.textLight, fontWeight: FontWeight.bold)),
          content: const Text('Would you like a quick tour to see how things work?', style: TextStyle(color: TallyTapTheme.textGray)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                ref.read(tutorialProvider.notifier).markCompleted(kPrefTutorialPrimary);
              },
              child: const Text('Skip Tour', style: TextStyle(color: TallyTapTheme.textGray)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _initTutorial();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: TallyTapTheme.primaryMint,
                foregroundColor: TallyTapTheme.obsidianBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Start Tour', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _initTutorial() {
    tutorialCoachMark = TutorialCoachMark(
      targets: _createTargets(),
      colorShadow: Colors.black,
      textSkip: "SKIP",
      paddingFocus: 10,
      opacityShadow: 0.6,
      imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      beforeFocus: (target) async {
        final identify = target.identify.toString();
        
        // Automatically switch tabs based on the upcoming target (skip for the tab targets themselves)
        if (identify.startsWith("TargetBudgets") && identify != "TargetBudgetsTab") {
          ref.read(activeTabProvider.notifier).state = 1;
        } else if (identify.startsWith("TargetInsights") && identify != "TargetInsightsTab") {
          ref.read(activeTabProvider.notifier).state = 2;
        } else if (identify.startsWith("TargetTimeline") && identify != "TargetTimelineTab") {
          ref.read(activeTabProvider.notifier).state = 3;
        } else if (identify.startsWith("TargetToolkit") && identify != "TargetToolkitTab") {
          ref.read(activeTabProvider.notifier).state = 4;
        } else if (identify == "TargetHomeAccounts" || identify == "TargetHomeWidgets" || identify == "TargetFAB") {
          ref.read(activeTabProvider.notifier).state = 0;
        }

        // Wait a short moment for the new tab to render before finding the target context
        await Future.delayed(const Duration(milliseconds: 250));

        if (target.keyTarget?.currentContext != null) {
          if (identify == "TargetInsightsPills") {
            return;
          }
          Scrollable.ensureVisible(
            target.keyTarget!.currentContext!,
            alignment: 0.5,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          await Future.delayed(const Duration(milliseconds: 350));
        }
      },
      onClickOverlay: (target) {
        final identify = target.identify.toString();
        if (identify == "TargetBudgetsTab" || 
            identify == "TargetInsightsTab" || 
            identify == "TargetTimelineTab" || 
            identify == "TargetToolkitTab") {
          // Do nothing, force user to tap the target
        } else {
          tutorialCoachMark?.next();
        }
      },
      onFinish: () {
        ref.read(tutorialProvider.notifier).markCompleted(kPrefTutorialPrimary);
      },
      onClickTarget: (target) {
        if (target.identify == "TargetBudgetsTab") {
          ref.read(activeTabProvider.notifier).state = 1;
        } else if (target.identify == "TargetInsightsTab") {
          ref.read(activeTabProvider.notifier).state = 2;
        } else if (target.identify == "TargetTimelineTab") {
          ref.read(activeTabProvider.notifier).state = 3;
        } else if (target.identify == "TargetToolkitTab") {
          ref.read(activeTabProvider.notifier).state = 4;
        }
      },
      onSkip: () {
        ref.read(tutorialProvider.notifier).markCompleted(kPrefTutorialPrimary);
        return true;
      },
    );
    tutorialCoachMark?.show(context: context);
  }

  Widget _buildTutorialContent(TutorialCoachMarkController controller, String title, String description, {bool hideNext = false, String nextText = "Next"}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20)),
        const SizedBox(height: 10),
        Text(description, style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 16),
        if (!hideNext)
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: () => controller.next(),
              style: ElevatedButton.styleFrom(
                backgroundColor: TallyTapTheme.primaryMint,
                foregroundColor: TallyTapTheme.obsidianBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(nextText, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }

  List<TargetFocus> _createTargets() {
    List<TargetFocus> targets = [];

    // HOME TAB
    targets.add(TargetFocus(
      identify: "TargetHomeTab",
      keyTarget: TutorialService.mainNavHomeKey,
      alignSkip: Alignment.topRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.top,
          builder: (context, controller) => _buildTutorialContent(controller, "Home", "Welcome to your Dashboard. Here you can see a quick overview of your finances."),
        ),
      ],
    ));

    targets.add(TargetFocus(
      identify: "TargetHomeAccounts",
      keyTarget: TutorialService.homeAccountsKey,
      alignSkip: Alignment.topRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) => _buildTutorialContent(controller, "Accounts & Balances", "These start at 0 so you can track fresh expenses right away. If you prefer to track your true net worth, tap an account to set its 'Correct Balance'."),
        ),
      ],
    ));

    targets.add(TargetFocus(
      identify: "TargetHomeWidgets",
      keyTarget: TutorialService.homeSummaryKey,
      alignSkip: Alignment.topRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) => _buildTutorialContent(controller, "Dashboard Widgets", "View your summaries and categories below. Long-press any card to enter Edit Mode, where you can drag and reorder them."),
        ),
      ],
    ));

    targets.add(TargetFocus(
      identify: "TargetFAB",
      keyTarget: TutorialService.mainFabKey,
      alignSkip: Alignment.topRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.top,
          builder: (context, controller) => _buildTutorialContent(controller, "Quick Log", "Tap to quickly log a new transaction. Long-press for more options like recurring transactions."),
        ),
      ],
    ));

    // BUDGETS TAB
    targets.add(TargetFocus(
      identify: "TargetBudgetsTab",
      keyTarget: TutorialService.mainNavBudgetsKey,
      alignSkip: Alignment.topRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.top,
          builder: (context, controller) => _buildTutorialContent(
            controller, 
            "Budgets", 
            "Monitor your spending limits and control your money here.\n\nTap here to continue.",
            hideNext: true,
          ),
        ),
      ],
    ));

    targets.add(TargetFocus(
      identify: "TargetBudgetsRing",
      keyTarget: TutorialService.budgetsRingKey,
      alignSkip: Alignment.topRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) => _buildTutorialContent(controller, "Global Budget", "This is your overall spending limit for the period. Keep this green!"),
        ),
      ],
    ));

    targets.add(TargetFocus(
      identify: "TargetBudgetsManage",
      keyTarget: TutorialService.budgetsManageKey,
      alignSkip: Alignment.topRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.top,
          builder: (context, controller) => _buildTutorialContent(controller, "Category Envelopes", "Track specific categories here. Tap to manage or create new envelope budgets for things like Groceries or Entertainment."),
        ),
      ],
    ));

    // INSIGHTS TAB
    targets.add(TargetFocus(
      identify: "TargetInsightsTab",
      keyTarget: TutorialService.mainNavInsightsKey,
      alignSkip: Alignment.topRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.top,
          builder: (context, controller) => _buildTutorialContent(
            controller, 
            "Insights", 
            "Dive deep into your financial habits with detailed charts and trend analysis.\n\nTap here to continue.",
            hideNext: true,
          ),
        ),
      ],
    ));

    targets.add(TargetFocus(
      identify: "TargetInsightsDonut",
      keyTarget: TutorialService.insightsDonutKey,
      alignSkip: Alignment.topRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) => _buildTutorialContent(controller, "Spend Intentionality", "See your spending categorized by intent. This ring summarizes your financial behavior at a glance."),
        ),
      ],
    ));

    targets.add(TargetFocus(
      identify: "TargetInsightsPills",
      keyTarget: TutorialService.insightsPillEssentialKey,
      alignSkip: Alignment.topRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      paddingFocus: 20,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) => _buildTutorialContent(controller, "Intent Categories", "We categorize spending into Essential, Joyful, Avoidable, and Investments to help you understand your habits better."),
        ),
      ],
    ));

    // TIMELINE TAB
    targets.add(TargetFocus(
      identify: "TargetTimelineTab",
      keyTarget: TutorialService.mainNavTimelineKey,
      alignSkip: Alignment.topRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.top,
          builder: (context, controller) => _buildTutorialContent(
            controller, 
            "Timeline", 
            "Your entire transaction history is here.\n\nTap here to continue.",
            hideNext: true,
          ),
        ),
      ],
    ));

    targets.add(TargetFocus(
      identify: "TargetTimelineSearch",
      keyTarget: TutorialService.timelineSearchKey,
      alignSkip: Alignment.topRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) => _buildTutorialContent(controller, "Search & Filter", "Easily search for specific transactions or filter by date and category."),
        ),
      ],
    ));

    // TOOLKIT TAB
    targets.add(TargetFocus(
      identify: "TargetToolkitTab",
      keyTarget: TutorialService.mainNavToolkitKey,
      alignSkip: Alignment.topRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.top,
          builder: (context, controller) => _buildTutorialContent(
            controller, 
            "Toolkit", 
            "Access powerful financial tools, calculators, settings, and exports.\n\nTap here to continue.",
            hideNext: true,
          ),
        ),
      ],
    ));

    targets.add(TargetFocus(
      identify: "TargetToolkitReplay",
      keyTarget: TutorialService.toolkitReplayKey,
      alignSkip: Alignment.topRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.top,
          builder: (context, controller) => _buildTutorialContent(
            controller, 
            "Reset Tutorial", 
            "If you ever want to see this tour again or reset the individual tool guides, you can do it here.",
            nextText: "Finish",
          ),
        ),
      ],
    ));

    return targets;
  }
}
