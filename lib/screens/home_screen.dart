import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/theme.dart';
import '../providers/app_state_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/category_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/customization_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/source_provider.dart';
import '../services/transaction_service.dart';
import 'widgets/donut_chart_painter.dart';
import 'widgets/weekly_trend_painter.dart';
import 'widgets/transaction_item.dart';
import 'payment_source_details_screen.dart';
import '../services/tutorial_service.dart';
import 'sheets/recent_transactions_settings_sheet.dart';

final homeSummaryPeriodProvider = StateProvider<String>((ref) => 'weekly');
final homeBreakdownPeriodProvider = StateProvider<String>((ref) => 'weekly');
final homeSummaryOffsetProvider = StateProvider<int>((ref) => 0);
final homeBreakdownOffsetProvider = StateProvider<int>((ref) => 0);
final homeLegendExpandedProvider = StateProvider<bool>((ref) => false);

// Recent Reflections Settings Providers are in app_state_provider.dart

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


  Widget _wrapForEditMode(Widget child, String key, bool isEditMode, WidgetRef ref, int index) {
    if (!isEditMode) {
      return GestureDetector(
        onLongPress: () => ref.read(homeEditModeProvider.notifier).state = true,
        child: child,
      );
    }
    return Container(
      key: ValueKey(key),
      margin: const EdgeInsets.only(bottom: 24.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TallyTapTheme.primaryMint.withValues(alpha: 0.5), width: 2),
      ),
      child: Stack(
        children: [
          ReorderableDelayedDragStartListener(
            index: index,
            child: AbsorbPointer(
              child: Opacity(
                opacity: 0.8,
                child: child,
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: ReorderableDragStartListener(
              index: index,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: TallyTapTheme.obsidianCard,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.drag_handle, color: TallyTapTheme.primaryMint, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(customizationProvider); // Rebuild when source/category colors change
    final transactions = ref.watch(transactionListProvider);
    final categories = ref.watch(categoriesListProvider);
    final globalBudget = ref.watch(globalBudgetProvider);
    final currency = ref.watch(currencyProvider);
    final username = ref.watch(usernameProvider);
    final summaryPeriod = ref.watch(homeSummaryPeriodProvider);
    final breakdownPeriod = ref.watch(homeBreakdownPeriodProvider);
    final breakdownOffset = ref.watch(homeBreakdownOffsetProvider);
    final sources = ref.watch(sourcesListProvider);
    final startingBalances = ref.watch(sourceStartingBalancesProvider);
    final now = DateTime.now();
    final isEditMode = ref.watch(homeEditModeProvider);
    final homeLayout = ref.watch(homeLayoutProvider);

    // Filter and sort for Recent Reflections
    final recentCount = ref.watch(homeRecentCountProvider);
    final recentType = ref.watch(homeRecentTypeProvider);
    final recentSort = ref.watch(homeRecentSortProvider);
    final recentDensity = ref.watch(homeRecentDensityProvider);
    final recentTimeframe = ref.watch(homeRecentTimeframeProvider);

    final filteredRecentTransactions = transactions.where((tx) {
      if (recentType == 'expenses' && tx.category.toLowerCase() == 'income') return false;
      if (recentType == 'income' && tx.category.toLowerCase() != 'income') return false;
      
      if (recentTimeframe != 'all') {
        final txDate = tx.date;
        if (recentTimeframe == 'today') {
           if (txDate.year != now.year || txDate.month != now.month || txDate.day != now.day) return false;
        } else if (recentTimeframe == 'week') {
           final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
           final startOfDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
           if (txDate.isBefore(startOfDay)) return false;
        } else if (recentTimeframe == 'month') {
           if (txDate.year != now.year || txDate.month != now.month) return false;
        }
      }
      return true;
    }).toList();

    if (recentSort == 'highest') {
      filteredRecentTransactions.sort((a, b) => b.amount.compareTo(a.amount));
    } else {
      filteredRecentTransactions.sort((a, b) => b.date.compareTo(a.date));
    }

    // 1. Dynamic overall spent (for header greeting only, based on active global budget period)
    double totalSpent = 0.0;
    for (var tx in transactions) {
      if (tx.category.toLowerCase() != 'income') {
        if (globalBudget.period == 'weekly') {
          if (_isDateInCurrentWeek(tx.date)) {
            totalSpent += tx.amount.abs();
          }
        } else {
          if (_isDateInCurrentMonth(tx.date)) {
            totalSpent += tx.amount.abs();
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
            summaryTotalSpent += tx.amount.abs();
          }
        } else {
          if (_isDateInMonth(tx.date, adjustedNow)) {
            summaryTotalSpent += tx.amount.abs();
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
            summaryPrevSpent += tx.amount.abs();
          }
        }
      }
    } else {
      priorReferenceDate = DateTime(adjustedNow.year, adjustedNow.month - 1, 15);
      for (var tx in transactions) {
        if (tx.category.toLowerCase() != 'income') {
          if (_isDateInMonth(tx.date, priorReferenceDate)) {
            summaryPrevSpent += tx.amount.abs();
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
              balance += tx.amount.abs();
            } else {
              balance -= tx.amount.abs();
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
              balance += tx.amount.abs();
            } else {
              balance -= tx.amount.abs();
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
      final color = TallyTapTheme.getColorForCategory(entry.key, catIdx++);
      return DonutChartItem(
        name: entry.key,
        amount: entry.value,
        color: color,
      );
    }).toList()..sort((a, b) => b.amount.compareTo(a.amount));

    final List<DonutChartItem> chartCategories = [];
    if (dynamicCategories.length <= 5) {
      chartCategories.addAll(dynamicCategories);
    } else {
      chartCategories.addAll(dynamicCategories.take(5));
      final othersSum = dynamicCategories.skip(5).fold(0.0, (sum, item) => sum + item.amount);
      chartCategories.add(DonutChartItem(
        name: 'Others',
        amount: othersSum,
        color: const Color(0xFF6B7280),
      ));
    }

    final widgetAccounts = Column(
      key: TutorialService.homeAccountsKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
                  // Horizontal scrollable payment sources panel
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'ACCOUNTS & BALANCES',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: TallyTapTheme.textGray,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 94,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: sources.length,
                      itemBuilder: (context, index) {
                        final src = sources[index];
                        final srcColor = TallyTapTheme.getColorForSource(src);
                        final srcIcon = TallyTapTheme.getIconForSource(src);

                        // Calculate balance and transaction count
                        final srcTxs = transactions.where((tx) => tx.paymentMethod == src).toList();
                        double inflows = 0.0;
                        double outflows = 0.0;
                        for (final tx in srcTxs) {
                          if (tx.category.toLowerCase() == 'income') {
                            inflows += tx.amount.abs();
                          } else {
                            outflows += tx.amount.abs();
                          }
                        }
                        final double startBal = startingBalances[src] ?? 0.0;
                        final double currentBal = startBal + inflows - outflows;

                        return Container(
                          width: 170,
                          margin: const EdgeInsets.only(right: 14),
                          decoration: BoxDecoration(
                            color: TallyTapTheme.obsidianCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: srcColor.withOpacity(0.3), width: 1.0),
                          ),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PaymentSourceDetailsScreen(sourceName: src),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: srcColor.withOpacity(0.12),
                                    ),
                                    child: Icon(srcIcon, color: srcColor, size: 16),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          src,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: TallyTapTheme.textLight,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text.rich(
                                          TextSpan(
                                            children: [
                                              TextSpan(
                                                text: currentBal >= 0 ? '+ ' : '- ',
                                                style: TextStyle(
                                                  color: currentBal >= 0
                                                      ? const Color(0xFF10B981)
                                                      : const Color(0xFFEF4444),
                                                ),
                                              ),
                                              TextSpan(
                                                text: '$currency${currentBal.abs().toStringAsFixed(0)}',
                                                style: TextStyle(
                                                  color: srcColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${srcTxs.length} txs',
                                          style: const TextStyle(
                                            fontSize: 9,
                                            color: TallyTapTheme.textGray,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24)
      ],
    );

    final widgetSummary = Column(
      key: TutorialService.homeSummaryKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  const SizedBox(height: 20)
      ],
    );

    final widgetBreakdown = Column(
      key: TutorialService.homeCategoryKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                                child: DonutChart(categories: chartCategories, currency: currency),
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
                                  children: [
                                    ...dynamicCategories.take(5).map((cat) {
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 12.0),
                                        child: _buildLegendRow(
                                          cat.name,
                                          cat.amount,
                                          cat.color,
                                          currency
                                        ),
                                      );
                                    }),
                                    if (dynamicCategories.length > 5) ...[
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 12.0),
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () => ref.read(homeLegendExpandedProvider.notifier).state = !ref.read(homeLegendExpandedProvider),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF6B7280)),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  const Text(
                                                    'Others',
                                                    style: TextStyle(fontSize: 13, color: TallyTapTheme.textGray, fontWeight: FontWeight.w500),
                                                  ),
                                                ],
                                              ),
                                              Row(
                                                children: [
                                                  Text(
                                                    '$currency${dynamicCategories.skip(5).fold(0.0, (sum, item) => sum + item.amount).toStringAsFixed(0)}',
                                                    style: const TextStyle(fontSize: 13, color: TallyTapTheme.textLight, fontWeight: FontWeight.bold),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  AnimatedRotation(
                                                    turns: ref.watch(homeLegendExpandedProvider) ? 0.5 : 0.0,
                                                    duration: const Duration(milliseconds: 300),
                                                    child: const Icon(Icons.expand_more, size: 20, color: TallyTapTheme.textGray),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      AnimatedSize(
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                        alignment: Alignment.topCenter,
                                        child: ref.watch(homeLegendExpandedProvider)
                                            ? Column(
                                                children: dynamicCategories.skip(5).map((cat) {
                                                  return Padding(
                                                    padding: const EdgeInsets.only(bottom: 12.0, left: 18.0),
                                                    child: _buildLegendRow(
                                                      cat.name,
                                                      cat.amount,
                                                      cat.color,
                                                      currency
                                                    ),
                                                  );
                                                }).toList(),
                                              )
                                            : const SizedBox.shrink(),
                                      ),
                                    ],
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),),
                  const SizedBox(height: 20)
      ],
    );

    final widgetRecent = Column(
      key: TutorialService.homeRecentTxKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) => const RecentTransactionsSettingsSheet(),
                                  );
                                },
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // List of filtered live transactions
                          filteredRecentTransactions.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.receipt_long_outlined,
                                        size: 40,
                                        color: TallyTapTheme.textGray.withOpacity(0.3),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'No transactions matched',
                                        style: TextStyle(
                                          color: TallyTapTheme.textGray,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: recentCount == -1 
                                      ? filteredRecentTransactions.length 
                                      : (filteredRecentTransactions.length > recentCount ? recentCount : filteredRecentTransactions.length),
                                  separatorBuilder: (_, __) => Divider(
                                    color: TallyTapTheme.borderGreen, 
                                    height: recentDensity == 'compact' ? 12 : 24, 
                                    thickness: 0.5
                                  ),
                                  itemBuilder: (context, index) {
                                    final tx = filteredRecentTransactions[index];
                                    final todayOnly = DateTime(now.year, now.month, now.day);
                                    final txDateOnly = DateTime(tx.date.year, tx.date.month, tx.date.day);
                                    final diffDays = todayOnly.difference(txDateOnly).inDays;

                                    final String formattedDate;
                                    if (diffDays == 0) {
                                      formattedDate = 'Today, ${DateFormat('h:mm a').format(tx.date)}';
                                    } else if (diffDays == 1) {
                                      formattedDate = 'Yesterday, ${DateFormat('h:mm a').format(tx.date)}';
                                    } else if (diffDays < 7) {
                                      formattedDate = '${DateFormat('EEEE').format(tx.date)}, ${DateFormat('h:mm a').format(tx.date)}';
                                    } else {
                                      formattedDate = DateFormat('MMM d, yyyy').format(tx.date);
                                    }

                                    return TransactionItem(
                                      transaction: tx,
                                      currency: currency,
                                      subtitle: '$formattedDate • ${tx.paymentMethod}',
                                      padding: recentDensity == 'compact' ? const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0) : const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                                    );
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
                  )
      ],
    );

    final widgetsMap = {
      'accounts': widgetAccounts,
      'summary': widgetSummary,
      'breakdown': widgetBreakdown,
      'recent': widgetRecent,
    };
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              // Top Header removed

              // 3. Scrollable Dashboard Cards
              Expanded(
                child: isEditMode
                    ? ReorderableListView(
                        buildDefaultDragHandles: false,
                        padding: const EdgeInsets.only(bottom: 120),
                        physics: const BouncingScrollPhysics(),
                        header: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
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
                          ],
                        ),
                        onReorder: (oldIndex, newIndex) {
                          if (oldIndex < newIndex) {
                            newIndex -= 1;
                          }
                          final layout = List<String>.from(homeLayout);
                          final item = layout.removeAt(oldIndex);
                          layout.insert(newIndex, item);
                          ref.read(homeLayoutProvider.notifier).updateLayout(layout);
                        },
                        children: [
                          for (int i = 0; i < homeLayout.length; i++)
                            if (widgetsMap.containsKey(homeLayout[i]))
                              _wrapForEditMode(widgetsMap[homeLayout[i]]!, homeLayout[i], isEditMode, ref, i),
                        ],
                      )
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
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
                            for (int i = 0; i < homeLayout.length; i++)
                              if (widgetsMap.containsKey(homeLayout[i]))
                                _wrapForEditMode(widgetsMap[homeLayout[i]]!, homeLayout[i], isEditMode, ref, i),
                            const SizedBox(height: 120),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
        if (isEditMode)
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton(
                    heroTag: 'resetLayoutBtn',
                    onPressed: () {
                      ref.read(homeLayoutProvider.notifier).resetLayout();
                    },
                    backgroundColor: TallyTapTheme.obsidianCard,
                    foregroundColor: TallyTapTheme.textGray,
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: TallyTapTheme.borderGreen, width: 1.5),
                    ),
                    child: const Icon(Icons.refresh),
                  ),
                  const SizedBox(width: 12),
                  FloatingActionButton.extended(
                    heroTag: 'saveLayoutBtn',
                    onPressed: () {
                      ref.read(homeEditModeProvider.notifier).state = false;
                    },
                    backgroundColor: TallyTapTheme.primaryMint,
                    foregroundColor: TallyTapTheme.obsidianBg,
                    elevation: 8,
                    icon: const Icon(Icons.check),
                    label: const Text('Save Layout', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
      ],
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
