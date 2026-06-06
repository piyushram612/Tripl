import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/budget_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/currency_provider.dart';

class ManageBudgetsSheet extends ConsumerStatefulWidget {
  const ManageBudgetsSheet({super.key});

  @override
  ConsumerState<ManageBudgetsSheet> createState() => _ManageBudgetsSheetState();
}

class _ManageBudgetsSheetState extends ConsumerState<ManageBudgetsSheet> {
  final TextEditingController _globalLimitController = TextEditingController();
  final Map<String, TextEditingController> _categoryControllers = {};
  String _globalPeriod = 'monthly';

  String? _activeDragCategory;
  Offset _dragStartPos = Offset.zero;
  double _dragStartValue = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final categories = ref.read(categoriesListProvider);
      final limits = ref.read(budgetLimitsProvider);
      
      for (final cat in categories) {
        _categoryControllers[cat] = TextEditingController(
          text: (limits[cat] ?? 500.0).toStringAsFixed(0),
        );
      }
      
      final globalBudget = ref.read(globalBudgetProvider);
      setState(() {
        _globalPeriod = globalBudget.period;
        if (_globalPeriod == 'monthly') {
          _globalLimitController.text = globalBudget.monthlyAmount.toStringAsFixed(0);
        } else {
          _globalLimitController.text = globalBudget.weeklyAmount.toStringAsFixed(0);
        }
      });
    });
  }

  @override
  void dispose() {
    _globalLimitController.dispose();
    for (final ctrl in _categoryControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  IconData _getIconForCategory(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('din') || lower.contains('food')) return Icons.local_dining_rounded;
    if (lower.contains('commute') || lower.contains('trans')) return Icons.directions_transit_rounded;
    if (lower.contains('sub')) return Icons.subscriptions_rounded;
    if (lower.contains('util')) return Icons.bolt_rounded;
    if (lower.contains('groc')) return Icons.shopping_basket_rounded;
    if (lower.contains('shop')) return Icons.shopping_bag_rounded;
    if (lower.contains('health')) return Icons.favorite_rounded;
    if (lower.contains('house') || lower.contains('home')) return Icons.home_rounded;
    if (lower.contains('travel')) return Icons.flight_rounded;
    return Icons.category_rounded;
  }

  void _onPeriodSelected(String period) {
    final globalBudget = ref.read(globalBudgetProvider);
    setState(() {
      _globalPeriod = period;
      if (period == 'monthly') {
        _globalLimitController.text = globalBudget.monthlyAmount.toStringAsFixed(0);
      } else {
        _globalLimitController.text = globalBudget.weeklyAmount.toStringAsFixed(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesListProvider);
    final currency = ref.watch(currencyProvider);
    final excludedCategories = ref.watch(excludedCategoriesProvider);

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
                'Adjust Budgets',
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
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                          label: const Text('Monthly', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                          selected: _globalPeriod == 'monthly',
                          onSelected: (selected) {
                            if (selected) _onPeriodSelected('monthly');
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
                          label: const Text('Weekly', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                          selected: _globalPeriod == 'weekly',
                          onSelected: (selected) {
                            if (selected) _onPeriodSelected('weekly');
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
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Enter overall limit (e.g. 2000)',
                      hintStyle: const TextStyle(color: TallyTapTheme.textGray),
                      prefixText: '$currency ',
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'CATEGORY BUDGETS (OPTIONAL)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: TallyTapTheme.textGray,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.clear_all_rounded, size: 14, color: TallyTapTheme.primaryMint),
                        label: const Text(
                          'SET ALL TO ZERO',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: TallyTapTheme.primaryMint,
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          setState(() {
                            for (final ctrl in _categoryControllers.values) {
                              ctrl.text = '0';
                            }
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Optionally assign budgets to individual categories below. Leave blank to skip.',
                    style: TextStyle(
                      fontSize: 12,
                      color: TallyTapTheme.textGray,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Live Allocation Tracker inside Wizard
                  Consumer(
                    builder: (context, ref, child) {
                      final excludedCategories = ref.watch(excludedCategoriesProvider);
                      double totalAllocated = 0.0;
                      for (final entry in _categoryControllers.entries) {
                        final cat = entry.key;
                        final ctrl = entry.value;
                        if (!excludedCategories.contains(cat)) {
                          totalAllocated += double.tryParse(ctrl.text) ?? 0.0;
                        }
                      }
                      final double globalLimit = double.tryParse(_globalLimitController.text) ?? 0.0;
                      final bool isOverallocated = totalAllocated > globalLimit;
                      final double delta = (totalAllocated - globalLimit).abs();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isOverallocated ? const Color(0xFF2C1616) : const Color(0xFF0F2B20),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isOverallocated ? const Color(0xFFEF4444) : TallyTapTheme.primaryMint,
                            width: 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isOverallocated ? '⚠️ OVERALLOCATED' : 'ALLOCATION TRACKER',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                    color: isOverallocated ? const Color(0xFFEF4444) : TallyTapTheme.primaryMint,
                                  ),
                                ),
                                Text(
                                  '$currency${totalAllocated.toStringAsFixed(0)} / $currency${globalLimit.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: isOverallocated ? const Color(0xFFEF4444) : TallyTapTheme.primaryMint,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isOverallocated
                                  ? 'Your category budgets exceed your global limit by $currency${delta.toStringAsFixed(0)}. Consider reducing them.'
                                  : 'You have $currency${(globalLimit - totalAllocated).toStringAsFixed(0)} remaining to distribute across categories.',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: TallyTapTheme.textLight,
                                ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  if (categories.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'No categories defined. Add some in Settings!',
                        style: TextStyle(color: TallyTapTheme.textGray, fontSize: 13),
                      ),
                    )
                  else
                    ...categories.map((cat) {
                      final ctrl = _categoryControllers[cat] ??= TextEditingController();
                      final isDragging = _activeDragCategory == cat;
                      final isExcluded = excludedCategories.contains(cat);
                      
                      return GestureDetector(
                        onLongPressStart: isExcluded ? null : (details) {
                          HapticFeedback.heavyImpact();
                          setState(() {
                            _activeDragCategory = cat;
                            _dragStartPos = details.globalPosition;
                            _dragStartValue = double.tryParse(ctrl.text) ?? 0.0;
                          });
                        },
                        onLongPressMoveUpdate: isExcluded ? null : (details) {
                          final double deltaX = details.globalPosition.dx - _dragStartPos.dx;
                          double val = _dragStartValue + (deltaX * 5.0);
                          val = val.clamp(0.0, double.infinity);
                          
                          final oldValStr = ctrl.text;
                          final newValStr = val.toStringAsFixed(0);
                          if (oldValStr != newValStr) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              ctrl.text = newValStr;
                            });
                          }
                        },
                        onLongPressEnd: isExcluded ? null : (details) {
                          HapticFeedback.mediumImpact();
                          setState(() {
                            _activeDragCategory = null;
                          });
                        },
                        child: Transform.scale(
                          scale: isDragging ? 1.04 : 1.0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            curve: Curves.easeInOut,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            margin: const EdgeInsets.only(bottom: 12.0),
                            decoration: BoxDecoration(
                              color: isDragging ? const Color(0xFF132A22) : TallyTapTheme.obsidianCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDragging ? TallyTapTheme.primaryMint : TallyTapTheme.borderGreen,
                                width: isDragging ? 1.5 : 1.0,
                              ),
                              boxShadow: isDragging
                                  ? [
                                      BoxShadow(
                                        color: TallyTapTheme.primaryMint.withOpacity(0.15),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: !isExcluded,
                                  activeColor: TallyTapTheme.primaryMint,
                                  checkColor: TallyTapTheme.obsidianBg,
                                  onChanged: (val) {
                                    HapticFeedback.selectionClick();
                                    ref.read(excludedCategoriesProvider.notifier).toggleExclusion(cat);
                                    ref.read(budgetLimitsProvider.notifier).loadLimits();
                                  },
                                ),
                                const SizedBox(width: 4),
                                Opacity(
                                  opacity: isExcluded ? 0.4 : 1.0,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F1B17),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: TallyTapTheme.borderGreen, width: 0.5),
                                    ),
                                    child: Icon(
                                      _getIconForCategory(cat),
                                      color: TallyTapTheme.primaryMint,
                                      size: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Opacity(
                                    opacity: isExcluded ? 0.4 : 1.0,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          cat,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: TallyTapTheme.textLight,
                                          ),
                                        ),
                                        if (isDragging && !isExcluded) ...[
                                          const SizedBox(height: 2),
                                          const Text(
                                            '← Drag left/right to adjust →',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: TallyTapTheme.primaryMint,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 100,
                                  height: 42,
                                  child: Opacity(
                                    opacity: isExcluded ? 0.4 : 1.0,
                                    child: TextField(
                                      controller: ctrl,
                                      enabled: !isExcluded,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(
                                        color: TallyTapTheme.textLight,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      onChanged: (_) => setState(() {}),
                                      decoration: InputDecoration(
                                        hintText: 'e.g. 500',
                                        hintStyle: const TextStyle(color: TallyTapTheme.textGray, fontSize: 12),
                                        prefixText: currency,
                                        prefixStyle: const TextStyle(
                                          color: TallyTapTheme.primaryMint,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        filled: true,
                                        fillColor: TallyTapTheme.obsidianCard,
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: TallyTapTheme.borderGreen),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: TallyTapTheme.primaryMint, width: 1.2),
                                        ),
                                        disabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: TallyTapTheme.borderGreen, width: 0.5),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    final double? limit = double.tryParse(_globalLimitController.text);
                    if (limit != null && limit >= 0) {
                      ref.read(globalBudgetProvider.notifier).setGlobalBudget(limit, _globalPeriod);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Global $_globalPeriod budget set to $currency${limit.toStringAsFixed(0)}! Categories skipped.',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: TallyTapTheme.obsidianBg),
                          ),
                          backgroundColor: TallyTapTheme.primaryMint,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: TallyTapTheme.borderGreen),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'SKIP & SAVE',
                    style: TextStyle(
                      color: TallyTapTheme.primaryMint,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final double? limit = double.tryParse(_globalLimitController.text);
                    if (limit != null && limit >= 0) {
                      // 1. Save global budget
                      ref.read(globalBudgetProvider.notifier).setGlobalBudget(limit, _globalPeriod);
                      
                      // 2. Save entered category budgets
                      final Map<String, double> categoryBudgetsToSave = {};
                      for (final cat in categories) {
                        final ctrl = _categoryControllers[cat];
                        if (ctrl != null && ctrl.text.isNotEmpty) {
                          final double? catLimit = double.tryParse(ctrl.text);
                          if (catLimit != null && catLimit >= 0) {
                            categoryBudgetsToSave[cat] = catLimit;
                          }
                        }
                      }
                      
                      if (categoryBudgetsToSave.isNotEmpty) {
                        ref.read(budgetLimitsProvider.notifier).setMultipleLimits(categoryBudgetsToSave);
                      }
                      
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Global $_globalPeriod budget and category budgets saved!',
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
                    'SAVE ALL',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
