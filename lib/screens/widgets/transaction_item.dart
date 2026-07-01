import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/transaction_model.dart';
import '../transaction_details_screen.dart';
import '../tools/transfer_details_screen.dart';

class TransactionItem extends StatelessWidget {
  final ExpenseTransaction transaction;
  final String currency;
  final String subtitle;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool? isIncomeOverride;

  const TransactionItem({
    super.key,
    required this.transaction,
    required this.currency,
    required this.subtitle,
    this.padding,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.isIncomeOverride,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = isIncomeOverride ?? transaction.isIncome;
    final isTransfer = transaction.category.toLowerCase() == 'transfer';
    final activeColor = isTransfer
        ? const Color(0xFF94A3B8)
        : (isIncome ? const Color(0xFF10B981) : TallyTapTheme.textLight);
    
    final icon = isSelected
        ? Icons.check_circle_rounded
        : TallyTapTheme.getIconForCategory(transaction.category, isIncome);
    final iconBg = isSelected
        ? TallyTapTheme.primaryMint.withOpacity(0.15)
        : TallyTapTheme.getIconBgForCategory(transaction.category, isIncome);
    final iconColor = isSelected
        ? TallyTapTheme.primaryMint
        : (isTransfer
            ? const Color(0xFF94A3B8)
            : (isIncome ? const Color(0xFF10B981) : TallyTapTheme.textLight));

    return InkWell(
      onTap: onTap ?? () {
        if (isTransfer) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TransferDetailsScreen(transactionId: transaction.id),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TransactionDetailsScreen(transaction: transaction),
            ),
          );
        }
      },
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected 
              ? TallyTapTheme.primaryMint.withOpacity(0.05) 
              : (transaction.needsVerification ? const Color(0xFFF59E0B).withOpacity(0.05) : Colors.transparent),
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: TallyTapTheme.primaryMint.withOpacity(0.3), width: 1.0)
              : (transaction.needsVerification ? Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3), width: 1.0) : null),
        ),
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
                  border: Border.all(
                    color: isSelected ? TallyTapTheme.primaryMint : TallyTapTheme.borderGreen,
                    width: 0.5,
                  ),
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
                    '${isTransfer ? '' : (isIncome ? '+ ' : '- ')}$currency${transaction.amount.abs().toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: activeColor,
                    ),
                  ),
                  if (isTransfer) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF334155), width: 0.5),
                      ),
                      child: const Text(
                        'Transfer',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ] else ...[
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
                    if (transaction.needsVerification) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B2314),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF7A3E14), width: 0.5),
                        ),
                        child: const Text(
                          'Pending',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
