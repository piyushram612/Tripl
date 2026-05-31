import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'manage_items_sheet.dart';
import '../../providers/category_provider.dart';
import '../../providers/budget_provider.dart';
import '../../services/transaction_service.dart';
import '../../models/transaction_model.dart';
import '../../core/theme.dart';

class ManageCategoriesSheet extends ConsumerWidget {
  const ManageCategoriesSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesListProvider);
    final intents = ref.watch(categoryIntentsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: TallyTapTheme.obsidianBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: TallyTapTheme.borderGreen,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Manage Items (rename / delete / reorder / color / icon) ──
                      ManageItemsSheet(
                        title: 'Manage Categories',
                        itemLabel: 'Category',
                        hintText: 'Category name (e.g. Health)',
                        items: categories,
                        onAdd: (name) async {
                          await ref.read(categoriesListProvider.notifier).addCategory(name);
                          await ref.read(budgetLimitsProvider.notifier).loadLimits();
                        },
                        onDelete: (name) async {
                          await ref.read(categoriesListProvider.notifier).deleteCategory(name);
                          await ref.read(budgetLimitsProvider.notifier).loadLimits();
                        },
                        onUpdate: (oldName, newName) async {
                          await ref.read(categoriesListProvider.notifier).updateCategory(oldName, newName);
                          try {
                            final txListNotifier = ref.read(transactionListProvider.notifier);
                            final transactions = ref.read(transactionListProvider);
                            for (var tx in transactions) {
                              if (tx.category == oldName) {
                                final updatedTx = ExpenseTransaction(
                                  id: tx.id,
                                  amount: tx.amount,
                                  merchant: tx.merchant,
                                  date: tx.date,
                                  paymentMethod: tx.paymentMethod,
                                  category: newName,
                                );
                                await txListNotifier.updateTransaction(updatedTx);
                              }
                            }
                          } catch (e) {
                            debugPrint("Error updating transactions: $e");
                          }
                          await ref.read(budgetLimitsProvider.notifier).loadLimits();
                        },
                        onReorder: (oldIndex, newIndex) async {
                          await ref.read(categoriesListProvider.notifier).reorderCategories(oldIndex, newIndex);
                          await ref.read(budgetLimitsProvider.notifier).loadLimits();
                        },
                      ),

                      // ── Intent Mapping Section ────────────────────────────────
                      if (categories.isNotEmpty) ...[
                        const Divider(color: TallyTapTheme.borderGreen, height: 1),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'SPENDING INTENT',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                  color: TallyTapTheme.textGray,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Assign each category to an intent bucket. This drives your Monthly Intentionality ring and Budget Split.',
                                style: TextStyle(fontSize: 12, color: TallyTapTheme.textGray, height: 1.4),
                              ),
                              const SizedBox(height: 16),
                              ...categories.map((cat) {
                                final currentIntent = intents[cat] ?? CategoryIntent.essential;
                                return _IntentRow(
                                  category: cat,
                                  currentIntent: currentIntent,
                                  onChanged: (newIntent) async {
                                    await ref.read(categoryIntentsProvider.notifier).updateIntent(cat, newIntent);
                                  },
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Intent Row — shows current intent as a tappable chip, opens popup to change
// ─────────────────────────────────────────────────────────────────────────────

class _IntentRow extends StatelessWidget {
  final String category;
  final String currentIntent;
  final ValueChanged<String> onChanged;

  const _IntentRow({
    required this.category,
    required this.currentIntent,
    required this.onChanged,
  });

  static const Map<String, Color> _intentColors = {
    CategoryIntent.essential:   Color(0xFF4EDEA3),
    CategoryIntent.joyful:      Color(0xFF9FB6DF),
    CategoryIntent.avoidable:   Color(0xFFFFB5B5),
    CategoryIntent.investments: Color(0xFF8B5CF6),
  };

  static const Map<String, IconData> _intentIcons = {
    CategoryIntent.essential:   Icons.shield_outlined,
    CategoryIntent.joyful:      Icons.favorite_outline_rounded,
    CategoryIntent.avoidable:   Icons.do_not_disturb_alt_outlined,
    CategoryIntent.investments: Icons.trending_up_outlined,
  };

  static const Map<String, String> _intentLabels = {
    CategoryIntent.essential:   'Essential',
    CategoryIntent.joyful:      'Joyful',
    CategoryIntent.avoidable:   'Avoidable',
    CategoryIntent.investments: 'Investments',
  };

  @override
  Widget build(BuildContext context) {
    final catColor      = TallyTapTheme.getColorForCategory(category);
    final catIcon       = TallyTapTheme.getIconForCategory(category);
    final selectedColor = _intentColors[currentIntent] ?? TallyTapTheme.primaryMint;
    final selectedIcon  = _intentIcons[currentIntent]  ?? Icons.shield_outlined;
    final selectedLabel = _intentLabels[currentIntent] ?? currentIntent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: TallyTapTheme.obsidianCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: TallyTapTheme.borderGreen),
        ),
        child: Row(
          children: [
            // Category colour icon
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(catIcon, color: catColor, size: 16),
            ),
            const SizedBox(width: 10),
            // Category name — Expanded so it takes available space and ellipses when tight
            Expanded(
              child: Text(
                category,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: TallyTapTheme.textLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Intent chip — stable fixed-size widget; no animated width changes
            PopupMenuButton<String>(
              onSelected: (intent) {
                HapticFeedback.selectionClick();
                onChanged(intent);
              },
              color: const Color(0xFF1A2520),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: TallyTapTheme.borderGreen),
              ),
              offset: const Offset(0, 8),
              itemBuilder: (context) => CategoryIntent.all.map((intent) {
                final ic    = _intentColors[intent]!;
                final ii    = _intentIcons[intent]!;
                final il    = _intentLabels[intent]!;
                final isSel = intent == currentIntent;
                return PopupMenuItem<String>(
                  value: intent,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: ic.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(ii, color: ic, size: 15),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        il,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
                          color: isSel ? ic : TallyTapTheme.textLight,
                        ),
                      ),
                      if (isSel) ...[
                        const Spacer(),
                        Icon(Icons.check_rounded, color: ic, size: 16),
                      ],
                    ],
                  ),
                );
              }).toList(),
              // Trigger: a stable-size chip showing icon + label + caret
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: selectedColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: selectedColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(selectedIcon, color: selectedColor, size: 12),
                    const SizedBox(width: 5),
                    Text(
                      selectedLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: selectedColor,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      color: selectedColor.withValues(alpha: 0.6),
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
