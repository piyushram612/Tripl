import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';

final currencyProvider = StateNotifierProvider<CurrencyNotifier, String>((ref) {
  return CurrencyNotifier();
});

class CurrencyNotifier extends StateNotifier<String> {
  CurrencyNotifier() : super('₹') {
    loadCurrency();
  }

  static const Map<String, double> exchangeRates = {
    '\$': 1.0,
    '₹': 95.0,
    '€': 0.92,
    '£': 0.79,
    '¥': 150.0,
  };

  Future<void> loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    state = prefs.getString('currency_symbol') ?? '₹';
  }

  Future<void> setCurrency(
    String newCurrency, {
    required bool convertValues,
    required bool applyToExisting,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final oldCurrency = prefs.getString('currency_symbol') ?? '₹';
    if (oldCurrency == newCurrency) return;

    final oldRate = exchangeRates[oldCurrency] ?? 95.0;
    final newRate = exchangeRates[newCurrency] ?? 95.0;
    final rate = convertValues ? (newRate / oldRate) : 1.0;

    // Update transactions if requested and rate is not 1.0 (or even if rate is 1.0 but convertValues is false, we don't scale)
    if (applyToExisting && rate != 1.0) {
      final txJsonStr = prefs.getString('transactions_json');
      if (txJsonStr != null && txJsonStr != '[]') {
        try {
          final List<dynamic> decoded = json.decode(txJsonStr);
          final updated = decoded.map((item) {
            final tx = ExpenseTransaction.fromMap(item);
            return ExpenseTransaction(
              id: tx.id,
              amount: tx.amount * rate,
              merchant: tx.merchant,
              date: tx.date,
              paymentMethod: tx.paymentMethod,
              category: tx.category,
              notes: tx.notes,
              paidTo: tx.paidTo,
              needsVerification: tx.needsVerification,
              reminderDate: tx.reminderDate,
              groupId: tx.groupId,
            ).toMap();
          }).toList();
          await prefs.setString('transactions_json', json.encode(updated));
        } catch (_) {}
      }
    }

    // Update global budget and category budgets if convertValues is true
    if (rate != 1.0) {
      // Update global budget
      final globalAmount = prefs.getDouble('global_budget_amount') ?? 2000.0;
      await prefs.setDouble('global_budget_amount', globalAmount * rate);

      // Update category budgets
      final catsStr = prefs.getString('categories_json');
      List<String> categories = ['Dining', 'Commute', 'Subscriptions', 'Utilities', 'Groceries', 'Shopping', 'Housing', 'Health', 'Travel', 'Other'];
      if (catsStr != null && catsStr.isNotEmpty) {
        try {
          categories = List<String>.from(json.decode(catsStr));
        } catch (_) {}
      }
      for (final cat in categories) {
        final key = 'budget_limit_$cat';
        if (prefs.containsKey(key)) {
          final limit = prefs.getDouble(key)!;
          await prefs.setDouble(key, limit * rate);
        }
      }
    }

    await prefs.setString('currency_symbol', newCurrency);
    state = newCurrency;
  }
}
