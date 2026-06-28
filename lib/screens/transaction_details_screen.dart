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
import '../services/notification_service.dart';

class TransactionDetailsScreen extends ConsumerStatefulWidget {
  final ExpenseTransaction transaction;

  const TransactionDetailsScreen({
    super.key,
    required this.transaction,
  });

  @override
  ConsumerState<TransactionDetailsScreen> createState() =>
      _TransactionDetailsScreenState();
}

class _TransactionDetailsScreenState
    extends ConsumerState<TransactionDetailsScreen> {
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _merchantController;
  late TextEditingController _amountController;
  late TextEditingController _notesController;
  late TextEditingController _paidToController;
  late DateTime _selectedDate;
  late String _selectedCategory;
  late String _selectedPaymentMethod;
  late bool _finishLater;
  late DateTime _reminderDate;
  late TimeOfDay _reminderTime;

  @override
  void initState() {
    super.initState();
    _merchantController =
        TextEditingController(text: widget.transaction.merchant);
    _amountController = TextEditingController(
        text: widget.transaction.amount.toStringAsFixed(2));
    _notesController =
        TextEditingController(text: widget.transaction.notes);
    _paidToController =
        TextEditingController(text: widget.transaction.paidTo);
    _selectedDate = widget.transaction.date;
    _selectedCategory = widget.transaction.category;
    _selectedPaymentMethod = widget.transaction.paymentMethod;
    _finishLater = widget.transaction.needsVerification;
    _reminderDate = widget.transaction.reminderDate ?? DateTime.now();
    _reminderTime = widget.transaction.reminderDate != null
        ? TimeOfDay.fromDateTime(widget.transaction.reminderDate!)
        : TimeOfDay.now();
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _paidToController.dispose();
    super.dispose();
  }

  // ── helpers ───────────────────────────────────────────────────────────────

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

  void _saveChanges() {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter a valid amount'),
        backgroundColor: Color(0xFFEF4444),
      ));
      return;
    }
    final tx = ExpenseTransaction(
      id: widget.transaction.id,
      amount: amount,
      merchant: _merchantController.text.trim(),
      date: _selectedDate,
      paymentMethod: _selectedPaymentMethod,
      category: _selectedCategory,
      notes: _notesController.text.trim(),
      paidTo: _paidToController.text.trim(),
      needsVerification: _finishLater,
      reminderDate: _finishLater ? DateTime(
        _reminderDate.year,
        _reminderDate.month,
        _reminderDate.day,
        _reminderTime.hour,
        _reminderTime.minute,
      ) : null,
      wasFinishLater: widget.transaction.wasFinishLater || _finishLater,
      hideFromLedger: widget.transaction.hideFromLedger,
      groupId: widget.transaction.groupId,
      isIncome: widget.transaction.isIncome,
    );

    ref.read(transactionListProvider.notifier).updateTransaction(tx);
    
    // Manage notification
    if (tx.needsVerification && tx.reminderDate != null) {
      NotificationService.scheduleTransactionReminder(tx);
    } else {
      NotificationService.cancelNotification(tx.id);
    }

    setState(() => _isEditing = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Transaction updated successfully'),
      backgroundColor: TallyTapTheme.primaryMint,
    ));
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TallyTapTheme.obsidianCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: TallyTapTheme.borderGreen),
        ),
        title: const Text(
          'Delete Transaction?',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: TallyTapTheme.textLight,
            fontSize: 20,
            fontFamily: 'Outfit',
          ),
        ),
        content: const Text(
          'Are you sure you want to permanently delete this transaction? This action cannot be undone.',
          style: TextStyle(color: TallyTapTheme.textGray, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(
                    color: TallyTapTheme.primaryMint,
                    fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () {
              ref
                  .read(transactionListProvider.notifier)
                  .deleteTransaction(widget.transaction.id);
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Transaction deleted'),
                backgroundColor: Color(0xFFEF4444),
              ));
            },
            child: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);
    final categories = ref.watch(categoriesListProvider);
    final sources = ref.watch(sourcesListProvider);
    final visibilities = ref.watch(categoryVisibilityProvider);

    final isIncome = widget.transaction.isIncome;
    final activeColor =
        isIncome ? const Color(0xFF10B981) : TallyTapTheme.primaryMint;
    final accentColor = TallyTapTheme.getColorForCategory(_selectedCategory);
    final formattedDate =
        DateFormat('EEEE, MMMM d, y').format(_selectedDate);
    final formattedTime = DateFormat('h:mm a').format(_selectedDate);
    final shortDate = DateFormat('MMM d, y').format(_selectedDate);

    // Make sure dropdowns don't throw if category/source was deleted
    final dropdownCategories = List<String>.from(categories);
    if (!dropdownCategories.contains(_selectedCategory)) {
      dropdownCategories.add(_selectedCategory);
    }
    final dropdownSources = List<String>.from(sources);
    if (!dropdownSources.contains(_selectedPaymentMethod)) {
      dropdownSources.add(_selectedPaymentMethod);
    }

    final filteredCategories = dropdownCategories.where((c) {
      if (c.toLowerCase() == 'income') return false;
      final vis = visibilities[c] ?? CategoryVisibility.expense;
      if (isIncome) {
        return vis == CategoryVisibility.income || vis == CategoryVisibility.both;
      } else {
        return vis == CategoryVisibility.expense || vis == CategoryVisibility.both;
      }
    }).toList();
    if (!filteredCategories.contains(_selectedCategory)) {
      filteredCategories.insert(0, _selectedCategory);
    }

    final dateLabel = _isToday(_selectedDate)
        ? 'Today, $shortDate'
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
        title: Text(
          _isEditing ? 'Edit Transaction' : 'Transaction Details',
          style: const TextStyle(
            color: TallyTapTheme.textLight,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            fontFamily: 'Outfit',
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isEditing
                  ? Icons.close_rounded
                  : Icons.edit_note_rounded,
              color: TallyTapTheme.primaryMint,
              size: _isEditing ? 24 : 28,
            ),
            onPressed: () {
              HapticFeedback.mediumImpact();
              setState(() {
                if (_isEditing) {
                  _merchantController.text = widget.transaction.merchant;
                  _amountController.text =
                      widget.transaction.amount.toStringAsFixed(2);
                  _notesController.text = widget.transaction.notes;
                  _paidToController.text = widget.transaction.paidTo;
                  _selectedDate = widget.transaction.date;
                  _selectedCategory = widget.transaction.category;
                  _selectedPaymentMethod = widget.transaction.paymentMethod;
                  _finishLater = widget.transaction.needsVerification;
                  _reminderDate = widget.transaction.reminderDate ?? DateTime.now();
                  _reminderTime = widget.transaction.reminderDate != null
                      ? TimeOfDay.fromDateTime(widget.transaction.reminderDate!)
                      : TimeOfDay.now();
                }
                _isEditing = !_isEditing;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: Color(0xFFEF4444)),
            onPressed: () {
              HapticFeedback.vibrate();
              _confirmDelete();
            },
          ),
          const SizedBox(width: 8),
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
                      // ── AMOUNT CARD ────────────────────────────────────
                      _AmountCard(
                        currency: currency,
                        isEditing: _isEditing,
                        isIncome: isIncome,
                        accentColor: accentColor,
                        activeColor: activeColor,
                        amountController: _amountController,
                        merchantController: _merchantController,
                        selectedCategory: _selectedCategory,
                      ),

                      const SizedBox(height: 24),

                      // ── MERCHANT FIELD (edit mode) ─────────────────────
                      if (_isEditing) ...[
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
                            hintText: 'e.g. Starbucks, Salary, Rent...',
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
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Merchant is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ── PAID TO / PAID BY SECTION ──────────────────────
                      if (_isEditing || _paidToController.text.isNotEmpty) ...[
                        _SectionLabel(
                            label: isIncome
                                ? 'Paid By'
                                : 'Paid To'),
                        const SizedBox(height: 10),
                        if (_isEditing)
                          TextFormField(
                            controller: _paidToController,
                            style: const TextStyle(
                              color: TallyTapTheme.textLight,
                              fontWeight: FontWeight.w600,
                            ),
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              hintText: isIncome
                                  ? 'e.g. Employer, Client...'
                                  : 'e.g. Landlord, Store Name...',
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
                                borderSide: BorderSide(
                                    color: activeColor, width: 1.5),
                              ),
                            ),
                          )
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              color: TallyTapTheme.obsidianCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: TallyTapTheme.borderGreen),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.storefront_rounded,
                                    color: TallyTapTheme.textGray, size: 16),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _paidToController.text,
                                    style: const TextStyle(
                                      color: TallyTapTheme.textLight,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 24),
                      ],

                      // ── CATEGORY SECTION ───────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _SectionLabel(label: 'Category'),
                          if (!_isEditing)
                            _CategoryPill(
                                category: _selectedCategory,
                                color: accentColor),
                        ],
                      ),
                      if (_isEditing) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 84,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: filteredCategories.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (ctx, i) {
                              final cat = filteredCategories[i];
                              final selected = cat == _selectedCategory;
                              final color =
                                  TallyTapTheme.getColorForCategory(cat);
                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedCategory = cat);
                                },
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 200),
                                  width: 72,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? color.withOpacity(0.15)
                                        : TallyTapTheme.obsidianCard,
                                    borderRadius:
                                        BorderRadius.circular(18),
                                    border: Border.all(
                                      color: selected
                                          ? color
                                          : TallyTapTheme.borderGreen,
                                      width: selected ? 1.8 : 1.0,
                                    ),
                                    boxShadow: selected
                                        ? [
                                            BoxShadow(
                                              color:
                                                  color.withOpacity(0.25),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            )
                                          ]
                                        : null,
                                  ),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
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
                                          TallyTapTheme.getIconForCategory(
                                              cat, isIncome),
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
                      const SizedBox(height: 24),



                      // ── PAYMENT SOURCE SECTION ─────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _SectionLabel(
                              label: isIncome
                                  ? 'Deposit Destination'
                                  : 'Payment Source'),
                          if (!_isEditing)
                            _SourcePill(
                              source: _selectedPaymentMethod,
                              color: TallyTapTheme.getColorForSource(
                                  _selectedPaymentMethod),
                            ),
                        ],
                      ),
                      if (_isEditing) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 110,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: dropdownSources.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (ctx, i) {
                              final src = dropdownSources[i];
                              final selected =
                                  src == _selectedPaymentMethod;
                              final srcColor =
                                  TallyTapTheme.getColorForSource(src);
                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(
                                      () => _selectedPaymentMethod = src);
                                },
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 200),
                                  width: 148,
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
                                          color:
                                              srcColor.withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          TallyTapTheme.getIconForSource(
                                              src),
                                          color: srcColor,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
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
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],

                      // ── DATE ROW ───────────────────────────────────────
                      const SizedBox(height: 24),
                      _isEditing
                          ? Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () async {
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
                                      if (picked == null) return;
                                      setState(() {
                                        _selectedDate = DateTime(
                                          picked.year,
                                          picked.month,
                                          picked.day,
                                          _selectedDate.hour,
                                          _selectedDate.minute,
                                        );
                                      });
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
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              dateLabel,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: activeColor,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
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
                                      final darkScheme = const ColorScheme.dark(
                                        primary: TallyTapTheme.primaryMint,
                                        onPrimary: TallyTapTheme.obsidianBg,
                                        surface: TallyTapTheme.obsidianCard,
                                        onSurface: TallyTapTheme.textLight,
                                      );
                                      final time = await showTimePicker(
                                        context: context,
                                        initialTime: TimeOfDay.fromDateTime(_selectedDate),
                                        builder: (ctx, child) =>
                                            Theme(data: Theme.of(ctx).copyWith(colorScheme: darkScheme), child: child!),
                                      );
                                      if (time == null) return;
                                      setState(() {
                                        _selectedDate = DateTime(
                                          _selectedDate.year,
                                          _selectedDate.month,
                                          _selectedDate.day,
                                          time.hour,
                                          time.minute,
                                        );
                                      });
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
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              formattedTime,
                                              style: TextStyle(
                                                color: activeColor,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 14),
                              decoration: BoxDecoration(
                                color: TallyTapTheme.obsidianCard,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: TallyTapTheme.borderGreen),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today_outlined,
                                      color: activeColor, size: 18),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          formattedDate,
                                          style: const TextStyle(
                                            color:
                                                TallyTapTheme.textLight,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          formattedTime,
                                          style: const TextStyle(
                                            color:
                                                TallyTapTheme.textGray,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                      const SizedBox(height: 24),

                      // ── NOTES SECTION ─────────────────────────────────
                      _SectionLabel(
                          label: _isEditing
                              ? 'Notes (optional)'
                              : 'Notes'),
                      const SizedBox(height: 10),
                      if (_isEditing)
                        TextField(
                          controller: _notesController,
                          style: const TextStyle(
                            color: TallyTapTheme.textLight,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 4,
                          minLines: 2,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText:
                                'Add a note about this transaction...',
                            hintStyle: const TextStyle(
                                color: TallyTapTheme.textGray,
                                fontSize: 14),
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
                              borderSide: BorderSide(
                                  color: activeColor, width: 1.5),
                            ),
                            prefixIcon: const Padding(
                              padding:
                                  EdgeInsets.only(left: 16, right: 8),
                              child: Icon(
                                Icons.notes_rounded,
                                color: TallyTapTheme.textGray,
                                size: 18,
                              ),
                            ),
                            prefixIconConstraints: const BoxConstraints(
                                minWidth: 0, minHeight: 0),
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: TallyTapTheme.obsidianCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: TallyTapTheme.borderGreen),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.notes_rounded,
                                  color: TallyTapTheme.textGray, size: 16),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _notesController.text.isNotEmpty
                                      ? _notesController.text
                                      : 'No notes added.',
                                  style: TextStyle(
                                    color: _notesController.text.isNotEmpty
                                        ? TallyTapTheme.textLight
                                        : TallyTapTheme.textGray,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    fontStyle:
                                        _notesController.text.isEmpty
                                            ? FontStyle.italic
                                            : FontStyle.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_isEditing) ...[
                        const SizedBox(height: 24),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _finishLater = !_finishLater);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              color: TallyTapTheme.obsidianCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _finishLater ? activeColor : TallyTapTheme.borderGreen,
                                width: _finishLater ? 1.5 : 1.0,
                              ),
                              boxShadow: _finishLater ? [
                                BoxShadow(
                                  color: activeColor.withOpacity(0.15),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                )
                              ] : null,
                            ),
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: _finishLater ? activeColor : TallyTapTheme.obsidianBg.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: _finishLater ? activeColor : TallyTapTheme.textGray.withOpacity(0.5),
                                    ),
                                  ),
                                  child: _finishLater
                                      ? const Icon(Icons.check_rounded, size: 16, color: TallyTapTheme.obsidianBg)
                                      : null,
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  isIncome ? 'Verify Receipt' : 'Finish later',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: TallyTapTheme.textLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.fastOutSlowIn,
                          child: _finishLater
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () async {
                                            final picked = await showDatePicker(
                                              context: context,
                                              initialDate: _reminderDate,
                                              firstDate: DateTime.now(),
                                              lastDate: DateTime(2101),
                                              builder: (ctx, child) => Theme(
                                                  data: Theme.of(ctx).copyWith(
                                                    colorScheme: const ColorScheme.dark(
                                                      primary: TallyTapTheme.primaryMint,
                                                      onPrimary: TallyTapTheme.obsidianBg,
                                                      surface: TallyTapTheme.obsidianCard,
                                                      onSurface: TallyTapTheme.textLight,
                                                    ),
                                                  ),
                                                  child: child!),
                                            );
                                            if (picked != null) {
                                              setState(() => _reminderDate = picked);
                                            }
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
                                                Icon(Icons.notifications_active_outlined, color: activeColor, size: 18),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    DateFormat('MMM d, y').format(_reminderDate),
                                                    style: const TextStyle(
                                                      color: TallyTapTheme.textLight,
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 13,
                                                    ),
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
                                            final time = await showTimePicker(
                                              context: context,
                                              initialTime: _reminderTime,
                                              builder: (ctx, child) => Theme(
                                                  data: Theme.of(ctx).copyWith(
                                                    colorScheme: const ColorScheme.dark(
                                                      primary: TallyTapTheme.primaryMint,
                                                      onPrimary: TallyTapTheme.obsidianBg,
                                                      surface: TallyTapTheme.obsidianCard,
                                                      onSurface: TallyTapTheme.textLight,
                                                    ),
                                                  ),
                                                  child: child!),
                                            );
                                            if (time != null) {
                                              setState(() => _reminderTime = time);
                                            }
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
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    _reminderTime.format(context),
                                                    style: const TextStyle(
                                                      color: TallyTapTheme.textLight,
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // ── VERIFY RECEIPT BUTTON (view mode only) ──────────────────────
              if (!_isEditing && widget.transaction.needsVerification)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withOpacity(0.35),
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
                      icon: const Icon(Icons.verified_outlined, size: 22),
                      label: Text(
                        isIncome ? 'Verify Receipt' : 'Mark as Completed',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        
                        // Complete it
                        final tx = ExpenseTransaction(
                          id: widget.transaction.id,
                          amount: widget.transaction.amount,
                          merchant: widget.transaction.merchant,
                          date: widget.transaction.date,
                          paymentMethod: widget.transaction.paymentMethod,
                          category: widget.transaction.category,
                          notes: widget.transaction.notes,
                          paidTo: widget.transaction.paidTo,
                          needsVerification: false,
                          reminderDate: null,
                          wasFinishLater: true,
                          hideFromLedger: widget.transaction.hideFromLedger,
                          groupId: widget.transaction.groupId,
                        );

                        ref.read(transactionListProvider.notifier).updateTransaction(tx);
                        NotificationService.cancelNotification(tx.id);

                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('${isIncome ? "Receipt verified" : "Transaction completed"} successfully'),
                          backgroundColor: const Color(0xFF10B981),
                        ));
                      },
                    ),
                  ),
                ),

              // ── SAVE BUTTON (edit mode only) ───────────────────────────
              if (_isEditing)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        colors: [
                          TallyTapTheme.primaryMint,
                          Color(0xFF33C28A)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: TallyTapTheme.primaryMint.withOpacity(0.35),
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
                      label: const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _saveChanges();
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

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.category, required this.color});
  final String category;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            category,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourcePill extends StatelessWidget {
  const _SourcePill({required this.source, required this.color});
  final String source;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(TallyTapTheme.getIconForSource(source), color: color, size: 13),
          const SizedBox(width: 6),
          Text(
            source,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({
    required this.currency,
    required this.isEditing,
    required this.isIncome,
    required this.accentColor,
    required this.activeColor,
    required this.amountController,
    required this.merchantController,
    required this.selectedCategory,
  });

  final String currency;
  final bool isEditing;
  final bool isIncome;
  final Color accentColor;
  final Color activeColor;
  final TextEditingController amountController;
  final TextEditingController merchantController;
  final String selectedCategory;

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
            color: accentColor.withOpacity(0.06),
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

          // Amount row
          if (isEditing)
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
                      controller: amountController,
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: TallyTapTheme.textLight,
                        fontFamily: 'Outfit',
                        letterSpacing: -2,
                      ),
                      textAlign: TextAlign.left,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
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
                        if (val == null || val.trim().isEmpty) return 'Required';
                        if (double.tryParse(val) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                ),
              ],
            )
          else
            Text(
              '${isIncome ? '+' : '-'} $currency${double.tryParse(amountController.text)?.toStringAsFixed(2) ?? '0.00'}',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w900,
                color: isIncome
                    ? const Color(0xFF10B981)
                    : TallyTapTheme.textLight,
                letterSpacing: -1.5,
                fontFamily: 'Outfit',
              ),
            ),

          const SizedBox(height: 6),

          // Merchant label (view mode only)
          if (!isEditing)
            Text(
              merchantController.text.isNotEmpty
                  ? merchantController.text
                  : 'Unknown Merchant',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: TallyTapTheme.textGray,
              ),
            ),

          const SizedBox(height: 12),

          // Category + icon badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accentColor.withOpacity(0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  TallyTapTheme.getIconForCategory(selectedCategory, isIncome),
                  color: accentColor,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  selectedCategory,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
