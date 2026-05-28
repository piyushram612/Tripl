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

class TransactionDetailsScreen extends ConsumerStatefulWidget {
  final ExpenseTransaction transaction;

  const TransactionDetailsScreen({
    super.key,
    required this.transaction,
  });

  @override
  ConsumerState<TransactionDetailsScreen> createState() => _TransactionDetailsScreenState();
}

class _TransactionDetailsScreenState extends ConsumerState<TransactionDetailsScreen> {
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _merchantController;
  late TextEditingController _amountController;
  late DateTime _selectedDate;
  late String _selectedCategory;
  late String _selectedPaymentMethod;

  @override
  void initState() {
    super.initState();
    _merchantController = TextEditingController(text: widget.transaction.merchant);
    _amountController = TextEditingController(text: widget.transaction.amount.toStringAsFixed(2));
    _selectedDate = widget.transaction.date;
    _selectedCategory = widget.transaction.category;
    _selectedPaymentMethod = widget.transaction.paymentMethod;
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Color _getColorForCategory(String cat) {
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
    return TallyTapTheme.primaryMint;
  }

  IconData _getIconForCategory(String cat, bool isIncome) {
    if (isIncome) return Icons.arrow_downward_rounded;
    final clean = cat.toLowerCase();
    if (clean.contains('dining') || clean.contains('food') || clean.contains('dinner') || clean.contains('restaurant')) {
      return Icons.local_cafe_outlined;
    } else if (clean.contains('commute') || clean.contains('transport') || clean.contains('car') || clean.contains('cab')) {
      return Icons.directions_transit_filled_outlined;
    } else if (clean.contains('sub') || clean.contains('subscriptions') || clean.contains('entertainment')) {
      return Icons.subscriptions_outlined;
    } else if (clean.contains('utility') || clean.contains('bill') || clean.contains('electricity')) {
      return Icons.bolt_outlined;
    } else {
      return Icons.local_mall_outlined;
    }
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: TallyTapTheme.primaryMint,
              onPrimary: TallyTapTheme.obsidianBg,
              surface: TallyTapTheme.obsidianCard,
              onSurface: TallyTapTheme.textLight,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: TallyTapTheme.primaryMint,
                onPrimary: TallyTapTheme.obsidianBg,
                surface: TallyTapTheme.obsidianCard,
                onSurface: TallyTapTheme.textLight,
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  void _saveChanges() {
    if (_formKey.currentState!.validate()) {
      final double? parsedAmount = double.tryParse(_amountController.text);
      if (parsedAmount == null || parsedAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid amount'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        return;
      }

      final updatedTx = ExpenseTransaction(
        id: widget.transaction.id,
        amount: parsedAmount,
        merchant: _merchantController.text.trim(),
        date: _selectedDate,
        paymentMethod: _selectedPaymentMethod,
        category: _selectedCategory,
      );

      ref.read(transactionListProvider.notifier).updateTransaction(updatedTx);
      
      setState(() {
        _isEditing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction updated successfully'),
          backgroundColor: TallyTapTheme.primaryMint,
        ),
      );
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: TallyTapTheme.obsidianCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: TallyTapTheme.borderGreen, width: 1.0),
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
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: TallyTapTheme.primaryMint,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: () {
                ref.read(transactionListProvider.notifier).deleteTransaction(widget.transaction.id);
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(this.context).pop(); // Back to list screen
                
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Transaction deleted successfully'),
                    backgroundColor: Color(0xFFEF4444),
                  ),
                );
              },
              child: const Text(
                'Delete',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);
    final categories = ref.watch(categoriesListProvider);
    final sources = ref.watch(sourcesListProvider);

    final isIncome = _selectedCategory.toLowerCase() == 'income';
    final accentColor = _getColorForCategory(_selectedCategory);
    final formattedDate = DateFormat('EEEE, MMMM d, y').format(_selectedDate);
    final formattedTime = DateFormat('h:mm a').format(_selectedDate);
    final shortFormattedDate = DateFormat('MMM d, y').format(_selectedDate);

    // If active categories/sources do not contain current selected, temporarily add to avoid dropdown errors
    final dropdownCategories = List<String>.from(categories);
    if (!dropdownCategories.contains(_selectedCategory)) {
      dropdownCategories.add(_selectedCategory);
    }
    final dropdownSources = List<String>.from(sources);
    if (!dropdownSources.contains(_selectedPaymentMethod)) {
      dropdownSources.add(_selectedPaymentMethod);
    }

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
              _isEditing ? Icons.close_rounded : Icons.edit_note_rounded,
              color: TallyTapTheme.primaryMint,
              size: _isEditing ? 24 : 28,
            ),
            onPressed: () {
              HapticFeedback.mediumImpact();
              setState(() {
                if (_isEditing) {
                  // Reset form inputs to original values on cancel
                  _merchantController.text = widget.transaction.merchant;
                  _amountController.text = widget.transaction.amount.toStringAsFixed(2);
                  _selectedDate = widget.transaction.date;
                  _selectedCategory = widget.transaction.category;
                  _selectedPaymentMethod = widget.transaction.paymentMethod;
                }
                _isEditing = !_isEditing;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
            onPressed: () {
              HapticFeedback.vibrate();
              _confirmDelete();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      // Header Section with Giant Amount
                      Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.08),
                                shape: BoxShape.circle,
                                border: Border.all(color: accentColor.withOpacity(0.2), width: 1.0),
                              ),
                              child: Icon(
                                _getIconForCategory(_selectedCategory, isIncome),
                                color: accentColor,
                                size: 36,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (!_isEditing) ...[
                              Text(
                                '${isIncome ? '+' : '-'} $currency${double.tryParse(_amountController.text)?.toStringAsFixed(2) ?? widget.transaction.amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w900,
                                  color: isIncome ? const Color(0xFF10B981) : TallyTapTheme.textLight,
                                  letterSpacing: -1.5,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _merchantController.text.isNotEmpty
                                    ? _merchantController.text
                                    : 'Unknown Merchant',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: TallyTapTheme.textGray,
                                ),
                              ),
                            ] else ...[
                              // Editable Merchant & Amount fields
                              TextFormField(
                                controller: _amountController,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: TallyTapTheme.textLight,
                                  fontFamily: 'Outfit',
                                ),
                                textAlign: TextAlign.center,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  prefixText: '$currency ',
                                  prefixStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: TallyTapTheme.primaryMint),
                                  hintText: '0.00',
                                  hintStyle: TextStyle(color: TallyTapTheme.textGray.withOpacity(0.4)),
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Required';
                                  if (double.tryParse(val) == null) return 'Invalid number';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: 220,
                                child: TextFormField(
                                  controller: _merchantController,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: TallyTapTheme.textLight,
                                  ),
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    hintText: 'Merchant Name',
                                    hintStyle: TextStyle(color: TallyTapTheme.textGray.withOpacity(0.5)),
                                    border: InputBorder.none,
                                    isDense: true,
                                    focusedBorder: const UnderlineInputBorder(
                                      borderSide: BorderSide(color: TallyTapTheme.primaryMint, width: 1.0),
                                    ),
                                    enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(color: TallyTapTheme.borderGreen.withOpacity(0.5), width: 1.0),
                                    ),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) return 'Merchant is required';
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Details Block Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // CATEGORY row
                              _buildMetaRow(
                                label: 'Category',
                                valueWidget: _isEditing
                                    ? DropdownButtonFormField<String>(
                                        value: _selectedCategory,
                                        dropdownColor: TallyTapTheme.obsidianCard,
                                        style: const TextStyle(color: TallyTapTheme.textLight, fontSize: 14, fontWeight: FontWeight.bold),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        iconEnabledColor: TallyTapTheme.primaryMint,
                                        items: dropdownCategories.map((String cat) {
                                          return DropdownMenuItem<String>(
                                            value: cat,
                                            child: Text(cat),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() {
                                              _selectedCategory = val;
                                            });
                                          }
                                        },
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(shape: BoxShape.circle, color: accentColor),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _selectedCategory,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: TallyTapTheme.textLight,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                              const Divider(color: TallyTapTheme.borderGreen, height: 32, thickness: 0.5),

                              // PAYMENT METHOD row
                              _buildMetaRow(
                                label: 'Source',
                                valueWidget: _isEditing
                                    ? DropdownButtonFormField<String>(
                                        value: _selectedPaymentMethod,
                                        dropdownColor: TallyTapTheme.obsidianCard,
                                        style: const TextStyle(color: TallyTapTheme.textLight, fontSize: 14, fontWeight: FontWeight.bold),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        iconEnabledColor: TallyTapTheme.primaryMint,
                                        items: dropdownSources.map((String src) {
                                          return DropdownMenuItem<String>(
                                            value: src,
                                            child: Text(src),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() {
                                              _selectedPaymentMethod = val;
                                            });
                                          }
                                        },
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.account_balance_wallet_outlined, color: TallyTapTheme.textGray, size: 14),
                                          const SizedBox(width: 8),
                                          Text(
                                            _selectedPaymentMethod,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: TallyTapTheme.textLight,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                              const Divider(color: TallyTapTheme.borderGreen, height: 32, thickness: 0.5),

                              // DATE & TIME row
                              _buildMetaRow(
                                label: 'Date & Time',
                                valueWidget: _isEditing
                                    ? InkWell(
                                        onTap: () => _selectDateTime(context),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.calendar_month_outlined, color: TallyTapTheme.primaryMint, size: 16),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  '$shortFormattedDate, $formattedTime',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w800,
                                                    color: TallyTapTheme.primaryMint,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    : Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            formattedDate,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: TallyTapTheme.textLight,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            formattedTime,
                                            style: const TextStyle(
                                              fontSize: 12,
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
                      const SizedBox(height: 24),

                      // Premium insight or context card if viewing
                      if (!_isEditing) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F2B20),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF144D37)),
                                  ),
                                  child: const Icon(
                                    Icons.lightbulb_outline_rounded,
                                    color: TallyTapTheme.primaryMint,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Reflected instantly!',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: TallyTapTheme.textLight),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'All edits sync dynamically with internal widgets, budget lines, and active insights.',
                                        style: TextStyle(fontSize: 11, color: TallyTapTheme.textGray, height: 1.3),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Floating Bottom Button in Edit Mode
            if (_isEditing)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [TallyTapTheme.primaryMint, Color(0xFF33C28A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: TallyTapTheme.primaryMint.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: TallyTapTheme.obsidianBg,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _saveChanges();
                    },
                    child: const Text(
                      'SAVE CHANGES',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow({required String label, required Widget valueWidget}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: TallyTapTheme.textGray,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: valueWidget,
          ),
        ),
      ],
    );
  }
}
