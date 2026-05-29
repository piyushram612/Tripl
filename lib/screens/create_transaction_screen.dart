import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../models/transaction_model.dart';
import '../providers/category_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/source_provider.dart';
import '../services/transaction_service.dart';

class CreateTransactionScreen extends ConsumerStatefulWidget {
  const CreateTransactionScreen({super.key});

  @override
  ConsumerState<CreateTransactionScreen> createState() =>
      _CreateTransactionScreenState();
}

class _CreateTransactionScreenState
    extends ConsumerState<CreateTransactionScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _merchantController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _isIncome = false;
  String? _selectedCategory;
  String? _selectedPaymentMethod;

  late final AnimationController _amountPulse;
  late final Animation<double> _amountScale;

  @override
  void initState() {
    super.initState();
    _amountPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
    _amountScale = CurvedAnimation(parent: _amountPulse, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _amountPulse.dispose();
    super.dispose();
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  String _generateUuid() {
    final random = Random();
    final List<int> values =
        List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40;
    values[8] = (values[8] & 0x3f) | 0x80;
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) buffer.write('-');
      buffer.write(values[i].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  Color _categoryColor(String cat) {
    if (_isIncome) return const Color(0xFF10B981);
    return TallyTapTheme.getColorForCategory(cat);
  }

  IconData _categoryIcon(String cat) =>
      TallyTapTheme.getIconForCategory(cat, _isIncome);

  /// Sum transactions for a given source to show a rough balance.
  double _balanceForSource(List<ExpenseTransaction> txs, String src) {
    double b = 0;
    for (final t in txs) {
      if (t.paymentMethod == src) {
        b += t.category.toLowerCase() == 'income' ? t.amount : -t.amount;
      }
    }
    return b;
  }

  Future<void> _pickDate(BuildContext context) async {
    final darkScheme = const ColorScheme.dark(
      primary: TallyTapTheme.primaryMint,
      onPrimary: TallyTapTheme.obsidianBg,
      surface: TallyTapTheme.obsidianCard,
      onSurface: TallyTapTheme.textLight,
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      builder: (ctx, child) =>
          Theme(data: Theme.of(ctx).copyWith(colorScheme: darkScheme), child: child!),
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
      builder: (ctx, child) =>
          Theme(data: Theme.of(ctx).copyWith(colorScheme: darkScheme), child: child!),
    );
    if (time == null) return;
    setState(() {
      _selectedDate = DateTime(
          picked.year, picked.month, picked.day, time.hour, time.minute);
    });
  }

  void _saveTransaction() {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter a valid amount'),
        backgroundColor: Color(0xFFEF4444),
      ));
      return;
    }
    final category = _isIncome ? 'Income' : (_selectedCategory ?? 'Other');
    final source = _selectedPaymentMethod ?? 'Cash';
    final merchant = _merchantController.text.trim().isNotEmpty
        ? _merchantController.text.trim()
        : (_isIncome ? 'Quick Income' : 'Quick Expense');

    ref.read(transactionListProvider.notifier).addTransaction(
          ExpenseTransaction(
            id: _generateUuid(),
            amount: amount,
            merchant: merchant,
            date: _selectedDate,
            paymentMethod: source,
            category: category,
            notes: _notesController.text.trim(),
          ),
        );
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${_isIncome ? 'Income' : 'Expense'} logged!'),
      backgroundColor: TallyTapTheme.primaryMint,
    ));
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);
    final categories = ref.watch(categoriesListProvider)
        .where((c) => c.toLowerCase() != 'income')
        .toList();
    final sources = ref.watch(sourcesListProvider);
    final allTx = ref.watch(transactionListProvider);

    // auto-select defaults
    if (_selectedCategory == null && categories.isNotEmpty) {
      _selectedCategory = categories.first;
    }
    if (_selectedPaymentMethod == null && sources.isNotEmpty) {
      _selectedPaymentMethod = sources.first;
    }

    final activeColor =
        _isIncome ? const Color(0xFF10B981) : TallyTapTheme.primaryMint;
    final catColor = _categoryColor(_selectedCategory ?? 'Other');

    final dateLabel = _isToday(_selectedDate)
        ? 'Today, ${DateFormat('MMM d, y').format(_selectedDate)}'
        : DateFormat('EEE, MMM d, y').format(_selectedDate);

    return Scaffold(
      backgroundColor: TallyTapTheme.obsidianBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: TallyTapTheme.textLight, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Log Transaction',
          style: TextStyle(
            color: TallyTapTheme.textLight,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            fontFamily: 'Outfit',
          ),
        ),
        actions: [
          // Expense / Income pill toggle in the app bar
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: _TypeToggle(
              isIncome: _isIncome,
              onChanged: (v) => setState(() => _isIncome = v),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── AMOUNT CARD ──────────────────────────────────────
                      _AmountCard(
                        currency: currency,
                        controller: _amountController,
                        activeColor: activeColor,
                        catColor: catColor,
                      ),

                      const SizedBox(height: 24),

                      // ── MERCHANT FIELD ───────────────────────────────────
                      _SectionLabel(label: 'Merchant / Title'),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _merchantController,
                        style: const TextStyle(
                          color: TallyTapTheme.textLight,
                          fontWeight: FontWeight.w600,
                        ),
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: _isIncome
                              ? 'e.g. Salary, Dividend, Gift...'
                              : 'e.g. Starbucks, Amazon, Rent...',
                          hintStyle: const TextStyle(
                              color: TallyTapTheme.textGray, fontSize: 14),
                          filled: true,
                          fillColor: TallyTapTheme.obsidianCard,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                                color: TallyTapTheme.borderGreen),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                BorderSide(color: activeColor, width: 1.5),
                          ),
                        ),
                      ),

                      // ── CATEGORY ROW (Expense only) ──────────────────────
                      if (!_isIncome) ...[
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _SectionLabel(label: 'Select Category'),
                            Text(
                              'Manage All',
                              style: TextStyle(
                                fontSize: 12,
                                color: activeColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 84,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: categories.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (ctx, i) {
                              final cat = categories[i];
                              final selected = cat == _selectedCategory;
                              final color = _categoryColor(cat);
                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedCategory = cat);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 72,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? color.withOpacity(0.15)
                                        : TallyTapTheme.obsidianCard,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: selected
                                          ? color
                                          : TallyTapTheme.borderGreen,
                                      width: selected ? 1.8 : 1.0,
                                    ),
                                    boxShadow: selected
                                        ? [
                                            BoxShadow(
                                              color: color.withOpacity(0.25),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            )
                                          ]
                                        : null,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: selected
                                              ? color.withOpacity(0.2)
                                              : TallyTapTheme.obsidianBg
                                                  .withOpacity(0.5),
                                        ),
                                        child: Icon(
                                          _categoryIcon(cat),
                                          color: selected
                                              ? color
                                              : TallyTapTheme.textGray,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        cat,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: selected
                                              ? color
                                              : TallyTapTheme.textGray,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],

                      // ── PAYMENT SOURCE CARDS ─────────────────────────────
                      const SizedBox(height: 24),
                      _SectionLabel(label: 'Payment Source'),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 110,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: sources.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (ctx, i) {
                            final src = sources[i];
                            final selected = src == _selectedPaymentMethod;
                            final srcColor =
                                TallyTapTheme.getColorForSource(src);
                            final balance = _balanceForSource(allTx, src);
                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(
                                    () => _selectedPaymentMethod = src);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 150,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? srcColor.withOpacity(0.12)
                                      : TallyTapTheme.obsidianCard,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: selected
                                        ? srcColor
                                        : TallyTapTheme.borderGreen,
                                    width: selected ? 1.8 : 1.0,
                                  ),
                                  boxShadow: selected
                                      ? [
                                          BoxShadow(
                                            color:
                                                srcColor.withOpacity(0.2),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          )
                                        ]
                                      : null,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: srcColor.withOpacity(0.15),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        TallyTapTheme.getIconForSource(src),
                                        color: srcColor,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          src,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: selected
                                                ? TallyTapTheme.textLight
                                                : TallyTapTheme.textGray,
                                          ),
                                        ),
                                        Text(
                                          '$currency${balance.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: selected
                                                ? srcColor
                                                : TallyTapTheme.textGray
                                                    .withOpacity(0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // ── DATE ROW ─────────────────────────────────────────
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () => _pickDate(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          decoration: BoxDecoration(
                            color: TallyTapTheme.obsidianCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: TallyTapTheme.borderGreen,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_outlined,
                                  color: activeColor, size: 18),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  dateLabel,
                                  style: const TextStyle(
                                    color: TallyTapTheme.textLight,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: TallyTapTheme.borderGreen
                                      .withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Change',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: TallyTapTheme.textLight,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── NOTES FIELD ──────────────────────────────────────
                      const SizedBox(height: 24),
                      _SectionLabel(label: 'Notes (optional)'),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _notesController,
                        style: const TextStyle(
                          color: TallyTapTheme.textLight,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 3,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Add a note about this transaction...',
                          hintStyle: const TextStyle(
                              color: TallyTapTheme.textGray, fontSize: 14),
                          filled: true,
                          fillColor: TallyTapTheme.obsidianCard,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                                color: TallyTapTheme.borderGreen),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                BorderSide(color: activeColor, width: 1.5),
                          ),
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(left: 16, right: 8),
                            child: Icon(
                              Icons.notes_rounded,
                              color: TallyTapTheme.textGray,
                              size: 18,
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(
                              minWidth: 0, minHeight: 0),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // ── CTA BUTTON ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      colors: _isIncome
                          ? [const Color(0xFF10B981), const Color(0xFF059669)]
                          : [
                              TallyTapTheme.primaryMint,
                              const Color(0xFF33C28A)
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: TallyTapTheme.obsidianBg,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    icon: const Icon(Icons.check_circle_outline_rounded,
                        size: 22),
                    label: Text(
                      _isIncome ? 'Log Income' : 'Log Expense',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _saveTransaction();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: TallyTapTheme.textGray,
        ),
      );
}

class _TypeToggle extends StatelessWidget {
  const _TypeToggle({required this.isIncome, required this.onChanged});
  final bool isIncome;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: TallyTapTheme.obsidianCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TallyTapTheme.borderGreen),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pill('Expense', !isIncome, TallyTapTheme.primaryMint,
              () => onChanged(false)),
          _pill('Income', isIncome, const Color(0xFF10B981),
              () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _pill(
      String label, bool active, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: active
              ? Border.all(color: color.withOpacity(0.6), width: 1.0)
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: active ? color : TallyTapTheme.textGray,
          ),
        ),
      ),
    );
  }
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({
    required this.currency,
    required this.controller,
    required this.activeColor,
    required this.catColor,
  });

  final String currency;
  final TextEditingController controller;
  final Color activeColor;
  final Color catColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: TallyTapTheme.obsidianCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: TallyTapTheme.borderGreen),
        boxShadow: [
          BoxShadow(
            color: activeColor.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'TRANSACTION AMOUNT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
              color: TallyTapTheme.textGray,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                currency,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: activeColor,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: IntrinsicWidth(
                  child: TextFormField(
                    controller: controller,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: TallyTapTheme.textLight,
                      fontFamily: 'Outfit',
                      letterSpacing: -2,
                    ),
                    textAlign: TextAlign.left,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      hintStyle: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: TallyTapTheme.textGray.withOpacity(0.25),
                        fontFamily: 'Outfit',
                        letterSpacing: -2,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Required';
                      }
                      if (double.tryParse(val) == null) {
                        return 'Invalid number';
                      }
                      return null;
                    },
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
