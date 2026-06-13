import 'dart:convert';
import 'package:uuid/uuid.dart';

enum TransactionType { expense, income }
enum RecurrenceFrequency { daily, weekly, monthly, yearly, custom }
enum MonthlyRecurrenceType { dayOfMonth, nthWeekday }
enum EndConditionType { never, onDate, afterOccurrences }
enum ReminderTiming { atDueTime, oneHourBefore, sixHoursBefore, twelveHoursBefore, oneDayBefore, threeDaysBefore, oneWeekBefore }
enum BusinessDayHandling { doNothing, previous, next }
enum RecurringStatus { active, paused, completed }

class RecurringTransaction {
  final String id;
  final TransactionType type;
  final double amount;
  final String title;
  final String category;
  final String? notes;
  final RecurrenceFrequency frequency;
  final int frequencyInterval;
  final List<int>? weeklyDays;
  final MonthlyRecurrenceType? monthlyType;
  final DateTime startDate;
  final EndConditionType endCondition;
  final DateTime? endDate;
  final int? endOccurrences;
  final int occurrencesCompleted;
  final bool reminderEnabled;
  final ReminderTiming? reminderTiming;
  final bool autoCreate;
  final bool logAsPending;
  final String? merchant;
  final String paymentMethod;
  final bool isVariableAmount;
  final double? expectedAmount;
  final BusinessDayHandling businessDayHandling;
  final bool rememberCategory;
  final RecurringStatus status;
  final DateTime nextDueDate;
  final DateTime? lastProcessedDate;

  RecurringTransaction({
    String? id,
    required this.type,
    required this.amount,
    required this.title,
    required this.category,
    this.notes,
    required this.frequency,
    this.frequencyInterval = 1,
    this.weeklyDays,
    this.monthlyType,
    required this.startDate,
    required this.endCondition,
    this.endDate,
    this.endOccurrences,
    this.occurrencesCompleted = 0,
    this.reminderEnabled = true,
    this.reminderTiming,
    required this.autoCreate,
    this.logAsPending = false,
    this.merchant,
    required this.paymentMethod,
    this.isVariableAmount = false,
    this.expectedAmount,
    this.businessDayHandling = BusinessDayHandling.doNothing,
    this.rememberCategory = false,
    this.status = RecurringStatus.active,
    required this.nextDueDate,
    this.lastProcessedDate,
  }) : id = id ?? const Uuid().v4();

  RecurringTransaction copyWith({
    String? id,
    TransactionType? type,
    double? amount,
    String? title,
    String? category,
    String? notes,
    RecurrenceFrequency? frequency,
    int? frequencyInterval,
    List<int>? weeklyDays,
    MonthlyRecurrenceType? monthlyType,
    DateTime? startDate,
    EndConditionType? endCondition,
    DateTime? endDate,
    int? endOccurrences,
    int? occurrencesCompleted,
    bool? reminderEnabled,
    ReminderTiming? reminderTiming,
    bool? autoCreate,
    bool? logAsPending,
    String? merchant,
    String? paymentMethod,
    bool? isVariableAmount,
    double? expectedAmount,
    BusinessDayHandling? businessDayHandling,
    bool? rememberCategory,
    RecurringStatus? status,
    DateTime? nextDueDate,
    DateTime? lastProcessedDate,
  }) {
    return RecurringTransaction(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      title: title ?? this.title,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      frequency: frequency ?? this.frequency,
      frequencyInterval: frequencyInterval ?? this.frequencyInterval,
      weeklyDays: weeklyDays ?? this.weeklyDays,
      monthlyType: monthlyType ?? this.monthlyType,
      startDate: startDate ?? this.startDate,
      endCondition: endCondition ?? this.endCondition,
      endDate: endDate ?? this.endDate,
      endOccurrences: endOccurrences ?? this.endOccurrences,
      occurrencesCompleted: occurrencesCompleted ?? this.occurrencesCompleted,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTiming: reminderTiming ?? this.reminderTiming,
      autoCreate: autoCreate ?? this.autoCreate,
      logAsPending: logAsPending ?? this.logAsPending,
      merchant: merchant ?? this.merchant,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isVariableAmount: isVariableAmount ?? this.isVariableAmount,
      expectedAmount: expectedAmount ?? this.expectedAmount,
      businessDayHandling: businessDayHandling ?? this.businessDayHandling,
      rememberCategory: rememberCategory ?? this.rememberCategory,
      status: status ?? this.status,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      lastProcessedDate: lastProcessedDate ?? this.lastProcessedDate,
    );
  }

  static DateTime calculateNextDueDate(DateTime start, RecurrenceFrequency freq, {int interval = 1, List<int>? weeklyDays}) {
    DateTime next = start;
    switch (freq) {
      case RecurrenceFrequency.daily:
        next = next.add(Duration(days: 1 * interval));
        break;
      case RecurrenceFrequency.weekly:
        if (weeklyDays != null && weeklyDays.isNotEmpty) {
          final sortedDays = List<int>.from(weeklyDays)..sort();
          int currentDay = next.weekday;
          int? nextDay;
          for (int day in sortedDays) {
            if (day > currentDay) {
              nextDay = day;
              break;
            }
          }
          if (nextDay != null) {
            next = next.add(Duration(days: nextDay - currentDay));
          } else {
            int daysToAdd = (7 - currentDay) + (7 * (interval - 1)) + sortedDays.first;
            next = next.add(Duration(days: daysToAdd));
          }
        } else {
          next = next.add(Duration(days: 7 * interval));
        }
        break;
      case RecurrenceFrequency.monthly:
        next = DateTime(next.year, next.month + interval, next.day, next.hour, next.minute);
        break;
      case RecurrenceFrequency.yearly:
        next = DateTime(next.year + interval, next.month, next.day, next.hour, next.minute);
        break;
      case RecurrenceFrequency.custom:
        next = next.add(Duration(days: 30 * interval));
        break;
    }
    return next;
  }

  bool isCompleted(DateTime currentNextDate, int currentOccurrences) {
    if (endCondition == EndConditionType.never) return false;
    if (endCondition == EndConditionType.onDate) {
      if (endDate != null && currentNextDate.isAfter(endDate!)) {
        return true;
      }
    }
    if (endCondition == EndConditionType.afterOccurrences) {
      if (endOccurrences != null && currentOccurrences >= endOccurrences!) {
        return true;
      }
    }
    return false;
  }

  RecurringTransaction advance({bool skip = false}) {
    final nextDate = calculateNextDueDate(nextDueDate, frequency, interval: frequencyInterval, weeklyDays: weeklyDays);
    final newOccurrences = occurrencesCompleted + (skip ? 0 : 1);
    final newStatus = isCompleted(nextDate, newOccurrences) ? RecurringStatus.completed : status;

    return copyWith(
      nextDueDate: nextDate,
      occurrencesCompleted: newOccurrences,
      lastProcessedDate: DateTime.now(),
      status: newStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'amount': amount,
      'title': title,
      'category': category,
      'notes': notes,
      'frequency': frequency.name,
      'frequencyInterval': frequencyInterval,
      'weeklyDays': weeklyDays,
      'monthlyType': monthlyType?.name,
      'startDate': startDate.toIso8601String(),
      'endCondition': endCondition.name,
      'endDate': endDate?.toIso8601String(),
      'endOccurrences': endOccurrences,
      'occurrencesCompleted': occurrencesCompleted,
      'reminderEnabled': reminderEnabled,
      'reminderTiming': reminderTiming?.name,
      'autoCreate': autoCreate,
      'logAsPending': logAsPending,
      'merchant': merchant,
      'paymentMethod': paymentMethod,
      'isVariableAmount': isVariableAmount,
      'expectedAmount': expectedAmount,
      'businessDayHandling': businessDayHandling.name,
      'rememberCategory': rememberCategory,
      'status': status.name,
      'nextDueDate': nextDueDate.toIso8601String(),
      'lastProcessedDate': lastProcessedDate?.toIso8601String(),
    };
  }

  factory RecurringTransaction.fromMap(Map<String, dynamic> map) {
    return RecurringTransaction(
      id: map['id'],
      type: TransactionType.values.byName(map['type'] ?? 'expense'),
      amount: (map['amount'] as num).toDouble(),
      title: map['title'] ?? '',
      category: map['category'] ?? 'Other',
      notes: map['notes'],
      frequency: RecurrenceFrequency.values.byName(map['frequency'] ?? 'monthly'),
      frequencyInterval: map['frequencyInterval'] ?? 1,
      weeklyDays: (map['weeklyDays'] as List<dynamic>?)?.map((e) => e as int).toList(),
      monthlyType: map['monthlyType'] != null ? MonthlyRecurrenceType.values.byName(map['monthlyType']) : null,
      startDate: DateTime.parse(map['startDate']),
      endCondition: EndConditionType.values.byName(map['endCondition'] ?? 'never'),
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : null,
      endOccurrences: map['endOccurrences'],
      occurrencesCompleted: map['occurrencesCompleted'] ?? 0,
      reminderEnabled: map['reminderEnabled'] ?? true,
      reminderTiming: map['reminderTiming'] != null ? ReminderTiming.values.byName(map['reminderTiming']) : null,
      autoCreate: map['autoCreate'] ?? false,
      logAsPending: map['logAsPending'] ?? false,
      merchant: map['merchant'],
      paymentMethod: map['paymentMethod'] ?? 'Cash',
      isVariableAmount: map['isVariableAmount'] ?? false,
      expectedAmount: map['expectedAmount'] != null ? (map['expectedAmount'] as num).toDouble() : null,
      businessDayHandling: BusinessDayHandling.values.byName(map['businessDayHandling'] ?? 'doNothing'),
      rememberCategory: map['rememberCategory'] ?? false,
      status: RecurringStatus.values.byName(map['status'] ?? 'active'),
      nextDueDate: DateTime.parse(map['nextDueDate']),
      lastProcessedDate: map['lastProcessedDate'] != null ? DateTime.parse(map['lastProcessedDate']) : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory RecurringTransaction.fromJson(String source) => RecurringTransaction.fromMap(json.decode(source));
}
