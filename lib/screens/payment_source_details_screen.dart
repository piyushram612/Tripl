import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../core/theme.dart';
import '../models/transaction_model.dart';
import '../providers/currency_provider.dart';
import '../providers/source_provider.dart';
import '../providers/customization_provider.dart';
import '../services/transaction_service.dart';
import 'widgets/donut_chart_painter.dart';

class PaymentSourceDetailsScreen extends ConsumerStatefulWidget {
  final String sourceName;

  const PaymentSourceDetailsScreen({
    super.key,
    required this.sourceName,
  });

  @override
  ConsumerState<PaymentSourceDetailsScreen> createState() => _PaymentSourceDetailsScreenState();
}

class _PaymentSourceDetailsScreenState extends ConsumerState<PaymentSourceDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _balanceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  void _showColorPicker() {
    final List<Color> colorPalette = [
      TallyTapTheme.primaryMint,
      TallyTapTheme.primaryViolet,
      TallyTapTheme.primarySlate,
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEC4899), // Pink
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFFEF4444), // Red
      const Color(0xFF10B981), // Emerald Green
      const Color(0xFF3B82F6), // Blue
      const Color(0xFFF97316), // Orange
      const Color(0xFF84CC16), // Lime Green
    ];

    // Track the locally-selected color; only applied on Save
    Color selectedColor = TallyTapTheme.getColorForSource(widget.sourceName);

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            backgroundColor: TallyTapTheme.obsidianCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: TallyTapTheme.borderGreen, width: 1.5),
            ),
            title: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: selectedColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Choose Accent Color',
                  style: TextStyle(
                    color: TallyTapTheme.textLight,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 300,
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                itemCount: colorPalette.length,
                itemBuilder: (context, idx) {
                  final color = colorPalette[idx];
                  final isSelected = selectedColor.value == color.value;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      // Only update local state — no provider call yet
                      setDialogState(() => selectedColor = color);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: isSelected
                            ? [BoxShadow(
                                color: color.withValues(alpha: 0.6),
                                blurRadius: 10,
                                spreadRadius: 2,
                              )]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 18,
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: TallyTapTheme.textGray),
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_rounded, size: 16),
                label: const Text('Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedColor,
                  foregroundColor: TallyTapTheme.obsidianBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onPressed: () async {
                  HapticFeedback.mediumImpact();
                  Navigator.pop(dialogContext);
                  // Apply the selection — revision counter bumps, all watchers rebuild
                  await ref.read(customizationProvider.notifier)
                      .updateSourceColor(widget.sourceName, selectedColor);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showBalanceCorrectionDialog(double incomes, double expenses) {
    // Current total = Starting + Incomes - Expenses
    final startingBalances = ref.read(sourceStartingBalancesProvider);
    final currentStarting = startingBalances[widget.sourceName] ?? 0.0;
    final currentTotal = currentStarting + incomes - expenses;

    _balanceController.text = currentTotal.toStringAsFixed(2);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: TallyTapTheme.obsidianCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: TallyTapTheme.borderGreen, width: 1.5),
        ),
        title: const Text(
          'Correct Account Balance',
          style: TextStyle(color: TallyTapTheme.primaryMint, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: _balanceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: TallyTapTheme.textLight, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: 'Enter actual balance...',
            hintStyle: const TextStyle(color: TallyTapTheme.textGray),
            filled: true,
            fillColor: TallyTapTheme.obsidianBg,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: TallyTapTheme.borderGreen),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: TallyTapTheme.primaryMint),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: TallyTapTheme.textGray)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: TallyTapTheme.primaryMint,
              foregroundColor: TallyTapTheme.obsidianBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              final desired = double.tryParse(_balanceController.text) ?? 0.0;
              final newStarting = desired - (incomes - expenses);
              
              await ref.read(sourceStartingBalancesProvider.notifier).setStartingBalance(widget.sourceName, newStarting);
              
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Account balance corrected successfully!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showMergeDialog() async {
    final sources = ref.read(sourcesListProvider);
    final otherSources = sources.where((s) => s != widget.sourceName).toList();

    if (otherSources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No other payment sources available to merge into.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    String selectedTarget = otherSources.first;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: TallyTapTheme.obsidianCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: TallyTapTheme.borderGreen, width: 1.5),
          ),
          title: Text(
            'Merge "${widget.sourceName}"',
            style: const TextStyle(color: TallyTapTheme.primaryMint, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'This will move all transactions from this account into the selected target account, merge their balances, and delete this account.',
                style: TextStyle(color: TallyTapTheme.textLight, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              const Text(
                'TARGET ACCOUNT',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: TallyTapTheme.textGray, letterSpacing: 1.0),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: TallyTapTheme.obsidianBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: TallyTapTheme.borderGreen),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedTarget,
                    dropdownColor: TallyTapTheme.obsidianCard,
                    isExpanded: true,
                    style: const TextStyle(color: TallyTapTheme.textLight, fontWeight: FontWeight.bold),
                    items: otherSources.map((s) {
                      return DropdownMenuItem<String>(
                        value: s,
                        child: Text(s),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedTarget = val;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: TallyTapTheme.textGray)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Merge & Delete'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    final listNotifier = ref.read(transactionListProvider.notifier);
    final transactions = ref.read(transactionListProvider);

    // 1. Move all transactions
    final sourceTxs = transactions.where((tx) => tx.paymentMethod == widget.sourceName).toList();
    for (final tx in sourceTxs) {
      final updatedTx = ExpenseTransaction(
        id: tx.id,
        amount: tx.amount,
        merchant: tx.merchant,
        date: tx.date,
        paymentMethod: selectedTarget,
        category: tx.category,
        notes: tx.notes,
        paidTo: tx.paidTo,
        needsVerification: tx.needsVerification,
        reminderDate: tx.reminderDate,
        groupId: tx.groupId,
      );
      await listNotifier.updateTransaction(updatedTx);
    }

    // 2. Merge Starting Balances
    final startingBalances = ref.read(sourceStartingBalancesProvider);
    final myStarting = startingBalances[widget.sourceName] ?? 0.0;
    final targetStarting = startingBalances[selectedTarget] ?? 0.0;

    await ref.read(sourceStartingBalancesProvider.notifier).setStartingBalance(selectedTarget, targetStarting + myStarting);
    await ref.read(sourceStartingBalancesProvider.notifier).setStartingBalance(widget.sourceName, 0.0);

    // 3. Delete this source
    await ref.read(sourcesListProvider.notifier).deleteSource(widget.sourceName);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Merged into "$selectedTarget" and deleted "${widget.sourceName}".'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context); // Go back to Home
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(customizationProvider); // Rebuild when source/category colors change
    final transactions = ref.watch(transactionListProvider);
    final currency = ref.watch(currencyProvider);
    final startingBalances = ref.watch(sourceStartingBalancesProvider);
    
    final activeColor = TallyTapTheme.getColorForSource(widget.sourceName);



    // Filter transactions belonging strictly to this source
    final sourceTxs = transactions.where((tx) => tx.paymentMethod == widget.sourceName).toList();

    // Sort chronologically (oldest first) for cumulative graph calculations
    final sortedChronological = List<ExpenseTransaction>.from(sourceTxs)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Calculate Incomes, Expenses, and Balances
    double totalIncome = 0.0;
    double totalExpense = 0.0;

    for (final tx in sourceTxs) {
      final isInc = tx.category.toLowerCase() == 'income';
      if (isInc) {
        totalIncome += tx.amount.abs();
      } else {
        totalExpense += tx.amount.abs();
      }
    }

    final double starting = startingBalances[widget.sourceName] ?? 0.0;
    final double netCalculated = starting + totalIncome - totalExpense;

    // Load and compute Billing Cycle configuration and parameters
    final billingConfigs = ref.watch(sourceBillingCyclesProvider);
    final config = billingConfigs[widget.sourceName] ?? SourceBillingCycleConfig(statementDay: 1, dueDay: 20, isEnabled: false);

    DateTime? statementStart;
    DateTime? statementEnd;
    DateTime? previousStatementStart;
    DateTime? previousStatementEnd;
    DateTime? dueDate;
    int daysRemaining = 0;
    double currentCycleSpent = 0.0;
    double lastStatementSpent = 0.0;

    if (config.isEnabled) {
      final today = DateTime.now();
      if (today.day >= config.statementDay) {
        statementStart = DateTime(today.year, today.month, config.statementDay);
        statementEnd = DateTime(today.year, today.month + 1, config.statementDay - 1);

        previousStatementStart = DateTime(today.year, today.month - 1, config.statementDay);
        previousStatementEnd = DateTime(today.year, today.month, config.statementDay - 1);
      } else {
        statementStart = DateTime(today.year, today.month - 1, config.statementDay);
        statementEnd = DateTime(today.year, today.month, config.statementDay - 1);

        previousStatementStart = DateTime(today.year, today.month - 2, config.statementDay);
        previousStatementEnd = DateTime(today.year, today.month - 1, config.statementDay - 1);
      }

      dueDate = DateTime(previousStatementEnd.year, previousStatementEnd.month + 1, config.dueDay);
      daysRemaining = dueDate.difference(DateTime(today.year, today.month, today.day)).inDays;

      for (final tx in sourceTxs) {
        if (tx.category.toLowerCase() != 'income') {
          // Check if transaction falls inside current billing cycle
          if (tx.date.isAfter(statementStart.subtract(const Duration(seconds: 1))) &&
              tx.date.isBefore(statementEnd.add(const Duration(days: 1)))) {
            currentCycleSpent += tx.amount.abs();
          }
          // Check if transaction falls inside previous billing cycle
          if (tx.date.isAfter(previousStatementStart.subtract(const Duration(seconds: 1))) &&
              tx.date.isBefore(previousStatementEnd.add(const Duration(days: 1)))) {
            lastStatementSpent += tx.amount.abs();
          }
        }
      }
    }

    final String currentCycleStr = statementStart != null && statementEnd != null
        ? '${DateFormat('MMM d').format(statementStart)} - ${DateFormat('MMM d').format(statementEnd)}'
        : '';
    final String dueDateStr = dueDate != null
        ? DateFormat('MMMM d, y').format(dueDate)
        : '';

    // Build timeline details for all-time line graph
    final List<double> graphValues = [];
    final List<String> graphLabels = [];

    double runningBalance = starting;
    graphValues.add(runningBalance);
    graphLabels.add('Start');

    for (int i = 0; i < sortedChronological.length; i++) {
      final tx = sortedChronological[i];
      final isInc = tx.category.toLowerCase() == 'income';
      runningBalance += isInc ? tx.amount : -tx.amount;
      graphValues.add(runningBalance);

      // Label showing date for start/middle/end points
      if (i == 0 || i == sortedChronological.length ~/ 2 || i == sortedChronological.length - 1) {
        graphLabels.add('${tx.date.day}/${tx.date.month}');
      } else {
        graphLabels.add('');
      }
    }

    if (graphValues.length == 1) {
      graphValues.add(runningBalance);
      graphLabels.add('Now');
    }

    // Donut chart items strictly for this payment source
    final Map<String, double> expenseSum = {};
    final Map<String, double> incomeSum = {};

    for (final tx in sourceTxs) {
      final isInc = tx.category.toLowerCase() == 'income';
      if (isInc) {
        incomeSum[tx.category] = (incomeSum[tx.category] ?? 0.0) + tx.amount;
      } else {
        expenseSum[tx.category] = (expenseSum[tx.category] ?? 0.0) + tx.amount;
      }
    }

    int expIdx = 0;
    final List<DonutChartItem> expenseCategories = expenseSum.entries.map((e) {
      return DonutChartItem(name: e.key, amount: e.value, color: TallyTapTheme.getColorForCategory(e.key, expIdx++));
    }).toList()..sort((a, b) => b.amount.compareTo(a.amount));

    int incIdx = 0;
    final List<DonutChartItem> incomeCategories = incomeSum.entries.map((e) {
      return DonutChartItem(name: e.key, amount: e.value, color: TallyTapTheme.getColorForCategory(e.key, incIdx++));
    }).toList()..sort((a, b) => b.amount.compareTo(a.amount));

    return Scaffold(
      backgroundColor: TallyTapTheme.obsidianBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: TallyTapTheme.textLight),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.sourceName,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: TallyTapTheme.textLight,
            fontFamily: 'Outfit',
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.color_lens_rounded, color: activeColor),
            onPressed: _showColorPicker,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Balance & Adjustments Panel
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              activeColor.withOpacity(0.12),
                              activeColor.withOpacity(0.02),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: activeColor.withOpacity(0.4), width: 1.5),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'CURRENT BALANCE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: TallyTapTheme.textGray,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  netCalculated >= 0 ? '+ ' : '- ',
                                  style: TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w900,
                                    color: netCalculated >= 0
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFEF4444),
                                    height: 1.0,
                                  ),
                                ),
                                Text(
                                  currency,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: activeColor,
                                    height: 1.2,
                                  ),
                                ),
                                Text(
                                  netCalculated.abs().toStringAsFixed(2),
                                  style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w900,
                                    color: TallyTapTheme.textLight,
                                    height: 1.0,
                                    letterSpacing: -1.0,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            const Divider(color: TallyTapTheme.borderGreen, height: 1),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    const Text('Total Inflows', style: TextStyle(fontSize: 10, color: TallyTapTheme.textGray)),
                                    const SizedBox(height: 4),
                                    Text(
                                      '+ $currency${totalIncome.toStringAsFixed(0)}',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
                                    ),
                                  ],
                                ),
                                Column(
                                  children: [
                                    const Text('Total Outflows', style: TextStyle(fontSize: 10, color: TallyTapTheme.textGray)),
                                    const SizedBox(height: 4),
                                    Text(
                                      '- $currency${totalExpense.toStringAsFixed(0)}',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Billing Cycle Info Card
                      config.isEnabled
                          ? _buildBillingCycleCard(context, config, currentCycleSpent, lastStatementSpent, currentCycleStr, dueDateStr, daysRemaining)
                          : _buildBillingCycleDisabledCard(context, config),

                      const SizedBox(height: 20),

                      // Correct Balance & Merge CTAs Row
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showBalanceCorrectionDialog(totalIncome, totalExpense),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: activeColor.withOpacity(0.5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: Icon(Icons.edit_rounded, color: activeColor, size: 16),
                              label: Text(
                                'Correct Balance',
                                style: TextStyle(color: activeColor, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _showMergeDialog,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: TallyTapTheme.borderGreen),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.merge_type_rounded, color: Colors.redAccent, size: 16),
                              label: const Text(
                                'Merge Account',
                                style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // All-time balance graph
                      const Text(
                        'ALL TIME BALANCE CURVE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: TallyTapTheme.textGray,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        height: 200,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: TallyTapTheme.obsidianCard,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: TallyTapTheme.borderGreen),
                        ),
                        child: CustomPaint(
                          painter: AllTimeBalancePainter(
                            values: graphValues,
                            labels: graphLabels,
                            lineColor: activeColor,
                          ),
                          child: Container(),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Tabs selector (Expense vs Income breakdowns)
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F1B17),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: TallyTapTheme.borderGreen),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                          indicator: BoxDecoration(
                            color: activeColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          labelColor: TallyTapTheme.obsidianBg,
                          unselectedLabelColor: TallyTapTheme.textGray,
                          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          tabs: const [
                            Tab(text: 'EXPENSES'),
                            Tab(text: 'INCOMES'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Tab View contents
                      SizedBox(
                        height: 360,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildDonutTab(expenseCategories, currency, 'No expenses tracked.'),
                            _buildDonutTab(incomeCategories, currency, 'No income tracked.'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonutTab(List<DonutChartItem> categories, String currency, String emptyText) {
    if (categories.isEmpty) {
      return Center(
        child: Text(
          emptyText,
          style: const TextStyle(color: TallyTapTheme.textGray, fontSize: 13),
        ),
      );
    }

    return Column(
      children: [
        Center(child: DonutChart(categories: categories, currency: currency)),
        const SizedBox(height: 20),
        Expanded(
          child: ListView.builder(
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: cat.color),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          cat.name,
                          style: const TextStyle(fontSize: 13, color: TallyTapTheme.textGray, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    Text(
                      '$currency${cat.amount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 13, color: TallyTapTheme.textLight, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBillingCycleCard(
      BuildContext context,
      SourceBillingCycleConfig config,
      double currentCycleSpent,
      double lastStatementSpent,
      String currentCycleStr,
      String dueDateStr,
      int daysRemaining) {
    final activeColor = TallyTapTheme.getColorForSource(widget.sourceName);
    final currency = ref.read(currencyProvider);
    return Card(
      color: TallyTapTheme.obsidianCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: activeColor.withOpacity(0.2), width: 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.credit_card_rounded, color: activeColor, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Billing Cycle Details',
                      style: TextStyle(
                        color: TallyTapTheme.textLight,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.settings_rounded, color: TallyTapTheme.textGray, size: 16),
                  onPressed: () => _showBillingCycleConfigDialog(config),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current Cycle Spent', style: TextStyle(color: TallyTapTheme.textGray, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(
                      '$currentCycleStr',
                      style: const TextStyle(color: TallyTapTheme.textLight, fontSize: 10, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Text(
                  '- $currency${currentCycleSpent.toStringAsFixed(2)}',
                  style: const TextStyle(color: TallyTapTheme.textLight, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(color: TallyTapTheme.borderGreen, height: 20, thickness: 0.5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Last Statement Balance', style: TextStyle(color: TallyTapTheme.textGray, fontSize: 11)),
                Text(
                  '- $currency${lastStatementSpent.toStringAsFixed(2)}',
                  style: const TextStyle(color: TallyTapTheme.textLight, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: daysRemaining < 0
                    ? const Color(0xFF3B1616)
                    : daysRemaining <= 5
                        ? const Color(0xFF33200D)
                        : const Color(0xFF0F1B17),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: daysRemaining < 0
                      ? Colors.redAccent.withOpacity(0.3)
                      : daysRemaining <= 5
                          ? Colors.amber.withOpacity(0.3)
                          : TallyTapTheme.borderGreen,
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Payment Due Date', style: TextStyle(color: TallyTapTheme.textGray, fontSize: 10)),
                      const SizedBox(height: 4),
                      Text(
                        '$dueDateStr',
                        style: const TextStyle(color: TallyTapTheme.textLight, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: daysRemaining < 0
                          ? Colors.redAccent.withOpacity(0.2)
                          : daysRemaining <= 5
                              ? Colors.amber.withOpacity(0.2)
                              : TallyTapTheme.primaryMint.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      daysRemaining < 0
                          ? 'Overdue'
                          : daysRemaining == 0
                              ? 'Due Today'
                              : daysRemaining == 1
                                  ? 'Due Tomorrow'
                                  : 'Due in $daysRemaining days',
                      style: TextStyle(
                        color: daysRemaining < 0
                            ? Colors.redAccent
                            : daysRemaining <= 5
                                ? Colors.amber
                                : TallyTapTheme.primaryMint,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillingCycleDisabledCard(BuildContext context, SourceBillingCycleConfig config) {
    final activeColor = TallyTapTheme.getColorForSource(widget.sourceName);
    return Card(
      color: TallyTapTheme.obsidianCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: TallyTapTheme.borderGreen.withOpacity(0.5), width: 1.0),
      ),
      child: InkWell(
        onTap: () => _showBillingCycleConfigDialog(config),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: activeColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.credit_card_rounded, color: activeColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Setup Billing Cycle',
                      style: TextStyle(
                        color: TallyTapTheme.textLight,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Track statement period spend, payment due dates, and alerts (ideal for Credit Cards).',
                      style: TextStyle(
                        color: TallyTapTheme.textGray.withOpacity(0.7),
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded, color: TallyTapTheme.textGray.withOpacity(0.5), size: 14),
            ],
          ),
        ),
      ),
    );
  }

  void _showBillingCycleConfigDialog(SourceBillingCycleConfig config) {
    int statementDay = config.statementDay;
    int dueDay = config.dueDay;
    bool isEnabled = config.isEnabled;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: TallyTapTheme.obsidianBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.credit_card_rounded, color: TallyTapTheme.primaryMint, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Billing Cycle Settings',
                    style: TextStyle(color: TallyTapTheme.textLight, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Enable Billing Cycle',
                          style: TextStyle(color: TallyTapTheme.textLight, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        Switch(
                          value: isEnabled,
                          activeColor: TallyTapTheme.primaryMint,
                          activeTrackColor: TallyTapTheme.primaryMint.withOpacity(0.3),
                          onChanged: (val) {
                            setDialogState(() {
                              isEnabled = val;
                            });
                          },
                        ),
                      ],
                    ),
                    if (isEnabled) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Statement Closing Day of Month',
                        style: TextStyle(color: TallyTapTheme.textGray, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: statementDay.toDouble(),
                              min: 1,
                              max: 28,
                              divisions: 27,
                              activeColor: TallyTapTheme.primaryMint,
                              onChanged: (val) {
                                setDialogState(() {
                                  statementDay = val.round();
                                });
                              },
                            ),
                          ),
                          Text(
                            '$statementDay',
                            style: const TextStyle(color: TallyTapTheme.textLight, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Payment Due Day of Month',
                        style: TextStyle(color: TallyTapTheme.textGray, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: dueDay.toDouble(),
                              min: 1,
                              max: 28,
                              divisions: 27,
                              activeColor: TallyTapTheme.primaryMint,
                              onChanged: (val) {
                                setDialogState(() {
                                  dueDay = val.round();
                                });
                              },
                            ),
                          ),
                          Text(
                            '$dueDay',
                            style: const TextStyle(color: TallyTapTheme.textLight, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Note: Days are capped at 28 to support all calendar months seamlessly.',
                        style: TextStyle(color: TallyTapTheme.textGray, fontSize: 10, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel', style: TextStyle(color: TallyTapTheme.textGray)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(dialogCtx);
                    final newConfig = SourceBillingCycleConfig(
                      statementDay: statementDay,
                      dueDay: dueDay,
                      isEnabled: isEnabled,
                    );
                    await ref.read(sourceBillingCyclesProvider.notifier).setConfig(widget.sourceName, newConfig);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isEnabled
                              ? 'Billing cycle configured successfully!'
                              : 'Billing cycle disabled.'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: TallyTapTheme.primaryMint,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TallyTapTheme.primaryMint,
                    foregroundColor: TallyTapTheme.obsidianBg,
                  ),
                  child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class AllTimeBalancePainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color lineColor;

  AllTimeBalancePainter({
    required this.values,
    required this.labels,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final paintLine = Paint()
      ..color = lineColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintShadow = Paint()
      ..style = PaintingStyle.fill;

    double maxVal = values.reduce((a, b) => a > b ? a : b);
    double minVal = values.reduce((a, b) => a < b ? a : b);

    // Padding so curve doesn't hit edge
    final double paddingY = 24.0;
    final double paddingX = 16.0;

    final double usableHeight = size.height - (paddingY * 2);
    final double usableWidth = size.width - (paddingX * 2);

    final double range = maxVal - minVal;
    final double divisor = range == 0 ? 1.0 : range;

    final List<Offset> points = [];
    final double stepX = usableWidth / (values.length - 1);

    for (int i = 0; i < values.length; i++) {
      final double x = paddingX + (i * stepX);
      final double normalizedY = (values[i] - minVal) / divisor;
      final double y = size.height - paddingY - (normalizedY * usableHeight);
      points.add(Offset(x, y));
    }

    // Draw grid bounds guide line
    final boundsPaint = Paint()
      ..color = TallyTapTheme.borderGreen
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(paddingX, paddingY), Offset(paddingX + usableWidth, paddingY), boundsPaint);
    canvas.drawLine(Offset(paddingX, size.height - paddingY), Offset(paddingX + usableWidth, size.height - paddingY), boundsPaint);

    // Build curve
    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlPointX = p0.dx + (p1.dx - p0.dx) / 2;
      path.cubicTo(controlPointX, p0.dy, controlPointX, p1.dy, p1.dx, p1.dy);
    }

    // Draw filled area gradient
    final fillPath = Path.from(path);
    fillPath.lineTo(points.last.dx, size.height - paddingY);
    fillPath.lineTo(points.first.dx, size.height - paddingY);
    fillPath.close();

    paintShadow.shader = LinearGradient(
      colors: [lineColor.withOpacity(0.18), lineColor.withOpacity(0.0)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTRB(paddingX, paddingY, paddingX + usableWidth, size.height - paddingY));

    canvas.drawPath(fillPath, paintShadow);
    canvas.drawPath(path, paintLine);

    // Labels drawing
    const textStyle = TextStyle(color: TallyTapTheme.textGray, fontSize: 10, fontWeight: FontWeight.bold);
    
    // Draw min / max values
    final maxTp = TextPainter(
      text: TextSpan(text: maxVal.toStringAsFixed(0), style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    maxTp.paint(canvas, Offset(paddingX, paddingY - 14));

    final minTp = TextPainter(
      text: TextSpan(text: minVal.toStringAsFixed(0), style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    minTp.paint(canvas, Offset(paddingX, size.height - paddingY - 22));

    // Draw chronological label markers
    for (int i = 0; i < labels.length; i++) {
      if (labels[i].isEmpty) continue;
      final labelOffset = points[i];
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(labelOffset.dx - (tp.width / 2), size.height - 8));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
