import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tripl/models/transaction_model.dart';
import 'package:tripl/models/outstanding_model.dart';
import 'package:tripl/providers/outstanding_provider.dart';
import 'package:tripl/services/transaction_service.dart';
import 'package:tripl/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final db = await DatabaseService.instance.database;
    await db.delete('transactions');
    await db.delete('outstanding_records');
  });

  group('ExpenseTransaction.fromMap healing test', () {
    test('Ensures category: "Income" always resolves to isIncome: true even if map had isIncome: false', () {
      final mapWithBug = {
        'id': 'tx_123',
        'amount': 5000.0,
        'merchant': 'Rahul',
        'date': DateTime.now().toIso8601String(),
        'paymentMethod': 'Cash',
        'category': 'Income',
        'notes': 'Settled net balance: Rahul paid back',
        'paidTo': '',
        'isIncome': false, // previously generated with the bug
      };

      final tx = ExpenseTransaction.fromMap(mapWithBug);
      expect(tx.isIncome, isTrue);
      expect(tx.category, equals('Income'));
    });
  });

  group('Outstanding Partial Settlement tests', () {
    test('settleRecordPartial splits an active record into active remainder and settled record', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(outstandingListProvider.notifier);
      await notifier.loadRecords();

      final record = OutstandingRecord(
        id: 'rec_1',
        personName: 'Rahul',
        amount: 5000.0,
        notes: 'Lunch loan',
        date: DateTime.now(),
        isLent: true,
      );

      await notifier.addRecord(record);

      expect(container.read(outstandingListProvider).length, equals(1));
      expect(container.read(outstandingListProvider).first.amount, equals(5000.0));

      // Settle partial 2000
      await notifier.settleRecordPartial('rec_1', 2000.0, recordTimelineTx: true, paymentMethod: 'Cash');

      final records = container.read(outstandingListProvider);
      expect(records.length, equals(2));

      final activeRecord = records.firstWhere((r) => !r.isSettled);
      final settledRecord = records.firstWhere((r) => r.isSettled);

      expect(activeRecord.id, equals('rec_1'));
      expect(activeRecord.amount, equals(3000.0));

      expect(settledRecord.amount, equals(2000.0));
      expect(settledRecord.isSettled, isTrue);
      expect(settledRecord.linkedTransactionId, isNotNull);

      // Verify timeline transaction logged as income
      final transactions = container.read(transactionListProvider);
      expect(transactions.length, equals(1));
      final tx = transactions.first;
      expect(tx.amount, equals(2000.0));
      expect(tx.isIncome, isTrue);
      expect(tx.category, equals('Income'));
    });

    test('settlePersonAmount settles across multiple records correctly', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(outstandingListProvider.notifier);
      await notifier.loadRecords();

      final r1 = OutstandingRecord(
        id: 'r1',
        personName: 'Priya',
        amount: 1500.0,
        notes: 'Movie',
        date: DateTime.now().subtract(const Duration(days: 2)),
        isLent: true,
      );
      final r2 = OutstandingRecord(
        id: 'r2',
        personName: 'Priya',
        amount: 3500.0,
        notes: 'Groceries',
        date: DateTime.now().subtract(const Duration(days: 1)),
        isLent: true,
      );

      await notifier.addRecord(r1);
      await notifier.addRecord(r2);

      // Total lent to Priya: 5000. Settle 2000 partially.
      await notifier.settlePersonAmount('Priya', 2000.0, true, linkedTimelineTxId: 'settle_tx_1');

      final records = container.read(outstandingListProvider);
      final active = records.where((r) => !r.isSettled && r.personName == 'Priya').toList();
      final settled = records.where((r) => r.isSettled && r.personName == 'Priya').toList();

      // Total active should now be 3000
      final activeSum = active.fold<double>(0.0, (sum, r) => sum + r.amount);
      expect(activeSum, equals(3000.0));

      // Total settled should be 2000
      final settledSum = settled.fold<double>(0.0, (sum, r) => sum + r.amount);
      expect(settledSum, equals(2000.0));
    });
  });
}
