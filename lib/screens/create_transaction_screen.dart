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
  ConsumerState<CreateTransactionScreen> createState() => _CreateTransactionScreenState();
}

class _CreateTransactionScreenState extends ConsumerState<CreateTransactionScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _merchantController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  bool _isIncome = false;
  
  String? _selectedCategory;
  String? _selectedPaymentMethod;

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  String _generateUuid() {
    final random = Random();
    final List<int> values = List<int>.generate(16, (i) => random.nextInt(256));
    
    // Set version to 4
    values[6] = (values[6] & 0x0f) | 0x40;
    // Set variant to RFC 4122
    values[8] = (values[8] & 0x3f) | 0x80;
    
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) {
        buffer.write('-');
      }
      buffer.write(values[i].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  Color _getColorForCategory(String cat) {
    if (_isIncome) return const Color(0xFF22C55E); // Green for Income
    return TallyTapTheme.getColorForCategory(cat);
  }

  IconData _getIconForCategory(String cat) {
    return TallyTapTheme.getIconForCategory(cat, _isIncome);
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
      if (!mounted) return;
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

  void _saveTransaction() {
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

      final categoryToSave = _isIncome ? 'Income' : (_selectedCategory ?? 'Other');
      final sourceToSave = _selectedPaymentMethod ?? 'Cash';
      final merchantToSave = _merchantController.text.trim().isNotEmpty 
          ? _merchantController.text.trim() 
          : (_isIncome ? 'Quick Income' : 'Quick Expense');

      final newTx = ExpenseTransaction(
        id: _generateUuid(),
        amount: parsedAmount,
        merchant: merchantToSave,
        date: _selectedDate,
        paymentMethod: sourceToSave,
        category: categoryToSave,
      );

      ref.read(transactionListProvider.notifier).addTransaction(newTx);
      
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_isIncome ? 'Income' : 'Expense'} logged successfully'),
          backgroundColor: TallyTapTheme.primaryMint,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);
    final categories = ref.watch(categoriesListProvider)
        .where((c) => c.toLowerCase() != 'income').toList(); // Filter out 'income' from regular categories list
    final sources = ref.watch(sourcesListProvider);

    // Initial default values if not selected
    if (_selectedCategory == null && categories.isNotEmpty) {
      _selectedCategory = categories.first;
    }
    if (_selectedPaymentMethod == null && sources.isNotEmpty) {
      _selectedPaymentMethod = sources.first;
    }

    final activeColor = _isIncome ? const Color(0xFF10B981) : TallyTapTheme.primaryMint;
    final accentColor = _isIncome ? const Color(0xFF10B981) : _getColorForCategory(_selectedCategory ?? 'Other');
    
    final formattedTime = DateFormat('h:mm a').format(_selectedDate);
    final shortFormattedDate = DateFormat('MMM d, y').format(_selectedDate);

    return Scaffold(
      backgroundColor: TallyTapTheme.obsidianBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: TallyTapTheme.textLight, size: 20),
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
                      
                      // Giant Amount Input
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
                                _getIconForCategory(_selectedCategory ?? 'Other'),
                                color: accentColor,
                                size: 36,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _amountController,
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                color: TallyTapTheme.textLight,
                                fontFamily: 'Outfit',
                                letterSpacing: -1.0,
                              ),
                              textAlign: TextAlign.center,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                prefixText: '$currency ',
                                prefixStyle: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: activeColor),
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
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),

                      // TRANSACTION TYPE TOGGLE (Expense vs Income)
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _isIncome = false;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: !_isIncome ? TallyTapTheme.obsidianCard : Colors.transparent,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: !_isIncome ? TallyTapTheme.primaryMint : TallyTapTheme.borderGreen,
                                    width: 1.2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    'EXPENSE',
                                    style: TextStyle(
                                      color: !_isIncome ? TallyTapTheme.primaryMint : TallyTapTheme.textGray,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _isIncome = true;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _isIncome ? TallyTapTheme.obsidianCard : Colors.transparent,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _isIncome ? const Color(0xFF10B981) : TallyTapTheme.borderGreen,
                                    width: 1.2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    'INCOME',
                                    style: TextStyle(
                                      color: _isIncome ? const Color(0xFF10B981) : TallyTapTheme.textGray,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Merchant / Title Input Field
                      TextFormField(
                        controller: _merchantController,
                        style: const TextStyle(color: TallyTapTheme.textLight, fontWeight: FontWeight.bold),
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Title / Description',
                          labelStyle: const TextStyle(color: TallyTapTheme.textGray, fontSize: 13, fontWeight: FontWeight.bold),
                          hintText: _isIncome ? 'e.g. Salary, Dividend, Gift' : 'e.g. Starbucks, Groceries, Rent',
                          hintStyle: const TextStyle(color: TallyTapTheme.textGray),
                          filled: true,
                          fillColor: TallyTapTheme.obsidianCard,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: TallyTapTheme.borderGreen),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: activeColor, width: 1.5),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // DETAILS BLOCK
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // CATEGORY Selection (Only show for Expense)
                              if (!_isIncome) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Category',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: TallyTapTheme.textGray,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: DropdownButtonFormField<String>(
                                          value: _selectedCategory,
                                          isExpanded: true,
                                          borderRadius: BorderRadius.circular(16),
                                          dropdownColor: TallyTapTheme.obsidianCard,
                                          style: const TextStyle(color: TallyTapTheme.textLight, fontSize: 14, fontWeight: FontWeight.bold),
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                          iconEnabledColor: TallyTapTheme.primaryMint,
                                          items: categories.map((String cat) {
                                            return DropdownMenuItem<String>(
                                              value: cat,
                                              child: Align(
                                                alignment: Alignment.centerRight,
                                                child: Text(cat),
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(() {
                                                _selectedCategory = val;
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(color: TallyTapTheme.borderGreen, height: 32, thickness: 0.5),
                              ],

                              // PAYMENT METHOD / SOURCE Selection
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _isIncome ? 'Deposit Destination' : 'Paid From / Source',
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
                                      child: DropdownButtonFormField<String>(
                                        value: _selectedPaymentMethod,
                                        isExpanded: true,
                                        borderRadius: BorderRadius.circular(16),
                                        dropdownColor: TallyTapTheme.obsidianCard,
                                        style: const TextStyle(color: TallyTapTheme.textLight, fontSize: 14, fontWeight: FontWeight.bold),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        iconEnabledColor: activeColor,
                                        items: sources.map((String src) {
                                          return DropdownMenuItem<String>(
                                            value: src,
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: Text(src),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() {
                                              _selectedPaymentMethod = val;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const Divider(color: TallyTapTheme.borderGreen, height: 32, thickness: 0.5),

                              // DATE & TIME row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Date & Time',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: TallyTapTheme.textGray,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: InkWell(
                                        onTap: () => _selectDateTime(context),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.calendar_month_outlined, color: activeColor, size: 16),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  '$shortFormattedDate, $formattedTime',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w800,
                                                    color: activeColor,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom CTA
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [activeColor, _isIncome ? const Color(0xFF059669) : const Color(0xFF33C28A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: activeColor.withOpacity(0.3),
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
                    _saveTransaction();
                  },
                  child: const Text(
                    'LOG TRANSACTION',
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
}
