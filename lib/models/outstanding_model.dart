import 'dart:convert';

class OutstandingRecord {
  final String id;
  final String personName;
  final double amount;
  final String notes;
  final DateTime date;
  final bool isLent; // true if they owe me (lent), false if I owe them (borrowed)
  final bool isSettled;
  final DateTime? settledDate;
  final String? linkedTransactionId; // Optional link to wallet timeline transaction

  OutstandingRecord({
    required this.id,
    required this.personName,
    required this.amount,
    required this.notes,
    required this.date,
    required this.isLent,
    this.isSettled = false,
    this.settledDate,
    this.linkedTransactionId,
  });

  OutstandingRecord copyWith({
    String? id,
    String? personName,
    double? amount,
    String? notes,
    DateTime? date,
    bool? isLent,
    bool? isSettled,
    DateTime? settledDate,
    String? linkedTransactionId,
  }) {
    return OutstandingRecord(
      id: id ?? this.id,
      personName: personName ?? this.personName,
      amount: amount ?? this.amount,
      notes: notes ?? this.notes,
      date: date ?? this.date,
      isLent: isLent ?? this.isLent,
      isSettled: isSettled ?? this.isSettled,
      settledDate: settledDate ?? this.settledDate,
      linkedTransactionId: linkedTransactionId ?? this.linkedTransactionId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'personName': personName,
      'amount': amount,
      'notes': notes,
      'date': date.toIso8601String(),
      'isLent': isLent,
      'isSettled': isSettled,
      'settledDate': settledDate?.toIso8601String(),
      'linkedTransactionId': linkedTransactionId,
    };
  }

  factory OutstandingRecord.fromMap(Map<String, dynamic> map) {
    return OutstandingRecord(
      id: map['id'] ?? '',
      personName: map['personName'] ?? '',
      amount: (map['amount'] as num).toDouble(),
      notes: map['notes'] ?? '',
      date: DateTime.parse(map['date']),
      isLent: map['isLent'] ?? true,
      isSettled: map['isSettled'] ?? false,
      settledDate: map['settledDate'] != null ? DateTime.parse(map['settledDate']) : null,
      linkedTransactionId: map['linkedTransactionId'],
    );
  }

  String toJson() => json.encode(toMap());

  factory OutstandingRecord.fromJson(String source) =>
      OutstandingRecord.fromMap(json.decode(source));
}
