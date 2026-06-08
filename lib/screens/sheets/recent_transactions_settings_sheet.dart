import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../home_screen.dart'; // To access the providers
import '../../providers/app_state_provider.dart';

class RecentTransactionsSettingsSheet extends ConsumerWidget {
  const RecentTransactionsSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(homeRecentCountProvider);
    final type = ref.watch(homeRecentTypeProvider);
    final sort = ref.watch(homeRecentSortProvider);
    final density = ref.watch(homeRecentDensityProvider);
    final timeframe = ref.watch(homeRecentTimeframeProvider);

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: TallyTapTheme.obsidianBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: TallyTapTheme.textGray.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Recent Reflections Settings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: TallyTapTheme.textLight,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),

              _buildSection(
                title: 'Show Limit',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildChoiceChip(context, '5 Items', count == 5, () => ref.read(homeRecentCountProvider.notifier).updateVal(5)),
                    _buildChoiceChip(context, '10 Items', count == 10, () => ref.read(homeRecentCountProvider.notifier).updateVal(10)),
                    _buildChoiceChip(context, '15 Items', count == 15, () => ref.read(homeRecentCountProvider.notifier).updateVal(15)),
                    _buildChoiceChip(
                      context, 
                      (count != 5 && count != 10 && count != 15) ? 'Custom ($count)' : 'Custom', 
                      count != 5 && count != 10 && count != 15, 
                      () => _showCustomCountDialog(context, ref, count)
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _buildSection(
                title: 'Transaction Type',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildChoiceChip(context, 'All Types', type == 'all', () => ref.read(homeRecentTypeProvider.notifier).updateVal('all')),
                    _buildChoiceChip(context, 'Expenses', type == 'expenses', () => ref.read(homeRecentTypeProvider.notifier).updateVal('expenses')),
                    _buildChoiceChip(context, 'Income', type == 'income', () => ref.read(homeRecentTypeProvider.notifier).updateVal('income')),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _buildSection(
                title: 'Sort By',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildChoiceChip(context, 'Newest First', sort == 'newest', () => ref.read(homeRecentSortProvider.notifier).updateVal('newest')),
                    _buildChoiceChip(context, 'Highest Amount', sort == 'highest', () => ref.read(homeRecentSortProvider.notifier).updateVal('highest')),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _buildSection(
                title: 'Timeframe',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildChoiceChip(context, 'All Time', timeframe == 'all', () => ref.read(homeRecentTimeframeProvider.notifier).updateVal('all')),
                    _buildChoiceChip(context, 'Today', timeframe == 'today', () => ref.read(homeRecentTimeframeProvider.notifier).updateVal('today')),
                    _buildChoiceChip(context, 'This Week', timeframe == 'week', () => ref.read(homeRecentTimeframeProvider.notifier).updateVal('week')),
                    _buildChoiceChip(context, 'This Month', timeframe == 'month', () => ref.read(homeRecentTimeframeProvider.notifier).updateVal('month')),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _buildSection(
                title: 'Display Density',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildChoiceChip(context, 'Comfortable', density == 'comfortable', () => ref.read(homeRecentDensityProvider.notifier).updateVal('comfortable')),
                    _buildChoiceChip(context, 'Compact', density == 'compact', () => ref.read(homeRecentDensityProvider.notifier).updateVal('compact')),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: TallyTapTheme.textGray,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildChoiceChip(BuildContext context, String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? TallyTapTheme.primaryMint.withOpacity(0.05) : TallyTapTheme.obsidianCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? TallyTapTheme.primaryMint : TallyTapTheme.obsidianCard,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: TallyTapTheme.primaryMint.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? TallyTapTheme.primaryMint : TallyTapTheme.textLight,
          ),
        ),
      ),
    );
  }
  void _showCustomCountDialog(BuildContext context, WidgetRef ref, int currentCount) {
    final controller = TextEditingController(text: currentCount > 0 ? currentCount.toString() : '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: TallyTapTheme.obsidianCard,
          title: const Text('Custom Limit', style: TextStyle(color: TallyTapTheme.textLight)),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: TallyTapTheme.textLight),
            decoration: InputDecoration(
              hintText: 'Enter number of items',
              hintStyle: const TextStyle(color: TallyTapTheme.textGray),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: TallyTapTheme.borderGreen),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: TallyTapTheme.primaryMint),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: TallyTapTheme.textGray)),
            ),
            TextButton(
              onPressed: () {
                final val = int.tryParse(controller.text);
                if (val != null && val > 0) {
                  ref.read(homeRecentCountProvider.notifier).updateVal(val);
                }
                Navigator.pop(context);
              },
              child: const Text('Save', style: TextStyle(color: TallyTapTheme.primaryMint, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
