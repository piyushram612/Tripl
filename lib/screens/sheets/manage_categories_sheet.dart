import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'manage_items_sheet.dart';
import '../../providers/category_provider.dart';
import '../../providers/customization_provider.dart';
import '../../providers/budget_provider.dart';
import '../../services/transaction_service.dart';
import '../../models/transaction_model.dart';
import '../../core/theme.dart';

class ManageCategoriesSheet extends ConsumerWidget {
  const ManageCategoriesSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesListProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: TallyTapTheme.obsidianBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ManageItemsSheet(
            title: 'Manage Categories',
            itemLabel: 'Category',
            hintText: 'Category name (e.g. Health)',
            items: categories,
            scrollController: scrollController,
            onAdd: (name) async {
              await ref.read(categoriesListProvider.notifier).addCategory(name);
              await ref.read(budgetLimitsProvider.notifier).loadLimits();
            },
            onDelete: (name) async {
              await ref.read(categoriesListProvider.notifier).deleteCategory(name);
              await ref.read(budgetLimitsProvider.notifier).loadLimits();
            },
            onUpdate: (oldName, newName) async {
              await ref.read(customizationProvider.notifier).migrateCategoryCustomizations(oldName, newName);
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
        );
      },
    );
  }
}
