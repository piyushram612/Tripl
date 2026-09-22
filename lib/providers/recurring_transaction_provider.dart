import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/recurring_transaction_model.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/transaction_service.dart';

final recurringTransactionsProvider = StateNotifierProvider<RecurringTransactionsNotifier, List<RecurringTransaction>>((ref) {
  return RecurringTransactionsNotifier(ref);
});

class RecurringTransactionsNotifier extends StateNotifier<List<RecurringTransaction>> {
  final Ref _ref;
  final DatabaseService _dbService = DatabaseService.instance;
  Timer? _timer;
  final Completer<void> _initCompleter = Completer<void>();

  RecurringTransactionsNotifier(this._ref) : super([]) {
    _loadTransactions();
    _startTimer();
  }

  Future<void> ensureLoaded() => _initCompleter.future;

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      _processDueTransactions();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    try {
      final list = await _dbService.getAllRecurringTransactions();
      state = list;
    } catch (e) {
      debugPrint('⚠️ [RecurringTransactionsNotifier] Error loading: $e');
    } finally {
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    }
    await _ref.read(transactionListProvider.notifier).ensureLoaded();
    await _processDueTransactions();
  }

  Future<void> _processDueTransactions() async {
    await ensureLoaded();
    await _ref.read(transactionListProvider.notifier).ensureLoaded();
    bool stateChanged = false;
    final List<RecurringTransaction> updatedState = List.from(state);

    for (int i = 0; i < updatedState.length; i++) {
      RecurringTransaction tx = updatedState[i];
      if (tx.status != RecurringStatus.active) continue;

      bool txChanged = false;
      while (tx.nextDueDate.isBefore(DateTime.now()) || tx.nextDueDate.isAtSameMomentAs(DateTime.now())) {
        if (tx.autoCreate) {
          final newExpense = ExpenseTransaction(
            id: const Uuid().v4(),
            amount: tx.amount,
            merchant: tx.merchant ?? tx.title,
            date: tx.nextDueDate,
            paymentMethod: tx.paymentMethod,
            category: tx.category,
            needsVerification: tx.logAsPending,
            wasFinishLater: tx.logAsPending,
            isIncome: tx.type == TransactionType.income,
          );
          await _ref.read(transactionListProvider.notifier).addTransaction(newExpense);
          
          tx = tx.advance();
          txChanged = true;

          if (tx.status == RecurringStatus.completed) {
            break;
          }
        } else {
          break;
        }
      }

      if (txChanged) {
        updatedState[i] = tx;
        stateChanged = true;
        await _dbService.updateRecurringTransaction(tx);
      }
    }

    if (stateChanged) {
      state = updatedState;
      for (var tx in updatedState) {
        if (tx.status == RecurringStatus.active && tx.reminderEnabled) {
          await NotificationService.scheduleRecurringNotification(tx);
        }
      }
    }
  }

  Future<void> checkDueTransactions() async {
    await ensureLoaded();
    await _ref.read(transactionListProvider.notifier).ensureLoaded();
    await _processDueTransactions();
  }

  Future<void> addTransaction(RecurringTransaction transaction) async {
    await ensureLoaded();
    await _dbService.insertRecurringTransaction(transaction);
    final newState = [...state, transaction];
    state = newState;
    
    if (transaction.reminderEnabled) {
      await NotificationService.scheduleRecurringNotification(transaction);
    }

    await _processDueTransactions();
  }

  Future<void> updateTransaction(RecurringTransaction transaction) async {
    await ensureLoaded();
    await _dbService.updateRecurringTransaction(transaction);
    final newState = [
      for (final tx in state)
        if (tx.id == transaction.id) transaction else tx,
    ];
    state = newState;
    
    if (transaction.reminderEnabled) {
      await NotificationService.scheduleRecurringNotification(transaction);
    } else {
      await NotificationService.cancelNotification(transaction.id);
    }

    await _processDueTransactions();
  }

  Future<void> deleteTransaction(String id) async {
    await ensureLoaded();
    await _dbService.deleteRecurringTransaction(id);
    final newState = state.where((tx) => tx.id != id).toList();
    state = newState;
    await NotificationService.cancelNotification(id);
  }

  Future<void> togglePause(String id) async {
    await ensureLoaded();
    final tx = state.firstWhere((element) => element.id == id);
    final newStatus = tx.status == RecurringStatus.active ? RecurringStatus.paused : RecurringStatus.active;
    final updated = tx.copyWith(status: newStatus);
    await updateTransaction(updated);
  }

  Future<void> markAsPaid(String id) async {
    await ensureLoaded();
    final index = state.indexWhere((tx) => tx.id == id);
    if (index == -1) return;
    
    var tx = state[index];
    if (tx.status != RecurringStatus.active) return;

    final newExpense = ExpenseTransaction(
      id: const Uuid().v4(),
      amount: tx.amount,
      merchant: tx.merchant ?? tx.title,
      date: DateTime.now(),
      paymentMethod: tx.paymentMethod,
      category: tx.category,
      isIncome: tx.type == TransactionType.income,
    );
    await _ref.read(transactionListProvider.notifier).addTransaction(newExpense);

    final updatedTx = tx.advance();
    await updateTransaction(updatedTx);
  }

  Future<void> skip(String id) async {
    await ensureLoaded();
    final index = state.indexWhere((tx) => tx.id == id);
    if (index == -1) return;
    
    var tx = state[index];
    if (tx.status != RecurringStatus.active) return;

    final updatedTx = tx.advance(skip: true);
    await updateTransaction(updatedTx);
  }
}
