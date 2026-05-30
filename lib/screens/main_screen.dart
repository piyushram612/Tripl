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
import 'settings_screen.dart';
import 'create_transaction_screen.dart';
import 'create_recurring_transaction_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> with WidgetsBindingObserver {
  final GlobalKey _fabKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Listen for native navigation requests
    const MethodChannel('com.piyushram612.tallytap/popup').setMethodCallHandler((call) async {
      if (call.method == 'navigate' && call.arguments == 'create_transaction') {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateTransactionScreen(),
            ),
          );
        }
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
    }
  }

  @override
  Widget build(BuildContext context) {
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
            SettingsScreen(),
          ],
        ),
      ),
      floatingActionButton: Container(
        key: _fabKey,
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
                        _buildNavBarItem(4, Icons.settings, 'Settings', currentIndex == 4),
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
    return Expanded(
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
    final RenderBox? fabBox = _fabKey.currentContext?.findRenderObject() as RenderBox?;
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
}
