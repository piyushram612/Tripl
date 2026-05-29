import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/transaction_model.dart';
import '../transaction_details_screen.dart';

class TransactionItem extends StatelessWidget {
  final ExpenseTransaction transaction;
  final String currency;
  final String subtitle;
  final EdgeInsetsGeometry? padding;

  const TransactionItem({
    super.key,
    required this.transaction,
    required this.currency,
    required this.subtitle,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.category.toLowerCase() == 'income';
    final activeColor = isIncome ? const Color(0xFF10B981) : TallyTapTheme.textLight;
    final icon = TallyTapTheme.getIconForCategory(transaction.category, isIncome);
    final iconBg = TallyTapTheme.getIconBgForCategory(transaction.category, isIncome);
    final iconColor = isIncome ? const Color(0xFF10B981) : TallyTapTheme.textLight;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TransactionDetailsScreen(transaction: transaction),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: padding ?? const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    transaction.merchant,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: TallyTapTheme.textLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: TallyTapTheme.textGray),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${isIncome ? '+' : '-'} $currency${transaction.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: activeColor,
                  ),
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
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
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
