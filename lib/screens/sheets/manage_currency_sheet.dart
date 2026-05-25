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
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? TallyTapTheme.primaryMint : Colors.transparent,
                        width: 1.0,
                      ),
                    ),
                    tileColor: isSelected ? TallyTapTheme.primaryMint.withOpacity(0.1) : Colors.transparent,
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
                        await ref.read(currencyProvider.notifier).setCurrency(currency['symbol']!);
                        
                        // Force a refresh of dependent providers
                        ref.read(transactionListProvider.notifier).loadTransactions();
                        ref.read(globalBudgetProvider.notifier).loadGlobalBudget();
                        ref.read(budgetLimitsProvider.notifier).loadLimits();
                        
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Currency updated to ${currency['name']} and values converted.'),
                              duration: const Duration(seconds: 3),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          Navigator.pop(context);
                        }
                      }
                    },
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
