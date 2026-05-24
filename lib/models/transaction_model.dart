import 'dart:convert';

class ExpenseTransaction {
  final String id;
  final double amount;
  final String merchant;
  final DateTime date;
  final String paymentMethod;
  final String category; // String to support dynamic categories

  ExpenseTransaction({
    required this.id,
    required this.amount,
    required this.merchant,
    required this.date,
    required this.paymentMethod,
    required this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'merchant': merchant,
      'date': date.toIso8601String(),
      'paymentMethod': paymentMethod,
      'category': category,
    };
  }

  factory ExpenseTransaction.fromMap(Map<String, dynamic> map) {
    return ExpenseTransaction(
      id: map['id'] ?? '',
      amount: (map['amount'] as num).toDouble(),
      merchant: map['merchant'] ?? '',
      date: DateTime.parse(map['date']),
      paymentMethod: map['paymentMethod'] ?? '',
      category: map['category'] ?? 'Other',
    );
  }

  String toJson() => json.encode(toMap());

  factory ExpenseTransaction.fromJson(String source) => ExpenseTransaction.fromMap(json.decode(source));
}
