import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/transaction_model.dart';
import '../models/recurring_transaction_model.dart';
import '../models/outstanding_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  DatabaseService._internal();

  static const String dbName = 'tripl.db';
  static const int dbVersion = 1;

  Database? _db;
  Completer<Database>? _initCompleter;

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<Database>();
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, dbName);

      final db = await openDatabase(
        path,
        version: dbVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
          try {
            await db.execute('PRAGMA journal_mode = WAL');
          } catch (e) {
            debugPrint('⚠️ [DatabaseService] WAL mode not enabled: $e');
          }
        },
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );

      _db = db;
      _initCompleter!.complete(db);
      return db;
    } catch (e, stack) {
      debugPrint('❌ [DatabaseService] Failed to initialize database: $e\n$stack');
      _initCompleter!.completeError(e, stack);
      _initCompleter = null;
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    debugPrint('🚀 [DatabaseService] Creating database schema v$version...');
    final batch = db.batch();

    // ── 1. Transactions Table ──
    batch.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY NOT NULL,
        amount REAL NOT NULL,
        merchant TEXT NOT NULL,
        date TEXT NOT NULL,
        paymentMethod TEXT NOT NULL,
        category TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        paidTo TEXT NOT NULL DEFAULT '',
        needsVerification INTEGER NOT NULL DEFAULT 0,
        reminderDate TEXT,
        wasFinishLater INTEGER NOT NULL DEFAULT 0,
        hideFromLedger INTEGER NOT NULL DEFAULT 0,
        groupId TEXT,
        isIncome INTEGER NOT NULL DEFAULT 0
      );
    ''');
    batch.execute('CREATE INDEX idx_transactions_date ON transactions(date DESC);');
    batch.execute('CREATE INDEX idx_transactions_category ON transactions(category);');
    batch.execute('CREATE INDEX idx_transactions_group_id ON transactions(groupId);');
    batch.execute('CREATE INDEX idx_transactions_payment_method ON transactions(paymentMethod);');

    // ── 2. Recurring Transactions Table ──
    batch.execute('''
      CREATE TABLE recurring_transactions (
        id TEXT PRIMARY KEY NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        notes TEXT,
        frequency TEXT NOT NULL,
        frequencyInterval INTEGER NOT NULL DEFAULT 1,
        weeklyDays TEXT,
        monthlyType TEXT,
        startDate TEXT NOT NULL,
        endCondition TEXT NOT NULL,
        endDate TEXT,
        endOccurrences INTEGER,
        occurrencesCompleted INTEGER NOT NULL DEFAULT 0,
        reminderEnabled INTEGER NOT NULL DEFAULT 1,
        reminderTiming TEXT,
        autoCreate INTEGER NOT NULL DEFAULT 0,
        logAsPending INTEGER NOT NULL DEFAULT 0,
        merchant TEXT,
        paymentMethod TEXT NOT NULL,
        isVariableAmount INTEGER NOT NULL DEFAULT 0,
        expectedAmount REAL,
        businessDayHandling TEXT NOT NULL DEFAULT 'doNothing',
        rememberCategory INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'active',
        nextDueDate TEXT NOT NULL,
        lastProcessedDate TEXT
      );
    ''');
    batch.execute('CREATE INDEX idx_recurring_status_due ON recurring_transactions(status, nextDueDate);');

    // ── 3. Outstanding Records Table ──
    batch.execute('''
      CREATE TABLE outstanding_records (
        id TEXT PRIMARY KEY NOT NULL,
        personName TEXT NOT NULL,
        amount REAL NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        date TEXT NOT NULL,
        isLent INTEGER NOT NULL,
        isSettled INTEGER NOT NULL DEFAULT 0,
        settledDate TEXT,
        linkedTransactionId TEXT
      );
    ''');
    batch.execute('CREATE INDEX idx_outstanding_settled ON outstanding_records(isSettled);');
    batch.execute('CREATE INDEX idx_outstanding_date ON outstanding_records(date DESC);');
    batch.execute('CREATE INDEX idx_outstanding_linked_tx ON outstanding_records(linkedTransactionId);');

    await batch.commit(noResult: true);
    debugPrint('✅ [DatabaseService] Schema created successfully.');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('🔄 [DatabaseService] Upgrading DB from v$oldVersion to v$newVersion...');
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ── TRANSACTIONS CRUD & TIMELINE QUERIES ────────────────────────────────────
  // ════════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> _transactionToDb(ExpenseTransaction tx) {
    return {
      'id': tx.id,
      'amount': tx.amount,
      'merchant': tx.merchant,
      'date': tx.date.toIso8601String(),
      'paymentMethod': tx.paymentMethod,
      'category': tx.category,
      'notes': tx.notes,
      'paidTo': tx.paidTo,
      'needsVerification': tx.needsVerification ? 1 : 0,
      'reminderDate': tx.reminderDate?.toIso8601String(),
      'wasFinishLater': tx.wasFinishLater ? 1 : 0,
      'hideFromLedger': tx.hideFromLedger ? 1 : 0,
      'groupId': tx.groupId,
      'isIncome': tx.isIncome ? 1 : 0,
    };
  }

  Future<List<ExpenseTransaction>> getAllTransactions() async {
    final db = await database;
    final rows = await db.query('transactions', orderBy: 'date DESC');
    return rows.map((r) => ExpenseTransaction.fromMap(r)).toList();
  }

  /// Sub-millisecond distinct query to fetch available year-months (e.g. ['2026-09', '2026-08'])
  Future<List<String>> getAvailableMonths() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT DISTINCT substr(date, 1, 7) AS ym 
      FROM transactions 
      WHERE date IS NOT NULL AND length(date) >= 7
      ORDER BY ym DESC;
    ''');
    final list = rows.map((r) => r['ym'] as String).toList();
    if (list.isEmpty) {
      final now = DateTime.now();
      list.add('${now.year}-${now.month.toString().padLeft(2, '0')}');
    }
    return list;
  }

  /// On-demand query to fetch only transactions for a specific month
  Future<List<ExpenseTransaction>> getTransactionsForMonth(int year, int month) async {
    final db = await database;
    final startDate = DateTime(year, month, 1).toIso8601String();
    final nextMonth = month == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
    final endDate = nextMonth.toIso8601String();

    final rows = await db.query(
      'transactions',
      where: 'date >= ? AND date < ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date DESC',
    );
    return rows.map((r) => ExpenseTransaction.fromMap(r)).toList();
  }

  /// High-speed global search across all history
  Future<List<ExpenseTransaction>> searchTransactions(String query, {int limit = 60}) async {
    final db = await database;
    final clean = '%${query.trim().toLowerCase()}%';
    final rows = await db.query(
      'transactions',
      where: 'lower(merchant) LIKE ? OR lower(category) LIKE ? OR lower(notes) LIKE ? OR lower(paymentMethod) LIKE ? OR lower(paidTo) LIKE ?',
      whereArgs: [clean, clean, clean, clean, clean],
      orderBy: 'date DESC',
      limit: limit,
    );
    return rows.map((r) => ExpenseTransaction.fromMap(r)).toList();
  }

  Future<void> insertTransaction(ExpenseTransaction tx) async {
    final db = await database;
    await db.insert(
      'transactions',
      _transactionToDb(tx),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertTransactions(List<ExpenseTransaction> txs) async {
    if (txs.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final tx in txs) {
      batch.insert(
        'transactions',
        _transactionToDb(tx),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateTransaction(ExpenseTransaction tx) async {
    final db = await database;
    await db.update(
      'transactions',
      _transactionToDb(tx),
      where: 'id = ?',
      whereArgs: [tx.id],
    );
  }

  Future<void> updateTransfer({
    required String groupId,
    required String fromAccount,
    required String toAccount,
    required double amount,
    required DateTime date,
    required String notes,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'transactions',
        where: 'groupId = ?',
        whereArgs: [groupId],
      );
      for (final row in rows) {
        final tx = ExpenseTransaction.fromMap(row);
        final bool isOutflow = !tx.isIncome;
        final updatedTx = tx.copyWith(
          paymentMethod: isOutflow ? fromAccount : toAccount,
          amount: amount,
          date: date,
          notes: notes,
          merchant: isOutflow ? 'Transfer to $toAccount' : 'Transfer from $fromAccount',
        );
        await txn.update(
          'transactions',
          _transactionToDb(updatedTx),
          where: 'id = ?',
          whereArgs: [tx.id],
        );
      }
    });
  }

  Future<void> deleteTransaction(String id) async {
    final db = await database;
    final rows = await db.query('transactions', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;
    final tx = ExpenseTransaction.fromMap(rows.first);
    if (tx.category.toLowerCase() == 'transfer' && tx.groupId != null && tx.groupId!.isNotEmpty) {
      await db.delete('transactions', where: 'groupId = ?', whereArgs: [tx.groupId]);
    } else {
      await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> updateVerificationStatus(String id, {required bool needsVerification}) async {
    final db = await database;
    await db.update(
      'transactions',
      {'needsVerification': needsVerification ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateReminderDate(String id, DateTime? reminderDate) async {
    final db = await database;
    await db.update(
      'transactions',
      {'reminderDate': reminderDate?.toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearAllTransactions() async {
    final db = await database;
    await db.delete('transactions');
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ── RECURRING TRANSACTIONS CRUD ─────────────────────────────────────────────
  // ════════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> _recurringToDb(RecurringTransaction tx) {
    return {
      'id': tx.id,
      'type': tx.type.name,
      'amount': tx.amount,
      'title': tx.title,
      'category': tx.category,
      'notes': tx.notes,
      'frequency': tx.frequency.name,
      'frequencyInterval': tx.frequencyInterval,
      'weeklyDays': tx.weeklyDays != null ? json.encode(tx.weeklyDays) : null,
      'monthlyType': tx.monthlyType?.name,
      'startDate': tx.startDate.toIso8601String(),
      'endCondition': tx.endCondition.name,
      'endDate': tx.endDate?.toIso8601String(),
      'endOccurrences': tx.endOccurrences,
      'occurrencesCompleted': tx.occurrencesCompleted,
      'reminderEnabled': tx.reminderEnabled ? 1 : 0,
      'reminderTiming': tx.reminderTiming?.name,
      'autoCreate': tx.autoCreate ? 1 : 0,
      'logAsPending': tx.logAsPending ? 1 : 0,
      'merchant': tx.merchant,
      'paymentMethod': tx.paymentMethod,
      'isVariableAmount': tx.isVariableAmount ? 1 : 0,
      'expectedAmount': tx.expectedAmount,
      'businessDayHandling': tx.businessDayHandling.name,
      'rememberCategory': tx.rememberCategory ? 1 : 0,
      'status': tx.status.name,
      'nextDueDate': tx.nextDueDate.toIso8601String(),
      'lastProcessedDate': tx.lastProcessedDate?.toIso8601String(),
    };
  }

  Future<List<RecurringTransaction>> getAllRecurringTransactions() async {
    final db = await database;
    final rows = await db.query('recurring_transactions', orderBy: 'nextDueDate ASC');
    return rows.map((r) => RecurringTransaction.fromMap(r)).toList();
  }

  Future<void> insertRecurringTransaction(RecurringTransaction tx) async {
    final db = await database;
    await db.insert(
      'recurring_transactions',
      _recurringToDb(tx),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertRecurringTransactions(List<RecurringTransaction> txs) async {
    if (txs.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final tx in txs) {
      batch.insert(
        'recurring_transactions',
        _recurringToDb(tx),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateRecurringTransaction(RecurringTransaction tx) async {
    final db = await database;
    await db.update(
      'recurring_transactions',
      _recurringToDb(tx),
      where: 'id = ?',
      whereArgs: [tx.id],
    );
  }

  Future<void> deleteRecurringTransaction(String id) async {
    final db = await database;
    await db.delete('recurring_transactions', where: 'id = ?', whereArgs: [id]);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ── OUTSTANDING RECORDS CRUD ────────────────────────────────────────────────
  // ════════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> _outstandingToDb(OutstandingRecord rec) {
    return {
      'id': rec.id,
      'personName': rec.personName,
      'amount': rec.amount,
      'notes': rec.notes,
      'date': rec.date.toIso8601String(),
      'isLent': rec.isLent ? 1 : 0,
      'isSettled': rec.isSettled ? 1 : 0,
      'settledDate': rec.settledDate?.toIso8601String(),
      'linkedTransactionId': rec.linkedTransactionId,
    };
  }

  Future<List<OutstandingRecord>> getAllOutstandingRecords() async {
    final db = await database;
    final rows = await db.query('outstanding_records', orderBy: 'date DESC');
    return rows.map((r) => OutstandingRecord.fromMap(r)).toList();
  }

  Future<void> insertOutstandingRecord(OutstandingRecord rec) async {
    final db = await database;
    await db.insert(
      'outstanding_records',
      _outstandingToDb(rec),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertOutstandingRecords(List<OutstandingRecord> records) async {
    if (records.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final rec in records) {
      batch.insert(
        'outstanding_records',
        _outstandingToDb(rec),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateOutstandingRecord(OutstandingRecord rec) async {
    final db = await database;
    await db.update(
      'outstanding_records',
      _outstandingToDb(rec),
      where: 'id = ?',
      whereArgs: [rec.id],
    );
  }

  Future<void> deleteOutstandingRecord(String id) async {
    final db = await database;
    await db.delete('outstanding_records', where: 'id = ?', whereArgs: [id]);
  }
}
