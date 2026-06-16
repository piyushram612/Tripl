import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/recurring_transaction_model.dart';
import '../models/transaction_model.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:isolate';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/transaction_service.dart';
import '../providers/recurring_transaction_provider.dart';
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  WidgetsFlutterBinding.ensureInitialized();
  print('🔔 [Background] Action triggered: ${notificationResponse.actionId}');
  final action = notificationResponse.actionId;
  final payloadStr = notificationResponse.payload;
  if (action == null || payloadStr == null) {
    print('⚠️ [Background] Action or payload is null, returning.');
    return;
  }

  final SendPort? sendPort = IsolateNameServer.lookupPortByName('notification_action_port');
  if (sendPort != null) {
    print('🔔 [Background] Main isolate is alive. Forwarding action...');
    sendPort.send({
      'id': notificationResponse.id,
      'actionId': action,
      'input': notificationResponse.input,
      'payload': payloadStr,
      'notificationResponseType': notificationResponse.notificationResponseType.index,
    });
    return;
  }

  print('🔔 [Background] Main isolate is dead. Processing action locally...');
  await NotificationService.processAction(action, payloadStr);
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static ProviderContainer? _container;

  static Future<void> _initTimezonesForBackground() async {
    print('🔔 [NotificationService] Initializing Timezones for background...');
    tz.initializeTimeZones();
    try {
      final TimezoneInfo timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));
    } catch (e) {
      print('⚠️ [NotificationService] Failed to set local timezone: $e. Falling back to UTC.');
    }
  }

  static Future<void> handleForegroundAction(NotificationResponse notificationResponse) async {
    print('🔔 [Foreground] Processing action...');
    final action = notificationResponse.actionId;
    final payloadStr = notificationResponse.payload;
    if (action == null || payloadStr == null) return;
    
    await processAction(action, payloadStr);
    
    if (_container != null) {
      print('🔔 [Foreground] Refreshing UI providers...');
      _container!.read(transactionListProvider.notifier).loadTransactions();
      _container!.read(recurringTransactionsProvider.notifier).checkDueTransactions();
    }
  }

  static Future<void> processAction(String action, String payloadStr) async {
    try {
      final payload = jsonDecode(payloadStr);
      final type = payload['type'];
      final id = payload['id'];
      final notificationId = payload['notificationId'];
      
      final prefs = await SharedPreferences.getInstance();

      if (type == 'transaction') {
        final jsonStr = prefs.getString('transactions_json');
        if (jsonStr != null) {
          final List<dynamic> decoded = json.decode(jsonStr);
          final txs = decoded.map((e) => ExpenseTransaction.fromMap(e)).toList();
          final idx = txs.indexWhere((t) => t.id == id);
          if (idx != -1) {
            if (action == 'mark_verified') {
              txs[idx] = txs[idx].copyWith(needsVerification: false);
              await prefs.setString('transactions_json', json.encode(txs.map((e) => e.toMap()).toList()));
              if (notificationId != null) {
                await cancelNotificationById(notificationId);
              }
            } else if (action == 'remind_later') {
              final mins = prefs.getInt('tripl_snooze_duration_mins') ?? 240;
              txs[idx] = txs[idx].copyWith(reminderDate: DateTime.now().add(Duration(minutes: mins)));
              await prefs.setString('transactions_json', json.encode(txs.map((e) => e.toMap()).toList()));
              await _initTimezonesForBackground();
              await scheduleTransactionReminder(txs[idx]);
            }
          }
        }
      } else if (type == 'recurring') {
        final data = prefs.getString('tripl_recurring_transactions');
        if (data != null) {
          final List<dynamic> decoded = json.decode(data);
          final rTxs = decoded.map((e) => RecurringTransaction.fromMap(e)).toList();
          final idx = rTxs.indexWhere((t) => t.id == id);
          if (idx != -1) {
            var rTx = rTxs[idx];
            if (action == 'mark_verified') {
              final jsonStr = prefs.getString('transactions_json');
              if (jsonStr != null) {
                final List<dynamic> tDecoded = json.decode(jsonStr);
                final txs = tDecoded.map((e) => ExpenseTransaction.fromMap(e)).toList();
                final tIdx = txs.indexWhere((t) => t.needsVerification && t.amount == rTx.amount && t.merchant == (rTx.merchant ?? rTx.title));
                if (tIdx != -1) {
                  txs[tIdx] = txs[tIdx].copyWith(needsVerification: false);
                  await prefs.setString('transactions_json', json.encode(txs.map((e) => e.toMap()).toList()));
                  if (notificationId != null) await cancelNotificationById(notificationId);
                } else {
                  final newExpense = ExpenseTransaction(
                    id: const Uuid().v4(),
                    amount: rTx.amount,
                    merchant: rTx.merchant ?? rTx.title,
                    date: rTx.nextDueDate,
                    paymentMethod: rTx.paymentMethod,
                    category: rTx.type == TransactionType.income ? 'Income' : rTx.category,
                    needsVerification: false,
                    wasFinishLater: true,
                  );
                  txs.add(newExpense);
                  await prefs.setString('transactions_json', json.encode(txs.map((e) => e.toMap()).toList()));
                  rTxs[idx] = rTx.advance();
                  await prefs.setString('tripl_recurring_transactions', json.encode(rTxs.map((e) => e.toMap()).toList()));
                  await _initTimezonesForBackground();
                  await scheduleRecurringNotification(rTxs[idx]);
                }
              }
            } else if (action == 'remind_later') {
              await _initTimezonesForBackground();
              final mins = prefs.getInt('tripl_snooze_duration_mins') ?? 240;
              final snoozeTime = DateTime.now().add(Duration(minutes: mins));
              await _notificationsPlugin.zonedSchedule(
                id: rTx.id.hashCode,
                title: rTx.autoCreate ? 'Action Required: Auto-Created Log' : 'Payment Due',
                body: rTx.autoCreate 
                  ? 'Auto-logged ${rTx.title} (₹${rTx.amount.toStringAsFixed(0)}). Please verify.' 
                  : '${rTx.title} is due for ₹${rTx.amount.toStringAsFixed(0)}.',
                scheduledDate: tz.TZDateTime.from(snoozeTime, tz.local),
                notificationDetails: NotificationDetails(
                  android: AndroidNotificationDetails(
                    'tripl_recurring_v2',
                    'Recurring Transactions',
                    channelDescription: 'Reminders for recurring transactions',
                    importance: Importance.max,
                    priority: Priority.high,
                    actions: rTx.autoCreate 
                      ? const [
                          AndroidNotificationAction('mark_verified', 'Mark as Verified', showsUserInterface: false, cancelNotification: true),
                          AndroidNotificationAction('remind_later', 'Remind Later', showsUserInterface: false, cancelNotification: true),
                        ]
                      : const [
                          AndroidNotificationAction('log_paid', 'Log as Paid', showsUserInterface: false, cancelNotification: true),
                          AndroidNotificationAction('skip', 'Skip', showsUserInterface: false, cancelNotification: true),
                          AndroidNotificationAction('remind_later', 'Remind Later', showsUserInterface: false, cancelNotification: true),
                        ],
                  ),
                ),
                payload: payloadStr,
                androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              );
            } else if (action == 'log_paid') {
              final jsonStr = prefs.getString('transactions_json');
              List<ExpenseTransaction> txs = [];
              if (jsonStr != null) {
                 final List<dynamic> tDecoded = json.decode(jsonStr);
                 txs = tDecoded.map((e) => ExpenseTransaction.fromMap(e)).toList();
              }
              final newExpense = ExpenseTransaction(
                id: const Uuid().v4(),
                amount: rTx.amount,
                merchant: rTx.merchant ?? rTx.title,
                date: DateTime.now(),
                paymentMethod: rTx.paymentMethod,
                category: rTx.type == TransactionType.income ? 'Income' : rTx.category,
              );
              txs.add(newExpense);
              await prefs.setString('transactions_json', json.encode(txs.map((e) => e.toMap()).toList()));
              rTxs[idx] = rTx.advance();
              await prefs.setString('tripl_recurring_transactions', json.encode(rTxs.map((e) => e.toMap()).toList()));
              await _initTimezonesForBackground();
              await scheduleRecurringNotification(rTxs[idx]);
            } else if (action == 'skip') {
              rTxs[idx] = rTx.advance(skip: true);
              await prefs.setString('tripl_recurring_transactions', json.encode(rTxs.map((e) => e.toMap()).toList()));
              await _initTimezonesForBackground();
              await scheduleRecurringNotification(rTxs[idx]);
            }
          }
        }
      }
    } catch (e) {
      print('Error processing action: $e');
    }
  }

  static Future<void> initialize(ProviderContainer appContainer) async {
    _container = appContainer;
    print('🔔 [NotificationService] Initializing FlutterLocalNotificationsPlugin...');
    tz.initializeTimeZones();
    try {
      final TimezoneInfo timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = timeZoneInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      print('🔔 [NotificationService] Timezone successfully set to: $timeZoneName');
    } catch (e) {
      print('⚠️ [NotificationService] Failed to set local timezone: $e. Falling back to UTC.');
    }

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings = InitializationSettings(android: androidSettings);
    await _notificationsPlugin.initialize(
      settings: settings,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      onDidReceiveNotificationResponse: handleForegroundAction,
    );

    if (Platform.isAndroid) {
      Future(() async {
        try {
          final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
              _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
          await androidImplementation?.requestNotificationsPermission();
          await androidImplementation?.requestExactAlarmsPermission();
        } catch (e) {
          print('⚠️ [NotificationService] Failed to request Android permissions: $e');
        }
      });
    }
    print('🔔 [NotificationService] Initialization completed successfully.');
  }

  static Future<void> scheduleRecurringNotification(RecurringTransaction tx) async {
    if (!tx.reminderEnabled) {
      print('🔔 [NotificationService] Reminder disabled for "${tx.title}", skipping scheduling.');
      return;
    }

    DateTime scheduledTime = tx.nextDueDate;
    
    if (tx.reminderTiming != null) {
      switch (tx.reminderTiming!) {
        case ReminderTiming.oneHourBefore:
          scheduledTime = scheduledTime.subtract(const Duration(hours: 1));
          break;
        case ReminderTiming.sixHoursBefore:
          scheduledTime = scheduledTime.subtract(const Duration(hours: 6));
          break;
        case ReminderTiming.twelveHoursBefore:
          scheduledTime = scheduledTime.subtract(const Duration(hours: 12));
          break;
        case ReminderTiming.oneDayBefore:
          scheduledTime = scheduledTime.subtract(const Duration(days: 1));
          break;
        case ReminderTiming.threeDaysBefore:
          scheduledTime = scheduledTime.subtract(const Duration(days: 3));
          break;
        case ReminderTiming.oneWeekBefore:
          scheduledTime = scheduledTime.subtract(const Duration(days: 7));
          break;
        case ReminderTiming.atDueTime:
          break;
      }
    }

    if (scheduledTime.isBefore(DateTime.now())) {
      print('⚠️ [NotificationService] Scheduled time ($scheduledTime) is in the past, skipping recurring reminder.');
      return;
    }

    int notificationId = tx.id.hashCode;

    String body;
    String title;
    List<AndroidNotificationAction> actions = [];

    if (tx.autoCreate) {
      if (tx.logAsPending) {
        title = 'Action Required: Auto-Created Log';
        body = 'Auto-logged ${tx.title} (₹${tx.amount.toStringAsFixed(0)}). Please verify.';
        actions = [
          const AndroidNotificationAction('mark_verified', 'Mark as Verified', showsUserInterface: false, cancelNotification: true),
          const AndroidNotificationAction('remind_later', 'Remind Later', showsUserInterface: false, cancelNotification: true),
        ];
      } else {
        title = 'Payment Logged';
        body = 'Auto-logged: ${tx.title} (₹${tx.amount.toStringAsFixed(0)})';
      }
    } else {
      title = 'Payment Due';
      body = '${tx.title} is due for ₹${tx.amount.toStringAsFixed(0)}.';
      actions = [
        const AndroidNotificationAction('log_paid', 'Log as Paid', showsUserInterface: false, cancelNotification: true),
        const AndroidNotificationAction('skip', 'Skip', showsUserInterface: false, cancelNotification: true),
        const AndroidNotificationAction('remind_later', 'Remind Later', showsUserInterface: false, cancelNotification: true),
      ];
    }

    await _notificationsPlugin.zonedSchedule(
      id: notificationId,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'tripl_recurring_v2',
          'Recurring Transactions',
          channelDescription: 'Reminders for recurring transactions',
          importance: Importance.max,
          priority: Priority.high,
          actions: actions,
        ),
      ),
      payload: jsonEncode({'type': 'recurring', 'id': tx.id, 'notificationId': notificationId}),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    print('✅ [NotificationService] Successfully scheduled recurring reminder for "${tx.title}" (Notification ID: $notificationId)');
  }

  static Future<void> scheduleTransactionReminder(ExpenseTransaction tx) async {
    if (!tx.needsVerification || tx.reminderDate == null) {
      return;
    }
    
    if (tx.reminderDate!.isBefore(DateTime.now())) {
      return;
    }

    int notificationId = tx.id.hashCode;
    
    await _notificationsPlugin.zonedSchedule(
      id: notificationId,
      title: 'Pending Verification',
      body: 'Verify transaction for ${tx.merchant} (₹${tx.amount.toStringAsFixed(0)})',
      scheduledDate: tz.TZDateTime.from(tx.reminderDate!, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'tripl_verification_v2',
          'Receipt Verification',
          channelDescription: 'Reminders to verify receipts and finish logging transactions',
          importance: Importance.max,
          priority: Priority.high,
          actions: [
            AndroidNotificationAction('mark_verified', 'Mark as Verified', showsUserInterface: false, cancelNotification: true),
            AndroidNotificationAction('remind_later', 'Remind Later', showsUserInterface: false, cancelNotification: true),
          ],
        ),
      ),
      payload: jsonEncode({'type': 'transaction', 'id': tx.id, 'notificationId': notificationId}),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    print('✅ [NotificationService] Successfully scheduled verification reminder for "${tx.merchant}" (Notification ID: $notificationId)');
  }

  static Future<void> cancelNotificationById(int notificationId) async {
    await _notificationsPlugin.cancel(id: notificationId);
  }

  static Future<void> cancelNotification(String id) async {
    await _notificationsPlugin.cancel(id: id.hashCode);
  }

  static Future<void> showInstantNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'tripl_test_v2',
      'Test Notifications',
      channelDescription: 'Channel for testing notifications instantly',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      id: 999,
      title: 'Tripl Test Notification',
      body: 'This is an instant test notification from Tripl! 🚀',
      notificationDetails: details,
    );
  }
}
