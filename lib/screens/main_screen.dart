import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import '../models/transaction_model.dart';
import '../services/platform_service.dart';
import '../services/transaction_service.dart';
import 'widgets/budget_ring_painter.dart';
import 'widgets/dashed_border_container.dart';
import 'widgets/donut_chart_painter.dart';
import 'widgets/intent_ring_painter.dart';
import 'widgets/weekly_trend_painter.dart';

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

// Categories List Provider
final categoriesListProvider = StateNotifierProvider<CategoriesListNotifier, List<String>>((ref) {
  return CategoriesListNotifier();
});

class CategoriesListNotifier extends StateNotifier<List<String>> {
  CategoriesListNotifier() : super([]) {
    loadCategories();
  }

  static const List<String> defaultCategories = [
    'Dining',
    'Commute',
    'Subscriptions',
    'Utilities',
    'Groceries',
    'Shopping',
    'Housing',
    'Health',
    'Travel',
    'Other',
  ];

  Future<void> loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final jsonStr = prefs.getString('categories_json');
    if (jsonStr == null || jsonStr.isEmpty) {
      await prefs.setString('categories_json', json.encode(defaultCategories));
      state = List.from(defaultCategories);
    } else {
      try {
        final List<dynamic> decoded = json.decode(jsonStr);
        state = decoded.map((e) => e.toString()).toList();
      } catch (e) {
        state = List.from(defaultCategories);
      }
    }
  }

  Future<void> addCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || state.contains(trimmed)) return;
    final updated = List<String>.from(state)..add(trimmed);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('categories_json', json.encode(updated));
    state = updated;
  }

  Future<void> deleteCategory(String name) async {
    final updated = List<String>.from(state)..remove(name);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('categories_json', json.encode(updated));
    state = updated;
  }
}

// Payment Sources List Provider
final sourcesListProvider = StateNotifierProvider<SourcesListNotifier, List<String>>((ref) {
  return SourcesListNotifier();
});

class SourcesListNotifier extends StateNotifier<List<String>> {
  SourcesListNotifier() : super([]) {
    loadSources();
  }

  static const List<String> defaultSources = [
    'Cash',
    'Bank Account',
    'Credit Card',
  ];

  Future<void> loadSources() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final jsonStr = prefs.getString('sources_json');
    if (jsonStr == null || jsonStr.isEmpty) {
      await prefs.setString('sources_json', json.encode(defaultSources));
      state = List.from(defaultSources);
    } else {
      try {
        final List<dynamic> decoded = json.decode(jsonStr);
        state = decoded.map((e) => e.toString()).toList();
      } catch (e) {
        state = List.from(defaultSources);
      }
    }
  }

  Future<void> addSource(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || state.contains(trimmed)) return;
    final updated = List<String>.from(state)..add(trimmed);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sources_json', json.encode(updated));
    state = updated;
  }

  Future<void> deleteSource(String name) async {
    final updated = List<String>.from(state)..remove(name);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sources_json', json.encode(updated));
    state = updated;
  }
}

final budgetLimitsProvider = StateNotifierProvider<BudgetLimitsNotifier, Map<String, double>>((ref) {
  return BudgetLimitsNotifier();
});

class BudgetLimitsNotifier extends StateNotifier<Map<String, double>> {
  BudgetLimitsNotifier() : super({}) {
    loadLimits();
  }

  Future<void> loadLimits() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    
    final Map<String, double> loaded = {};
    
    final jsonStr = prefs.getString('categories_json');
    List<String> activeCategories = CategoriesListNotifier.defaultCategories;
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List<dynamic> decoded = json.decode(jsonStr);
        activeCategories = decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }

    final defaultLimits = {
      'Dining': 800.0,
      'Commute': 400.0,
      'Subscriptions': 400.0,
      'Utilities': 300.0,
      'Other': 2000.0,
    };

    for (final cat in activeCategories) {
      final key = 'budget_limit_$cat';
      final defaultLimit = defaultLimits[cat] ?? 500.0;
      loaded[cat] = prefs.getDouble(key) ?? defaultLimit;
    }
    state = loaded;
  }

  Future<void> setLimit(String category, double limit) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'budget_limit_$category';
    await prefs.setDouble(key, limit);
    await loadLimits();
  }
}

class GlobalBudgetState {
  final double amount;
  final String period; // 'monthly' or 'weekly'

  GlobalBudgetState({required this.amount, required this.period});
}

final globalBudgetProvider = StateNotifierProvider<GlobalBudgetNotifier, GlobalBudgetState>((ref) {
  return GlobalBudgetNotifier();
});

class GlobalBudgetNotifier extends StateNotifier<GlobalBudgetState> {
  GlobalBudgetNotifier() : super(GlobalBudgetState(amount: 2000.0, period: 'monthly')) {
    loadGlobalBudget();
  }

  Future<void> loadGlobalBudget() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final amount = prefs.getDouble('global_budget_amount') ?? 2000.0;
    final period = prefs.getString('global_budget_period') ?? 'monthly';
    state = GlobalBudgetState(amount: amount, period: period);
  }

  Future<void> setGlobalBudget(double amount, String period) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('global_budget_amount', amount);
    await prefs.setString('global_budget_period', period);
    state = GlobalBudgetState(amount: amount, period: period);
  }
}


class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> with WidgetsBindingObserver {
  String _searchQuery = "";
  String _activeFilter = "All Activity";
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _categoryInputController = TextEditingController();
  final TextEditingController _sourceInputController = TextEditingController();
  Timer? _refreshTimer;

  bool _isDateInCurrentWeek(DateTime date) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    return date.isAfter(startOfDay.subtract(const Duration(seconds: 1)));
  }

  bool _isDateInCurrentMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  String _getWeekRangeString() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    
    final startMonth = _getMonthName(startOfWeek.month).substring(0, 3);
    final endMonth = _getMonthName(endOfWeek.month).substring(0, 3);
    
    if (startOfWeek.month == endOfWeek.month) {
      return '$startMonth ${startOfWeek.day} - ${endOfWeek.day}, ${now.year}';
    } else {
      return '$startMonth ${startOfWeek.day} - $endMonth ${endOfWeek.day}, ${now.year}';
    }
  }

  String _getMonthString() {
    final now = DateTime.now();
    return '${_getMonthName(now.month)} ${now.year}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Poll for SharedPreferences updates every 1 second to instantly reflect native entries
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        ref.read(transactionListProvider.notifier).loadTransactions();
        ref.read(categoriesListProvider.notifier).loadCategories();
        ref.read(sourcesListProvider.notifier).loadSources();
        ref.read(budgetLimitsProvider.notifier).loadLimits();
        ref.read(globalBudgetProvider.notifier).loadGlobalBudget();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    _categoryInputController.dispose();
    _sourceInputController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When returning from the native Compose popup drawer overlay, reload transactions automatically
    if (state == AppLifecycleState.resumed) {
      ref.read(transactionListProvider.notifier).loadTransactions();
      ref.read(categoriesListProvider.notifier).loadCategories();
      ref.read(sourcesListProvider.notifier).loadSources();
      ref.read(budgetLimitsProvider.notifier).loadLimits();
      ref.read(globalBudgetProvider.notifier).loadGlobalBudget();
    }
  }

  void _showManageBudgetsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TallyTapTheme.obsidianBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        side: BorderSide(color: TallyTapTheme.borderGreen, width: 1.0),
      ),
      builder: (context) {
        return const _ManageBudgetsSheet();
      },
    );
  }

  void _showManageCategoriesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TallyTapTheme.obsidianBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        side: BorderSide(color: TallyTapTheme.borderGreen, width: 1.0),
      ),
      builder: (context) {
        return const _ManageCategoriesSheet();
      },
    );
  }

  void _showManageSourcesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TallyTapTheme.obsidianBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        side: BorderSide(color: TallyTapTheme.borderGreen, width: 1.0),
      ),
      builder: (context) {
        return const _ManageSourcesSheet();
      },
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1B17),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: TallyTapTheme.primaryMint,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: TallyTapTheme.textLight),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: TallyTapTheme.textGray),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: TallyTapTheme.textGray,
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTab = ref.watch(activeTabProvider);

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: activeTab,
          children: [
            _buildHomeTab(context),
            _buildBudgetsTab(context),
            _buildInsightsTab(context),
            _buildTimelineTab(context),
            _buildSettingsTab(context),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  // ==========================================
  // HOME TAB (THE PREMIUM OBDISIDAN DASHBOARD)
  // ==========================================
  Widget _buildHomeTab(BuildContext context) {
    final transactions = ref.watch(transactionListProvider);
    final categories = ref.watch(categoriesListProvider);
    final globalBudget = ref.watch(globalBudgetProvider);

    // Dynamic metrics calculation based on overall period (weekly vs monthly)
    double totalSpent = 0.0;

    for (var tx in transactions) {
      if (tx.category.toLowerCase() != 'income') {
        if (globalBudget.period == 'weekly') {
          if (_isDateInCurrentWeek(tx.date)) {
            totalSpent += tx.amount;
          }
        } else {
          if (_isDateInCurrentMonth(tx.date)) {
            totalSpent += tx.amount;
          }
        }
      }
    }

    // Dynamic Weekly Graph points
    final now = DateTime.now();
    final List<double> weeklyTrend = List.generate(7, (index) {
      final targetDate = now.subtract(Duration(days: 6 - index));
      double dayTotal = 0.0;
      for (var tx in transactions) {
        if (tx.date.year == targetDate.year &&
            tx.date.month == targetDate.month &&
            tx.date.day == targetDate.day &&
            tx.category.toLowerCase() != 'income') {
          dayTotal += tx.amount;
        }
      }
      return dayTotal;
    });

    String capitalizeCategory(String cat) {
      if (cat.isEmpty) return cat;
      final match = categories.firstWhere(
        (c) => c.toLowerCase() == cat.toLowerCase(),
        orElse: () => '',
      );
      if (match.isNotEmpty) return match;
      return cat.split(' ').map((word) {
        if (word.isEmpty) return word;
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      }).join(' ');
    }

    // Group actual categories dynamically based strictly on user transactions in the current period
    final Map<String, double> catSum = {};
    for (var tx in transactions) {
      if (tx.category.toLowerCase() != 'income') {
        if (globalBudget.period == 'weekly') {
          if (!_isDateInCurrentWeek(tx.date)) continue;
        } else {
          if (!_isDateInCurrentMonth(tx.date)) continue;
        }
        final normalizedCat = capitalizeCategory(tx.category);
        catSum[normalizedCat] = (catSum[normalizedCat] ?? 0.0) + tx.amount;
      }
    }

    int catIdx = 0;
    final dynamicCategories = catSum.entries.map((entry) {
      final color = _getColorForCategory(entry.key, catIdx++);
      return DonutChartCategory(
        name: entry.key,
        amount: entry.value,
        color: color,
      );
    }).toList()..sort((a, b) => b.amount.compareTo(a.amount));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          // 1. Top Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: TallyTapTheme.obsidianCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: TallyTapTheme.borderGreen),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: TallyTapTheme.primaryMint,
                  size: 20,
                ),
              ),
              const Text(
                'TallyTap',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: TallyTapTheme.textLight,
                  letterSpacing: -1.0,
                ),
              ),
              // Circular avatar matching mockup
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: TallyTapTheme.borderGreen, width: 1.5),
                  image: const DecorationImage(
                    image: NetworkImage('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&auto=format&fit=crop&q=80'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 2. Main Greeting Text
          const Text(
            'Good morning, Alex',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: TallyTapTheme.primaryMint,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 14, color: TallyTapTheme.textGray, height: 1.4),
              children: [
                const TextSpan(text: "You've spent "),
                TextSpan(
                  text: '\$${totalSpent.toStringAsFixed(0)}',
                  style: const TextStyle(color: TallyTapTheme.primaryMint, fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text: ' recently.\nYou\'re on track to stay within your \$${globalBudget.amount.toStringAsFixed(0)} ${globalBudget.period} budget.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 3. Scrollable Dashboard Cards
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // CARD A: Weekly Summary Line Graph
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'WEEKLY SUMMARY',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.5,
                                      color: TallyTapTheme.textGray,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        '\$${totalSpent.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")}',
                                        style: const TextStyle(
                                          fontSize: 34,
                                          fontWeight: FontWeight.w900,
                                          color: TallyTapTheme.textLight,
                                          letterSpacing: -1.0,
                                        ),
                                      ),
                                      const Text(
                                        '.00',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: TallyTapTheme.textGray,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              // Trend pill (+12%)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F2B20),
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(color: const Color(0xFF144D37)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.trending_up, color: TallyTapTheme.primaryMint, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      '+12%',
                                      style: TextStyle(
                                        color: TallyTapTheme.primaryMint,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          WeeklyTrendGraph(values: weeklyTrend),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // CARD B: Spending Breakdown
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Spending Breakdown',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: TallyTapTheme.textLight,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 1. Centered Octagon Donut chart
                              Center(
                                child: DonutChart(categories: dynamicCategories),
                              ),
                              const SizedBox(height: 24),
                              // 2. Legends below the chart
                              if (dynamicCategories.isEmpty)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12.0),
                                    child: Text(
                                      'No expenses yet',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: TallyTapTheme.textGray,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Column(
                                  children: dynamicCategories.asMap().entries.map((entry) {
                                    final cat = entry.value;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12.0),
                                      child: _buildLegendRow(
                                        cat.name,
                                        cat.amount,
                                        cat.color,
                                      ),
                                    );
                                  }).toList(),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // CARD C: Recent Reflections (Mockup Transactions)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Recent Reflections',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: TallyTapTheme.textLight,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.more_horiz, color: TallyTapTheme.textGray, size: 20),
                                onPressed: () {},
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // List of live transactions
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: transactions.length > 4 ? 4 : transactions.length,
                            separatorBuilder: (_, __) => const Divider(color: TallyTapTheme.borderGreen, height: 24, thickness: 0.5),
                            itemBuilder: (context, index) {
                              final tx = transactions[index];
                              return _buildTransactionItem(tx);
                            },
                          ),
                          const SizedBox(height: 20),
                          OutlinedButton(
                            onPressed: () {
                              ref.read(activeTabProvider.notifier).state = 3; // Switch to Timeline Tab
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: TallyTapTheme.borderGreen),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              'VIEW ALL TRANSACTIONS',
                              style: TextStyle(
                                color: TallyTapTheme.primaryMint,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper: Legends
  Widget _buildLegendRow(String title, double spent, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 13, color: TallyTapTheme.textGray, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        Text(
          '\$${spent.toStringAsFixed(0)}',
          style: const TextStyle(fontSize: 13, color: TallyTapTheme.textLight, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // Helper: Recent Reflections List Item
  Widget _buildTransactionItem(ExpenseTransaction tx) {
    IconData icon;
    Color iconBg;
    final clean = tx.category.toLowerCase();
    if (clean.contains('dining') || clean.contains('food') || clean.contains('dinner') || clean.contains('restaurant')) {
      icon = Icons.local_cafe_outlined;
      iconBg = const Color(0xFF261D4C); // Deep purple tint
    } else if (clean.contains('commute') || clean.contains('transport') || clean.contains('car') || clean.contains('cab')) {
      icon = Icons.directions_transit_filled_outlined;
      iconBg = const Color(0xFF1E284C); // Deep blue tint
    } else if (clean.contains('sub') || clean.contains('subscriptions') || clean.contains('entertainment')) {
      icon = Icons.subscriptions_outlined;
      iconBg = const Color(0xFF1B2B3A); // Slate tint
    } else if (clean.contains('utility') || clean.contains('bill') || clean.contains('electricity')) {
      icon = Icons.bolt_outlined;
      iconBg = const Color(0xFF332A15); // Amber tint
    } else {
      icon = Icons.local_mall_outlined;
      iconBg = const Color(0xFF142B24); // Mint tint
    }

    final formattedDate = tx.date.difference(DateTime.now()).inDays.abs() == 0
        ? 'Today, 8:42 AM'
        : tx.date.difference(DateTime.now()).inDays.abs() == 1
            ? 'Yesterday'
            : 'Mon, Oct 12'; // Mocking standard timeline labels matching mockup

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: iconBg,
            border: Border.all(color: TallyTapTheme.borderGreen, width: 0.5),
          ),
          child: Icon(icon, color: TallyTapTheme.textLight, size: 18),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tx.merchant,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: TallyTapTheme.textLight),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '$formattedDate • ${tx.paymentMethod}',
                style: const TextStyle(fontSize: 12, color: TallyTapTheme.textGray),
              ),
            ],
          ),
        ),
        Text(
          '-\$${tx.amount.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: TallyTapTheme.textLight),
        ),
      ],
    );
  }

  // ==========================================
  // NAVIGATION PAGES (FALLBACK CHANNELS)
  // ==========================================
  IconData _getIconForCategory(String cat) {
    final clean = cat.trim().toLowerCase();
    if (clean.contains('dining') || clean.contains('food') || clean.contains('restaurant') || clean.contains('cafe') || clean.contains('dinner') || clean.contains('lunch') || clean.contains('breakfast')) {
      return Icons.restaurant_menu_outlined;
    } else if (clean.contains('commute') || clean.contains('transport') || clean.contains('car') || clean.contains('cab')) {
      return Icons.directions_car_filled_outlined;
    } else if (clean.contains('sub') || clean.contains('entertainment') || clean.contains('movie') || clean.contains('play') || clean.contains('game')) {
      return Icons.sports_esports_outlined;
    } else if (clean.contains('utility') || clean.contains('bill') || clean.contains('electricity') || clean.contains('water') || clean.contains('gas')) {
      return Icons.bolt_outlined;
    } else if (clean.contains('grocer')) {
      return Icons.local_grocery_store_outlined;
    } else if (clean.contains('shop')) {
      return Icons.shopping_bag_outlined;
    } else if (clean.contains('house') || clean.contains('rent') || clean.contains('home')) {
      return Icons.home_outlined;
    } else if (clean.contains('health') || clean.contains('medical') || clean.contains('doctor') || clean.contains('gym')) {
      return Icons.health_and_safety_outlined;
    } else if (clean.contains('travel') || clean.contains('flight') || clean.contains('hotel')) {
      return Icons.card_travel_outlined;
    } else if (clean.contains('salary') || clean.contains('income') || clean.contains('pay')) {
      return Icons.attach_money_outlined;
    }
    return Icons.category_outlined;
  }

  Color _getColorForCategory(String cat, int index) {
    final clean = cat.trim().toLowerCase();
    if (clean.contains('dining') || clean.contains('food') || clean.contains('dinner')) {
      return TallyTapTheme.primaryMint; // #4EDEA3
    } else if (clean.contains('commute') || clean.contains('transport')) {
      return TallyTapTheme.primaryViolet; // #3A41C7
    } else if (clean.contains('sub') || clean.contains('entertainment')) {
      return TallyTapTheme.primarySlate; // #9FB6DF
    } else if (clean.contains('utility') || clean.contains('bill')) {
      return const Color(0xFFF59E0B); // Amber
    } else if (clean.contains('grocer')) {
      return const Color(0xFF10B981); // Emerald Green
    } else if (clean.contains('shop')) {
      return const Color(0xFFEC4899); // Pink
    } else if (clean.contains('house') || clean.contains('rent')) {
      return const Color(0xFF8B5CF6); // Purple
    } else if (clean.contains('health') || clean.contains('medical')) {
      return const Color(0xFFEF4444); // Red
    } else if (clean.contains('travel') || clean.contains('flight')) {
      return const Color(0xFF06B6D4); // Cyan
    } else if (clean.contains('salary') || clean.contains('income')) {
      return const Color(0xFF22C55E); // Green
    }
    final colors = [
      TallyTapTheme.primaryMint,
      TallyTapTheme.primaryViolet,
      TallyTapTheme.primarySlate,
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899),
      const Color(0xFF8B5CF6),
      const Color(0xFF06B6D4),
      const Color(0xFF10B981),
    ];
    return colors[index % colors.length];
  }

  Widget _buildBudgetsTab(BuildContext context) {
    final categories = ref.watch(categoriesListProvider);
    final transactions = ref.watch(transactionListProvider);
    final budgetLimits = ref.watch(budgetLimitsProvider);
    final globalBudget = ref.watch(globalBudgetProvider);

    // Calculate dynamic spent per category in the current period
    final Map<String, double> spentPerCategory = {};
    double totalSpent = 0.0;
    for (var tx in transactions) {
      if (tx.category.toLowerCase() != 'income') {
        if (globalBudget.period == 'weekly') {
          if (!_isDateInCurrentWeek(tx.date)) continue;
        } else {
          if (!_isDateInCurrentMonth(tx.date)) continue;
        }
        totalSpent += tx.amount;
        final matchedCategory = categories.firstWhere(
          (c) => c.toLowerCase() == tx.category.toLowerCase(),
          orElse: () => tx.category,
        );
        spentPerCategory[matchedCategory] = (spentPerCategory[matchedCategory] ?? 0.0) + tx.amount;
      }
    }

    final double overallProportion = globalBudget.amount > 0 ? (totalSpent / globalBudget.amount) : 0.0;
    final String percentText = '${(overallProportion * 100).toStringAsFixed(0)}%';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          // 1. Unified Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: TallyTapTheme.obsidianCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: TallyTapTheme.borderGreen),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: TallyTapTheme.primaryMint,
                  size: 20,
                ),
              ),
              const Text(
                'TallyTap',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: TallyTapTheme.textLight,
                  letterSpacing: -1.0,
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: TallyTapTheme.borderGreen, width: 1.5),
                  image: const DecorationImage(
                    image: NetworkImage('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&auto=format&fit=crop&q=80'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 2. Headlines
          Text(
            globalBudget.period == 'weekly' ? 'Weekly Budgets' : 'Monthly Budgets',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: TallyTapTheme.primaryMint,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Track your spending across categories.',
            style: TextStyle(
              fontSize: 14,
              color: TallyTapTheme.textGray,
            ),
          ),
          const SizedBox(height: 16),

          // 3. Date Capsule Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: TallyTapTheme.obsidianCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: TallyTapTheme.borderGreen),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.chevron_left_rounded, color: TallyTapTheme.textGray, size: 18),
                    const SizedBox(width: 12),
                    Text(
                      globalBudget.period == 'weekly' ? _getWeekRangeString() : _getMonthString(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: TallyTapTheme.textLight,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.chevron_right_rounded, color: TallyTapTheme.textGray, size: 18),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 4. Scrollable Budget Contents
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // CARD A: Global Limit Spent Ring
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          BudgetRingGraph(spent: totalSpent, limit: globalBudget.amount),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.circle, color: TallyTapTheme.primaryMint, size: 8),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Global ${globalBudget.period == 'monthly' ? 'Monthly' : 'Weekly'} Budget',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: TallyTapTheme.textLight),
                                  ),
                                ],
                              ),
                              Text(
                                percentText,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: TallyTapTheme.textLight),
                              ),
                            ],
                          ),
                          const Divider(color: TallyTapTheme.borderGreen, height: 24, thickness: 0.5),
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 13, color: TallyTapTheme.textLight, height: 1.4),
                              children: [
                                TextSpan(text: "You are pacing well within your global \$${globalBudget.amount.toStringAsFixed(0)} ${globalBudget.period} limit. Adjust settings in the "),
                                const TextSpan(
                                  text: "Manage Limits",
                                  style: TextStyle(fontWeight: FontWeight.bold, color: TallyTapTheme.primaryMint),
                                ),
                                const TextSpan(text: " panel below."),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          OutlinedButton.icon(
                            onPressed: () => _showManageBudgetsSheet(context),
                            icon: const Icon(Icons.tune_rounded, color: TallyTapTheme.primaryMint, size: 16),
                            label: const Text(
                              'Manage Limits',
                              style: TextStyle(color: TallyTapTheme.primaryMint, fontSize: 12, fontWeight: FontWeight.w800),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: TallyTapTheme.borderGreen),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Header: Categories
                  const Text(
                    'Categories',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: TallyTapTheme.textLight,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // CARD LIST: Categories rows
                  ...categories.asMap().entries.map((entry) {
                    final index = entry.key;
                    final cat = entry.value;
                    final spent = spentPerCategory[cat] ?? 0.0;
                    final limit = budgetLimits[cat] ?? 500.0;
                    final icon = _getIconForCategory(cat);
                    final color = _getColorForCategory(cat, index);
                    final proportion = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;

                    return _buildCategoryBudgetCard(
                      title: cat,
                      spent: spent,
                      limit: limit,
                      icon: icon,
                      proportion: proportion,
                      progressColor: color,
                    );
                  }).toList(),

                  // CARD E: Dashed Add Category Box
                  DashedBorderContainer(
                    child: InkWell(
                      onTap: () => _showManageBudgetsSheet(context),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        height: 90,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.add_circle_outline_rounded, color: TallyTapTheme.textGray, size: 24),
                            SizedBox(height: 8),
                            Text(
                              'ADJUST BUDGETS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: TallyTapTheme.textGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Category Budget Row Helper
  Widget _buildCategoryBudgetCard({
    required String title,
    required double spent,
    required double limit,
    required IconData icon,
    required double proportion,
    Color? progressColor,
  }) {
    final percent = (proportion * 100).toStringAsFixed(0);
    final activeColor = progressColor ?? TallyTapTheme.primaryMint;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          children: [
            Row(
              children: [
                // Icon wrapper
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1B17),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: TallyTapTheme.borderGreen, width: 0.5),
                  ),
                  child: Icon(icon, color: TallyTapTheme.primaryMint, size: 20),
                ),
                const SizedBox(width: 14),
                // Title
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: TallyTapTheme.textLight),
                  ),
                ),
                // Percent capsule
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13221E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$percent%',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: TallyTapTheme.textLight),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Amounts
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '\$${spent.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: TallyTapTheme.textLight),
                ),
                Text(
                  '/ \$${limit.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")}',
                  style: const TextStyle(fontSize: 12, color: TallyTapTheme.textGray, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Custom linear indicator
            Container(
              height: 6,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF14241F),
                borderRadius: BorderRadius.circular(100),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: proportion > 1.0 ? 1.0 : proportion,
                child: Container(
                  decoration: BoxDecoration(
                    color: activeColor,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsTab(BuildContext context) {
    final transactions = ref.watch(transactionListProvider);
    final budgetLimits = ref.watch(budgetLimitsProvider);

    double diningSpent = 0.0;
    double commuteSpent = 0.0;
    double subSpent = 0.0;
    double utilitiesSpent = 0.0;
    double otherSpent = 0.0;

    for (var tx in transactions) {
      final clean = tx.category.toLowerCase();
      if (clean != 'income') {
        if (clean.contains('dining') || clean.contains('food') || clean.contains('dinner')) {
          diningSpent += tx.amount;
        } else if (clean.contains('commute') || clean.contains('transport')) {
          commuteSpent += tx.amount;
        } else if (clean.contains('sub') || clean.contains('entertainment')) {
          subSpent += tx.amount;
        } else if (clean.contains('utility') || clean.contains('bill')) {
          utilitiesSpent += tx.amount;
        } else {
          otherSpent += tx.amount;
        }
      }
    }

    final double diningLimit = budgetLimits['Dining'] ?? 800.0;
    final double commuteLimit = budgetLimits['Commute'] ?? 400.0;
    final double utilitiesLimit = budgetLimits['Utilities'] ?? 300.0;
    final double otherLimit = budgetLimits['Other'] ?? 2000.0;

    final double essential = otherSpent + utilitiesSpent + commuteSpent;
    final double joyful = diningSpent;
    final double avoidable = subSpent;
    final double totalSpent = essential + joyful + avoidable;

    final String essentialPercent = totalSpent > 0 ? '${(essential / totalSpent * 100).toStringAsFixed(0)}%' : '0%';
    final String joyfulPercent = totalSpent > 0 ? '${(joyful / totalSpent * 100).toStringAsFixed(0)}%' : '0%';
    final String avoidablePercent = totalSpent > 0 ? '${(avoidable / totalSpent * 100).toStringAsFixed(0)}%' : '0%';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          // 1. Unified Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: TallyTapTheme.obsidianCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: TallyTapTheme.borderGreen),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: TallyTapTheme.primaryMint,
                  size: 20,
                ),
              ),
              const Text(
                'TallyTap',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: TallyTapTheme.textLight,
                  letterSpacing: -1.0,
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: TallyTapTheme.borderGreen, width: 1.5),
                  image: const DecorationImage(
                    image: NetworkImage('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&auto=format&fit=crop&q=80'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 2. Main Headlines
          const Text(
            'Monthly Intentionality',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: TallyTapTheme.primaryMint,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'A high-level overview of where your resources flowed this period, categorized by intent.',
            style: TextStyle(
              fontSize: 14,
              color: TallyTapTheme.textGray,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // 3. Scrollable Insights Content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // CARD A: Intent Circle Donut
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          IntentRingGraph(
                            essential: essential,
                            joyful: joyful,
                            avoidable: avoidable,
                            totalSpent: totalSpent,
                          ),
                          const SizedBox(height: 20),
                          // Custom Proportional Legends
                          _buildIntentLegendRow('Essential', essentialPercent, TallyTapTheme.primaryMint),
                          const Divider(color: TallyTapTheme.borderGreen, height: 24, thickness: 0.5),
                          _buildIntentLegendRow('Joyful', joyfulPercent, const Color(0xFF4B5E55)),
                          const Divider(color: TallyTapTheme.borderGreen, height: 24, thickness: 0.5),
                          _buildIntentLegendRow('Avoidable', avoidablePercent, const Color(0xFFFFB5B5)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // CARD B: Insight of the Day
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.lightbulb_outline_rounded, color: TallyTapTheme.primaryMint, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'INSIGHT OF THE DAY',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                  color: TallyTapTheme.primaryMint,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          RichText(
                            text: const TextSpan(
                              style: TextStyle(fontSize: 13, color: TallyTapTheme.textLight, height: 1.5),
                              children: [
                                TextSpan(text: "Your "),
                                TextSpan(
                                  text: "Joyful",
                                  style: TextStyle(color: Color(0xFF9FB6DF), fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: " spending increased by 12% this month, primarily driven by dining experiences. However, your "),
                                TextSpan(
                                  text: "Avoidable",
                                  style: TextStyle(color: Color(0xFFFFB5B5), fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: " expenses remain low, indicating strong fundamental habits."),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // CARD C: Category Breakdown Linear Progress Bars
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Category Breakdown',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: TallyTapTheme.primaryMint,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildCategoryProgressRow(
                            'Housing & Utilities',
                            otherSpent + utilitiesSpent,
                            (otherLimit + utilitiesLimit) > 0
                                ? ((otherSpent + utilitiesSpent) / (otherLimit + utilitiesLimit)).clamp(0.0, 1.0)
                                : 0.0,
                          ),
                          const SizedBox(height: 20),
                          _buildCategoryProgressRow(
                            'Food & Dining',
                            diningSpent,
                            diningLimit > 0 ? (diningSpent / diningLimit).clamp(0.0, 1.0) : 0.0,
                          ),
                          const SizedBox(height: 20),
                          _buildCategoryProgressRow(
                            'Transportation',
                            commuteSpent,
                            commuteLimit > 0 ? (commuteSpent / commuteLimit).clamp(0.0, 1.0) : 0.0,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Legend Helper
  Widget _buildIntentLegendRow(String title, String percent, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 13, color: TallyTapTheme.textGray, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        Text(
          percent,
          style: const TextStyle(fontSize: 13, color: TallyTapTheme.textLight, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // Progress Helper
  Widget _buildCategoryProgressRow(String title, double amount, double proportion) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 13, color: TallyTapTheme.textLight, fontWeight: FontWeight.w500),
            ),
            Text(
              '\$${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")}',
              style: const TextStyle(fontSize: 13, color: TallyTapTheme.primaryMint, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF14241F),
            borderRadius: BorderRadius.circular(100),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: proportion,
            child: Container(
              decoration: BoxDecoration(
                color: TallyTapTheme.primaryMint,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineTab(BuildContext context) {
    final transactions = ref.watch(transactionListProvider);

    // Apply search query and category filters dynamically
    final filtered = transactions.where((tx) {
      final matchesSearch = tx.merchant.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          tx.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          tx.paymentMethod.toLowerCase().contains(_searchQuery.toLowerCase());

      bool matchesTab = true;
      if (_activeFilter == "Income") {
        matchesTab = tx.category.toLowerCase() == 'income';
      } else if (_activeFilter == "Expenses") {
        matchesTab = tx.category.toLowerCase() != 'income';
      } else if (_activeFilter == "Transfers") {
        matchesTab = false; // Mock empty transfers
      }

      return matchesSearch && matchesTab;
    }).toList();

    // Group transactions by date
    final now = DateTime.now();
    final todayList = filtered.where((tx) =>
        tx.date.year == now.year && tx.date.month == now.month && tx.date.day == now.day).toList();

    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayList = filtered.where((tx) =>
        tx.date.year == yesterday.year && tx.date.month == yesterday.month && tx.date.day == yesterday.day).toList();

    final olderList = filtered.where((tx) =>
        !(tx.date.year == now.year && tx.date.month == now.month && tx.date.day == now.day) &&
        !(tx.date.year == yesterday.year && tx.date.month == yesterday.month && tx.date.day == yesterday.day)).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          // 1. Unified Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: TallyTapTheme.obsidianCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: TallyTapTheme.borderGreen),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: TallyTapTheme.primaryMint,
                  size: 20,
                ),
              ),
              const Text(
                'TallyTap',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: TallyTapTheme.textLight,
                  letterSpacing: -1.0,
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: TallyTapTheme.borderGreen, width: 1.5),
                  image: const DecorationImage(
                    image: NetworkImage('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&auto=format&fit=crop&q=80'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 2. Headline
          const Text(
            'Timeline',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: TallyTapTheme.textLight,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 16),

          // 3. Search Bar Input
          TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
            style: const TextStyle(fontSize: 14, color: TallyTapTheme.textLight),
            decoration: InputDecoration(
              hintText: 'Search transactions...',
              hintStyle: const TextStyle(fontSize: 14, color: TallyTapTheme.textGray),
              prefixIcon: const Icon(Icons.search, color: TallyTapTheme.textGray, size: 20),
              filled: true,
              fillColor: TallyTapTheme.obsidianCard,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: TallyTapTheme.borderGreen),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: TallyTapTheme.primaryMint),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 4. Horizontal Filters Scroll
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _buildFilterCapsule('All Activity'),
                _buildFilterCapsule('Income'),
                _buildFilterCapsule('Expenses'),
                _buildFilterCapsule('Transfers'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 5. Scrollable Timelines
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Today Section ---
                  if (todayList.isNotEmpty) ...[
                    _buildSectionHeader('Today', 'Oct 24'),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(
                          children: [
                            for (int i = 0; i < todayList.length; i++) ...[
                              _buildTimelineTransactionItem(todayList[i]),
                              if (i < todayList.length - 1)
                                const Divider(color: TallyTapTheme.borderGreen, height: 1, thickness: 0.5),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // --- Yesterday Section ---
                  if (yesterdayList.isNotEmpty) ...[
                    _buildSectionHeader('Yesterday', 'Oct 23'),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(
                          children: [
                            for (int i = 0; i < yesterdayList.length; i++) ...[
                              _buildTimelineTransactionItem(yesterdayList[i]),
                              if (i < yesterdayList.length - 1)
                                const Divider(color: TallyTapTheme.borderGreen, height: 1, thickness: 0.5),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // --- Older Section ---
                  if (olderList.isNotEmpty) ...[
                    _buildSectionHeader('Older Activity', ''),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(
                          children: [
                            for (int i = 0; i < olderList.length; i++) ...[
                              _buildTimelineTransactionItem(olderList[i]),
                              if (i < olderList.length - 1)
                                const Divider(color: TallyTapTheme.borderGreen, height: 1, thickness: 0.5),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Empty State if search returns nothing
                  if (filtered.isEmpty) ...[
                    const SizedBox(height: 60),
                    const Center(
                      child: Text(
                        'No matching transactions found.',
                        style: TextStyle(color: TallyTapTheme.textGray, fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 60),
                  ],

                  // 6. Glowing Green Spinner
                  const SizedBox(height: 12),
                  const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        valueColor: AlwaysStoppedAnimation<Color>(TallyTapTheme.primaryMint),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Filter capsule helper
  Widget _buildFilterCapsule(String label) {
    final isSelected = _activeFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeFilter = label;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? TallyTapTheme.primaryMint : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: isSelected ? null : Border.all(color: TallyTapTheme.borderGreen, width: 1.0),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            color: isSelected ? TallyTapTheme.obsidianBg : TallyTapTheme.textLight,
          ),
        ),
      ),
    );
  }

  // Date section header helper
  Widget _buildSectionHeader(String day, String dateStr) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          day,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: TallyTapTheme.textLight),
        ),
        if (dateStr.isNotEmpty)
          Text(
            dateStr,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: TallyTapTheme.textGray),
          ),
      ],
    );
  }

  // High-fidelity list item builder matching mockup
  Widget _buildTimelineTransactionItem(ExpenseTransaction tx) {
    final isIncome = tx.category.toLowerCase() == 'income';
    final activeColor = isIncome ? const Color(0xFF10B981) : TallyTapTheme.textLight;

    IconData icon;
    Color iconBg;
    Color iconColor = TallyTapTheme.textLight;

    if (isIncome) {
      icon = Icons.arrow_downward_rounded;
      iconBg = const Color(0xFF0F2B20); // Green tint
      iconColor = const Color(0xFF10B981);
    } else {
      final clean = tx.category.toLowerCase();
      if (clean.contains('dining') || clean.contains('food') || clean.contains('dinner') || clean.contains('restaurant')) {
        icon = Icons.local_cafe_outlined;
        iconBg = const Color(0xFF261D4C);
      } else if (clean.contains('commute') || clean.contains('transport') || clean.contains('car') || clean.contains('cab')) {
        icon = Icons.directions_transit_filled_outlined;
        iconBg = const Color(0xFF1E284C);
      } else if (clean.contains('sub') || clean.contains('subscriptions') || clean.contains('entertainment')) {
        icon = Icons.subscriptions_outlined;
        iconBg = const Color(0xFF1B2B3A);
      } else if (clean.contains('utility') || clean.contains('bill') || clean.contains('electricity')) {
        icon = Icons.bolt_outlined;
        iconBg = const Color(0xFF332A15);
      } else {
        icon = Icons.local_mall_outlined;
        iconBg = const Color(0xFF142B24);
      }
    }

    final formattedTime = "${tx.date.hour.toString().padLeft(2, '0')}:${tx.date.minute.toString().padLeft(2, '0')} ${tx.date.hour >= 12 ? 'PM' : 'AM'}";

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon Wrapper
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconBg,
              border: Border.all(color: TallyTapTheme.borderGreen, width: 0.5),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 16),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.merchant,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: TallyTapTheme.textLight),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '$formattedTime • ${tx.paymentMethod}',
                  style: const TextStyle(fontSize: 12, color: TallyTapTheme.textGray),
                ),
              ],
            ),
          ),
          // Amount & Income Badge Column
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isIncome ? '+' : '-'} \$${tx.amount.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: activeColor),
              ),
              if (isIncome) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F2B20),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF144D37), width: 0.5),
                  ),
                  child: const Text(
                    'Income',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SETTINGS TAB (GESTURE & QUICK LAUNCHERS)
  // ==========================================
  Widget _buildSettingsTab(BuildContext context) {
    final backTapEnabled = ref.watch(backTapEnabledProvider);
    final categories = ref.watch(categoriesListProvider);
    final sources = ref.watch(sourcesListProvider);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: TallyTapTheme.textLight,
              ),
            ),
            const SizedBox(height: 24),

            // Double Back Tap Toggle Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'HARDWARE INTERACTIONS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: TallyTapTheme.primaryMint,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F1B17),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.vibration_rounded,
                            color: TallyTapTheme.primaryMint,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Double Back Tap',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: TallyTapTheme.textLight),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Tap phone casing back or double-shake to trigger',
                                style: TextStyle(fontSize: 12, color: TallyTapTheme.textGray),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: backTapEnabled,
                          activeColor: TallyTapTheme.primaryMint,
                          onChanged: (val) {
                            ref.read(backTapEnabledProvider.notifier).toggle(val);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  val
                                      ? "Back Tap Listener Service Started!"
                                      : "Back Tap Listener Service Stopped.",
                                ),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const Divider(color: TallyTapTheme.borderGreen, height: 32),
                    // Manual Test CTA Button
                    ElevatedButton(
                      onPressed: () => PlatformService.showPopup(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TallyTapTheme.primaryMint,
                        foregroundColor: TallyTapTheme.obsidianBg,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.open_in_new_rounded, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Test Quick Popup',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Card B: Data Configuration (Manage categories and payment sources dynamically via bottom sheets)
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 20.0, top: 16.0, bottom: 8.0),
                      child: Text(
                        'DATA CONFIGURATION',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: TallyTapTheme.primaryMint,
                        ),
                      ),
                    ),
                    _buildSettingsTile(
                      icon: Icons.category_rounded,
                      title: 'Manage Categories',
                      subtitle: 'Add or remove custom expense categories',
                      onTap: () => _showManageCategoriesSheet(context),
                    ),
                    const Divider(color: TallyTapTheme.borderGreen, height: 1, indent: 20, endIndent: 20),
                    _buildSettingsTile(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'Manage Payment Sources',
                      subtitle: 'Configure custom cash or bank accounts',
                      onTap: () => _showManageSourcesSheet(context),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Shortcut Guide Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'SHORTCUT GUIDE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: TallyTapTheme.primaryMint,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '1. Static Shortcuts',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: TallyTapTheme.textLight),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Long press TallyTap icon on your phone launcher, select "Quick Add" to trigger instant overlays under 100ms.',
                      style: TextStyle(fontSize: 12, color: TallyTapTheme.textGray, height: 1.3),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // NAVIGATION BOTTOM BAR WITH MOCKUP GLOWS
  // ==========================================
  Widget _buildBottomNavBar(BuildContext context) {
    final activeTab = ref.watch(activeTabProvider);

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
          _buildNavBarItem(0, Icons.home_filled, 'Home', activeTab == 0),
          _buildNavBarItem(1, Icons.account_balance_wallet, 'Budgets', activeTab == 1),
          _buildNavBarItem(2, Icons.analytics_outlined, 'Insights', activeTab == 2),
          _buildNavBarItem(3, Icons.history_toggle_off, 'Timeline', activeTab == 3),
          _buildNavBarItem(4, Icons.settings, 'Settings', activeTab == 4),
        ],
      ),
    );
  }

  Widget _buildNavBarItem(int index, IconData icon, String label, bool isActive) {
    return InkWell(
      onTap: () => ref.read(activeTabProvider.notifier).state = index,
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

class _ManageBudgetsSheet extends ConsumerStatefulWidget {
  const _ManageBudgetsSheet();

  @override
  ConsumerState<_ManageBudgetsSheet> createState() => _ManageBudgetsSheetState();
}

class _ManageBudgetsSheetState extends ConsumerState<_ManageBudgetsSheet> {
  int _activeTab = 0; // 0 = Global Budget, 1 = Category Limits

  // Category Limits properties
  String? _selectedCategory;
  final TextEditingController _limitController = TextEditingController();

  // Global Budget properties
  final TextEditingController _globalLimitController = TextEditingController();
  String _globalPeriod = 'monthly';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final categories = ref.read(categoriesListProvider);
      final limits = ref.read(budgetLimitsProvider);
      if (categories.isNotEmpty) {
        setState(() {
          _selectedCategory = categories.first;
          _limitController.text = (limits[_selectedCategory!] ?? 500.0).toStringAsFixed(0);
        });
      }
      
      final globalBudget = ref.read(globalBudgetProvider);
      setState(() {
        _globalLimitController.text = globalBudget.amount.toStringAsFixed(0);
        _globalPeriod = globalBudget.period;
      });
    });
  }

  @override
  void dispose() {
    _limitController.dispose();
    _globalLimitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesListProvider);
    final limits = ref.watch(budgetLimitsProvider);

    if (_selectedCategory == null && categories.isNotEmpty) {
      _selectedCategory = categories.first;
      _limitController.text = (limits[_selectedCategory!] ?? 500.0).toStringAsFixed(0);
    }

    final double currentLimit = _selectedCategory != null ? (limits[_selectedCategory!] ?? 0.0) : 0.0;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Choose Budgets',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: TallyTapTheme.primaryMint,
                  letterSpacing: -0.5,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: TallyTapTheme.textGray),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Custom Tab Selector using sleek dark aesthetics
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: TallyTapTheme.obsidianCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: TallyTapTheme.borderGreen),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _activeTab = 0),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _activeTab == 0 ? TallyTapTheme.primaryMint : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'GLOBAL BUDGET',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: _activeTab == 0 ? TallyTapTheme.obsidianBg : TallyTapTheme.textGray,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _activeTab = 1),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _activeTab == 1 ? TallyTapTheme.primaryMint : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'CATEGORY LIMITS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: _activeTab == 1 ? TallyTapTheme.obsidianBg : TallyTapTheme.textGray,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_activeTab == 0) ...[
            const Text(
              'BUDGET PERIOD',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: TallyTapTheme.textGray,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text(
                      'Monthly',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                    selected: _globalPeriod == 'monthly',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _globalPeriod = 'monthly';
                        });
                      }
                    },
                    selectedColor: TallyTapTheme.primaryMint,
                    backgroundColor: TallyTapTheme.obsidianCard,
                    checkmarkColor: TallyTapTheme.obsidianBg,
                    labelStyle: TextStyle(
                      color: _globalPeriod == 'monthly' ? TallyTapTheme.obsidianBg : TallyTapTheme.textLight,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: _globalPeriod == 'monthly' ? TallyTapTheme.primaryMint : TallyTapTheme.borderGreen,
                        width: 1.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Text(
                      'Weekly',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                    selected: _globalPeriod == 'weekly',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _globalPeriod = 'weekly';
                        });
                      }
                    },
                    selectedColor: TallyTapTheme.primaryMint,
                    backgroundColor: TallyTapTheme.obsidianCard,
                    checkmarkColor: TallyTapTheme.obsidianBg,
                    labelStyle: TextStyle(
                      color: _globalPeriod == 'weekly' ? TallyTapTheme.obsidianBg : TallyTapTheme.textLight,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: _globalPeriod == 'weekly' ? TallyTapTheme.primaryMint : TallyTapTheme.borderGreen,
                        width: 1.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'BUDGET LIMIT',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: TallyTapTheme.textGray,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _globalLimitController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: TallyTapTheme.textLight, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'Enter overall limit (e.g. 2000)',
                hintStyle: const TextStyle(color: TallyTapTheme.textGray),
                prefixText: '\$ ',
                prefixStyle: const TextStyle(color: TallyTapTheme.primaryMint, fontWeight: FontWeight.bold),
                filled: true,
                fillColor: TallyTapTheme.obsidianCard,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: TallyTapTheme.borderGreen),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: TallyTapTheme.primaryMint, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                final double? limit = double.tryParse(_globalLimitController.text);
                if (limit != null && limit >= 0) {
                  ref.read(globalBudgetProvider.notifier).setGlobalBudget(limit, _globalPeriod);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Global $_globalPeriod budget set to \$${limit.toStringAsFixed(0)}!',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: TallyTapTheme.obsidianBg),
                      ),
                      backgroundColor: TallyTapTheme.primaryMint,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: TallyTapTheme.primaryMint,
                foregroundColor: TallyTapTheme.obsidianBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
              ),
              child: const Text(
                'SAVE GLOBAL BUDGET',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
            ),
          ] else ...[
            const Text(
              'SELECT CATEGORY',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: TallyTapTheme.textGray,
              ),
            ),
            const SizedBox(height: 12),
            if (categories.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'No categories defined. Add some in Settings!',
                  style: TextStyle(color: TallyTapTheme.textGray, fontSize: 13),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? TallyTapTheme.obsidianBg : TallyTapTheme.textLight,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedCategory = cat;
                              _limitController.text = (limits[cat] ?? 500.0).toStringAsFixed(0);
                            });
                          }
                        },
                        selectedColor: TallyTapTheme.primaryMint,
                        backgroundColor: TallyTapTheme.obsidianCard,
                        checkmarkColor: TallyTapTheme.obsidianBg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                          side: BorderSide(
                            color: isSelected ? TallyTapTheme.primaryMint : TallyTapTheme.borderGreen,
                            width: 1.0,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 20),
            Text(
              'BUDGET LIMIT (CURRENT: \$${currentLimit.toStringAsFixed(0)})',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: TallyTapTheme.textGray,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _limitController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: TallyTapTheme.textLight, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'Enter limit (e.g. 500)',
                hintStyle: const TextStyle(color: TallyTapTheme.textGray),
                prefixText: '\$ ',
                prefixStyle: const TextStyle(color: TallyTapTheme.primaryMint, fontWeight: FontWeight.bold),
                filled: true,
                fillColor: TallyTapTheme.obsidianCard,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: TallyTapTheme.borderGreen),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: TallyTapTheme.primaryMint, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                if (_selectedCategory == null) return;
                final double? limit = double.tryParse(_limitController.text);
                if (limit != null && limit >= 0) {
                  ref.read(budgetLimitsProvider.notifier).setLimit(_selectedCategory!, limit);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '$_selectedCategory budget limit updated to \$${limit.toStringAsFixed(0)}!',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: TallyTapTheme.obsidianBg),
                      ),
                      backgroundColor: TallyTapTheme.primaryMint,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: TallyTapTheme.primaryMint,
                foregroundColor: TallyTapTheme.obsidianBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
              ),
              child: const Text(
                'SAVE BUDGET LIMIT',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ManageCategoriesSheet extends ConsumerStatefulWidget {
  const _ManageCategoriesSheet();

  @override
  ConsumerState<_ManageCategoriesSheet> createState() => _ManageCategoriesSheetState();
}

class _ManageCategoriesSheetState extends ConsumerState<_ManageCategoriesSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesListProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Manage Categories',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: TallyTapTheme.primaryMint,
                  letterSpacing: -0.5,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: TallyTapTheme.textGray),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'ACTIVE CATEGORIES (TAP TO DELETE)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: TallyTapTheme.textGray,
            ),
          ),
          const SizedBox(height: 12),
          if (categories.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                'No custom categories active. Add one below!',
                style: TextStyle(color: TallyTapTheme.textGray, fontSize: 13),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: categories.map((cat) {
                    return InputChip(
                      label: Text(
                        cat,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: TallyTapTheme.textLight,
                        ),
                      ),
                      backgroundColor: TallyTapTheme.obsidianCard,
                      selectedColor: TallyTapTheme.primaryMint,
                      checkmarkColor: TallyTapTheme.obsidianBg,
                      deleteIcon: const Icon(
                        Icons.close_rounded,
                        color: TallyTapTheme.primaryMint,
                        size: 14,
                      ),
                      onDeleted: () {
                        ref.read(categoriesListProvider.notifier).deleteCategory(cat);
                        ref.read(budgetLimitsProvider.notifier).loadLimits();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Deleted category: $cat'),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                        side: const BorderSide(color: TallyTapTheme.borderGreen, width: 0.5),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 24),
          const Text(
            'ADD NEW CATEGORY',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: TallyTapTheme.textGray,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: TallyTapTheme.textLight, fontWeight: FontWeight.bold, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Category name (e.g. Health)',
                    hintStyle: const TextStyle(color: TallyTapTheme.textGray, fontSize: 13),
                    filled: true,
                    fillColor: TallyTapTheme.obsidianCard,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: TallyTapTheme.borderGreen),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: TallyTapTheme.primaryMint, width: 1.0),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () {
                  final text = _controller.text.trim();
                  if (text.isNotEmpty) {
                    ref.read(categoriesListProvider.notifier).addCategory(text);
                    ref.read(budgetLimitsProvider.notifier).loadLimits();
                    _controller.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added category: $text'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.add_circle_rounded, color: TallyTapTheme.primaryMint, size: 36),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManageSourcesSheet extends ConsumerStatefulWidget {
  const _ManageSourcesSheet();

  @override
  ConsumerState<_ManageSourcesSheet> createState() => _ManageSourcesSheetState();
}

class _ManageSourcesSheetState extends ConsumerState<_ManageSourcesSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(sourcesListProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Manage Payment Sources',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: TallyTapTheme.primaryMint,
                  letterSpacing: -0.5,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: TallyTapTheme.textGray),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'ACTIVE PAYMENT SOURCES (TAP TO DELETE)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: TallyTapTheme.textGray,
            ),
          ),
          const SizedBox(height: 12),
          if (sources.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                'No custom payment sources active. Add one below!',
                style: TextStyle(color: TallyTapTheme.textGray, fontSize: 13),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: sources.map((src) {
                    return InputChip(
                      label: Text(
                        src,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: TallyTapTheme.textLight,
                        ),
                      ),
                      backgroundColor: TallyTapTheme.obsidianCard,
                      selectedColor: TallyTapTheme.primaryMint,
                      checkmarkColor: TallyTapTheme.obsidianBg,
                      deleteIcon: const Icon(
                        Icons.close_rounded,
                        color: TallyTapTheme.primaryMint,
                        size: 14,
                      ),
                      onDeleted: () {
                        ref.read(sourcesListProvider.notifier).deleteSource(src);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Deleted payment source: $src'),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                        side: const BorderSide(color: TallyTapTheme.borderGreen, width: 0.5),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 24),
          const Text(
            'ADD NEW PAYMENT SOURCE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: TallyTapTheme.textGray,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: TallyTapTheme.textLight, fontWeight: FontWeight.bold, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Source name (e.g. Cash, Credit Card)',
                    hintStyle: const TextStyle(color: TallyTapTheme.textGray, fontSize: 13),
                    filled: true,
                    fillColor: TallyTapTheme.obsidianCard,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: TallyTapTheme.borderGreen),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: TallyTapTheme.primaryMint, width: 1.0),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () {
                  final text = _controller.text.trim();
                  if (text.isNotEmpty) {
                    ref.read(sourcesListProvider.notifier).addSource(text);
                    _controller.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added payment source: $text'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.add_circle_rounded, color: TallyTapTheme.primaryMint, size: 36),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
