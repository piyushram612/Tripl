import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/outstanding_model.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';
import '../services/transaction_service.dart';

final outstandingListProvider = StateNotifierProvider<OutstandingListNotifier, List<OutstandingRecord>>((ref) {
  return OutstandingListNotifier(ref);
});

class OutstandingListNotifier extends StateNotifier<List<OutstandingRecord>> {
  final Ref _ref;
  final DatabaseService _dbService = DatabaseService.instance;
  final Completer<void> _initCompleter = Completer<void>();

  OutstandingListNotifier(this._ref) : super([]) {
    loadRecords();
  }

  Future<void> ensureLoaded() => _initCompleter.future;

  Future<void> loadRecords() async {
    try {
      final list = await _dbService.getAllOutstandingRecords();
      state = list..sort((a, b) => b.date.compareTo(a.date));
    } catch (e) {
      debugPrint("⚠️ [OutstandingListNotifier] Error loading records: $e");
      state = [];
    } finally {
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    }
  }

  Future<void> addRecord(OutstandingRecord record, {bool recordTimelineTx = false, String? paymentMethod}) async {
    await ensureLoaded();
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
        isIncome: isIncome,
      );

      // Save to transaction provider
      await _ref.read(transactionListProvider.notifier).addTransaction(timelineTx);
    }

    final newRecord = record.copyWith(linkedTransactionId: linkedTxId);
    await _dbService.insertOutstandingRecord(newRecord);
    state = [newRecord, ...state]..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> settleRecord(String id, {bool recordTimelineTx = false, String? paymentMethod}) async {
    await ensureLoaded();
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
        isIncome: isIncome,
      );

      await _ref.read(transactionListProvider.notifier).addTransaction(timelineTx);
    }

    final updated = record.copyWith(
      isSettled: true,
      settledDate: DateTime.now(),
      linkedTransactionId: settleTxId ?? record.linkedTransactionId,
    );

    await _dbService.updateOutstandingRecord(updated);

    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index) updated else state[i]
    ];
  }

  Future<void> settleRecordPartial(
    String id,
    double settleAmount, {
    bool recordTimelineTx = false,
    String? paymentMethod,
  }) async {
    await ensureLoaded();
    final index = state.indexWhere((r) => r.id == id);
    if (index == -1) return;

    final record = state[index];
    if (record.isSettled) return;

    if (settleAmount >= record.amount) {
      await settleRecord(id, recordTimelineTx: recordTimelineTx, paymentMethod: paymentMethod);
      return;
    }

    if (settleAmount <= 0) return;

    String? settleTxId;

    if (recordTimelineTx && paymentMethod != null) {
      final txId = DateTime.now().millisecondsSinceEpoch.toString();
      settleTxId = txId;

      final isIncome = record.isLent; // Getting paid back = inflow (Income), Paying back = outflow (Expense)

      final timelineTx = ExpenseTransaction(
        id: txId,
        amount: settleAmount,
        merchant: record.personName,
        date: DateTime.now(),
        paymentMethod: paymentMethod,
        category: isIncome ? 'Income' : 'Other',
        notes: record.isLent
            ? 'Partial settlement: Rahul paid back for "${record.notes}"'.replaceAll('Rahul', record.personName)
            : 'Partial settlement: Paid back Rahul for "${record.notes}"'.replaceAll('Rahul', record.personName),
        paidTo: !record.isLent ? record.personName : '',
        isIncome: isIncome,
      );

      await _ref.read(transactionListProvider.notifier).addTransaction(timelineTx);
    }

    final remainingRecord = record.copyWith(
      amount: record.amount - settleAmount,
    );

    final settledRecord = OutstandingRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      personName: record.personName,
      amount: settleAmount,
      notes: record.notes.isNotEmpty
          ? '${record.notes} (Partial settlement)'
          : 'Partial settlement',
      date: record.date,
      isLent: record.isLent,
      isSettled: true,
      settledDate: DateTime.now(),
      linkedTransactionId: settleTxId,
    );

    await _dbService.updateOutstandingRecord(remainingRecord);
    await _dbService.insertOutstandingRecord(settledRecord);

    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index) remainingRecord else state[i],
      settledRecord,
    ]..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> settlePersonAmount(
    String personName,
    double settleAmount,
    bool isLentDirection, {
    String? linkedTimelineTxId,
  }) async {
    await ensureLoaded();
    if (settleAmount <= 0) return;

    double remainingToSettle = settleAmount;

    final activeForPerson = state.where((r) => !r.isSettled && r.personName == personName).toList();
    activeForPerson.sort((a, b) {
      if (a.isLent == isLentDirection && b.isLent != isLentDirection) return -1;
      if (a.isLent != isLentDirection && b.isLent == isLentDirection) return 1;
      return a.date.compareTo(b.date);
    });

    final Map<String, OutstandingRecord> modifiedActive = {};
    final List<OutstandingRecord> newSettled = [];

    for (final r in activeForPerson) {
      if (remainingToSettle <= 0) break;

      if (r.amount <= remainingToSettle + 0.0001) {
        remainingToSettle -= r.amount;
        final updated = r.copyWith(
          isSettled: true,
          settledDate: DateTime.now(),
          linkedTransactionId: linkedTimelineTxId ?? r.linkedTransactionId,
        );
        modifiedActive[r.id] = updated;
        await _dbService.updateOutstandingRecord(updated);
      } else {
        final portion = remainingToSettle;
        remainingToSettle = 0;

        final updated = r.copyWith(
          amount: r.amount - portion,
        );
        modifiedActive[r.id] = updated;
        await _dbService.updateOutstandingRecord(updated);

        final newRec = OutstandingRecord(
          id: '${DateTime.now().millisecondsSinceEpoch}_${newSettled.length}',
          personName: r.personName,
          amount: portion,
          notes: r.notes.isNotEmpty ? '${r.notes} (Partial settlement)' : 'Partial settlement',
          date: r.date,
          isLent: r.isLent,
          isSettled: true,
          settledDate: DateTime.now(),
          linkedTransactionId: linkedTimelineTxId,
        );
        newSettled.add(newRec);
        await _dbService.insertOutstandingRecord(newRec);
      }
    }

    state = [
      for (final r in state)
        if (modifiedActive.containsKey(r.id)) modifiedActive[r.id]! else r,
      ...newSettled,
    ]..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> deleteRecord(String id) async {
    await ensureLoaded();
    await _dbService.deleteOutstandingRecord(id);
    state = state.where((r) => r.id != id).toList();
  }

  Future<void> clearAll() async {
    final db = await _dbService.database;
    await db.delete('outstanding_records');
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
    final isIncome = tx.isIncome;
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
