import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../providers/app_state_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/category_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/source_provider.dart';
import '../services/transaction_service.dart';

import 'home_screen.dart';
import 'budgets_screen.dart';
import 'insights_screen.dart';
import 'timeline_screen.dart';
import 'settings_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initial data load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(transactionListProvider.notifier).loadTransactions();
      ref.read(categoriesListProvider.notifier).loadCategories();
      ref.read(sourcesListProvider.notifier).loadSources();
      ref.read(budgetLimitsProvider.notifier).loadLimits();
      ref.read(globalBudgetProvider.notifier).loadGlobalBudget();
      ref.read(currencyProvider.notifier).loadCurrency();
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(activeTabProvider);

    return Scaffold(
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
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    final currentIndex = ref.watch(activeTabProvider);

    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: TallyTapTheme.obsidianBg,
        border: Border(
          top: BorderSide(color: TallyTapTheme.borderGreen, width: 1.0),
        ),
      ),
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
    );
  }

  Widget _buildNavBarItem(int index, IconData icon, String label, bool isActive) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(activeTabProvider.notifier).state = index;
      },
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isActive ? TallyTapTheme.primaryMint : TallyTapTheme.textGray,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
              color: isActive ? TallyTapTheme.primaryMint : TallyTapTheme.textGray,
            ),
          ),
        ],
      ),
    );
  }
}
