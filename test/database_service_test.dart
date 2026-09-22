import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tripl/models/transaction_model.dart';
import 'package:tripl/models/recurring_transaction_model.dart';
import 'package:tripl/models/outstanding_model.dart';
import 'package:tripl/services/database_service.dart';
import 'package:tripl/services/migration_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('DatabaseService Tests', () {
    late DatabaseService dbService;

    setUp(() async {
      dbService = DatabaseService.instance;
      final db = await dbService.database;
      await db.delete('transactions');
      await db.delete('recurring_transactions');
      await db.delete('outstanding_records');
    });

    test('Insert and fetch single transaction', () async {
      final tx = ExpenseTransaction(
        id: 'tx-1',
        amount: 450.0,
        merchant: 'Blue Tokai Coffee',
        date: DateTime(2026, 9, 15, 10, 30),
        paymentMethod: 'Credit Card',
        category: 'Dining',
        notes: 'Cold brew and croissant',
        paidTo: 'Cafe',
        isIncome: false,
      );

      await dbService.insertTransaction(tx);
      final list = await dbService.getAllTransactions();

      expect(list.length, 1);
      expect(list.first.id, 'tx-1');
      expect(list.first.amount, 450.0);
      expect(list.first.merchant, 'Blue Tokai Coffee');
      expect(list.first.category, 'Dining');
      expect(list.first.paymentMethod, 'Credit Card');
      expect(list.first.isIncome, false);
    });

    test('Month-by-month range queries and available months', () async {
      final txAug = ExpenseTransaction(
        id: 'tx-aug',
        amount: 1200.0,
        merchant: 'Groceries Store',
        date: DateTime(2026, 8, 20, 15, 0),
        paymentMethod: 'Cash',
        category: 'Groceries',
      );

      final txSep1 = ExpenseTransaction(
        id: 'tx-sep-1',
        amount: 300.0,
        merchant: 'Metro Commute',
        date: DateTime(2026, 9, 5, 9, 0),
        paymentMethod: 'Metro Card',
        category: 'Commute',
      );

      final txSep2 = ExpenseTransaction(
        id: 'tx-sep-2',
        amount: 5000.0,
        merchant: 'Salary Credit',
        date: DateTime(2026, 9, 1, 12, 0),
        paymentMethod: 'Bank Account',
        category: 'Income',
        isIncome: true,
      );

      await dbService.insertTransactions([txAug, txSep1, txSep2]);

      // 1. Check distinct available months
      final available = await dbService.getAvailableMonths();
      expect(available, contains('2026-09'));
      expect(available, contains('2026-08'));

      // 2. Query only September
      final sepTxs = await dbService.getTransactionsForMonth(2026, 9);
      expect(sepTxs.length, 2);
      expect(sepTxs.map((t) => t.id), containsAll(['tx-sep-1', 'tx-sep-2']));
      expect(sepTxs.map((t) => t.id), isNot(contains('tx-aug')));

      // 3. Query only August
      final augTxs = await dbService.getTransactionsForMonth(2026, 8);
      expect(augTxs.length, 1);
      expect(augTxs.first.id, 'tx-aug');
    });

    test('Search transactions across history', () async {
      final tx1 = ExpenseTransaction(
        id: 's-1',
        amount: 150.0,
        merchant: 'Starbucks Coffee',
        date: DateTime(2026, 5, 10),
        paymentMethod: 'Cash',
        category: 'Dining',
        notes: 'Meeting with client',
      );

      final tx2 = ExpenseTransaction(
        id: 's-2',
        amount: 800.0,
        merchant: 'Amazon Marketplace',
        date: DateTime(2026, 9, 12),
        paymentMethod: 'Credit Card',
        category: 'Shopping',
        notes: 'Coffee beans pack',
      );

      await dbService.insertTransactions([tx1, tx2]);

      // Search 'Coffee' should match merchant in tx1 and notes in tx2
      final results = await dbService.searchTransactions('coffee');
      expect(results.length, 2);

      // Search 'Starbucks' should only match tx1
      final starbucksResults = await dbService.searchTransactions('starbucks');
      expect(starbucksResults.length, 1);
      expect(starbucksResults.first.id, 's-1');
    });

    test('Atomic update transfer with dual legs', () async {
      final legDebit = ExpenseTransaction(
        id: 'leg-1',
        amount: 1000.0,
        merchant: 'Transfer to Bank Account',
        date: DateTime(2026, 9, 10),
        paymentMethod: 'Cash',
        category: 'Transfer',
        groupId: 'grp-transfer-1',
        isIncome: false,
      );

      final legCredit = ExpenseTransaction(
        id: 'leg-2',
        amount: 1000.0,
        merchant: 'Transfer from Cash',
        date: DateTime(2026, 9, 10),
        paymentMethod: 'Bank Account',
        category: 'Transfer',
        groupId: 'grp-transfer-1',
        isIncome: true,
      );

      await dbService.insertTransactions([legDebit, legCredit]);

      // Update transfer details atomically
      await dbService.updateTransfer(
        groupId: 'grp-transfer-1',
        fromAccount: 'Cash Wallet',
        toAccount: 'HDFC Bank',
        amount: 2500.0,
        date: DateTime(2026, 9, 11),
        notes: 'ATM deposit',
      );

      final updated = await dbService.getAllTransactions();
      expect(updated.length, 2);

      final debit = updated.firstWhere((t) => !t.isIncome);
      expect(debit.amount, 2500.0);
      expect(debit.paymentMethod, 'Cash Wallet');
      expect(debit.merchant, 'Transfer to HDFC Bank');

      final credit = updated.firstWhere((t) => t.isIncome);
      expect(credit.amount, 2500.0);
      expect(credit.paymentMethod, 'HDFC Bank');
      expect(credit.merchant, 'Transfer from Cash Wallet');
    });

    test('Recurring transaction insertion and query', () async {
      final rTx = RecurringTransaction(
        id: 'rec-1',
        type: TransactionType.expense,
        amount: 199.0,
        title: 'Spotify Subscription',
        category: 'Subscriptions',
        frequency: RecurrenceFrequency.monthly,
        startDate: DateTime(2026, 1, 1),
        endCondition: EndConditionType.never,
        autoCreate: true,
        paymentMethod: 'Credit Card',
        nextDueDate: DateTime(2026, 9, 25),
      );

      await dbService.insertRecurringTransaction(rTx);
      final list = await dbService.getAllRecurringTransactions();

      expect(list.length, 1);
      expect(list.first.id, 'rec-1');
      expect(list.first.title, 'Spotify Subscription');
      expect(list.first.amount, 199.0);
      expect(list.first.autoCreate, true);
    });

    test('Outstanding record insertion and settle update', () async {
      final debt = OutstandingRecord(
        id: 'out-1',
        personName: 'Rohan Sharma',
        amount: 500.0,
        notes: 'Lunch split',
        date: DateTime(2026, 9, 15),
        isLent: true,
        isSettled: false,
      );

      await dbService.insertOutstandingRecord(debt);
      var records = await dbService.getAllOutstandingRecords();
      expect(records.length, 1);
      expect(records.first.isSettled, false);

      // Settle
      final settled = debt.copyWith(isSettled: true, settledDate: DateTime.now());
      await dbService.updateOutstandingRecord(settled);

      records = await dbService.getAllOutstandingRecords();
      expect(records.length, 1);
      expect(records.first.isSettled, true);
    });
  });

  group('MigrationService Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final dbService = DatabaseService.instance;
      final db = await dbService.database;
      await db.delete('transactions');
      await db.delete('recurring_transactions');
      await db.delete('outstanding_records');
    });

    test('Migrates legacy JSON into SQLite cleanly', () async {
      final legacyTxs = [
        {
          'id': 'legacy-tx-1',
          'amount': 350.0,
          'merchant': 'Bookstore',
          'date': '2026-09-10T14:30:00.000',
          'paymentMethod': 'Cash',
          'category': 'Other',
          'notes': 'Novel',
          'paidTo': 'Shop',
          'needsVerification': false,
          'isIncome': false,
        }
      ];

      final legacyRecurring = [
        {
          'id': 'legacy-rec-1',
          'type': 'expense',
          'amount': 599.0,
          'title': 'Broadband',
          'category': 'Utilities',
          'frequency': 'monthly',
          'frequencyInterval': 1,
          'startDate': '2026-01-01T00:00:00.000',
          'endCondition': 'never',
          'occurrencesCompleted': 0,
          'reminderEnabled': true,
          'autoCreate': true,
          'logAsPending': false,
          'paymentMethod': 'Bank Account',
          'isVariableAmount': false,
          'businessDayHandling': 'doNothing',
          'rememberCategory': false,
          'status': 'active',
          'nextDueDate': '2026-09-30T00:00:00.000',
        }
      ];

      final legacyOutstanding = [
        {
          'id': 'legacy-out-1',
          'personName': 'Pooja',
          'amount': 250.0,
          'notes': 'Movie tickets',
          'date': '2026-09-08T18:00:00.000',
          'isLent': true,
          'isSettled': false,
        }
      ];

      SharedPreferences.setMockInitialValues({
        'transactions_json': json.encode(legacyTxs),
        'tripl_recurring_transactions': json.encode(legacyRecurring),
        'outstanding_ledger_json': json.encode(legacyOutstanding),
      });

      await MigrationService.runMigrationIfNeeded();

      final dbService = DatabaseService.instance;
      final txs = await dbService.getAllTransactions();
      final recurring = await dbService.getAllRecurringTransactions();
      final outstanding = await dbService.getAllOutstandingRecords();

      expect(txs.length, 1);
      expect(txs.first.id, 'legacy-tx-1');
      expect(txs.first.merchant, 'Bookstore');

      expect(recurring.length, 1);
      expect(recurring.first.id, 'legacy-rec-1');
      expect(recurring.first.title, 'Broadband');

      expect(outstanding.length, 1);
      expect(outstanding.first.id, 'legacy-out-1');
      expect(outstanding.first.personName, 'Pooja');

      // Verify second run skips without duplication
      await MigrationService.runMigrationIfNeeded();
      final txsSecond = await dbService.getAllTransactions();
      expect(txsSecond.length, 1);
    });
  });
}
