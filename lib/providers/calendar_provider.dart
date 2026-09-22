import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction_model.dart';
import '../models/recurring_transaction_model.dart';
import '../services/transaction_service.dart';
import 'recurring_transaction_provider.dart';

/// Active focused month in the calendar widget (day set to 1st of month)
final calendarFocusedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

/// Currently selected date for inspecting transactions in details sheet
final calendarSelectedDateProvider = StateProvider<DateTime?>((ref) => null);

/// Calendar view mode: 'month' or 'week'
final calendarViewModeProvider = StateProvider<String>((ref) => 'month');

/// Class holding aggregated daily financial metrics for a specific date
class DailySpendData {
  final DateTime date;
  final double totalExpense;
  final double totalIncome;
  final List<ExpenseTransaction> transactions;
  final List<RecurringTransaction> scheduledRecurring;

  const DailySpendData({
    required this.date,
    required this.totalExpense,
    required this.totalIncome,
    required this.transactions,
    required this.scheduledRecurring,
  });

  bool get hasActivity => totalExpense > 0 || totalIncome > 0 || scheduledRecurring.isNotEmpty;
}

final dailySpendMapProvider = Provider<Map<String, DailySpendData>>((ref) {
  final focusedMonth = ref.watch(calendarFocusedMonthProvider);
  final monthTxsAsync = ref.watch(monthlyTransactionsProvider(MonthYear(focusedMonth.year, focusedMonth.month)));
  final transactions = monthTxsAsync.value ?? [];
  final recurringList = ref.watch(recurringTransactionsProvider);

  final Map<String, List<ExpenseTransaction>> txMap = {};
  final Map<String, double> expenseMap = {};
  final Map<String, double> incomeMap = {};

  for (final tx in transactions) {
    if (tx.category.toLowerCase() == 'transfer') continue;

    final dateKey = '${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}-${tx.date.day.toString().padLeft(2, '0')}';
    txMap.putIfAbsent(dateKey, () => []).add(tx);

    if (tx.isIncome) {
      incomeMap[dateKey] = (incomeMap[dateKey] ?? 0.0) + tx.amount.abs();
    } else {
      expenseMap[dateKey] = (expenseMap[dateKey] ?? 0.0) + tx.amount.abs();
    }
  }

  // Calculate upcoming scheduled recurring payments for the next 60 days
  final Map<String, List<RecurringTransaction>> recurringMap = {};
  final now = DateTime.now();
  final startDate = DateTime(now.year, now.month - 1, 1);
  final endDate = DateTime(now.year, now.month + 3, 28);

  for (final rec in recurringList) {
    if (rec.status != RecurringStatus.active) continue;

    DateTime checkDate = rec.nextDueDate;
    while (checkDate.isBefore(endDate)) {
      if (!checkDate.isBefore(startDate)) {
        final dateKey = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
        recurringMap.putIfAbsent(dateKey, () => []).add(rec);
      }

      // Increment checkDate based on frequency
      switch (rec.frequency) {
        case RecurrenceFrequency.daily:
          checkDate = checkDate.add(Duration(days: 1 * rec.frequencyInterval));
          break;
        case RecurrenceFrequency.weekly:
          checkDate = checkDate.add(Duration(days: 7 * rec.frequencyInterval));
          break;
        case RecurrenceFrequency.monthly:
          checkDate = DateTime(checkDate.year, checkDate.month + rec.frequencyInterval, checkDate.day);
          break;
        case RecurrenceFrequency.yearly:
          checkDate = DateTime(checkDate.year + rec.frequencyInterval, checkDate.month, checkDate.day);
          break;
        default:
          checkDate = endDate; // Break loop if unknown
      }
    }
  }

  // Merge all keys
  final Set<String> allKeys = {...txMap.keys, ...recurringMap.keys};
  final Map<String, DailySpendData> resultMap = {};

  for (final key in allKeys) {
    final parts = key.split('-');
    final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));

    resultMap[key] = DailySpendData(
      date: date,
      totalExpense: expenseMap[key] ?? 0.0,
      totalIncome: incomeMap[key] ?? 0.0,
      transactions: txMap[key] ?? [],
      scheduledRecurring: recurringMap[key] ?? [],
    );
  }

  return resultMap;
});

/// Computes average daily expense in the active focused month to determine intensity thresholds
final monthAverageDailySpendProvider = Provider<double>((ref) {
  final focusedMonth = ref.watch(calendarFocusedMonthProvider);
  final spendMap = ref.watch(dailySpendMapProvider);

  double monthTotal = 0.0;
  int activeDays = 0;

  spendMap.forEach((key, data) {
    if (data.date.year == focusedMonth.year && data.date.month == focusedMonth.month) {
      if (data.totalExpense > 0) {
        monthTotal += data.totalExpense;
        activeDays++;
      }
    }
  });

  if (activeDays == 0) return 50.0; // Default baseline benchmark
  return monthTotal / activeDays;
});
