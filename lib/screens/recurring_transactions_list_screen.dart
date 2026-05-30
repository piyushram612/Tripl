import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../models/recurring_transaction_model.dart';
import '../providers/recurring_transaction_provider.dart';
import '../providers/currency_provider.dart';
import 'create_recurring_transaction_screen.dart';
import 'recurring_transaction_details_screen.dart';

class RecurringTransactionsListScreen extends ConsumerStatefulWidget {
  const RecurringTransactionsListScreen({super.key});

  @override
  ConsumerState<RecurringTransactionsListScreen> createState() => _RecurringTransactionsListScreenState();
}

class _RecurringTransactionsListScreenState extends ConsumerState<RecurringTransactionsListScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(recurringTransactionsProvider);
    final currency = ref.watch(currencyProvider);

    var filtered = transactions.where((tx) {
      if (_searchQuery.isNotEmpty && !tx.title.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      if (_selectedFilter != 'All' && tx.status.name.toLowerCase() != _selectedFilter.toLowerCase()) {
        return false;
      }
      return true;
    }).toList();

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
          'Recurring Payments',
          style: TextStyle(color: TallyTapTheme.textLight, fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Outfit'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: TallyTapTheme.primaryMint),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CreateRecurringTransactionScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
              child: TextField(
                style: const TextStyle(color: TallyTapTheme.textLight),
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search payments...',
                  hintStyle: const TextStyle(color: TallyTapTheme.textGray),
                  prefixIcon: const Icon(Icons.search_rounded, color: TallyTapTheme.textGray),
                  filled: true,
                  fillColor: TallyTapTheme.obsidianCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
            ),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: ['All', 'Active', 'Paused', 'Completed'].map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(filter, style: TextStyle(color: isSelected ? TallyTapTheme.obsidianBg : TallyTapTheme.textLight, fontWeight: FontWeight.bold)),
                      selected: isSelected,
                      selectedColor: TallyTapTheme.primaryMint,
                      backgroundColor: TallyTapTheme.obsidianCard,
                      onSelected: (val) => setState(() => _selectedFilter = filter),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // List
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No recurring payments found.', style: TextStyle(color: TallyTapTheme.textGray)))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final tx = filtered[index];
                        final isIncome = tx.type == TransactionType.income;
                        final activeColor = isIncome ? const Color(0xFF10B981) : TallyTapTheme.primaryMint;
                        
                        bool isDue = tx.nextDueDate.isBefore(DateTime.now()) || tx.nextDueDate.isAtSameMomentAs(DateTime.now());
                        bool showManualActions = isDue && !tx.autoCreate && tx.status == RecurringStatus.active;

                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RecurringTransactionDetailsScreen(transaction: tx),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: TallyTapTheme.obsidianCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: showManualActions ? Colors.orange.withOpacity(0.5) : TallyTapTheme.borderGreen.withOpacity(0.3)),
                            ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: activeColor.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.autorenew_rounded, color: activeColor),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(tx.title, style: const TextStyle(color: TallyTapTheme.textLight, fontSize: 16, fontWeight: FontWeight.bold)),
                                        Text('${tx.frequency.name} • ${tx.category}', style: const TextStyle(color: TallyTapTheme.textGray, fontSize: 12)),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text('Next Due: ${DateFormat('dd MMM yyyy').format(tx.nextDueDate)}', style: const TextStyle(color: TallyTapTheme.textGray, fontSize: 10)),
                                            if (showManualActions) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                                child: const Text('DUE', style: TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold)),
                                              ),
                                            ]
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('$currency${tx.amount.toStringAsFixed(0)}', style: const TextStyle(color: TallyTapTheme.textLight, fontSize: 16, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          InkWell(
                                            onTap: () {
                                              HapticFeedback.lightImpact();
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(builder: (context) => CreateRecurringTransactionScreen(existingTransaction: tx)),
                                              );
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: TallyTapTheme.obsidianBg,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: TallyTapTheme.borderGreen),
                                              ),
                                              child: const Text('Edit', style: TextStyle(color: TallyTapTheme.textLight, fontSize: 10, fontWeight: FontWeight.bold)),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          InkWell(
                                            onTap: () {
                                              HapticFeedback.lightImpact();
                                              ref.read(recurringTransactionsProvider.notifier).togglePause(tx.id);
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: tx.status == RecurringStatus.active ? TallyTapTheme.obsidianBg : Colors.orange.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: tx.status == RecurringStatus.active ? TallyTapTheme.borderGreen : Colors.orange),
                                              ),
                                              child: Text(tx.status == RecurringStatus.active ? 'Pause' : 'Resume', style: TextStyle(color: tx.status == RecurringStatus.active ? TallyTapTheme.textLight : Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (showManualActions) ...[
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () => ref.read(recurringTransactionsProvider.notifier).skip(tx.id),
                                      child: const Text('Skip', style: TextStyle(color: TallyTapTheme.textGray, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: activeColor,
                                        foregroundColor: TallyTapTheme.obsidianBg,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () => ref.read(recurringTransactionsProvider.notifier).markAsPaid(tx.id),
                                      child: const Text('Mark Paid', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          ],
        ),
      ),
    );
  }
}
