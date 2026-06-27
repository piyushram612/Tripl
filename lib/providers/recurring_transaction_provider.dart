import 'dart:convert';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/recurring_transaction_model.dart';
import '../models/transaction_model.dart';
import '../services/notification_service.dart';
import '../services/transaction_service.dart';

final recurringTransactionsProvider = StateNotifierProvider<RecurringTransactionsNotifier, List<RecurringTransaction>>((ref) {
  return RecurringTransactionsNotifier(ref);
});

class RecurringTransactionsNotifier extends StateNotifier<List<RecurringTransaction>> {
  static const _storageKey = 'tallytap_recurring_transactions';
  final Ref _ref;
  Timer? _timer;

  RecurringTransactionsNotifier(this._ref) : super([]) {
    _loadTransactions();
    _startTimer();
  }

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
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_storageKey);
    if (data != null) {
      final List<dynamic> decoded = json.decode(data);
      state = decoded.map((item) => RecurringTransaction.fromMap(item)).toList();
    }
    await _processDueTransactions();
  }

  Future<void> _processDueTransactions() async {
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
      }
    }

    if (stateChanged) {
      state = updatedState;
      await _saveTransactions(updatedState);
      for (var tx in updatedState) {
        if (tx.status == RecurringStatus.active && tx.reminderEnabled) {
          await NotificationService.scheduleRecurringNotification(tx);
        }
      }
    }
  }

  Future<void> checkDueTransactions() async {
    await _processDueTransactions();
  }

  Future<void> _saveTransactions(List<RecurringTransaction> transactions) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = json.encode(transactions.map((tx) => tx.toMap()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  Future<void> addTransaction(RecurringTransaction transaction) async {
    final newState = [...state, transaction];
    state = newState;
    await _saveTransactions(newState);
    
    if (transaction.reminderEnabled) {
      await NotificationService.scheduleRecurringNotification(transaction);
    }

    await _processDueTransactions();
  }

  Future<void> updateTransaction(RecurringTransaction transaction) async {
    final newState = [
      for (final tx in state)
        if (tx.id == transaction.id) transaction else tx,
    ];
    state = newState;
    await _saveTransactions(newState);
    
    if (transaction.reminderEnabled) {
      await NotificationService.scheduleRecurringNotification(transaction);
    } else {
      await NotificationService.cancelNotification(transaction.id);
    }

    await _processDueTransactions();
  }

  Future<void> deleteTransaction(String id) async {
    final newState = state.where((tx) => tx.id != id).toList();
    state = newState;
    await _saveTransactions(newState);
    await NotificationService.cancelNotification(id);
  }

  Future<void> togglePause(String id) async {
    final tx = state.firstWhere((element) => element.id == id);
    final newStatus = tx.status == RecurringStatus.active ? RecurringStatus.paused : RecurringStatus.active;
    final updated = tx.copyWith(status: newStatus);
    await updateTransaction(updated);
  }

  Future<void> markAsPaid(String id) async {
    final index = state.indexWhere((tx) => tx.id == id);
    if (index == -1) return;
    
    var tx = state[index];
    if (tx.status != RecurringStatus.active) return;

    final newExpense = ExpenseTransaction(
      id: const Uuid().v4(),
      amount: tx.amount,
      merchant: tx.merchant ?? tx.title,
      date: DateTime.now(), // Create transaction with current time
      paymentMethod: tx.paymentMethod,
      category: tx.category,
      isIncome: tx.type == TransactionType.income,
    );
    await _ref.read(transactionListProvider.notifier).addTransaction(newExpense);

    final updatedTx = tx.advance();
    await updateTransaction(updatedTx);
  }

  Future<void> skip(String id) async {
    final index = state.indexWhere((tx) => tx.id == id);
    if (index == -1) return;
    
    var tx = state[index];
    if (tx.status != RecurringStatus.active) return;

    final updatedTx = tx.advance(skip: true);
    await updateTransaction(updatedTx);
  }
}
