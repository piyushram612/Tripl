import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../models/transaction_model.dart';
import '../models/filter_criteria.dart';
import '../providers/currency_provider.dart';
import '../services/transaction_service.dart';
import 'widgets/transaction_item.dart';
import 'widgets/timeline_filter_sheet.dart';
import 'group_transaction_details_screen.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  String _searchQuery = '';
  String _activeFilter = 'All Activity';
  final TextEditingController _searchController = TextEditingController();
  FilterCriteria _filterCriteria = FilterCriteria();

  bool _isSelectionMode = false;
  final Set<String> _selectedTransactionIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFilterMenu(BuildContext context, double maxAmount) async {
    final result = await showModalBottomSheet<FilterCriteria>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 24,
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: TimelineFilterSheet(
          initialCriteria: _filterCriteria,
          maxTransactionAmount: maxAmount,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _filterCriteria = result;
      });
    }
  }

  List<TimelineItem> _groupTransactions(List<ExpenseTransaction> transactions) {
    final Map<String, List<ExpenseTransaction>> groups = {};
    final List<TimelineItem> result = [];

    for (final tx in transactions) {
      if (tx.groupId != null && tx.groupId!.startsWith('group_')) {
        groups.putIfAbsent(tx.groupId!, () => []).add(tx);
      } else {
        result.add(TimelineItem(singleTransaction: tx));
      }
    }

    groups.forEach((groupId, txs) {
      result.add(TimelineItem(
        groupId: groupId,
        groupTransactions: txs..sort((a, b) => b.date.compareTo(a.date)),
      ));
    });

    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  void _batchSelectedTransactions() async {
    if (_selectedTransactionIds.isEmpty) return;

    final groupNameController = TextEditingController(text: "Group Outing");
    final groupName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: TallyTapTheme.obsidianCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: TallyTapTheme.borderGreen, width: 1.5),
        ),
        title: const Text(
          'Group Transaction Name',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: TallyTapTheme.primaryMint,
            fontFamily: 'Outfit',
          ),
        ),
        content: TextField(
          controller: groupNameController,
          autofocus: true,
          style: const TextStyle(color: TallyTapTheme.textLight),
          decoration: InputDecoration(
            hintText: 'e.g. Restaurant split, Weekend trip...',
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
            onPressed: () {
              final name = groupNameController.text.trim();
              Navigator.pop(context, name.isEmpty ? "Group Outing" : name);
            },
            child: const Text('Create Group', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (groupName == null) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final generatedGroupId = "group_${timestamp}_$groupName";

    final listNotifier = ref.read(transactionListProvider.notifier);
    final transactions = ref.read(transactionListProvider);

    for (final txId in _selectedTransactionIds) {
      final originalTx = transactions.firstWhere((tx) => tx.id == txId);
      final updatedTx = ExpenseTransaction(
        id: originalTx.id,
        amount: originalTx.amount,
        merchant: originalTx.merchant,
        date: originalTx.date,
        paymentMethod: originalTx.paymentMethod,
        category: originalTx.category,
        notes: originalTx.notes,
        paidTo: originalTx.paidTo,
        needsVerification: originalTx.needsVerification,
        reminderDate: originalTx.reminderDate,
        groupId: generatedGroupId,
      );
      await listNotifier.updateTransaction(updatedTx);
    }

    setState(() {
      _isSelectionMode = false;
      _selectedTransactionIds.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Group "$groupName" created successfully!'),
          backgroundColor: TallyTapTheme.borderGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _ungroupTransactions(String groupId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: TallyTapTheme.obsidianCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: TallyTapTheme.borderGreen, width: 1.5),
        ),
        title: const Text(
          'Ungroup Transactions?',
          style: TextStyle(
            color: TallyTapTheme.primaryMint,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'This will split this group back into individual transactions.',
          style: TextStyle(color: TallyTapTheme.textLight),
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
            child: const Text('Ungroup'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final listNotifier = ref.read(transactionListProvider.notifier);
    final transactions = ref.read(transactionListProvider);

    final groupedTxs = transactions.where((tx) => tx.groupId == groupId).toList();
    for (final tx in groupedTxs) {
      final updatedTx = ExpenseTransaction(
        id: tx.id,
        amount: tx.amount,
        merchant: tx.merchant,
        date: tx.date,
        paymentMethod: tx.paymentMethod,
        category: tx.category,
        notes: tx.notes,
        paidTo: tx.paidTo,
        needsVerification: tx.needsVerification,
        reminderDate: tx.reminderDate,
        groupId: null,
      );
      await listNotifier.updateTransaction(updatedTx);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transactions ungrouped successfully!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _addSelectedToGroup(String groupId) async {
    if (_selectedTransactionIds.isEmpty) return;

    String groupName = "Group Transaction";
    final parts = groupId.split('_');
    if (parts.length >= 3) {
      groupName = parts.sublist(2).join('_');
    }

    final count = _selectedTransactionIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: TallyTapTheme.obsidianCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: TallyTapTheme.borderGreen, width: 1.5),
        ),
        title: Text(
          'Add to $groupName?',
          style: const TextStyle(
            color: TallyTapTheme.primaryMint,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Do you want to add the $count selected transaction(s) to this group?',
          style: const TextStyle(color: TallyTapTheme.textLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
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
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add to Group', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final listNotifier = ref.read(transactionListProvider.notifier);
    final transactions = ref.read(transactionListProvider);

    for (final txId in _selectedTransactionIds) {
      final originalTx = transactions.firstWhere((tx) => tx.id == txId);
      final updatedTx = ExpenseTransaction(
        id: originalTx.id,
        amount: originalTx.amount,
        merchant: originalTx.merchant,
        date: originalTx.date,
        paymentMethod: originalTx.paymentMethod,
        category: originalTx.category,
        notes: originalTx.notes,
        paidTo: originalTx.paidTo,
        needsVerification: originalTx.needsVerification,
        reminderDate: originalTx.reminderDate,
        groupId: groupId,
      );
      await listNotifier.updateTransaction(updatedTx);
    }

    setState(() {
      _isSelectionMode = false;
      _selectedTransactionIds.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added transaction(s) to "$groupName" successfully!'),
          backgroundColor: TallyTapTheme.borderGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionListProvider);
    final currency = ref.watch(currencyProvider);

    double maxAmount = 100.0;
    if (transactions.isNotEmpty) {
      double rawMax = transactions.map((t) => t.amount).reduce((a, b) => a > b ? a : b);
      maxAmount = ((rawMax / 100).ceil() * 100).toDouble();
      if (maxAmount < 100) maxAmount = 100;
    }

    final grouped = _groupTransactions(transactions);

    final filteredItems = grouped.where((item) {
      if (item.isGroup) {
        final groupName = getGroupName(item.groupId!);
        final matchesSearch = groupName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            item.groupTransactions!.any((tx) =>
                tx.merchant.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                tx.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                tx.paymentMethod.toLowerCase().contains(_searchQuery.toLowerCase()));

        bool matchesTab = true;
        double netVal = 0.0;
        for (final tx in item.groupTransactions!) {
          final isInc = tx.category.toLowerCase() == 'income';
          netVal += isInc ? tx.amount : -tx.amount;
        }

        if (_activeFilter == "Income") {
          matchesTab = netVal > 0;
        } else if (_activeFilter == "Expenses") {
          matchesTab = netVal <= 0;
        } else if (_activeFilter == "Transfers") {
          matchesTab = false;
        }

        bool matchesFilter = true;
        if (_filterCriteria.isActive) {
          if (_filterCriteria.startDate != null) {
            final start = DateTime(_filterCriteria.startDate!.year, _filterCriteria.startDate!.month, _filterCriteria.startDate!.day);
            if (item.date.isBefore(start)) matchesFilter = false;
          }
          if (_filterCriteria.endDate != null) {
            final end = DateTime(_filterCriteria.endDate!.year, _filterCriteria.endDate!.month, _filterCriteria.endDate!.day, 23, 59, 59);
            if (item.date.isAfter(end)) matchesFilter = false;
          }
          final absNetVal = netVal.abs();
          if (_filterCriteria.minAmount != null && absNetVal < _filterCriteria.minAmount!) {
            matchesFilter = false;
          }
          if (_filterCriteria.maxAmount != null && absNetVal > _filterCriteria.maxAmount!) {
            matchesFilter = false;
          }
        }

        return matchesSearch && matchesTab && matchesFilter;
      } else {
        final tx = item.singleTransaction!;
        final matchesSearch = tx.merchant.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            tx.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            tx.paymentMethod.toLowerCase().contains(_searchQuery.toLowerCase());

        bool matchesTab = true;
        if (_activeFilter == "Income") {
          matchesTab = tx.category.toLowerCase() == 'income';
        } else if (_activeFilter == "Expenses") {
          matchesTab = tx.category.toLowerCase() != 'income';
        } else if (_activeFilter == "Transfers") {
          matchesTab = false;
        }

        bool matchesFilter = true;
        if (_filterCriteria.isActive) {
          if (_filterCriteria.startDate != null) {
            final start = DateTime(_filterCriteria.startDate!.year, _filterCriteria.startDate!.month, _filterCriteria.startDate!.day);
            if (tx.date.isBefore(start)) matchesFilter = false;
          }
          if (_filterCriteria.endDate != null) {
            final end = DateTime(_filterCriteria.endDate!.year, _filterCriteria.endDate!.month, _filterCriteria.endDate!.day, 23, 59, 59);
            if (tx.date.isAfter(end)) matchesFilter = false;
          }
          if (_filterCriteria.minAmount != null && tx.amount < _filterCriteria.minAmount!) {
            matchesFilter = false;
          }
          if (_filterCriteria.maxAmount != null && tx.amount > _filterCriteria.maxAmount!) {
            matchesFilter = false;
          }
          if (_filterCriteria.categories.isNotEmpty && !_filterCriteria.categories.contains(tx.category)) {
            matchesFilter = false;
          }
          if (_filterCriteria.paymentMethods.isNotEmpty && !_filterCriteria.paymentMethods.contains(tx.paymentMethod)) {
            matchesFilter = false;
          }
          if (_filterCriteria.needsVerification != null && tx.needsVerification != _filterCriteria.needsVerification) {
            matchesFilter = false;
          }
        }

        return matchesSearch && matchesTab && matchesFilter;
      }
    }).toList();

    final now = DateTime.now();
    final todayList = filteredItems.where((item) =>
        item.date.year == now.year && item.date.month == now.month && item.date.day == now.day).toList();

    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayList = filteredItems.where((item) =>
        item.date.year == yesterday.year && item.date.month == yesterday.month && item.date.day == yesterday.day).toList();

    final olderList = filteredItems.where((item) =>
        !(item.date.year == now.year && item.date.month == now.month && item.date.day == now.day) &&
        !(item.date.year == yesterday.year && item.date.month == yesterday.month && item.date.day == yesterday.day)).toList();

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: TallyTapTheme.obsidianCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: TallyTapTheme.borderGreen),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: TallyTapTheme.primaryMint,
                      size: 20,
                    ),
                  ),
                  const Text(
                    'TallyTap',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: TallyTapTheme.textLight,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(width: 38),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Timeline',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: TallyTapTheme.textLight,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                style: const TextStyle(fontSize: 14, color: TallyTapTheme.textLight),
                decoration: InputDecoration(
                  hintText: 'Search transactions...',
                  hintStyle: const TextStyle(fontSize: 14, color: TallyTapTheme.textGray),
                  prefixIcon: const Icon(Icons.search, color: TallyTapTheme.textGray, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.tune,
                      color: _filterCriteria.isActive ? TallyTapTheme.primaryMint : TallyTapTheme.textGray,
                    ),
                    onPressed: () => _showFilterMenu(context, maxAmount),
                  ),
                  filled: true,
                  fillColor: TallyTapTheme.obsidianCard,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: TallyTapTheme.borderGreen),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: TallyTapTheme.primaryMint),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildFilterCapsule('All Activity'),
                    _buildFilterCapsule('Income'),
                    _buildFilterCapsule('Expenses'),
                    _buildFilterCapsule('Transfers'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (todayList.isNotEmpty) ...[
                        _buildSectionHeader('Today', ''),
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Column(
                              children: [
                                for (int i = 0; i < todayList.length; i++) ...[
                                  _buildTimelineItem(todayList[i], currency),
                                  if (i < todayList.length - 1)
                                    const Divider(color: TallyTapTheme.borderGreen, height: 1, thickness: 0.5),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (yesterdayList.isNotEmpty) ...[
                        _buildSectionHeader('Yesterday', ''),
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Column(
                              children: [
                                for (int i = 0; i < yesterdayList.length; i++) ...[
                                  _buildTimelineItem(yesterdayList[i], currency),
                                  if (i < yesterdayList.length - 1)
                                    const Divider(color: TallyTapTheme.borderGreen, height: 1, thickness: 0.5),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (olderList.isNotEmpty) ...[
                        _buildSectionHeader('Older Activity', ''),
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Column(
                              children: [
                                for (int i = 0; i < olderList.length; i++) ...[
                                  _buildTimelineItem(olderList[i], currency, showDate: true),
                                  if (i < olderList.length - 1)
                                    const Divider(color: TallyTapTheme.borderGreen, height: 1, thickness: 0.5),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (filteredItems.isEmpty) ...[
                        const SizedBox(height: 60),
                        const Center(
                          child: Text(
                            'No matching transactions found.',
                            style: TextStyle(color: TallyTapTheme.textGray, fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 60),
                      ],
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildSelectionPanel(),
      ],
    );
  }

  Widget _buildSelectionPanel() {
    if (!_isSelectionMode) return const SizedBox.shrink();

    return Positioned(
      top: 12,
      left: 16,
      right: 16,
      child: Material(
        elevation: 10,
        color: TallyTapTheme.obsidianCard,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TallyTapTheme.primaryMint, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: TallyTapTheme.primaryMint.withOpacity(0.12),
                blurRadius: 16,
                spreadRadius: 2,
              )
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: TallyTapTheme.textGray, size: 20),
                    onPressed: () {
                      setState(() {
                        _isSelectionMode = false;
                        _selectedTransactionIds.clear();
                      });
                    },
                  ),
                  Text(
                    '${_selectedTransactionIds.length} Selected',
                    style: const TextStyle(
                      color: TallyTapTheme.textLight,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TallyTapTheme.primaryMint,
                  foregroundColor: TallyTapTheme.obsidianBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: _selectedTransactionIds.length < 2
                    ? null
                    : _batchSelectedTransactions,
                icon: const Icon(Icons.group_work_rounded, size: 18),
                label: const Text(
                  'Group Split',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterCapsule(String label) {
    final isSelected = _activeFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeFilter = label;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? TallyTapTheme.primaryMint : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: isSelected ? null : Border.all(color: TallyTapTheme.borderGreen, width: 1.0),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            color: isSelected ? TallyTapTheme.obsidianBg : TallyTapTheme.textLight,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String day, String dateStr) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          day,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: TallyTapTheme.textLight),
        ),
        if (dateStr.isNotEmpty)
          Text(
            dateStr,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: TallyTapTheme.textGray),
          ),
      ],
    );
  }

  Widget _buildTimelineItem(TimelineItem item, String currency, {bool showDate = false}) {
    if (item.isGroup) {
      return GroupTransactionCard(
        groupId: item.groupId!,
        transactions: item.groupTransactions!,
        currency: currency,
        onTap: _isSelectionMode
            ? () => _addSelectedToGroup(item.groupId!)
            : null,
        onLongPress: () {
          if (!_isSelectionMode) {
            _ungroupTransactions(item.groupId!);
          }
        },
      );
    }

    final tx = item.singleTransaction!;
    final isSelected = _selectedTransactionIds.contains(tx.id);

    int hour = tx.date.hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;

    final formattedTime = "${hour.toString().padLeft(2, '0')}:${tx.date.minute.toString().padLeft(2, '0')} $period";
    String subtitle = '$formattedTime • ${tx.paymentMethod}';

    if (showDate) {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final monthStr = months[tx.date.month - 1];
      final dateStr = '$monthStr ${tx.date.day}';
      
      if (tx.date.year != DateTime.now().year) {
        subtitle = '$dateStr, ${tx.date.year} • $subtitle';
      } else {
        subtitle = '$dateStr • $subtitle';
      }
    }

    return TransactionItem(
      transaction: tx,
      currency: currency,
      subtitle: subtitle,
      isSelected: isSelected,
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      onTap: _isSelectionMode
          ? () {
              setState(() {
                if (_selectedTransactionIds.contains(tx.id)) {
                  _selectedTransactionIds.remove(tx.id);
                  if (_selectedTransactionIds.isEmpty) {
                    _isSelectionMode = false;
                  }
                } else {
                  _selectedTransactionIds.add(tx.id);
                }
              });
            }
          : null,
      onLongPress: () {
        setState(() {
          _isSelectionMode = true;
          _selectedTransactionIds.add(tx.id);
        });
      },
    );
  }
}

class TimelineItem {
  final ExpenseTransaction? singleTransaction;
  final String? groupId;
  final List<ExpenseTransaction>? groupTransactions;

  TimelineItem({
    this.singleTransaction,
    this.groupId,
    this.groupTransactions,
  });

  bool get isGroup => groupId != null;

  DateTime get date {
    if (isGroup) {
      return groupTransactions!.map((t) => t.date).reduce((a, b) => a.isAfter(b) ? a : b);
    } else {
      return singleTransaction!.date;
    }
  }
}

String getGroupName(String groupId) {
  final parts = groupId.split('_');
  if (parts.length >= 3) {
    return parts.sublist(2).join('_');
  }
  return "Group Transaction";
}

class GroupTransactionCard extends StatefulWidget {
  final String groupId;
  final List<ExpenseTransaction> transactions;
  final String currency;
  final VoidCallback onLongPress;
  final VoidCallback? onTap;

  const GroupTransactionCard({
    super.key,
    required this.groupId,
    required this.transactions,
    required this.currency,
    required this.onLongPress,
    this.onTap,
  });

  @override
  State<GroupTransactionCard> createState() => _GroupTransactionCardState();
}

class _GroupTransactionCardState extends State<GroupTransactionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    double netAmount = 0.0;
    for (final tx in widget.transactions) {
      final isInc = tx.category.toLowerCase() == 'income';
      netAmount += isInc ? tx.amount : -tx.amount;
    }
    final isNetIncome = netAmount >= 0;
    final displayAmount = netAmount.abs();

    String groupName = "Group Transaction";
    final parts = widget.groupId.split('_');
    if (parts.length >= 3) {
      groupName = parts.sublist(2).join('_');
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: TallyTapTheme.obsidianCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: TallyTapTheme.primaryMint.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: TallyTapTheme.primaryMint.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: widget.onTap ?? () {
              setState(() {
                _expanded = !_expanded;
              });
            },
            onLongPress: widget.onLongPress,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: TallyTapTheme.primaryMint.withOpacity(0.15),
                      border: Border.all(color: TallyTapTheme.primaryMint, width: 1.0),
                    ),
                    child: const Icon(
                      Icons.group_work_rounded,
                      color: TallyTapTheme.primaryMint,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                groupName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: TallyTapTheme.primaryMint,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: TallyTapTheme.primaryMint.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${widget.transactions.length} items',
                                style: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: TallyTapTheme.primaryMint,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Net ${isNetIncome ? 'Income' : 'Expense'} • Tap to ${_expanded ? 'collapse' : 'expand'}',
                          style: const TextStyle(fontSize: 11, color: TallyTapTheme.textGray),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${isNetIncome ? '+' : '-'} ${widget.currency}${displayAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: isNetIncome ? const Color(0xFF10B981) : TallyTapTheme.textLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        color: TallyTapTheme.textGray,
                        size: 16,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(color: TallyTapTheme.borderGreen, height: 1),
            Container(
              color: TallyTapTheme.obsidianBg.withOpacity(0.5),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.transactions.length,
                separatorBuilder: (context, index) => const Divider(
                  color: TallyTapTheme.borderGreen,
                  height: 1,
                  thickness: 0.5,
                ),
                itemBuilder: (context, index) {
                  final tx = widget.transactions[index];
                  final isInc = tx.category.toLowerCase() == 'income';
                  final color = isInc ? const Color(0xFF10B981) : TallyTapTheme.textLight;
                  int hour = tx.date.hour;
                  final period = hour >= 12 ? 'PM' : 'AM';
                  if (hour > 12) hour -= 12;
                  if (hour == 0) hour = 12;
                  final formattedTime = "${hour.toString().padLeft(2, '0')}:${tx.date.minute.toString().padLeft(2, '0')} $period";

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Icon(
                          isInc ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                          color: isInc ? const Color(0xFF10B981) : TallyTapTheme.textGray,
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tx.merchant,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: TallyTapTheme.textLight,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$formattedTime • ${tx.category}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: TallyTapTheme.textGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${isInc ? '+' : '-'} ${widget.currency}${tx.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              color: TallyTapTheme.obsidianBg.withOpacity(0.5),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GroupTransactionDetailsScreen(groupId: widget.groupId),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: TallyTapTheme.primaryMint,
                    side: const BorderSide(color: TallyTapTheme.borderGreen),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.receipt_long_rounded, size: 18),
                  label: const Text(
                    'View Details & Verify',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
