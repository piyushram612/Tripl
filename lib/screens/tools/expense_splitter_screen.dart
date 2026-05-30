import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/transaction_model.dart';
import '../../services/transaction_service.dart';

class ExpenseSplitterScreen extends ConsumerStatefulWidget {
  const ExpenseSplitterScreen({super.key});

  @override
  ConsumerState<ExpenseSplitterScreen> createState() => _ExpenseSplitterScreenState();
}

class _ExpenseSplitterScreenState extends ConsumerState<ExpenseSplitterScreen> {
  final TextEditingController _amountController = TextEditingController(text: "0.00");
  final TextEditingController _descController = TextEditingController(text: "Restaurant Outing");
  int _peopleCount = 4;
  final List<TextEditingController> _friendControllers = [];

  @override
  void initState() {
    super.initState();
    _updateFriendControllers();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    for (final controller in _friendControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _updateFriendControllers() {
    // We need peopleCount - 1 friend controllers (excluding "You")
    final requiredFriends = _peopleCount - 1;
    if (_friendControllers.length < requiredFriends) {
      while (_friendControllers.length < requiredFriends) {
        final index = _friendControllers.length + 1;
        _friendControllers.add(TextEditingController(text: "Friend $index"));
      }
    } else if (_friendControllers.length > requiredFriends) {
      while (_friendControllers.length > requiredFriends) {
        final controller = _friendControllers.removeLast();
        controller.dispose();
      }
    }
  }

  double get _totalAmount {
    return double.tryParse(_amountController.text) ?? 0.0;
  }

  double get _amountPerPerson {
    if (_peopleCount <= 0) return 0.0;
    return _totalAmount / _peopleCount;
  }

  void _logGroupSplit() async {
    if (_totalAmount <= 0) return;

    HapticFeedback.heavyImpact();

    final groupDesc = _descController.text.trim();
    final groupName = groupDesc.isEmpty ? "Group Outing" : groupDesc;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final generatedGroupId = "group_${timestamp}_$groupName";

    final listNotifier = ref.read(transactionListProvider.notifier);
    final splitVal = _amountPerPerson;

    // 1. Create main expense paid by "You"
    final mainTx = ExpenseTransaction(
      id: "tx_${timestamp}_main",
      amount: _totalAmount,
      merchant: "$groupName (Paid by You)",
      date: DateTime.now(),
      paymentMethod: "Card",
      category: "Dining",
      notes: "Group Split total paid",
      groupId: generatedGroupId,
    );
    await listNotifier.addTransaction(mainTx);

    // 2. Create incomes for other friends
    for (int i = 0; i < _friendControllers.length; i++) {
      final friendName = _friendControllers[i].text.trim();
      final name = friendName.isEmpty ? "Friend ${i + 1}" : friendName;

      final repaymentTx = ExpenseTransaction(
        id: "tx_${timestamp}_friend_$i",
        amount: splitVal,
        merchant: "Split repayment from $name",
        date: DateTime.now(),
        paymentMethod: "UPI",
        category: "Income",
        notes: "Group Split share",
        groupId: generatedGroupId,
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
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Split Results Panel
                Container(
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
                        'EACH PERSON PAYS',
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
                            _amountPerPerson.toStringAsFixed(2),
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
                        'You paid ₹${_totalAmount.toStringAsFixed(2)} • You get back ₹${(_amountPerPerson * (_peopleCount - 1)).toStringAsFixed(2)}',
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
                            decoration: const InputDecoration(
                              prefixText: '₹ ',
                              prefixStyle: TextStyle(color: TallyTapTheme.primaryMint, fontWeight: FontWeight.bold),
                              border: InputBorder.none,
                            ),
                            onChanged: (val) {
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

                // Friends Names customizer
                const Text(
                  'PARTICIPANTS NAMES',
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
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Card(
                          color: TallyTapTheme.obsidianCard.withOpacity(0.5),
                          child: const ListTile(
                            leading: CircleAvatar(
                              backgroundColor: TallyTapTheme.primaryMint,
                              radius: 14,
                              child: Icon(Icons.person, color: TallyTapTheme.obsidianBg, size: 16),
                            ),
                            title: Text(
                              'You (Payee)',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: TallyTapTheme.primaryMint),
                            ),
                            trailing: Text(
                              '₹ 0.00',
                              style: TextStyle(fontSize: 13, color: TallyTapTheme.textGray),
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
                          child: Row(
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
                                  ),
                                ),
                              ),
                              Text(
                                '₹${_amountPerPerson.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: TallyTapTheme.textLight),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // Button: Log group split
                ElevatedButton.icon(
                  onPressed: _totalAmount <= 0 ? null : _logGroupSplit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TallyTapTheme.primaryMint,
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
    );
  }
}
