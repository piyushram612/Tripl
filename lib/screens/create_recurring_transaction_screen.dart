import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../models/recurring_transaction_model.dart';
import '../providers/recurring_transaction_provider.dart';
import '../providers/category_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/source_provider.dart';
import 'widgets/transaction_form_components.dart';
import 'dart:ui';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/tutorial_service.dart';
import '../providers/tutorial_provider.dart';
import 'sheets/manage_categories_sheet.dart';

class CreateRecurringTransactionScreen extends ConsumerStatefulWidget {
  final RecurringTransaction? existingTransaction;

  const CreateRecurringTransactionScreen({super.key, this.existingTransaction});

  @override
  ConsumerState<CreateRecurringTransactionScreen> createState() => _CreateRecurringTransactionScreenState();
}

class _CreateRecurringTransactionScreenState extends ConsumerState<CreateRecurringTransactionScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _intervalController = TextEditingController(text: '1');
  final TextEditingController _endOccurrencesController = TextEditingController();

  TransactionType _type = TransactionType.expense;
  String? _selectedCategory;
  String? _selectedSource;
  
  RecurrenceFrequency _frequency = RecurrenceFrequency.monthly;
  DateTime _startDate = DateTime.now();
  TimeOfDay? _executionTime;
  EndConditionType _endCondition = EndConditionType.never;
  DateTime? _endDate;
  List<int> _selectedDays = [];

  bool _reminderEnabled = true;
  ReminderTiming _reminderTiming = ReminderTiming.oneDayBefore;
  
  bool _autoCreate = true;
  bool _logAsPending = false;
  TutorialCoachMark? tutorialCoachMark;

  @override
  void initState() {
    super.initState();
    if (widget.existingTransaction != null) {
      final tx = widget.existingTransaction!;
      _type = tx.type;
      _amountController.text = tx.amount.toString();
      _titleController.text = tx.title;
      _selectedCategory = tx.category;
      _selectedSource = tx.paymentMethod;
      _frequency = tx.frequency;
      _intervalController.text = tx.frequencyInterval.toString();
      _startDate = tx.startDate;
      _executionTime = TimeOfDay(hour: tx.startDate.hour, minute: tx.startDate.minute);
      _endCondition = tx.endCondition;
      _endDate = tx.endDate;
      _selectedDays = tx.weeklyDays != null ? List<int>.from(tx.weeklyDays!) : [];
      _endOccurrencesController.text = tx.endOccurrences?.toString() ?? '';
      _reminderEnabled = tx.reminderEnabled;
      _reminderTiming = tx.reminderTiming ?? ReminderTiming.oneDayBefore;
      _autoCreate = tx.autoCreate;
      _logAsPending = tx.logAsPending;
    } else {
      _executionTime = TimeOfDay.now();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkTutorialStatus();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _intervalController.dispose();
    _endOccurrencesController.dispose();
    super.dispose();
  }

  Color _getColorForCategory(String cat) {
    if (_type == TransactionType.income) return const Color(0xFF22C55E); // Green for Income
    return TallyTapTheme.getColorForCategory(cat);
  }

  IconData _getIconForCategory(String cat) {
    return TallyTapTheme.getIconForCategory(cat, _type == TransactionType.income);
  }

  String _getFrequencyLabel(RecurrenceFrequency f) {
    switch (f) {
      case RecurrenceFrequency.daily: return 'Daily';
      case RecurrenceFrequency.weekly: return 'Weekly';
      case RecurrenceFrequency.monthly: return 'Monthly';
      case RecurrenceFrequency.yearly: return 'Yearly';
      case RecurrenceFrequency.custom: return 'Custom';
    }
  }

  String _getEndConditionLabel(EndConditionType e) {
    switch (e) {
      case EndConditionType.never: return 'Never';
      case EndConditionType.onDate: return 'On Date';
      case EndConditionType.afterOccurrences: return 'After Occurrences';
    }
  }

  String _getReminderTimingLabel(ReminderTiming r) {
    switch (r) {
      case ReminderTiming.atDueTime: return 'At Due Time';
      case ReminderTiming.oneHourBefore: return '1 Hour Before';
      case ReminderTiming.sixHoursBefore: return '6 Hours Before';
      case ReminderTiming.twelveHoursBefore: return '12 Hours Before';
      case ReminderTiming.oneDayBefore: return '1 Day Before';
      case ReminderTiming.threeDaysBefore: return '3 Days Before';
      case ReminderTiming.oneWeekBefore: return '1 Week Before';
    }
  }

  void _applyTemplate(String template) {
    setState(() {
      _amountController.clear();
      _logAsPending = false;
      switch (template) {
        case 'Netflix':
          _titleController.text = 'Netflix';
          _selectedCategory = 'Entertainment';
          _type = TransactionType.expense;
          _frequency = RecurrenceFrequency.monthly;
          _autoCreate = true;
          break;
        case 'Spotify':
          _titleController.text = 'Spotify';
          _selectedCategory = 'Entertainment';
          _type = TransactionType.expense;
          _frequency = RecurrenceFrequency.monthly;
          _autoCreate = true;
          break;
        case 'Salary':
          _titleController.text = 'Salary';
          _selectedCategory = 'Income'; 
          _type = TransactionType.income;
          _frequency = RecurrenceFrequency.monthly;
          _autoCreate = true;
          break;
        case 'Rent':
          _titleController.text = 'House Rent';
          _selectedCategory = 'Housing';
          _type = TransactionType.expense;
          _frequency = RecurrenceFrequency.monthly;
          _autoCreate = true;
          break;
        case 'EMI':
          _titleController.text = 'EMI';
          _selectedCategory = 'Bills';
          _type = TransactionType.expense;
          _frequency = RecurrenceFrequency.monthly;
          _autoCreate = true;
          break;
        case 'SIP':
          _titleController.text = 'Mutual Fund SIP';
          _selectedCategory = 'Investment';
          _type = TransactionType.expense;
          _frequency = RecurrenceFrequency.monthly;
          _autoCreate = true;
          break;
        case 'Internet':
          _titleController.text = 'Internet Bill';
          _selectedCategory = 'Bills';
          _type = TransactionType.expense;
          _frequency = RecurrenceFrequency.monthly;
          _autoCreate = true;
          break;
        case 'Recharge':
          _titleController.text = 'Mobile Recharge';
          _selectedCategory = 'Bills';
          _type = TransactionType.expense;
          _frequency = RecurrenceFrequency.monthly;
          _autoCreate = true;
          break;
      }
    });
  }

  void _saveTransaction() {
    if (_formKey.currentState!.validate()) {
      final amount = double.tryParse(_amountController.text) ?? 0.0;
      if (amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid amount'), backgroundColor: Colors.red),
        );
        return;
      }
      
      final categoryToSave = _selectedCategory ?? 'Other';
      final sourceToSave = _selectedSource ?? 'Cash';
      
      DateTime effectiveStartDate = _startDate;
      if (_executionTime != null) {
        effectiveStartDate = DateTime(
          _startDate.year,
          _startDate.month,
          _startDate.day,
          _executionTime!.hour,
          _executionTime!.minute,
        );
      }
      
      int interval = 1;
      if (_frequency == RecurrenceFrequency.custom) {
        interval = int.tryParse(_intervalController.text) ?? 1;
        if (interval < 1) interval = 1;
      }

      List<int>? weeklyDays = _frequency == RecurrenceFrequency.weekly && _selectedDays.isNotEmpty ? _selectedDays : null;
      DateTime initialNextDue = effectiveStartDate;
      if (widget.existingTransaction == null && weeklyDays != null && !weeklyDays.contains(effectiveStartDate.weekday)) {
        initialNextDue = RecurringTransaction.calculateNextDueDate(
          effectiveStartDate.subtract(const Duration(days: 1)),
          RecurrenceFrequency.weekly,
          interval: 1,
          weeklyDays: weeklyDays,
        );
        initialNextDue = DateTime(initialNextDue.year, initialNextDue.month, initialNextDue.day, effectiveStartDate.hour, effectiveStartDate.minute);
      }

      final tx = RecurringTransaction(
        id: widget.existingTransaction?.id,
        type: _type,
        amount: amount,
        title: _titleController.text,
        category: categoryToSave,
        frequency: _frequency,
        frequencyInterval: interval,
        weeklyDays: weeklyDays,
        startDate: effectiveStartDate,
        endCondition: _endCondition,
        endDate: _endDate,
        endOccurrences: int.tryParse(_endOccurrencesController.text),
        reminderEnabled: _reminderEnabled,
        reminderTiming: _reminderEnabled ? _reminderTiming : null,
        autoCreate: _autoCreate,
        logAsPending: _logAsPending,
        paymentMethod: sourceToSave,
        merchant: _titleController.text, // Using title as merchant
        nextDueDate: widget.existingTransaction?.nextDueDate ?? initialNextDue,
      );

      if (widget.existingTransaction == null) {
        ref.read(recurringTransactionsProvider.notifier).addTransaction(tx);
      } else {
        ref.read(recurringTransactionsProvider.notifier).updateTransaction(tx);
      }

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recurring transaction ${widget.existingTransaction == null ? 'created' : 'updated'}'), backgroundColor: TallyTapTheme.primaryMint),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);
    final visibilities = ref.watch(categoryVisibilityProvider);
    final categoriesList = ref.watch(categoriesListProvider).where((c) {
      if (c.toLowerCase() == 'income') return false;
      final vis = visibilities[c] ?? CategoryVisibility.expense;
      if (_type == TransactionType.income) {
        return vis == CategoryVisibility.income || vis == CategoryVisibility.both;
      } else {
        return vis == CategoryVisibility.expense || vis == CategoryVisibility.both;
      }
    }).toList();
    final sourcesList = ref.watch(sourcesListProvider);

    // Ensure selected category is in the list to avoid chips not showing it
    final List<String> categoriesToRender = List.from(categoriesList);
    if (_selectedCategory != null && !categoriesToRender.contains(_selectedCategory)) {
      categoriesToRender.insert(0, _selectedCategory!);
    }
    if (_selectedCategory == null && categoriesToRender.isNotEmpty) {
      _selectedCategory = categoriesToRender.first;
    }

    final List<String> sourcesToRender = List.from(sourcesList);
    if (_selectedSource != null && !sourcesToRender.contains(_selectedSource)) {
      sourcesToRender.insert(0, _selectedSource!);
    }
    if (_selectedSource == null && sourcesToRender.isNotEmpty) {
      _selectedSource = sourcesToRender.first;
    }

    final bool isIncome = _type == TransactionType.income;
    final activeColor = isIncome ? const Color(0xFF10B981) : TallyTapTheme.primaryMint;
    final catColor = _getColorForCategory(_selectedCategory ?? 'Other');

    return Scaffold(
      backgroundColor: TallyTapTheme.obsidianBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: TallyTapTheme.textLight, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.existingTransaction == null ? 'New Recurring' : 'Edit Recurring',
          style: const TextStyle(color: TallyTapTheme.textLight, fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Outfit'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: TypeToggle(
              isIncome: isIncome,
              onChanged: (v) => setState(() => _type = v ? TransactionType.income : TransactionType.expense),
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
                      // QUICK TEMPLATES (Only if new)
                      if (widget.existingTransaction == null) ...[
                        SingleChildScrollView(
                          key: TutorialService.createRecurringQuickTemplatesKey,
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: ['Salary', 'Rent', 'Netflix', 'Spotify', 'EMI', 'SIP', 'Internet', 'Recharge'].map((t) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ActionChip(
                                  label: Text(t, style: const TextStyle(color: TallyTapTheme.textLight, fontSize: 12, fontWeight: FontWeight.bold)),
                                  backgroundColor: TallyTapTheme.obsidianCard,
                                  side: const BorderSide(color: TallyTapTheme.borderGreen),
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    _applyTemplate(t);
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // AMOUNT CARD
                      AmountCard(
                        currency: currency,
                        controller: _amountController,
                        activeColor: activeColor,
                        catColor: catColor,
                      ),
                      const SizedBox(height: 24),

                      // TITLE FIELD
                      const SectionLabel(label: 'Merchant / Title'),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _titleController,
                        style: const TextStyle(
                          color: TallyTapTheme.textLight,
                          fontWeight: FontWeight.w600,
                        ),
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: isIncome
                              ? 'e.g. Salary, Dividend, Gift...'
                              : 'e.g. Netflix, Rent, Electricity...',
                          hintStyle: const TextStyle(color: TallyTapTheme.textGray, fontSize: 14),
                          filled: true,
                          fillColor: TallyTapTheme.obsidianCard,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: TallyTapTheme.borderGreen),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: activeColor, width: 1.5),
                          ),
                        ),
                        validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 24),

                      // CATEGORY ROW
                      // CATEGORY ROW
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SectionLabel(label: 'Select Category'),
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => const ManageCategoriesSheet(),
                                );
                              },
                              child: Text(
                                'Manage All',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: activeColor,
                                  fontWeight: FontWeight.w700,
                                ),
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
                            itemCount: categoriesToRender.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 12),
                            itemBuilder: (ctx, i) {
                              final cat = categoriesToRender[i];
                              final selected = cat == _selectedCategory;
                              final color = _getColorForCategory(cat);
                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedCategory = cat);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 72,
                                  decoration: BoxDecoration(
                                    color: selected ? color.withOpacity(0.15) : TallyTapTheme.obsidianCard,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: selected ? color : TallyTapTheme.borderGreen,
                                      width: selected ? 1.8 : 1.0,
                                    ),
                                    boxShadow: selected ? [
                                      BoxShadow(color: color.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4))
                                    ] : null,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: selected ? color.withOpacity(0.2) : TallyTapTheme.obsidianBg.withOpacity(0.5),
                                        ),
                                        child: Icon(
                                          _getIconForCategory(cat),
                                          color: selected ? color : TallyTapTheme.textGray,
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
                                          color: selected ? color : TallyTapTheme.textGray,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                      // PAYMENT SOURCE CARDS
                      const SectionLabel(label: 'Payment Source'),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 110,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: sourcesToRender.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (ctx, i) {
                            final src = sourcesToRender[i];
                            final selected = src == _selectedSource;
                            final srcColor = TallyTapTheme.getColorForSource(src);
                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedSource = src);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 150, // Matches width in create_transaction_screen
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: selected ? srcColor.withOpacity(0.12) : TallyTapTheme.obsidianCard,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: selected ? srcColor : TallyTapTheme.borderGreen,
                                    width: selected ? 1.8 : 1.0,
                                  ),
                                  boxShadow: selected ? [
                                    BoxShadow(color: srcColor.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))
                                  ] : null,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: srcColor.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        TallyTapTheme.getIconForSource(src),
                                        color: srcColor,
                                        size: 18,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      src,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: selected ? TallyTapTheme.textLight : TallyTapTheme.textGray,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      // SCHEDULE
                      const SectionLabel(label: 'Schedule'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final d = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime.now(), lastDate: DateTime(2100));
                                if (d != null) setState(() => _startDate = d);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: TallyTapTheme.obsidianCard,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: TallyTapTheme.borderGreen),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today_outlined, color: activeColor, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        DateFormat('MMM d, yyyy').format(_startDate),
                                        style: const TextStyle(color: TallyTapTheme.textLight, fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final t = await showTimePicker(context: context, initialTime: _executionTime ?? TimeOfDay.now());
                                if (t != null) setState(() => _executionTime = t);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: TallyTapTheme.obsidianCard,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: TallyTapTheme.borderGreen),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.access_time_rounded, color: activeColor, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _executionTime?.format(context) ?? 'Anytime',
                                        style: const TextStyle(color: TallyTapTheme.textLight, fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // FREQUENCY
                      const SectionLabel(label: 'Frequency'),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        key: TutorialService.createRecurringTemplateKey,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: RecurrenceFrequency.values.map((f) {
                            final isSelected = _frequency == f;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _frequency = f);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected ? activeColor.withOpacity(0.15) : TallyTapTheme.obsidianCard,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected ? activeColor : TallyTapTheme.borderGreen,
                                      width: isSelected ? 1.5 : 1.0,
                                    ),
                                    boxShadow: isSelected ? [BoxShadow(color: activeColor.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))] : null,
                                  ),
                                  child: Text(
                                    _getFrequencyLabel(f),
                                    style: TextStyle(color: isSelected ? activeColor : TallyTapTheme.textLight, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      if (_frequency == RecurrenceFrequency.weekly) ...[
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            for (int i = 1; i <= 7; i++) ...[
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    if (_selectedDays.contains(i)) {
                                      _selectedDays.remove(i);
                                    } else {
                                      _selectedDays.add(i);
                                    }
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _selectedDays.contains(i) ? activeColor.withOpacity(0.15) : TallyTapTheme.obsidianCard,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _selectedDays.contains(i) ? activeColor : TallyTapTheme.borderGreen,
                                      width: _selectedDays.contains(i) ? 1.5 : 1.0,
                                    ),
                                    boxShadow: _selectedDays.contains(i) ? [BoxShadow(color: activeColor.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))] : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i - 1],
                                      style: TextStyle(
                                        color: _selectedDays.contains(i) ? activeColor : TallyTapTheme.textGray,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      if (_frequency == RecurrenceFrequency.custom) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Text('Every ', style: TextStyle(color: TallyTapTheme.textGray, fontWeight: FontWeight.bold)),
                            SizedBox(
                              width: 60,
                              child: TextFormField(
                                controller: _intervalController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: activeColor, fontWeight: FontWeight.bold),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: TallyTapTheme.borderGreen)),
                                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: TallyTapTheme.primaryMint)),
                                ),
                              ),
                            ),
                            const Text(' Days', style: TextStyle(color: TallyTapTheme.textGray, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),

                      // END CONDITION
                      const SectionLabel(label: 'End Condition'),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        key: TutorialService.createRecurringEndConditionKey,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: EndConditionType.values.map((e) {
                            final isSelected = _endCondition == e;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _endCondition = e);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected ? activeColor.withOpacity(0.15) : TallyTapTheme.obsidianCard,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected ? activeColor : TallyTapTheme.borderGreen,
                                      width: isSelected ? 1.5 : 1.0,
                                    ),
                                    boxShadow: isSelected ? [BoxShadow(color: activeColor.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))] : null,
                                  ),
                                  child: Text(
                                    _getEndConditionLabel(e),
                                    style: TextStyle(color: isSelected ? activeColor : TallyTapTheme.textLight, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      if (_endCondition == EndConditionType.onDate) ...[
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () async {
                            final d = await showDatePicker(context: context, initialDate: _endDate ?? _startDate.add(const Duration(days: 30)), firstDate: _startDate, lastDate: DateTime(2100));
                            if (d != null) setState(() => _endDate = d);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            decoration: BoxDecoration(
                              color: TallyTapTheme.obsidianCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: TallyTapTheme.borderGreen),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.event_busy, color: activeColor, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  _endDate != null ? DateFormat('MMM d, yyyy').format(_endDate!) : 'Choose Date',
                                  style: const TextStyle(color: TallyTapTheme.textLight, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (_endCondition == EndConditionType.afterOccurrences) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Text('After ', style: TextStyle(color: TallyTapTheme.textGray, fontWeight: FontWeight.bold)),
                            SizedBox(
                              width: 60,
                              child: TextFormField(
                                controller: _endOccurrencesController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: activeColor, fontWeight: FontWeight.bold),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: TallyTapTheme.borderGreen)),
                                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: TallyTapTheme.primaryMint)),
                                ),
                              ),
                            ),
                            const Text(' Times', style: TextStyle(color: TallyTapTheme.textGray, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 32),
                      
                      // AUTOMATION & REMINDERS
                      Container(
                        key: TutorialService.createRecurringAutoLogKey,
                        decoration: BoxDecoration(
                          color: TallyTapTheme.obsidianCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: TallyTapTheme.borderGreen),
                        ),
                        child: Column(
                          children: [
                            CheckboxListTile(
                              title: const Text('Auto-Log Transaction', style: TextStyle(color: TallyTapTheme.textLight, fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: const Text('Automatically logs when due without asking', style: TextStyle(color: TallyTapTheme.textGray, fontSize: 12)),
                              value: _autoCreate,
                              activeColor: activeColor,
                              checkColor: TallyTapTheme.obsidianBg,
                              onChanged: (val) => setState(() {
                                _autoCreate = val ?? true;
                                if (!_autoCreate) _logAsPending = false;
                              }),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                            if (_autoCreate)
                              CheckboxListTile(
                                contentPadding: const EdgeInsets.only(left: 48.0, right: 16.0),
                                title: const Text('Require manual verification', style: TextStyle(color: TallyTapTheme.textLight, fontWeight: FontWeight.w600, fontSize: 13)),
                                subtitle: const Text('Logs as a \'Finish Later\' draft for you to review', style: TextStyle(color: TallyTapTheme.textGray, fontSize: 12)),
                                value: _logAsPending,
                                activeColor: activeColor,
                                checkColor: TallyTapTheme.obsidianBg,
                                onChanged: (val) => setState(() => _logAsPending = val ?? false),
                                controlAffinity: ListTileControlAffinity.leading,
                              ),
                            const Divider(color: TallyTapTheme.borderGreen, height: 1),
                            CheckboxListTile(
                              title: const Text('Enable Reminders', style: TextStyle(color: TallyTapTheme.textLight, fontWeight: FontWeight.bold, fontSize: 14)),
                              value: _reminderEnabled,
                              activeColor: activeColor,
                              checkColor: TallyTapTheme.obsidianBg,
                              onChanged: (val) => setState(() => _reminderEnabled = val ?? true),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                            if (_reminderEnabled) ...[
                              Padding(
                                padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0, top: 8.0),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  child: Row(
                                    children: ReminderTiming.values.map((r) {
                                      final isSelected = _reminderTiming == r;
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 8.0),
                                        child: GestureDetector(
                                          onTap: () {
                                            HapticFeedback.selectionClick();
                                            setState(() => _reminderTiming = r);
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: isSelected ? activeColor.withOpacity(0.15) : TallyTapTheme.obsidianBg,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isSelected ? activeColor : TallyTapTheme.borderGreen,
                                                width: isSelected ? 1.5 : 1.0,
                                              ),
                                            ),
                                            child: Text(
                                              _getReminderTimingLabel(r),
                                              style: TextStyle(color: isSelected ? activeColor : TallyTapTheme.textLight, fontWeight: FontWeight.bold, fontSize: 11),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ]
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // CTA BUTTON
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Container(
                  key: TutorialService.createRecurringSaveKey,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      colors: isIncome
                          ? [const Color(0xFF10B981), const Color(0xFF059669)]
                          : [TallyTapTheme.primaryMint, const Color(0xFF33C28A)],
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 22),
                    label: Text(
                      widget.existingTransaction == null ? 'Create Recurring' : 'Update Recurring',
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

  Future<void> _checkTutorialStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool(kPrefTutorialCreateRecurringTx) ?? false;
    if (!hasSeen && mounted) {
      _initTutorial();
    }
  }

  void _initTutorial() {
    tutorialCoachMark = TutorialCoachMark(
      targets: _createTargets(),
      colorShadow: Colors.black,
      textSkip: "SKIP",
      paddingFocus: 10,
      opacityShadow: 0.6,
      imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      beforeFocus: (target) async {
        if (target.keyTarget?.currentContext != null) {
          Scrollable.ensureVisible(
            target.keyTarget!.currentContext!,
            alignment: 0.5,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          await Future.delayed(const Duration(milliseconds: 350));
        }
      },
      onClickOverlay: (target) {
        tutorialCoachMark?.next();
      },
      onFinish: () {
        ref.read(tutorialProvider.notifier).markCompleted(kPrefTutorialCreateRecurringTx);
      },
      onSkip: () {
        ref.read(tutorialProvider.notifier).markCompleted(kPrefTutorialCreateRecurringTx);
        return true;
      },
    );
    tutorialCoachMark?.show(context: context);
  }

  Widget _buildTutorialContent(TutorialCoachMarkController controller, String title, String description) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20)),
        const SizedBox(height: 10),
        Text(description, style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: () => controller.next(),
            style: ElevatedButton.styleFrom(
              backgroundColor: TallyTapTheme.primaryMint,
              foregroundColor: TallyTapTheme.obsidianBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Next"),
          ),
        ),
      ],
    );
  }

  List<TargetFocus> _createTargets() {
    List<TargetFocus> targets = [];

    if (widget.existingTransaction == null) {
      targets.add(TargetFocus(
        identify: "TargetQuickTemplates",
        keyTarget: TutorialService.createRecurringQuickTemplatesKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => _buildTutorialContent(controller, "Quick Templates", "Use these templates to quickly set up common recurring payments like Rent or Netflix."),
          ),
        ],
      ));
    }

    targets.add(TargetFocus(
      identify: "TargetFrequency",
      keyTarget: TutorialService.createRecurringTemplateKey,
      alignSkip: Alignment.topRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) => _buildTutorialContent(controller, "Frequency", "Set how often this transaction repeats (e.g., Weekly, Monthly)."),
        ),
      ],
    ));

    targets.add(TargetFocus(
      identify: "TargetEndCondition",
      keyTarget: TutorialService.createRecurringEndConditionKey,
      alignSkip: Alignment.topRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.top,
          builder: (context, controller) => _buildTutorialContent(controller, "End Condition", "Set when this recurring payment should stop, or let it repeat forever."),
        ),
      ],
    ));

    targets.add(TargetFocus(
      identify: "TargetAutomation",
      keyTarget: TutorialService.createRecurringAutoLogKey,
      alignSkip: Alignment.topRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.top,
          builder: (context, controller) => _buildTutorialContent(controller, "Automation", "Choose whether to auto-log transactions or draft them for your manual review."),
        ),
      ],
    ));

    targets.add(TargetFocus(
      identify: "TargetSave",
      keyTarget: TutorialService.createRecurringSaveKey,
      alignSkip: Alignment.topRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.top,
          builder: (context, controller) => _buildTutorialContent(controller, "Save", "Tap here to save your recurring transaction."),
        ),
      ],
    ));

    return targets;
  }
}
