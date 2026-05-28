import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../models/transaction_model.dart';
import '../providers/currency_provider.dart';
import '../services/transaction_service.dart';
import 'transaction_details_screen.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  String _searchQuery = '';
  String _activeFilter = 'All Activity';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionListProvider);
    final currency = ref.watch(currencyProvider);

    final filtered = transactions.where((tx) {
      final matchesSearch = tx.merchant.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          tx.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          tx.paymentMethod.toLowerCase().contains(_searchQuery.toLowerCase());

      bool matchesTab = true;
      if (_activeFilter == "Income") {
        matchesTab = tx.category.toLowerCase() == 'income';
      } else if (_activeFilter == "Expenses") {
        matchesTab = tx.category.toLowerCase() != 'income';
      } else if (_activeFilter == "Transfers") {
        matchesTab = false; // Mock empty transfers
      }

      return matchesSearch && matchesTab;
    }).toList();

    final now = DateTime.now();
    final todayList = filtered.where((tx) =>
        tx.date.year == now.year && tx.date.month == now.month && tx.date.day == now.day).toList();

    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayList = filtered.where((tx) =>
        tx.date.year == yesterday.year && tx.date.month == yesterday.month && tx.date.day == yesterday.day).toList();

    final olderList = filtered.where((tx) =>
        !(tx.date.year == now.year && tx.date.month == now.month && tx.date.day == now.day) &&
        !(tx.date.year == yesterday.year && tx.date.month == yesterday.month && tx.date.day == yesterday.day)).toList();

    return Padding(
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
              const SizedBox(width: 38), // To balance the left wallet icon container and keep TallyTap centered
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
                              _buildTimelineTransactionItem(todayList[i], currency),
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
                              _buildTimelineTransactionItem(yesterdayList[i], currency),
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
                              _buildTimelineTransactionItem(olderList[i], currency),
                              if (i < olderList.length - 1)
                                const Divider(color: TallyTapTheme.borderGreen, height: 1, thickness: 0.5),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (filtered.isEmpty) ...[
                    const SizedBox(height: 60),
                    const Center(
                      child: Text(
                        'No matching transactions found.',
                        style: TextStyle(color: TallyTapTheme.textGray, fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 60),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
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

  Widget _buildTimelineTransactionItem(ExpenseTransaction tx, String currency) {
    final isIncome = tx.category.toLowerCase() == 'income';
    final activeColor = isIncome ? const Color(0xFF10B981) : TallyTapTheme.textLight;

    IconData icon;
    Color iconBg;
    Color iconColor = TallyTapTheme.textLight;

    if (isIncome) {
      icon = Icons.arrow_downward_rounded;
      iconBg = const Color(0xFF0F2B20); // Green tint
      iconColor = const Color(0xFF10B981);
    } else {
      final clean = tx.category.toLowerCase();
      if (clean.contains('dining') || clean.contains('food') || clean.contains('dinner') || clean.contains('restaurant')) {
        icon = Icons.local_cafe_outlined;
        iconBg = const Color(0xFF261D4C);
      } else if (clean.contains('commute') || clean.contains('transport') || clean.contains('car') || clean.contains('cab')) {
        icon = Icons.directions_transit_filled_outlined;
        iconBg = const Color(0xFF1E284C);
      } else if (clean.contains('sub') || clean.contains('subscriptions') || clean.contains('entertainment')) {
        icon = Icons.subscriptions_outlined;
        iconBg = const Color(0xFF1B2B3A);
      } else if (clean.contains('utility') || clean.contains('bill') || clean.contains('electricity')) {
        icon = Icons.bolt_outlined;
        iconBg = const Color(0xFF332A15);
      } else {
        icon = Icons.local_mall_outlined;
        iconBg = const Color(0xFF142B24);
      }
    }

    final formattedTime = "${tx.date.hour.toString().padLeft(2, '0')}:${tx.date.minute.toString().padLeft(2, '0')} ${tx.date.hour >= 12 ? 'PM' : 'AM'}";

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TransactionDetailsScreen(transaction: tx),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconBg,
                border: Border.all(color: TallyTapTheme.borderGreen, width: 0.5),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.merchant,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: TallyTapTheme.textLight),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$formattedTime • ${tx.paymentMethod}',
                    style: const TextStyle(fontSize: 12, color: TallyTapTheme.textGray),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isIncome ? '+' : '-'} $currency${tx.amount.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: activeColor),
                ),
                if (isIncome) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F2B20),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF144D37), width: 0.5),
                    ),
                    child: const Text(
                      'Income',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
