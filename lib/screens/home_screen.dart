import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/transaction_model.dart';
import '../providers/app_state_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/category_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/profile_provider.dart';
import '../services/transaction_service.dart';
import 'widgets/donut_chart_painter.dart';
import 'widgets/weekly_trend_painter.dart';

final homeSummaryPeriodProvider = StateProvider<String>((ref) => 'weekly');
final homeBreakdownPeriodProvider = StateProvider<String>((ref) => 'weekly');
final homeSummaryOffsetProvider = StateProvider<int>((ref) => 0);
final homeBreakdownOffsetProvider = StateProvider<int>((ref) => 0);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

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

  bool _isDateInWeek(DateTime date, DateTime referenceDate) {
    final startOfWeek = referenceDate.subtract(Duration(days: referenceDate.weekday - 1));
    final startOfDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    final endOfWeek = startOfDay.add(const Duration(days: 7));
    return date.isAfter(startOfDay.subtract(const Duration(seconds: 1))) && date.isBefore(endOfWeek);
  }

  bool _isDateInMonth(DateTime date, DateTime referenceDate) {
    return date.year == referenceDate.year && date.month == referenceDate.month;
  }

  String _getWeekRangeString(DateTime referenceDate) {
    final startOfWeek = referenceDate.subtract(Duration(days: referenceDate.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    final List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final startMonth = months[startOfWeek.month - 1];
    final endMonth = months[endOfWeek.month - 1];
    if (startOfWeek.year == endOfWeek.year) {
      if (startOfWeek.month == endOfWeek.month) {
        return "$startMonth ${startOfWeek.day} - ${endOfWeek.day}, ${startOfWeek.year}";
      } else {
        return "$startMonth ${startOfWeek.day} - $endMonth ${endOfWeek.day}, ${startOfWeek.year}";
      }
    } else {
      return "$startMonth ${startOfWeek.day}, ${startOfWeek.year} - $endMonth ${endOfWeek.day}, ${endOfWeek.year}";
    }
  }

  String _getMonthString(DateTime referenceDate) {
    final List<String> months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return "${months[referenceDate.month - 1]} ${referenceDate.year}";
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

  Widget _buildLegendRow(String title, double spent, Color color, String currency) {
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
          '$currency${spent.toStringAsFixed(0)}',
          style: const TextStyle(fontSize: 13, color: TallyTapTheme.textLight, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildTransactionItem(ExpenseTransaction tx, String currency) {
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
          '-$currency${tx.amount.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: TallyTapTheme.textLight),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionListProvider);
    final categories = ref.watch(categoriesListProvider);
    final globalBudget = ref.watch(globalBudgetProvider);
    final currency = ref.watch(currencyProvider);
    final username = ref.watch(usernameProvider);
    final summaryPeriod = ref.watch(homeSummaryPeriodProvider);
    final breakdownPeriod = ref.watch(homeBreakdownPeriodProvider);
    final breakdownOffset = ref.watch(homeBreakdownOffsetProvider);
    final now = DateTime.now();

    // 1. Dynamic overall spent (for header greeting only, based on active global budget period)
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

    final summaryOffset = ref.watch(homeSummaryOffsetProvider);
    final DateTime adjustedNow;
    if (summaryPeriod == 'weekly') {
      adjustedNow = now.add(Duration(days: summaryOffset * 7));
    } else {
      adjustedNow = DateTime(now.year, now.month + summaryOffset, 15);
    }

    // 2. Summary Card metrics (Line Graph, based on summaryPeriod & summaryOffset)
    double summaryTotalSpent = 0.0;
    for (var tx in transactions) {
      if (tx.category.toLowerCase() != 'income') {
        if (summaryPeriod == 'weekly') {
          if (_isDateInWeek(tx.date, adjustedNow)) {
            summaryTotalSpent += tx.amount;
          }
        } else {
          if (_isDateInMonth(tx.date, adjustedNow)) {
            summaryTotalSpent += tx.amount;
          }
        }
      }
    }

    double summaryPrevSpent = 0.0;
    final DateTime priorReferenceDate;
    if (summaryPeriod == 'weekly') {
      priorReferenceDate = adjustedNow.subtract(const Duration(days: 7));
      for (var tx in transactions) {
        if (tx.category.toLowerCase() != 'income') {
          if (_isDateInWeek(tx.date, priorReferenceDate)) {
            summaryPrevSpent += tx.amount;
          }
        }
      }
    } else {
      priorReferenceDate = DateTime(adjustedNow.year, adjustedNow.month - 1, 15);
      for (var tx in transactions) {
        if (tx.category.toLowerCase() != 'income') {
          if (_isDateInMonth(tx.date, priorReferenceDate)) {
            summaryPrevSpent += tx.amount;
          }
        }
      }
    }
    
    final bool isOverspending = summaryTotalSpent > summaryPrevSpent;
    
    double percentChange = 0.0;
    if (summaryPrevSpent > 0) {
      percentChange = ((summaryTotalSpent - summaryPrevSpent) / summaryPrevSpent) * 100;
    } else if (summaryTotalSpent > 0) {
      percentChange = 100.0;
    }
    
    final String percentText = (percentChange >= 0 ? '+' : '') + percentChange.toStringAsFixed(0) + '%';

    final List<double> graphValues;
    final List<String> graphLabels;

    if (summaryPeriod == 'weekly') {
      final startOfWeek = adjustedNow.subtract(Duration(days: adjustedNow.weekday - 1));
      final List<double> dailyBalances = List.generate(7, (index) {
        final targetDate = startOfWeek.add(Duration(days: index));
        double balance = 0.0;
        for (var tx in transactions) {
          if (!_isDateInWeek(tx.date, adjustedNow)) continue;
          final txDateOnly = DateTime(tx.date.year, tx.date.month, tx.date.day);
          final targetDateOnly = DateTime(targetDate.year, targetDate.month, targetDate.day);
          if (txDateOnly.isBefore(targetDateOnly) || txDateOnly.isAtSameMomentAs(targetDateOnly)) {
            if (tx.category.toLowerCase() == 'income') {
              balance += tx.amount;
            } else {
              balance -= tx.amount;
            }
          }
        }
        return balance;
      });
      graphValues = [0.0, ...dailyBalances];
      graphLabels = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    } else {
      final totalDays = DateTime(adjustedNow.year, adjustedNow.month + 1, 0).day;
      final List<double> dailyBalances = List.generate(totalDays, (index) {
        final targetDate = DateTime(adjustedNow.year, adjustedNow.month, index + 1);
        double balance = 0.0;
        for (var tx in transactions) {
          if (!_isDateInMonth(tx.date, adjustedNow)) continue;
          final txDateOnly = DateTime(tx.date.year, tx.date.month, tx.date.day);
          final targetDateOnly = DateTime(targetDate.year, targetDate.month, targetDate.day);
          if (txDateOnly.isBefore(targetDateOnly) || txDateOnly.isAtSameMomentAs(targetDateOnly)) {
            if (tx.category.toLowerCase() == 'income') {
              balance += tx.amount;
            } else {
              balance -= tx.amount;
            }
          }
        }
        return balance;
      });
      graphValues = [0.0, ...dailyBalances];
      
      final List<String> dailyLabels = List.generate(totalDays, (index) {
        final day = index + 1;
        if (day == 1 || day == 10 || day == 20 || day == totalDays) {
          return '$day';
        }
        return '';
      });
      graphLabels = ['', ...dailyLabels];
    }

    final dateRangeString = summaryPeriod == 'weekly' 
        ? _getWeekRangeString(adjustedNow) 
        : _getMonthString(adjustedNow);

    final DateTime adjustedBreakdownNow;
    if (breakdownPeriod == 'weekly') {
      adjustedBreakdownNow = now.add(Duration(days: breakdownOffset * 7));
    } else {
      adjustedBreakdownNow = DateTime(now.year, now.month + breakdownOffset, 15);
    }

    final dateRangeBreakdownString = breakdownPeriod == 'weekly' 
        ? _getWeekRangeString(adjustedBreakdownNow) 
        : _getMonthString(adjustedBreakdownNow);

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
        if (breakdownPeriod == 'weekly') {
          if (!_isDateInWeek(tx.date, adjustedBreakdownNow)) continue;
        } else {
          if (!_isDateInMonth(tx.date, adjustedBreakdownNow)) continue;
        }
        final normalizedCat = capitalizeCategory(tx.category);
        catSum[normalizedCat] = (catSum[normalizedCat] ?? 0.0) + tx.amount;
      }
    }

    int catIdx = 0;
    final dynamicCategories = catSum.entries.map((entry) {
      final color = _getColorForCategory(entry.key, catIdx++);
      return DonutChartItem(
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
              const SizedBox(width: 38), // To balance the left wallet icon container and keep TallyTap centered
            ],
          ),
          const SizedBox(height: 24),

          // 2. Main Greeting Text
          Builder(
            builder: (context) {
              final int hour = now.hour;
              String greetingWord = 'Good morning';
              if (hour >= 12 && hour < 17) {
                greetingWord = 'Good afternoon';
              } else if (hour >= 17 && hour < 22) {
                greetingWord = 'Good evening';
              } else if (hour >= 22 || hour < 5) {
                greetingWord = 'Good night';
              }

              return Text(
                '$greetingWord, $username',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: TallyTapTheme.primaryMint,
                  letterSpacing: -0.8,
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 14, color: TallyTapTheme.textGray, height: 1.4),
              children: [
                const TextSpan(text: "You've spent "),
                TextSpan(
                  text: '$currency${totalSpent.toStringAsFixed(0)}',
                  style: const TextStyle(color: TallyTapTheme.primaryMint, fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text: ' recently.\nYou\'re on track to stay within your $currency${globalBudget.amount.toStringAsFixed(0)} ${globalBudget.period} budget.',
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
                  GestureDetector(
                    onHorizontalDragEnd: (details) {
                      if (details.primaryVelocity == null) return;
                      if (details.primaryVelocity! > 0) {
                        ref.read(homeSummaryOffsetProvider.notifier).state--;
                      } else if (details.primaryVelocity! < 0) {
                        if (summaryOffset < 0) {
                          ref.read(homeSummaryOffsetProvider.notifier).state++;
                        }
                      }
                    },
                    child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                summaryPeriod == 'weekly' ? 'WEEKLY SUMMARY' : 'MONTHLY SUMMARY',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                  color: TallyTapTheme.textGray,
                                ),
                              ),
                              _buildMiniPeriodToggle(
                                activePeriod: summaryPeriod,
                                onChanged: (val) {
                                  ref.read(homeSummaryPeriodProvider.notifier).state = val;
                                  ref.read(homeSummaryOffsetProvider.notifier).state = 0; // Reset offset!
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  ref.read(homeSummaryOffsetProvider.notifier).state--;
                                },
                                behavior: HitTestBehavior.opaque,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: TallyTapTheme.obsidianCard,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: TallyTapTheme.borderGreen, width: 0.5),
                                  ),
                                  child: const Icon(
                                    Icons.chevron_left_rounded,
                                    color: TallyTapTheme.primaryMint,
                                    size: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                dateRangeString,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: TallyTapTheme.primaryMint,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: summaryOffset < 0 ? () {
                                  ref.read(homeSummaryOffsetProvider.notifier).state++;
                                } : null,
                                behavior: HitTestBehavior.opaque,
                                child: Opacity(
                                  opacity: summaryOffset < 0 ? 1.0 : 0.4,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: TallyTapTheme.obsidianCard,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: TallyTapTheme.borderGreen, width: 0.5),
                                    ),
                                    child: const Icon(
                                      Icons.chevron_right_rounded,
                                      color: TallyTapTheme.primaryMint,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '$currency${summaryTotalSpent.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")}',
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
                              // Trend pill (dynamic % and color shifts warning red vs saving green)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isOverspending ? const Color(0xFF2C1616) : const Color(0xFF0F2B20),
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(color: isOverspending ? const Color(0xFF4C1D1D) : const Color(0xFF144D37)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isOverspending ? Icons.trending_up : Icons.trending_down, 
                                      color: isOverspending ? const Color(0xFFEF4444) : TallyTapTheme.primaryMint, 
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      percentText,
                                      style: TextStyle(
                                        color: isOverspending ? const Color(0xFFEF4444) : TallyTapTheme.primaryMint,
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
                          WeeklyTrendGraph(values: graphValues, labels: graphLabels, isOverspending: isOverspending),
                        ],
                      ),
                    ),
                  ),),
                  const SizedBox(height: 20),

                  // CARD B: Spending Breakdown
                  GestureDetector(
                    onHorizontalDragEnd: (details) {
                      if (details.primaryVelocity == null) return;
                      if (details.primaryVelocity! > 0) {
                        ref.read(homeBreakdownOffsetProvider.notifier).state--;
                      } else if (details.primaryVelocity! < 0) {
                        if (breakdownOffset < 0) {
                          ref.read(homeBreakdownOffsetProvider.notifier).state++;
                        }
                      }
                    },
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Spending Breakdown',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: TallyTapTheme.textLight,
                                  ),
                                ),
                                _buildMiniPeriodToggle(
                                  activePeriod: breakdownPeriod,
                                  onChanged: (val) {
                                    ref.read(homeBreakdownPeriodProvider.notifier).state = val;
                                    ref.read(homeBreakdownOffsetProvider.notifier).state = 0; // Reset offset!
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    ref.read(homeBreakdownOffsetProvider.notifier).state--;
                                  },
                                  behavior: HitTestBehavior.opaque,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: TallyTapTheme.obsidianCard,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: TallyTapTheme.borderGreen, width: 0.5),
                                    ),
                                    child: const Icon(
                                      Icons.chevron_left_rounded,
                                      color: TallyTapTheme.primaryMint,
                                      size: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  dateRangeBreakdownString,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: TallyTapTheme.primaryMint,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: breakdownOffset < 0 ? () {
                                    ref.read(homeBreakdownOffsetProvider.notifier).state++;
                                  } : null,
                                  behavior: HitTestBehavior.opaque,
                                  child: Opacity(
                                    opacity: breakdownOffset < 0 ? 1.0 : 0.4,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: TallyTapTheme.obsidianCard,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: TallyTapTheme.borderGreen, width: 0.5),
                                      ),
                                      child: const Icon(
                                        Icons.chevron_right_rounded,
                                        color: TallyTapTheme.primaryMint,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 20),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 1. Centered Octagon Donut chart
                              Center(
                                child: DonutChart(categories: dynamicCategories, currency: currency),
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
                                        currency
                                      ),
                                    );
                                  }).toList(),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),),
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
                              return _buildTransactionItem(tx, currency);
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

  Widget _buildMiniPeriodToggle({
    required String activePeriod,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1B17),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TallyTapTheme.borderGreen, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMiniPeriodTab('week', isActive: activePeriod == 'weekly', onTap: () => onChanged('weekly')),
          _buildMiniPeriodTab('month', isActive: activePeriod == 'monthly', onTap: () => onChanged('monthly')),
        ],
      ),
    );
  }

  Widget _buildMiniPeriodTab(String text, {required bool isActive, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? TallyTapTheme.primaryMint : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: isActive ? TallyTapTheme.obsidianBg : TallyTapTheme.textGray,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
