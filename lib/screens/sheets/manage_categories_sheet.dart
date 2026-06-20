import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'manage_items_sheet.dart';
import '../../providers/category_provider.dart';
import '../../providers/customization_provider.dart';
import '../../providers/budget_provider.dart';
import '../../services/transaction_service.dart';
import '../../models/transaction_model.dart';
import '../../core/theme.dart';

class ManageCategoriesSheet extends ConsumerStatefulWidget {
  const ManageCategoriesSheet({super.key});

  @override
  ConsumerState<ManageCategoriesSheet> createState() => _ManageCategoriesSheetState();
}

class _ManageCategoriesSheetState extends ConsumerState<ManageCategoriesSheet> {
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  static const double _minSize = 0.35;
  static const double _maxSize = 0.95;

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesListProvider);

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.55,
      minChildSize: _minSize,
      maxChildSize: _maxSize,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: TallyTapTheme.obsidianBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle pill — dedicated gesture so it always expands/collapses
              // regardless of inner scroll position.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (details) {
                  final screenH = MediaQuery.of(context).size.height;
                  final delta = -details.primaryDelta! / screenH;
                  final next = (_sheetController.size + delta).clamp(_minSize, _maxSize);
                  _sheetController.jumpTo(next);
                },
                onTap: () {
                  final target = _sheetController.size < 0.7 ? _maxSize : _minSize;
                  _sheetController.animateTo(
                    target,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: TallyTapTheme.borderGreen,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
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
              await ref.read(categoryVisibilityProvider.notifier).removeVisibility(name);
              await ref.read(categoriesListProvider.notifier).deleteCategory(name);
              await ref.read(budgetLimitsProvider.notifier).loadLimits();
            },
            onUpdate: (oldName, newName) async {
              await ref.read(customizationProvider.notifier).migrateCategoryCustomizations(oldName, newName);
              await ref.read(categoryVisibilityProvider.notifier).renameVisibility(oldName, newName);
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
              ),
            ],
          ),
        );
      },
    );
  }
}
