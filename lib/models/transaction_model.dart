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
  final bool isIncome;

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
    this.isIncome = false,
  });

  ExpenseTransaction copyWith({
    String? id,
    double? amount,
    String? merchant,
    DateTime? date,
    String? paymentMethod,
    String? category,
    String? notes,
    String? paidTo,
    bool? needsVerification,
    DateTime? reminderDate,
    bool? wasFinishLater,
    bool? hideFromLedger,
    String? groupId,
    bool? isIncome,
  }) {
    return ExpenseTransaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      merchant: merchant ?? this.merchant,
      date: date ?? this.date,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      paidTo: paidTo ?? this.paidTo,
      needsVerification: needsVerification ?? this.needsVerification,
      reminderDate: reminderDate ?? this.reminderDate,
      wasFinishLater: wasFinishLater ?? this.wasFinishLater,
      hideFromLedger: hideFromLedger ?? this.hideFromLedger,
      groupId: groupId ?? this.groupId,
      isIncome: isIncome ?? this.isIncome,
    );
  }

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
      'isIncome': isIncome,
    };
  }

  factory ExpenseTransaction.fromMap(Map<String, dynamic> map) {
    final cat = (map['category'] ?? 'Other').toString();
    final lowerCat = cat.toLowerCase();
    // Guess isIncome based on default exclusive income categories or 'income' category
    final guessedIsIncome = lowerCat == 'income' ||
        lowerCat == 'salary' ||
        lowerCat == 'bonus' ||
        lowerCat == 'dividends';

    return ExpenseTransaction(
      id: map['id'] ?? '',
      amount: (map['amount'] as num).toDouble(),
      merchant: map['merchant'] ?? '',
      date: DateTime.parse(map['date']),
      paymentMethod: map['paymentMethod'] ?? '',
      category: cat,
      notes: map['notes'] ?? '',
      paidTo: map['paidTo'] ?? '',
      needsVerification: map['needsVerification'] ?? false,
      reminderDate: map['reminderDate'] != null ? DateTime.parse(map['reminderDate']) : null,
      wasFinishLater: map['wasFinishLater'] ?? (map['needsVerification'] ?? false), // Backwards compat: if needsVerification was true, it wasFinishLater.
      hideFromLedger: map['hideFromLedger'] ?? false,
      groupId: map['groupId'],
      isIncome: map['isIncome'] ?? guessedIsIncome,
    );
  }

  String toJson() => json.encode(toMap());

  factory ExpenseTransaction.fromJson(String source) =>
      ExpenseTransaction.fromMap(json.decode(source));
}
