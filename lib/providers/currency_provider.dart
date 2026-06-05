import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/transaction_model.dart';

final currencyProvider = StateNotifierProvider<CurrencyNotifier, String>((ref) {
  return CurrencyNotifier();
});

class CurrencyNotifier extends StateNotifier<String> {
  CurrencyNotifier() : super('₹') {
    loadCurrency();
  }

  static const Map<String, String> _symbolToCode = {
    '\$': 'usd',
    '₹': 'inr',
    '€': 'eur',
    '£': 'gbp',
    '¥': 'jpy',
  };

  static const Map<String, double> _fallbackRatesToUsd = {
    'usd': 1.0,
    'inr': 1 / 83.0,
    'eur': 1 / 0.92,
    'gbp': 1 / 0.79,
    'jpy': 1 / 150.0,
  };

  Future<void> loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    state = prefs.getString('currency_symbol') ?? '₹';
  }

  Future<double> _fetchExchangeRate(String oldSymbol, String newSymbol) async {
    final oldCode = _symbolToCode[oldSymbol];
    final newCode = _symbolToCode[newSymbol];
    
    if (oldCode == null || newCode == null) return 1.0;
    if (oldCode == newCode) return 1.0;

    final prefs = await SharedPreferences.getInstance();

    final urls = [
      'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/$oldCode.json',
      'https://latest.currency-api.pages.dev/v1/currencies/$oldCode.json'
    ];

    for (final url in urls) {
      try {
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data[oldCode] != null && data[oldCode][newCode] != null) {
            final rate = (data[oldCode][newCode] as num).toDouble();
            
            // Cache the successful rate
            await prefs.setDouble('cached_rate_${oldCode}_$newCode', rate);
            return rate;
          }
        }
      } catch (e) {
        debugPrint('Failed to fetch from $url: $e');
      }
    }

    // Try to fallback to cached rate
    final cachedRate = prefs.getDouble('cached_rate_${oldCode}_$newCode');
    if (cachedRate != null) {
      debugPrint('Falling back to cached rate for $oldCode to $newCode: $cachedRate');
      return cachedRate;
    }

    // Hardcoded fallback if network fails and no cache
    final oldRateToUsd = _fallbackRatesToUsd[oldCode] ?? 1.0;
    final newRateToUsd = _fallbackRatesToUsd[newCode] ?? 1.0;
    final fallbackRate = oldRateToUsd / newRateToUsd;
    debugPrint('Falling back to hardcoded rate for $oldCode to $newCode: $fallbackRate');
    
    return fallbackRate;
  }

  Future<void> setCurrency(
    String newCurrency, {
    required bool convertValues,
    required bool applyToExisting,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final oldCurrency = prefs.getString('currency_symbol') ?? '₹';
    if (oldCurrency == newCurrency) return;

    double rate = 1.0;
    if (convertValues) {
      rate = await _fetchExchangeRate(oldCurrency, newCurrency);
    }

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
