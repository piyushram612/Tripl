import 'package:flutter/material.dart';
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
  int _activeTab = 0; // 0 = Global Budget, 1 = Category Limits

  String? _selectedCategory;
  final TextEditingController _limitController = TextEditingController();

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
    final currency = ref.watch(currencyProvider);

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
                    label: const Text('Monthly', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    selected: _globalPeriod == 'monthly',
                    onSelected: (selected) {
                      if (selected) setState(() => _globalPeriod = 'monthly');
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
                      if (selected) setState(() => _globalPeriod = 'weekly');
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
                prefixText: '\$currency ',
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
                        'Global $_globalPeriod budget set to \$currency\${limit.toStringAsFixed(0)}!',
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
              'BUDGET LIMIT (CURRENT: \$currency\${currentLimit.toStringAsFixed(0)})',
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
                prefixText: '\$currency ',
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
                        '\$_selectedCategory budget limit updated to \$currency\${limit.toStringAsFixed(0)}!',
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
