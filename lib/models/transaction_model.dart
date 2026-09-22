import 'dart:convert';
import '../core/type_parsers.dart';

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
    final bool resolvedIsIncome;
    if (lowerCat == 'income' ||
        lowerCat == 'salary' ||
        lowerCat == 'bonus' ||
        lowerCat == 'dividends') {
      resolvedIsIncome = true;
    } else {
      resolvedIsIncome = parseBool(map['isIncome'], false);
    }

    final bool isVerification = parseBool(map['needsVerification'], false);
    final bool finishLater = map['wasFinishLater'] != null 
        ? parseBool(map['wasFinishLater'], false) 
        : isVerification;

    return ExpenseTransaction(
      id: map['id']?.toString() ?? '',
      amount: (map['amount'] as num).toDouble(),
      merchant: map['merchant']?.toString() ?? '',
      date: DateTime.parse(map['date']).toLocal(),
      paymentMethod: map['paymentMethod']?.toString() ?? '',
      category: cat,
      notes: map['notes']?.toString() ?? '',
      paidTo: map['paidTo']?.toString() ?? '',
      needsVerification: isVerification,
      reminderDate: map['reminderDate'] != null ? DateTime.parse(map['reminderDate']).toLocal() : null,
      wasFinishLater: finishLater,
      hideFromLedger: parseBool(map['hideFromLedger'], false),
      groupId: map['groupId']?.toString(),
      isIncome: resolvedIsIncome,
    );
  }

  String toJson() => json.encode(toMap());

  factory ExpenseTransaction.fromJson(String source) =>
      ExpenseTransaction.fromMap(json.decode(source));
}
