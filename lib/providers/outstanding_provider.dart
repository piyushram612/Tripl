import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/outstanding_model.dart';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';

final outstandingListProvider = StateNotifierProvider<OutstandingListNotifier, List<OutstandingRecord>>((ref) {
  return OutstandingListNotifier(ref);
});

class OutstandingListNotifier extends StateNotifier<List<OutstandingRecord>> {
  final Ref _ref;
  static const String _storageKey = 'outstanding_ledger_json';

  OutstandingListNotifier(this._ref) : super([]) {
    loadRecords();
  }

  Future<void> loadRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr == null || jsonStr == '[]') {
        state = [];
        return;
      }
      final List<dynamic> decoded = json.decode(jsonStr);
      state = decoded.map((item) => OutstandingRecord.fromMap(item)).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    } catch (e) {
      print("Error loading outstanding records: $e");
      state = [];
    }
  }

  Future<void> addRecord(OutstandingRecord record, {bool recordTimelineTx = false, String? paymentMethod}) async {
    String? linkedTxId;

    if (recordTimelineTx && paymentMethod != null) {
      // Automatically generate a transaction in the timeline
      final txId = DateTime.now().millisecondsSinceEpoch.toString();
      linkedTxId = txId;

      final isIncome = !record.isLent; // Borrowing money = inflow (Income), Lending money = outflow (Expense)

      final timelineTx = ExpenseTransaction(
        id: txId,
        amount: record.amount,
        merchant: record.personName,
        date: record.date,
        paymentMethod: paymentMethod,
        category: isIncome ? 'Income' : 'Other',
        notes: record.isLent
            ? 'Lent: ${record.notes}'.trim()
            : 'Borrowed: ${record.notes}'.trim(),
        paidTo: record.isLent ? record.personName : '',
      );

      // Save to transaction provider
      await _ref.read(transactionListProvider.notifier).addTransaction(timelineTx);
    }

    final newRecord = record.copyWith(linkedTransactionId: linkedTxId);
    state = [newRecord, ...state]..sort((a, b) => b.date.compareTo(a.date));
    await _saveToDisk();
  }

  Future<void> settleRecord(String id, {bool recordTimelineTx = false, String? paymentMethod}) async {
    final index = state.indexWhere((r) => r.id == id);
    if (index == -1) return;

    final record = state[index];
    if (record.isSettled) return;

    String? settleTxId;

    if (recordTimelineTx && paymentMethod != null) {
      // Automatically log the settlement event to the timeline
      final txId = DateTime.now().millisecondsSinceEpoch.toString();
      settleTxId = txId;

      final isIncome = record.isLent; // Getting paid back = inflow (Income), Paying back = outflow (Expense)

      final timelineTx = ExpenseTransaction(
        id: txId,
        amount: record.amount,
        merchant: record.personName,
        date: DateTime.now(),
        paymentMethod: paymentMethod,
        category: isIncome ? 'Income' : 'Other',
        notes: record.isLent
            ? 'Settled: Rahul paid back for "${record.notes}"'.replaceAll('Rahul', record.personName)
            : 'Settled: Paid back Rahul for "${record.notes}"'.replaceAll('Rahul', record.personName),
        paidTo: !record.isLent ? record.personName : '',
      );

      await _ref.read(transactionListProvider.notifier).addTransaction(timelineTx);
    }

    final updated = record.copyWith(
      isSettled: true,
      settledDate: DateTime.now(),
      // Track the settle transaction id if we recorded one
      linkedTransactionId: settleTxId ?? record.linkedTransactionId,
    );

    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index) updated else state[i]
    ];

    await _saveToDisk();
  }

  Future<void> deleteRecord(String id) async {
    state = state.where((r) => r.id != id).toList();
    await _saveToDisk();
  }

  Future<void> _saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = json.encode(state.map((r) => r.toMap()).toList());
      await prefs.setString(_storageKey, jsonStr);
    } catch (e) {
      print("Error saving outstanding records: $e");
    }
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    state = [];
  }
}

final combinedOutstandingProvider = Provider<List<OutstandingRecord>>((ref) {
  final manualRecords = ref.watch(outstandingListProvider);
  final transactions = ref.watch(transactionListProvider);

  final manualLinkedIds = manualRecords.map((r) => r.linkedTransactionId).where((id) => id != null).toSet();

  final synthRecords = transactions
      .where((tx) => tx.wasFinishLater && !tx.hideFromLedger && !manualLinkedIds.contains(tx.id))
      .map((tx) {
    final isIncome = tx.category.toLowerCase() == 'income';
    final isLent = isIncome; // Income means they owe me
    final personName = tx.paidTo.isNotEmpty ? tx.paidTo : tx.merchant;

    return OutstandingRecord(
      id: tx.id, // Synthesized records have the same ID as the transaction
      personName: personName,
      amount: tx.amount,
      notes: tx.notes.isNotEmpty ? tx.notes : tx.merchant,
      date: tx.date,
      isLent: isLent,
      isSettled: !tx.needsVerification,
      linkedTransactionId: tx.id,
    );
  }).toList();

  final allRecords = [...manualRecords, ...synthRecords];
  allRecords.sort((a, b) => b.date.compareTo(a.date));
  return allRecords;
});
