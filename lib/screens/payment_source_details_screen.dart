import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: TallyTapTheme.obsidianCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: TallyTapTheme.borderGreen, width: 1.5),
        ),
        title: const Text(
          'Choose Accent Color',
          style: TextStyle(color: TallyTapTheme.primaryMint, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 300,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: colorPalette.length,
            itemBuilder: (context, idx) {
              final color = colorPalette[idx];
              return GestureDetector(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  await ref.read(customizationProvider.notifier).updateSourceColor(widget.sourceName, color);
                  if (context.mounted) {
                    Navigator.pop(context);
                    setState(() {}); // Force local rebuild
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: TallyTapTheme.borderGreen, width: 2),
                  ),
                ),
              );
            },
          ),
        ),
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
        totalIncome += tx.amount;
      } else {
        totalExpense += tx.amount;
      }
    }

    final double starting = startingBalances[widget.sourceName] ?? 0.0;
    final double netCalculated = starting + totalIncome - totalExpense;

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
                                  currency,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: activeColor,
                                    height: 1.2,
                                  ),
                                ),
                                Text(
                                  netCalculated.toStringAsFixed(2),
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
