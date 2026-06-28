import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/currency_provider.dart';
import '../../providers/budget_provider.dart';
import '../../services/transaction_service.dart';

class ManageCurrencySheet extends ConsumerWidget {
  const ManageCurrencySheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentCurrency = ref.watch(currencyProvider);
    final currencies = [
      {'symbol': '₹', 'name': 'Indian Rupee'},
      {'symbol': '\$', 'name': 'US Dollar'},
      {'symbol': '€', 'name': 'Euro'},
      {'symbol': '£', 'name': 'British Pound'},
      {'symbol': '¥', 'name': 'Japanese Yen'},
    ];

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Select Currency',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: TallyTapTheme.primaryMint,
                  letterSpacing: -0.5,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: TallyTapTheme.textGray),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'GLOBAL CURRENCY (CHANGING THIS WILL CONVERT ALL EXISTING VALUES)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: TallyTapTheme.textGray,
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: currencies.map((currency) {
                  final isSelected = currentCurrency == currency['symbol'];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Material(
                      color: isSelected ? TallyTapTheme.primaryMint.withOpacity(0.1) : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected ? TallyTapTheme.primaryMint : Colors.transparent,
                          width: 1.0,
                        ),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected ? TallyTapTheme.primaryMint : TallyTapTheme.obsidianCard,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? TallyTapTheme.primaryMint : TallyTapTheme.borderGreen,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        currency['symbol']!,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? TallyTapTheme.obsidianBg : TallyTapTheme.primaryMint,
                        ),
                      ),
                    ),
                    title: Text(
                      currency['name']!,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? TallyTapTheme.primaryMint : TallyTapTheme.textLight,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: TallyTapTheme.primaryMint)
                        : null,
                    onTap: () async {
                      if (!isSelected) {
                        final result = await showDialog<Map<String, bool>>(
                          context: context,
                          builder: (context) => CurrencySettingsDialog(
                            currency: currency,
                            oldCurrencySymbol: currentCurrency,
                          ),
                        );

                        if (result == null) return;

                        final convertValues = result['convertValues'] ?? true;
                        final applyToExisting = result['applyToExisting'] ?? true;

                        if (context.mounted) {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const Center(
                              child: CircularProgressIndicator(color: TallyTapTheme.primaryMint),
                            ),
                          );
                        }

                        try {
                          await ref.read(currencyProvider.notifier).setCurrency(
                            currency['symbol']!,
                            convertValues: convertValues,
                            applyToExisting: applyToExisting,
                          );
                          
                          // Force a refresh of dependent providers
                          ref.read(transactionListProvider.notifier).loadTransactions();
                          ref.read(globalBudgetProvider.notifier).loadGlobalBudget();
                          ref.read(budgetLimitsProvider.notifier).loadLimits();
                          
                          if (context.mounted) {
                            Navigator.pop(context); // pop loading dialog
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Currency updated to ${currency['name']}. '
                                  '${convertValues ? "Values converted" : "Symbol changed"}'
                                  '${applyToExisting ? " for all transactions." : " for new transactions onwards."}'
                                ),
                                duration: const Duration(seconds: 3),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            Navigator.pop(context); // pop sheet
                          }
                        } catch (e) {
                          if (context.mounted) {
                            Navigator.pop(context); // pop loading dialog
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to update currency. Please try again.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    },
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CurrencySettingsDialog extends StatefulWidget {
  final Map<String, String> currency;
  final String oldCurrencySymbol;

  const CurrencySettingsDialog({
    super.key,
    required this.currency,
    required this.oldCurrencySymbol,
  });

  @override
  State<CurrencySettingsDialog> createState() => _CurrencySettingsDialogState();
}

class _CurrencySettingsDialogState extends State<CurrencySettingsDialog> {
  bool _convertValues = true;
  bool _applyToExisting = true;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: TallyTapTheme.obsidianCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: TallyTapTheme.borderGreen, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Change Currency to ${widget.currency['symbol']}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: TallyTapTheme.primaryMint,
                fontFamily: 'Outfit',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            // Question 1: Convert or Symbol Only
            const Text(
              'CONVERSION OPTION',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: TallyTapTheme.textGray,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            _buildSelectionCard(
              title: 'Convert Values',
              subtitle: 'Use exchange rates to convert all numeric amounts.',
              selected: _convertValues,
              onTap: () => setState(() => _convertValues = true),
            ),
            const SizedBox(height: 8),
            _buildSelectionCard(
              title: 'Change Symbol Only',
              subtitle: 'Keep all existing numbers exactly the same.',
              selected: !_convertValues,
              onTap: () => setState(() => _convertValues = false),
            ),
            const SizedBox(height: 20),

            // Question 2: All or From Now Onwards
            const Text(
              'APPLY TO WHICH TRANSACTIONS?',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: TallyTapTheme.textGray,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            _buildSelectionCard(
              title: 'All Transactions',
              subtitle: 'Apply changes to all existing and future transactions.',
              selected: _applyToExisting,
              onTap: () => setState(() => _applyToExisting = true),
            ),
            const SizedBox(height: 8),
            _buildSelectionCard(
              title: 'From Now Onwards',
              subtitle: 'Keep existing transactions as is; only apply to new transactions.',
              selected: !_applyToExisting,
              onTap: () => setState(() => _applyToExisting = false),
            ),
            const SizedBox(height: 24),

            // Actions
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: TallyTapTheme.textGray, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TallyTapTheme.primaryMint,
                      foregroundColor: TallyTapTheme.obsidianBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(context, {
                        'convertValues': _convertValues,
                        'applyToExisting': _applyToExisting,
                      });
                    },
                    child: const Text(
                      'Confirm',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionCard({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? TallyTapTheme.primaryMint.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? TallyTapTheme.primaryMint : TallyTapTheme.borderGreen,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? TallyTapTheme.primaryMint : TallyTapTheme.textGray,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Center(
                      child: Icon(
                        Icons.circle,
                        size: 10,
                        color: TallyTapTheme.primaryMint,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: selected ? TallyTapTheme.primaryMint : TallyTapTheme.textLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: TallyTapTheme.textGray,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
