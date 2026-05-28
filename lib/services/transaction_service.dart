import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';

final transactionServiceProvider = Provider<TransactionService>((ref) {
  return TransactionService();
});

final transactionListProvider = StateNotifierProvider<TransactionListNotifier, List<ExpenseTransaction>>((ref) {
  final service = ref.watch(transactionServiceProvider);
  return TransactionListNotifier(service);
});

class TransactionListNotifier extends StateNotifier<List<ExpenseTransaction>> {
  final TransactionService _service;

  TransactionListNotifier(this._service) : super([]) {
    loadTransactions();
  }

  Future<void> loadTransactions() async {
    final list = await _service.getTransactions();
    state = list;
  }

  Future<void> addTransaction(ExpenseTransaction tx) async {
    await _service.saveTransaction(tx);
    await loadTransactions();
  }

  Future<void> updateTransaction(ExpenseTransaction tx) async {
    await _service.updateTransaction(tx);
    await loadTransactions();
  }

  Future<void> deleteTransaction(String id) async {
    await _service.deleteTransaction(id);
    await loadTransactions();
  }

  Future<void> clearTransactions() async {
    await _service.clearAll();
    await loadTransactions();
  }
}

class TransactionService {
  static const String _key = 'transactions_json';

  Future<List<ExpenseTransaction>> getTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    
    // One-time clear of old mock data so the user starts with a clean database
    if (!(prefs.getBool('is_mock_cleared_v3') ?? false)) {
      await prefs.remove(_key);
      await prefs.setBool('is_mock_cleared_v3', true);
    }
    
    await prefs.reload(); // Force reload from disk to sync with native overlay instantly!
    final jsonStr = prefs.getString(_key);

    if (jsonStr == null || jsonStr == '[]') {
      return [];
    }

    try {
      final List<dynamic> decoded = json.decode(jsonStr);
      return decoded.map((item) => ExpenseTransaction.fromMap(item)).toList()
        ..sort((a, b) => b.date.compareTo(a.date)); // Sort newest first
    } catch (e) {
      print("Error decoding transactions: $e");
      return [];
    }
  }

  Future<void> saveTransaction(ExpenseTransaction tx) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getTransactions();
    list.add(tx);
    await prefs.setString(_key, json.encode(list.map((e) => e.toMap()).toList()));
  }

  Future<void> updateTransaction(ExpenseTransaction updatedTx) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getTransactions();
    final index = list.indexWhere((tx) => tx.id == updatedTx.id);
    if (index != -1) {
      list[index] = updatedTx;
      await prefs.setString(_key, json.encode(list.map((e) => e.toMap()).toList()));
    }
  }

  Future<void> deleteTransaction(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getTransactions();
    list.removeWhere((tx) => tx.id == id);
    await prefs.setString(_key, json.encode(list.map((e) => e.toMap()).toList()));
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
