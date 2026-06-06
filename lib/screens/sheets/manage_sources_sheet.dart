import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'manage_items_sheet.dart';
import '../../providers/source_provider.dart';
import '../../providers/customization_provider.dart';
import '../../services/transaction_service.dart';
import '../../models/transaction_model.dart';

class ManageSourcesSheet extends ConsumerWidget {
  const ManageSourcesSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(sourcesListProvider);

    return ManageItemsSheet(
      title: 'Manage Payment Sources',
      itemLabel: 'Payment Source',
      hintText: 'Source name (e.g. Cash, Credit Card)',
      items: sources,
      onAdd: (name) async {
        await ref.read(sourcesListProvider.notifier).addSource(name);
      },
      onDelete: (name) async {
        await ref.read(sourcesListProvider.notifier).deleteSource(name);
      },
      onUpdate: (oldName, newName) async {
        await ref.read(customizationProvider.notifier).migrateSourceCustomizations(oldName, newName);
        await ref.read(sourcesListProvider.notifier).updateSource(oldName, newName);
        
        // Proactively update all transactions using this source name to maintain integrity
        try {
          final txListNotifier = ref.read(transactionListProvider.notifier);
          final transactions = ref.read(transactionListProvider);
          for (var tx in transactions) {
            if (tx.paymentMethod == oldName) {
              final updatedTx = ExpenseTransaction(
                id: tx.id,
                amount: tx.amount,
                merchant: tx.merchant,
                date: tx.date,
                paymentMethod: newName,
                category: tx.category,
              );
              await txListNotifier.updateTransaction(updatedTx);
            }
          }
        } catch (e) {
          debugPrint("Error updating transactions: $e");
        }
      },
      onReorder: (oldIndex, newIndex) async {
        await ref.read(sourcesListProvider.notifier).reorderSources(oldIndex, newIndex);
      },
    );
  }
}
