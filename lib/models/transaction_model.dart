import 'dart:convert';

class ExpenseTransaction {
  final String id;
  final double amount;
  final String merchant;
  final DateTime date;
  final String paymentMethod;
  final String category; // String to support dynamic categories
  final String notes;    // Optional user notes
  final String paidTo;
  final bool needsVerification;
  final DateTime? reminderDate;
  final bool wasFinishLater;
  final bool hideFromLedger;

  final String? groupId;

  ExpenseTransaction({
    required this.id,
    required this.amount,
    required this.merchant,
    required this.date,
    required this.paymentMethod,
    required this.category,
    this.notes = '',
    this.paidTo = '',
    this.needsVerification = false,
    this.reminderDate,
    this.wasFinishLater = false,
    this.hideFromLedger = false,
    this.groupId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'merchant': merchant,
      'date': date.toIso8601String(),
      'paymentMethod': paymentMethod,
      'category': category,
      'notes': notes,
      'paidTo': paidTo,
      'needsVerification': needsVerification,
      'reminderDate': reminderDate?.toIso8601String(),
      'wasFinishLater': wasFinishLater,
      'hideFromLedger': hideFromLedger,
      'groupId': groupId,
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
      notes: map['notes'] ?? '',
      paidTo: map['paidTo'] ?? '',
      needsVerification: map['needsVerification'] ?? false,
      reminderDate: map['reminderDate'] != null ? DateTime.parse(map['reminderDate']) : null,
      wasFinishLater: map['wasFinishLater'] ?? (map['needsVerification'] ?? false), // Backwards compat: if needsVerification was true, it wasFinishLater.
      hideFromLedger: map['hideFromLedger'] ?? false,
      groupId: map['groupId'],
    );
  }

  String toJson() => json.encode(toMap());

  factory ExpenseTransaction.fromJson(String source) =>
      ExpenseTransaction.fromMap(json.decode(source));
}
