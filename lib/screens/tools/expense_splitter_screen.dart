import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/transaction_model.dart';
import '../../services/transaction_service.dart';
import 'dart:ui';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/tutorial_service.dart';
import '../../providers/tutorial_provider.dart';
import '../../providers/source_provider.dart';
import '../../providers/currency_provider.dart';

enum SplitMode { equal, custom, itemized }

class SplitItem {
  TextEditingController nameController;
  TextEditingController priceController;
  List<int> assignedParticipants;

  SplitItem({String name = "", double price = 0.0, required this.assignedParticipants})
      : nameController = TextEditingController(text: name),
        priceController = TextEditingController(text: price > 0 ? price.toString() : "");

  double get price => double.tryParse(priceController.text) ?? 0.0;
  String get name => nameController.text;

  void dispose() {
    nameController.dispose();
    priceController.dispose();
  }
}

class ExpenseSplitterScreen extends ConsumerStatefulWidget {
  const ExpenseSplitterScreen({super.key});

  @override
  ConsumerState<ExpenseSplitterScreen> createState() => _ExpenseSplitterScreenState();
}

class _ExpenseSplitterScreenState extends ConsumerState<ExpenseSplitterScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descController = TextEditingController(text: "Restaurant Outing");
  int _peopleCount = 4;
  final List<TextEditingController> _friendControllers = [];
  final List<bool> _friendVerificationFlags = [];
  TutorialCoachMark? tutorialCoachMark;

  SplitMode _currentSplitMode = SplitMode.equal;
  bool _isPercentageMode = false;
  
  List<double> _customValues = []; 
  List<bool> _customLocks = [];
  List<TextEditingController> _customValueControllers = [];
  
  List<SplitItem> _items = [];

  String? _selectedPaymentSource;
  String? _globalReceiptSource;
  final List<String?> _friendReceiptSources = [];

  @override
  void initState() {
    super.initState();
    _updateFriendControllers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkTutorialStatus();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    for (final controller in _friendControllers) {
      controller.dispose();
    }
    for (final controller in _customValueControllers) {
      controller.dispose();
    }
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _resetCustomValues() {
    if (_peopleCount <= 0) return;
    _customValues = List.filled(_peopleCount, 100.0 / _peopleCount);
    _customLocks = List.filled(_peopleCount, false);
    
    for (final controller in _customValueControllers) {
      controller.dispose();
    }
    _customValueControllers = [];
    for (int i = 0; i < _peopleCount; i++) {
      _customValueControllers.add(TextEditingController());
    }
    _syncCustomValueControllers();
  }

  void _syncCustomValueControllers() {
    for (int i = 0; i < _peopleCount; i++) {
      if (i < _customValueControllers.length && i < _customValues.length) {
        double val = _isPercentageMode ? _customValues[i] : (_customValues[i] * _totalAmount / 100.0);
        String valStr = val.toStringAsFixed(1);
        if (_customValueControllers[i].text != valStr) {
          _customValueControllers[i].value = TextEditingValue(
            text: valStr,
            selection: TextSelection.collapsed(offset: valStr.length)
          );
        }
      }
    }
  }

  void _updateFriendControllers() {
    final requiredFriends = _peopleCount - 1;
    if (_friendControllers.length < requiredFriends) {
      while (_friendControllers.length < requiredFriends) {
        final index = _friendControllers.length + 1;
        _friendControllers.add(TextEditingController(text: "Friend $index"));
        _friendVerificationFlags.add(false);
        _friendReceiptSources.add(null);
      }
    } else if (_friendControllers.length > requiredFriends) {
      while (_friendControllers.length > requiredFriends) {
        final controller = _friendControllers.removeLast();
        controller.dispose();
        _friendVerificationFlags.removeLast();
        _friendReceiptSources.removeLast();
      }
    }
    
    if (_customValues.length != _peopleCount) {
      _resetCustomValues();
    }
    
    for (var item in _items) {
      item.assignedParticipants.removeWhere((idx) => idx >= _peopleCount);
    }
  }

  double get _totalAmount {
    return double.tryParse(_amountController.text) ?? 0.0;
  }

  List<double> get _finalAmounts {
    List<double> amounts = List.filled(_peopleCount, 0.0);
    double total = _totalAmount;
    if (total <= 0) return amounts;
    
    if (_currentSplitMode == SplitMode.equal) {
        double val = _peopleCount > 0 ? total / _peopleCount : 0.0;
        amounts = List.filled(_peopleCount, val);
    } else if (_currentSplitMode == SplitMode.custom) {
        for (int i = 0; i < _peopleCount; i++) {
            amounts[i] = total * (_customValues[i] / 100.0);
        }
    } else if (_currentSplitMode == SplitMode.itemized) {
        for (var item in _items) {
            if (item.assignedParticipants.isNotEmpty) {
                double split = item.price / item.assignedParticipants.length;
                for (var idx in item.assignedParticipants) {
                    if (idx < _peopleCount) {
                        amounts[idx] += split;
                    }
                }
            }
        }
    }
    return amounts;
  }

  bool get _isValidSplit {
     if (_totalAmount <= 0) return false;
     if (_currentSplitMode == SplitMode.equal) return true;
     if (_currentSplitMode == SplitMode.custom) {
         double sum = _customValues.fold(0.0, (a, b) => a + b);
         return (sum - 100.0).abs() < 0.1; 
     }
     if (_currentSplitMode == SplitMode.itemized) {
         double sum = _items.fold(0.0, (a, b) => a + b.price);
         return (sum - _totalAmount).abs() < 0.1;
     }
     return true;
  }
  
  String get _validationWarning {
     if (_currentSplitMode == SplitMode.custom) {
         double sum = _customValues.fold(0.0, (a, b) => a + b);
         if ((sum - 100.0).abs() >= 0.1) {
            return "Percentages must sum to 100%. Currently: ${sum.toStringAsFixed(1)}%";
         }
     }
     if (_currentSplitMode == SplitMode.itemized) {
         double sum = _items.fold(0.0, (a, b) => a + b.price);
         if ((sum - _totalAmount).abs() >= 0.1) {
            return "Items total (₹${sum.toStringAsFixed(2)}) does not match Bill total (₹${_totalAmount.toStringAsFixed(2)})";
         }
     }
     return "";
  }

  void _onCustomValueChanged(int index, double newRawValue) {
      if (_customLocks[index]) return;
      HapticFeedback.selectionClick();
      
      double newValue = newRawValue;
      if (newValue < 0) newValue = 0;
      if (newValue > 100) newValue = 100;

      double oldVal = _customValues[index];
      double diff = newValue - oldVal;
      _customValues[index] = newValue;
      
      int unlockedCount = 0;
      double unlockedSum = 0;
      for (int i = 0; i < _peopleCount; i++) {
          if (i != index && !_customLocks[i]) {
              unlockedCount++;
              unlockedSum += _customValues[i];
          }
      }
      
      if (unlockedCount > 0) {
          for (int i = 0; i < _peopleCount; i++) {
              if (i != index && !_customLocks[i]) {
                  if (unlockedSum > 0) {
                      double proportion = _customValues[i] / unlockedSum;
                      _customValues[i] -= (diff * proportion);
                  } else {
                      _customValues[i] -= (diff / unlockedCount);
                  }
                  if (_customValues[i] < 0) _customValues[i] = 0;
                  if (_customValues[i] > 100) _customValues[i] = 100;
              }
          }
      }
      
      _syncCustomValueControllers();
      setState((){});
  }

  void _logGroupSplit() async {
    if (!_isValidSplit) return;

    HapticFeedback.heavyImpact();

    final groupDesc = _descController.text.trim();
    final groupName = groupDesc.isEmpty ? "Group Outing" : groupDesc;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final generatedGroupId = "group_${timestamp}_$groupName";

    final listNotifier = ref.read(transactionListProvider.notifier);
    final amounts = _finalAmounts;

    String mainNotes = "Group Split total paid";
    if (_currentSplitMode == SplitMode.itemized && _items.isNotEmpty) {
      mainNotes += "\n\nItemized Receipt:\n";
      for (var item in _items) {
        if (item.name.isNotEmpty) {
          String names = item.assignedParticipants.map((idx) {
             if (idx == 0) return "You";
             return _friendControllers[idx-1].text.trim().isEmpty ? "Friend $idx" : _friendControllers[idx-1].text.trim();
          }).join(", ");
          if (names.isEmpty) names = "Unassigned";
          mainNotes += "${item.name}:::${item.price.toStringAsFixed(2)}:::$names\n";
        }
      }
    }

    // 1. Create main expense paid by "You"
    final mainTx = ExpenseTransaction(
      id: "tx_${timestamp}_main",
      amount: _totalAmount,
      merchant: "$groupName (Paid by You)",
      date: DateTime.now(),
      paymentMethod: _selectedPaymentSource ?? "Card",
      category: "Dining",
      notes: mainNotes,
      groupId: generatedGroupId,
    );
    await listNotifier.addTransaction(mainTx);

    // 2. Create incomes for other friends
    for (int i = 0; i < _friendControllers.length; i++) {
      if (amounts[i+1] <= 0) continue; // Don't create transaction if they owe nothing

      final friendName = _friendControllers[i].text.trim();
      final name = friendName.isEmpty ? "Friend ${i + 1}" : friendName;

      final repaymentTx = ExpenseTransaction(
        id: "tx_${timestamp}_friend_$i",
        amount: amounts[i+1],
        merchant: "Split repayment from $name",
        date: DateTime.now(),
        paymentMethod: _friendReceiptSources[i] ?? _globalReceiptSource ?? "UPI",
        category: "Income",
        notes: "Group Split share",
        needsVerification: _friendVerificationFlags[i],
        wasFinishLater: _friendVerificationFlags[i],
        groupId: generatedGroupId,
        isIncome: true,
      );
      await listNotifier.addTransaction(repaymentTx);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logged "$groupName" split directly into timeline group!'),
          backgroundColor: TallyTapTheme.borderGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    double youGetBack = _totalAmount - _finalAmounts[0];
    if (youGetBack < 0) youGetBack = 0;

    final sources = ref.watch(sourcesListProvider);
    final allTx = ref.watch(transactionListProvider);
    final startingBalances = ref.watch(sourceStartingBalancesProvider);
    final currency = ref.watch(currencyProvider);

    if (_selectedPaymentSource == null && sources.isNotEmpty) {
      _selectedPaymentSource = sources.first;
    }
    if (_globalReceiptSource == null && sources.isNotEmpty) {
      _globalReceiptSource = sources.first;
    }

    return Scaffold(
      backgroundColor: TallyTapTheme.obsidianBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: TallyTapTheme.textLight),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Expense Splitter',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: TallyTapTheme.textLight,
            fontFamily: 'Outfit',
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Split Results Panel
                Container(
                  key: TutorialService.splitterResultKey,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        TallyTapTheme.primaryMint.withOpacity(0.12),
                        TallyTapTheme.primaryMint.withOpacity(0.02),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: TallyTapTheme.primaryMint.withOpacity(0.4), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'YOU GET BACK',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: TallyTapTheme.primaryMint,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '₹',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: TallyTapTheme.primaryMint,
                              height: 1.2,
                            ),
                          ),
                          Text(
                            youGetBack.toStringAsFixed(2),
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              color: TallyTapTheme.textLight,
                              height: 1.0,
                              letterSpacing: -1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'You paid ₹${_totalAmount.toStringAsFixed(2)} • Your share is ₹${_finalAmounts[0].toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 11, color: TallyTapTheme.textGray, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Details Configuration
                const Text(
                  'SPLIT PARAMETERS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: TallyTapTheme.textGray,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),

                // Description card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Description',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: TallyTapTheme.textLight),
                        ),
                        SizedBox(
                          width: 180,
                          child: TextField(
                            controller: _descController,
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: TallyTapTheme.textLight,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'e.g. Restaurant split',
                              hintStyle: TextStyle(color: TallyTapTheme.textGray),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Amount paid card
                Card(
                  key: TutorialService.splitterAmountKey,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'You Paid Total',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: TallyTapTheme.textLight),
                        ),
                        SizedBox(
                          width: 150,
                          child: TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: TallyTapTheme.primaryMint,
                            ),
                            decoration: InputDecoration(
                              hintText: '0.00',
                              hintStyle: TextStyle(color: TallyTapTheme.primaryMint.withOpacity(0.5)),
                              prefixText: '₹ ',
                              prefixStyle: const TextStyle(color: TallyTapTheme.primaryMint, fontWeight: FontWeight.bold),
                              border: InputBorder.none,
                            ),
                            onChanged: (val) {
                              _syncCustomValueControllers();
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Total People Counter card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total People',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: TallyTapTheme.textLight),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline_rounded, color: TallyTapTheme.textGray),
                              onPressed: _peopleCount <= 2
                                  ? null
                                  : () {
                                      HapticFeedback.lightImpact();
                                      setState(() {
                                        _peopleCount--;
                                        _updateFriendControllers();
                                      });
                                    },
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                '$_peopleCount',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: TallyTapTheme.textLight,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline_rounded, color: TallyTapTheme.primaryMint),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _peopleCount++;
                                  _updateFriendControllers();
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // SPLIT MODE SELECTOR
                const Text(
                  'SPLIT MODE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: TallyTapTheme.textGray,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                
                Container(
                  key: TutorialService.splitterModesKey,
                  decoration: BoxDecoration(
                    color: TallyTapTheme.obsidianCard,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(child: _buildModeTab("Equally", SplitMode.equal, Icons.pie_chart_outline)),
                      Expanded(child: _buildModeTab("Custom", SplitMode.custom, Icons.tune_rounded)),
                      Expanded(child: _buildModeTab("Items", SplitMode.itemized, Icons.receipt_long_rounded)),
                    ]
                  )
                ),
                const SizedBox(height: 24),

                // MODE SPECIFIC UI
                if (_currentSplitMode == SplitMode.custom) _buildCustomModeUI(),
                if (_currentSplitMode == SplitMode.itemized) _buildItemizedModeUI(),

                if (_currentSplitMode != SplitMode.equal) const SizedBox(height: 24),

                // Friends Names customizer
                const Text(
                  'PARTICIPANTS & VERIFICATION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: TallyTapTheme.textGray,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),

                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _peopleCount,
                  itemBuilder: (context, index) {
                    double amt = _finalAmounts[index];
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Card(
                          color: TallyTapTheme.obsidianCard.withOpacity(0.5),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: TallyTapTheme.primaryMint,
                              radius: 14,
                              child: Icon(Icons.person, color: TallyTapTheme.obsidianBg, size: 16),
                            ),
                            title: const Text(
                              'You (Payee)',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: TallyTapTheme.primaryMint),
                            ),
                            trailing: Text(
                              '₹ ${amt.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 13, color: TallyTapTheme.textGray),
                            ),
                          ),
                        ),
                      );
                    }

                    final friendIdx = index - 1;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: TallyTapTheme.borderGreen,
                                    radius: 14,
                                    child: Text(
                                      'F$index',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: TallyTapTheme.textGray),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: _friendControllers[friendIdx],
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: TallyTapTheme.textLight),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        hintText: 'Friend Name'
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '₹${amt.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: TallyTapTheme.textLight),
                                  ),
                                ],
                              ),
                              const Divider(color: TallyTapTheme.borderGreen, height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.pending_actions_rounded,
                                        size: 16,
                                        color: _friendVerificationFlags[friendIdx] ? const Color(0xFFF59E0B) : TallyTapTheme.textGray,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Needs Verification',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _friendVerificationFlags[friendIdx] ? const Color(0xFFF59E0B) : TallyTapTheme.textGray,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Switch(
                                    value: _friendVerificationFlags[friendIdx],
                                    activeColor: const Color(0xFFF59E0B),
                                    inactiveTrackColor: TallyTapTheme.obsidianBg,
                                    onChanged: (val) {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        _friendVerificationFlags[friendIdx] = val;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Receipt Source',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: TallyTapTheme.textGray),
                                  ),
                                  DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _friendReceiptSources[friendIdx] ?? _globalReceiptSource,
                                      dropdownColor: TallyTapTheme.obsidianCard,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: TallyTapTheme.primaryMint),
                                      icon: const Icon(Icons.arrow_drop_down_rounded, color: TallyTapTheme.primaryMint, size: 20),
                                      isDense: true,
                                      items: sources.map((String source) {
                                        return DropdownMenuItem<String>(
                                          value: source,
                                          child: Text(source),
                                        );
                                      }).toList(),
                                      onChanged: (String? newValue) {
                                        setState(() {
                                          _friendReceiptSources[friendIdx] = newValue;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 32),

                _buildSourceSelector(
                  title: 'PAYMENT SOURCE (YOU PAID VIA)',
                  sources: sources,
                  selectedSource: _selectedPaymentSource,
                  onSelected: (val) => setState(() => _selectedPaymentSource = val),
                  allTx: allTx,
                  startingBalances: startingBalances,
                  currency: currency,
                ),
                
                const SizedBox(height: 24),
                
                _buildSourceSelector(
                  title: 'GLOBAL RECEIPT SOURCE (REPAYMENT VIA)',
                  sources: sources,
                  selectedSource: _globalReceiptSource,
                  onSelected: (val) => setState(() => _globalReceiptSource = val),
                  allTx: allTx,
                  startingBalances: startingBalances,
                  currency: currency,
                ),

                const SizedBox(height: 32),

                // Button: Log group split
                ElevatedButton.icon(
                  onPressed: _isValidSplit ? _logGroupSplit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TallyTapTheme.primaryMint,
                    disabledBackgroundColor: TallyTapTheme.primaryMint.withOpacity(0.3),
                    foregroundColor: TallyTapTheme.obsidianBg,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.cloud_upload_rounded),
                  label: const Text(
                    'Log Split in Timeline Group',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
  
  Widget _buildWarningBanner() {
      if (_isValidSplit || _validationWarning.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
           padding: const EdgeInsets.all(12),
           decoration: BoxDecoration(
             color: Colors.redAccent.withOpacity(0.1),
             borderRadius: BorderRadius.circular(12),
             border: Border.all(color: Colors.redAccent.withOpacity(0.5))
           ),
           child: Row(
             children: [
               const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
               const SizedBox(width: 12),
               Expanded(
                 child: Text(
                   _validationWarning,
                   style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)
                 )
               )
             ]
           )
        )
      );
  }

  Widget _buildModeTab(String title, SplitMode mode, IconData icon) {
     bool isSelected = _currentSplitMode == mode;
     return GestureDetector(
        onTap: () {
           HapticFeedback.lightImpact();
           setState(() => _currentSplitMode = mode);
        },
        child: AnimatedContainer(
           duration: const Duration(milliseconds: 200),
           padding: const EdgeInsets.symmetric(vertical: 12),
           decoration: BoxDecoration(
              color: isSelected ? TallyTapTheme.primaryMint.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? TallyTapTheme.primaryMint.withOpacity(0.5) : Colors.transparent)
           ),
           child: Column(
              children: [
                 Icon(icon, size: 20, color: isSelected ? TallyTapTheme.primaryMint : TallyTapTheme.textGray),
                 const SizedBox(height: 4),
                 Text(title, style: TextStyle(
                    fontSize: 12, 
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? TallyTapTheme.primaryMint : TallyTapTheme.textGray
                 ))
              ]
           )
        )
     );
  }
  
  Widget _buildCustomModeUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_isValidSplit) _buildWarningBanner(),
        Row(
           mainAxisAlignment: MainAxisAlignment.spaceBetween,
           children: [
              const Text(
                 'CUSTOM SLIDERS',
                 style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: TallyTapTheme.textGray, letterSpacing: 1.5),
              ),
              Row(
                 children: [
                     Text("Amount", style: TextStyle(fontSize: 12, color: !_isPercentageMode ? TallyTapTheme.textLight : TallyTapTheme.textGray)),
                     Switch(
                        value: _isPercentageMode,
                        activeColor: TallyTapTheme.primaryMint,
                        inactiveThumbColor: TallyTapTheme.primaryMint,
                        inactiveTrackColor: TallyTapTheme.obsidianCard,
                        onChanged: (v) {
                           HapticFeedback.selectionClick();
                           setState(() {
                               _isPercentageMode = v;
                               _syncCustomValueControllers();
                           });
                        }
                     ),
                     Text("Percent", style: TextStyle(fontSize: 12, color: _isPercentageMode ? TallyTapTheme.textLight : TallyTapTheme.textGray)),
                 ]
              )
           ]
        ),
        const SizedBox(height: 8),
        ...List.generate(_peopleCount, (index) {
            String name = index == 0 ? "You" : _friendControllers[index-1].text;
            if (name.isEmpty) name = "F$index";
            
            return Padding(
               padding: const EdgeInsets.only(bottom: 8.0),
               child: Card(
                  child: Padding(
                     padding: const EdgeInsets.all(16),
                     child: Column(
                        children: [
                            Row(
                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
                               children: [
                                   Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: TallyTapTheme.textLight)),
                                   Row(
                                      children: [
                                         Container(
                                            width: 80,
                                            height: 36,
                                            decoration: BoxDecoration(
                                               color: TallyTapTheme.obsidianBg,
                                               borderRadius: BorderRadius.circular(8)
                                            ),
                                            alignment: Alignment.centerRight,
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            child: Focus(
                                              onFocusChange: (hasFocus) {
                                                if (!hasFocus) {
                                                  String val = _customValueControllers[index].text;
                                                  double numVal = double.tryParse(val) ?? 0.0;
                                                  double newPct = _isPercentageMode ? numVal : (numVal / _totalAmount * 100.0);
                                                  _onCustomValueChanged(index, newPct);
                                                }
                                              },
                                              child: TextField(
                                                  controller: _customValueControllers[index],
                                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                  textAlign: TextAlign.right,
                                                  style: const TextStyle(fontWeight: FontWeight.w900, color: TallyTapTheme.primaryMint, fontSize: 16),
                                                  decoration: InputDecoration(
                                                     border: InputBorder.none,
                                                     suffixText: _isPercentageMode ? "%" : "",
                                                     prefixText: !_isPercentageMode ? "₹" : "",
                                                     prefixStyle: const TextStyle(color: TallyTapTheme.primaryMint, fontWeight: FontWeight.bold),
                                                     suffixStyle: const TextStyle(color: TallyTapTheme.primaryMint, fontWeight: FontWeight.bold),
                                                  ),
                                                  onSubmitted: (val) {
                                                      double numVal = double.tryParse(val) ?? 0.0;
                                                      double newPct = _isPercentageMode ? numVal : (numVal / _totalAmount * 100.0);
                                                      _onCustomValueChanged(index, newPct);
                                                  },
                                              ),
                                            )
                                         ),
                                         const SizedBox(width: 8),
                                         GestureDetector(
                                            onTap: () {
                                                HapticFeedback.lightImpact();
                                                setState(() => _customLocks[index] = !_customLocks[index]);
                                            },
                                            child: Icon(_customLocks[index] ? Icons.lock_rounded : Icons.lock_open_rounded, 
                                              color: _customLocks[index] ? TallyTapTheme.primaryMint : TallyTapTheme.textGray, size: 24),
                                         )
                                      ]
                                   )
                               ]
                            ),
                            const SizedBox(height: 8),
                            Row(
                               children: [
                                   GestureDetector(
                                       onTap: () {
                                           double current = _isPercentageMode ? _customValues[index] : (_customValues[index] * _totalAmount / 100.0);
                                           double nextVal = current - 1.0;
                                           if (nextVal < 0) nextVal = 0;
                                           double newPct = _isPercentageMode ? nextVal : (nextVal / _totalAmount * 100.0);
                                           _onCustomValueChanged(index, newPct);
                                       },
                                       child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(shape: BoxShape.circle, color: TallyTapTheme.obsidianBg),
                                          child: const Icon(Icons.remove, size: 16, color: TallyTapTheme.textGray)
                                       )
                                   ),
                                   Expanded(
                                       child: SliderTheme(
                                          data: const SliderThemeData(
                                             trackHeight: 4,
                                             thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
                                             overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
                                          ),
                                          child: Slider(
                                             value: _customValues[index],
                                             min: 0,
                                             max: 100,
                                             activeColor: _customLocks[index] ? TallyTapTheme.primaryMint.withOpacity(0.5) : TallyTapTheme.primaryMint,
                                             inactiveColor: TallyTapTheme.borderGreen,
                                             onChanged: (newVal) => _onCustomValueChanged(index, newVal),
                                          )
                                       )
                                   ),
                                   GestureDetector(
                                       onTap: () {
                                           double current = _isPercentageMode ? _customValues[index] : (_customValues[index] * _totalAmount / 100.0);
                                           double nextVal = current + 1.0;
                                           double maxVal = _isPercentageMode ? 100.0 : _totalAmount;
                                           if (nextVal > maxVal) nextVal = maxVal;
                                           double newPct = _isPercentageMode ? nextVal : (nextVal / _totalAmount * 100.0);
                                           _onCustomValueChanged(index, newPct);
                                       },
                                       child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(shape: BoxShape.circle, color: TallyTapTheme.obsidianBg),
                                          child: const Icon(Icons.add, size: 16, color: TallyTapTheme.textGray)
                                       )
                                   ),
                               ]
                            )
                        ]
                     )
                  )
               )
            );
        })
      ]
    );
  }

  Widget _buildItemizedModeUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_isValidSplit) _buildWarningBanner(),
        Row(
           mainAxisAlignment: MainAxisAlignment.spaceBetween,
           children: [
              const Text(
                 'ITEMIZED LIST',
                 style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: TallyTapTheme.textGray, letterSpacing: 1.5),
              ),
              TextButton.icon(
                 icon: const Icon(Icons.add_circle_outline, size: 16),
                 label: const Text("Add Item"),
                 style: TextButton.styleFrom(foregroundColor: TallyTapTheme.primaryMint),
                 onPressed: () {
                     HapticFeedback.lightImpact();
                     setState(() => _items.add(SplitItem(name: "", price: 0.0, assignedParticipants: [])));
                 }
              )
           ]
        ),
        const SizedBox(height: 8),
        if (_items.isEmpty)
           Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: const Text("No items added. Tap 'Add Item' to start.", style: TextStyle(color: TallyTapTheme.textGray))
           ),
        ..._items.asMap().entries.map((entry) {
          int itemIdx = entry.key;
          SplitItem item = entry.value;
          return Card(
             margin: const EdgeInsets.only(bottom: 12),
             child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                   crossAxisAlignment: CrossAxisAlignment.stretch,
                   children: [
                       Row(
                         children: [
                            Expanded(child: TextField(
                               controller: item.nameController,
                               style: const TextStyle(color: TallyTapTheme.textLight, fontWeight: FontWeight.bold),
                               decoration: const InputDecoration(
                                   hintText: 'Item Name (e.g. Pizza)',
                                   hintStyle: TextStyle(color: TallyTapTheme.textGray),
                                   border: InputBorder.none,
                               ),
                               onChanged: (v) => setState((){}),
                            )),
                            Container(
                               width: 100,
                               padding: const EdgeInsets.symmetric(horizontal: 8),
                               decoration: BoxDecoration(
                                  color: TallyTapTheme.obsidianBg,
                                  borderRadius: BorderRadius.circular(8)
                               ),
                               child: TextField(
                                   controller: item.priceController,
                                   keyboardType: const TextInputType.numberWithOptions(decimal:true),
                                   style: const TextStyle(color: TallyTapTheme.primaryMint, fontWeight: FontWeight.bold),
                                   decoration: const InputDecoration(
                                      prefixText: '₹ ',
                                      prefixStyle: TextStyle(color: TallyTapTheme.primaryMint),
                                      border: InputBorder.none,
                                   ),
                                   onChanged: (v) => setState((){}),
                               )
                            ),
                            IconButton(
                               icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                               onPressed: () {
                                   HapticFeedback.lightImpact();
                                   setState(() {
                                       item.dispose();
                                       _items.removeAt(itemIdx);
                                   });
                               }
                            )
                         ]
                       ),
                       const Divider(color: TallyTapTheme.borderGreen),
                       const SizedBox(height: 8),
                       const Text("Shared by:", style: TextStyle(fontSize: 12, color: TallyTapTheme.textGray)),
                       const SizedBox(height: 8),
                       Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(_peopleCount, (personIdx) {
                              bool isSelected = item.assignedParticipants.contains(personIdx);
                              String name = personIdx == 0 ? "You" : _friendControllers[personIdx-1].text;
                              if (name.isEmpty) name = "F$personIdx";
                              return ChoiceChip(
                                  label: Text(name),
                                  selected: isSelected,
                                  selectedColor: TallyTapTheme.primaryMint.withOpacity(0.2),
                                  backgroundColor: TallyTapTheme.obsidianBg,
                                  labelStyle: TextStyle(
                                     color: isSelected ? TallyTapTheme.primaryMint : TallyTapTheme.textGray,
                                     fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                                  ),
                                  side: BorderSide(color: isSelected ? TallyTapTheme.primaryMint : TallyTapTheme.borderGreen),
                                  onSelected: (val) {
                                      HapticFeedback.selectionClick();
                                      setState((){
                                          if (val) item.assignedParticipants.add(personIdx);
                                          else item.assignedParticipants.remove(personIdx);
                                      });
                                  }
                              );
                          })
                       )
                   ]
                )
             )
          );
        })
      ]
    );
  }

  Future<void> _checkTutorialStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool(kPrefTutorialExpenseSplitter) ?? false;
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
        ref.read(tutorialProvider.notifier).markCompleted(kPrefTutorialExpenseSplitter);
      },
      onSkip: () {
        ref.read(tutorialProvider.notifier).markCompleted(kPrefTutorialExpenseSplitter);
        return true;
      },
    );
    tutorialCoachMark?.show(context: context);
  }

  double _balanceForSource(List<ExpenseTransaction> txs, String src, double startingBalance) {
    double b = startingBalance;
    for (final t in txs) {
      if (t.category.toLowerCase() == 'transfer') {
        if (t.paymentMethod == src) {
          b -= t.amount.abs();
        } else if (t.paidTo == src) {
          b += t.amount.abs();
        }
      } else {
        if (t.paymentMethod == src) {
          b += t.isIncome ? t.amount.abs() : -t.amount.abs();
        }
      }
    }
    return b;
  }

  Widget _buildSourceSelector({
    required String title,
    required List<String> sources,
    required String? selectedSource,
    required Function(String) onSelected,
    required List<ExpenseTransaction> allTx,
    required Map<String, double> startingBalances,
    required String currency,
  }) {
    if (sources.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: TallyTapTheme.textGray,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: sources.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (ctx, i) {
              final src = sources[i];
              final selected = src == selectedSource;
              final srcColor = TallyTapTheme.getColorForSource(src);
              final startBal = startingBalances[src] ?? 0.0;
              final balance = _balanceForSource(allTx, src, startBal);

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelected(src);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 150,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                              color: srcColor.withOpacity(0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : null,
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
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: balance >= 0 ? '+ ' : '- ',
                                  style: TextStyle(
                                    color: balance >= 0
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFEF4444),
                                  ),
                                ),
                                TextSpan(
                                  text: '$currency${balance.abs().toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: selected
                                        ? srcColor
                                        : TallyTapTheme.textGray.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
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
      ],
    );
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

    targets.add(TargetFocus(
      identify: "TargetAmountPaid",
      keyTarget: TutorialService.splitterAmountKey,
      alignSkip: Alignment.topRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) => _buildTutorialContent(controller, "Total Amount Paid", "Enter the total bill amount that you paid here."),
        ),
      ],
    ));

    targets.add(TargetFocus(
      identify: "TargetSplitModes",
      keyTarget: TutorialService.splitterModesKey,
      alignSkip: Alignment.topRight,
      shape: ShapeLightFocus.RRect,
      radius: 16,
      contents: [
        TargetContent(
          align: ContentAlign.top,
          builder: (context, controller) => _buildTutorialContent(
            controller, 
            "Choose a Split Mode", 
            "• Equally: Classic even split.\n• Custom: Auto-balancing sliders for percentages and exact amounts.\n• Items: Assign specific receipt items to participants."
          ),
        ),
      ],
    ));

    targets.add(TargetFocus(
      identify: "TargetSplitResults",
      keyTarget: TutorialService.splitterResultKey,
      alignSkip: Alignment.topRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) => _buildTutorialContent(controller, "Split Results", "See exactly how much each person owes you. When logged, it creates grouped transactions for easy tracking."),
        ),
      ],
    ));

    return targets;
  }
}
