import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import '../models/recurring_transaction_model.dart';
import '../models/outstanding_model.dart';
import 'database_service.dart';

class MigrationService {
  static const String _migrationFlagKey = 'is_sqlite_migrated_v2';
  static const String _legacyTransactionsKey = 'transactions_json';
  static const String _legacyTransactionsBackupKey = 'transactions_json_backup';
  static const String _legacyRecurringKey = 'tripl_recurring_transactions';
  static const String _legacyOutstandingKey = 'outstanding_ledger_json';

  /// Performs a one-time, non-destructive migration from SharedPreferences JSON to SQLite.
  /// Preserves all legacy JSON strings in archival backup keys for safety.
  static Future<void> runMigrationIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final bool alreadyMigrated = prefs.getBool(_migrationFlagKey) ?? false;

    if (alreadyMigrated) {
      debugPrint('ℹ️ [MigrationService] SQLite migration already completed.');
      return;
    }

    debugPrint('🚀 [MigrationService] Checking for legacy JSON data to migrate to SQLite...');
    final dbService = DatabaseService.instance;

    int migratedTransactions = 0;
    int migratedRecurring = 0;
    int migratedOutstanding = 0;

    try {
      // ── 1. Migrate Transactions ──
      var txJsonStr = prefs.getString(_legacyTransactionsKey);
      if (txJsonStr == null || txJsonStr == '[]') {
        txJsonStr = prefs.getString(_legacyTransactionsBackupKey);
      }

      if (txJsonStr != null && txJsonStr != '[]' && txJsonStr.trim().isNotEmpty) {
        try {
          final List<dynamic> decoded = json.decode(txJsonStr);
          final List<ExpenseTransaction> txs = [];
          for (final item in decoded) {
            try {
              if (item is Map<String, dynamic>) {
                txs.add(ExpenseTransaction.fromMap(item));
              } else if (item is Map) {
                txs.add(ExpenseTransaction.fromMap(Map<String, dynamic>.from(item)));
              }
            } catch (itemErr) {
              debugPrint('⚠️ [MigrationService] Skipping corrupt transaction: $itemErr');
            }
          }
          if (txs.isNotEmpty) {
            await dbService.insertTransactions(txs);
            migratedTransactions = txs.length;
            // Archive backup
            await prefs.setString('tripl_legacy_backup_transactions', txJsonStr);
          }
        } catch (e) {
          debugPrint('⚠️ [MigrationService] Error decoding transactions: $e');
        }
      }

      // ── 2. Migrate Recurring Transactions ──
      final recurringStr = prefs.getString(_legacyRecurringKey);
      if (recurringStr != null && recurringStr != '[]' && recurringStr.trim().isNotEmpty) {
        try {
          final List<dynamic> decoded = json.decode(recurringStr);
          final List<RecurringTransaction> rTxs = [];
          for (final item in decoded) {
            try {
              if (item is Map<String, dynamic>) {
                rTxs.add(RecurringTransaction.fromMap(item));
              } else if (item is Map) {
                rTxs.add(RecurringTransaction.fromMap(Map<String, dynamic>.from(item)));
              }
            } catch (itemErr) {
              debugPrint('⚠️ [MigrationService] Skipping corrupt recurring tx: $itemErr');
            }
          }
          if (rTxs.isNotEmpty) {
            await dbService.insertRecurringTransactions(rTxs);
            migratedRecurring = rTxs.length;
            // Archive backup
            await prefs.setString('tripl_legacy_backup_recurring', recurringStr);
          }
        } catch (e) {
          debugPrint('⚠️ [MigrationService] Error decoding recurring transactions: $e');
        }
      }

      // ── 3. Migrate Outstanding Records ──
      final outstandingStr = prefs.getString(_legacyOutstandingKey);
      if (outstandingStr != null && outstandingStr != '[]' && outstandingStr.trim().isNotEmpty) {
        try {
          final List<dynamic> decoded = json.decode(outstandingStr);
          final List<OutstandingRecord> records = [];
          for (final item in decoded) {
            try {
              if (item is Map<String, dynamic>) {
                records.add(OutstandingRecord.fromMap(item));
              } else if (item is Map) {
                records.add(OutstandingRecord.fromMap(Map<String, dynamic>.from(item)));
              }
            } catch (itemErr) {
              debugPrint('⚠️ [MigrationService] Skipping corrupt outstanding record: $itemErr');
            }
          }
          if (records.isNotEmpty) {
            await dbService.insertOutstandingRecords(records);
            migratedOutstanding = records.length;
            // Archive backup
            await prefs.setString('tripl_legacy_backup_outstanding', outstandingStr);
          }
        } catch (e) {
          debugPrint('⚠️ [MigrationService] Error decoding outstanding records: $e');
        }
      }

      // Mark migration flag as complete
      await prefs.setBool(_migrationFlagKey, true);
      debugPrint('✅ [MigrationService] Migration complete! Migrated: '
          '$migratedTransactions transactions, '
          '$migratedRecurring recurring rules, '
          '$migratedOutstanding outstanding records.');
    } catch (e, stack) {
      debugPrint('❌ [MigrationService] Migration encountered critical error: $e\n$stack');
      // Do not mark as migrated so it can retry or recover
    }
  }
}
