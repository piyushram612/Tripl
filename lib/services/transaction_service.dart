import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction_model.dart';
import '../models/month_year.dart';
import 'database_service.dart';

export '../models/month_year.dart';

final transactionServiceProvider = Provider<TransactionService>((ref) {
  return TransactionService(DatabaseService.instance);
});

/// Global version tick that increments whenever transactions are modified in SQLite.
/// Dependent monthly / search providers listen to this to invalidate caches seamlessly.
final transactionDbVersionProvider = StateProvider<int>((ref) => 0);

final transactionListProvider = StateNotifierProvider<TransactionListNotifier, List<ExpenseTransaction>>((ref) {
  final service = ref.watch(transactionServiceProvider);
  return TransactionListNotifier(service, ref);
});

/// Available months in the database as a list of MonthYear objects (e.g. Sep 2026, Aug 2026)
final availableMonthsProvider = FutureProvider<List<MonthYear>>((ref) async {
  // Re-run whenever DB version changes
  ref.watch(transactionDbVersionProvider);
  final service = ref.watch(transactionServiceProvider);
  return service.getAvailableMonths();
});

/// On-demand family provider: fetches ONLY the transactions for a requested MonthYear
final monthlyTransactionsProvider = FutureProvider.family<List<ExpenseTransaction>, MonthYear>((ref, monthYear) async {
  ref.watch(transactionDbVersionProvider);
  final service = ref.watch(transactionServiceProvider);
  return service.getTransactionsForMonth(monthYear.year, monthYear.month);
});

/// Fast indexed search across all historical transactions
final transactionSearchProvider = FutureProvider.family<List<ExpenseTransaction>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];
  ref.watch(transactionDbVersionProvider);
  final service = ref.watch(transactionServiceProvider);
  return service.searchTransactions(query);
});

class TransactionListNotifier extends StateNotifier<List<ExpenseTransaction>> {
  final TransactionService _service;
  final Ref _ref;
  int _currentSession = 0;
  final Completer<void> _initCompleter = Completer<void>();

  TransactionListNotifier(this._service, this._ref) : super([]) {
    loadTransactions();
  }

  /// Awaits until the initial database load has completely finished.
  Future<void> ensureLoaded() => _initCompleter.future;

  void _notifyDbChanged() {
    _ref.read(transactionDbVersionProvider.notifier).state++;
  }

  Future<void> loadTransactions() async {
    final session = ++_currentSession;
    try {
      final list = await _service.getTransactions();
      if (session == _currentSession) {
        state = list;
      }
    } catch (e) {
      debugPrint('⚠️ [TransactionListNotifier] Error loading transactions: $e');
    } finally {
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    }
  }

  Future<void> addTransaction(ExpenseTransaction tx) async {
    await ensureLoaded();
    await _service.insertTransaction(tx);
    final updatedList = [tx, ...state]..sort((a, b) => b.date.compareTo(a.date));
    state = updatedList;
    _notifyDbChanged();
  }

  Future<void> addTransactions(List<ExpenseTransaction> txs) async {
    await ensureLoaded();
    await _service.insertTransactions(txs);
    final Map<String, ExpenseTransaction> merged = {
      for (var tx in state) tx.id: tx,
    };
    for (var tx in txs) {
      merged[tx.id] = tx;
    }
    final updatedList = merged.values.toList()..sort((a, b) => b.date.compareTo(a.date));
    state = updatedList;
    _notifyDbChanged();
  }

  Future<void> updateTransaction(ExpenseTransaction tx) async {
    await ensureLoaded();
    await _service.updateTransaction(tx);
    final updatedList = state.map((item) => item.id == tx.id ? tx : item).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    state = updatedList;
    _notifyDbChanged();
  }

  Future<void> updateTransfer({
    required String groupId,
    required String fromAccount,
    required String toAccount,
    required double amount,
    required DateTime date,
    required String notes,
  }) async {
    await ensureLoaded();
    await _service.updateTransfer(
      groupId: groupId,
      fromAccount: fromAccount,
      toAccount: toAccount,
      amount: amount,
      date: date,
      notes: notes,
    );
    await loadTransactions();
    _notifyDbChanged();
  }

  Future<void> deleteTransaction(String id) async {
    await ensureLoaded();
    await _service.deleteTransaction(id);
    final toDeleteIndex = state.indexWhere((tx) => tx.id == id);
    if (toDeleteIndex == -1) return;

    final toDelete = state[toDeleteIndex];
    final updatedList = List<ExpenseTransaction>.from(state);
    if (toDelete.category.toLowerCase() == 'transfer' && toDelete.groupId != null) {
      updatedList.removeWhere((tx) => tx.groupId == toDelete.groupId);
    } else {
      updatedList.removeAt(toDeleteIndex);
    }
    state = updatedList;
    _notifyDbChanged();
  }

  Future<void> clearTransactions() async {
    await ensureLoaded();
    await _service.clearAll();
    state = [];
    _notifyDbChanged();
  }

  Future<void> importTransactions(List<ExpenseTransaction> txs, {bool overwrite = false}) async {
    await ensureLoaded();
    if (overwrite) {
      await _service.clearAll();
      await _service.insertTransactions(txs);
      final updatedList = List<ExpenseTransaction>.from(txs)..sort((a, b) => b.date.compareTo(a.date));
      state = updatedList;
    } else {
      await _service.insertTransactions(txs);
      final Map<String, ExpenseTransaction> merged = {
        for (var tx in state) tx.id: tx,
      };
      for (var tx in txs) {
        merged[tx.id] = tx;
      }
      final updatedList = merged.values.toList()..sort((a, b) => b.date.compareTo(a.date));
      state = updatedList;
    }
    _notifyDbChanged();
  }
}

class TransactionService {
  final DatabaseService _dbService;

  TransactionService([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService.instance;

  Future<List<ExpenseTransaction>> getTransactions() async {
    return _dbService.getAllTransactions();
  }

  Future<List<MonthYear>> getAvailableMonths() async {
    final rawYmList = await _dbService.getAvailableMonths();
    return rawYmList.map((ym) => MonthYear.fromYearMonthString(ym)).toList();
  }

  Future<List<ExpenseTransaction>> getTransactionsForMonth(int year, int month) async {
    return _dbService.getTransactionsForMonth(year, month);
  }

  Future<List<ExpenseTransaction>> searchTransactions(String query, {int limit = 60}) async {
    return _dbService.searchTransactions(query, limit: limit);
  }

  Future<void> insertTransaction(ExpenseTransaction tx) async {
    await _dbService.insertTransaction(tx);
  }

  Future<void> insertTransactions(List<ExpenseTransaction> txs) async {
    await _dbService.insertTransactions(txs);
  }

  Future<void> updateTransaction(ExpenseTransaction updatedTx) async {
    await _dbService.updateTransaction(updatedTx);
  }

  Future<void> deleteTransaction(String id) async {
    await _dbService.deleteTransaction(id);
  }

  Future<void> updateTransfer({
    required String groupId,
    required String fromAccount,
    required String toAccount,
    required double amount,
    required DateTime date,
    required String notes,
  }) async {
    await _dbService.updateTransfer(
      groupId: groupId,
      fromAccount: fromAccount,
      toAccount: toAccount,
      amount: amount,
      date: date,
      notes: notes,
    );
  }

  Future<void> clearAll() async {
    await _dbService.clearAllTransactions();
  }

  Future<void> saveTransactions(List<ExpenseTransaction> txs, {bool overwrite = false}) async {
    if (overwrite) {
      await _dbService.clearAllTransactions();
    }
    await _dbService.insertTransactions(txs);
  }
}
