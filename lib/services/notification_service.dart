import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/recurring_transaction_model.dart';
import '../models/transaction_model.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    tz.initializeTimeZones();
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings = InitializationSettings(android: androidSettings);
    await _notificationsPlugin.initialize(settings: settings);

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
      await androidImplementation?.requestExactAlarmsPermission();
    }
  }

  static Future<void> scheduleRecurringNotification(RecurringTransaction tx) async {
    if (!tx.reminderEnabled) return;

    DateTime scheduledTime = tx.nextDueDate;
    
    // Adjust time based on reminder timing
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
        default:
          break;
      }
    }

    if (scheduledTime.isBefore(DateTime.now())) {
      // If the scheduled time is already past, don't schedule for now.
      return;
    }

    int notificationId = tx.id.hashCode;

    String body = tx.autoCreate
        ? 'Auto Created: ${tx.title} - ₹${tx.amount.toStringAsFixed(0)}'
        : '${tx.title} due. ₹${tx.amount.toStringAsFixed(0)}. Open to confirm.';

    await _notificationsPlugin.zonedSchedule(
      id: notificationId,
      title: 'Recurring Transaction Reminder',
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'tallytap_recurring',
          'Recurring Transactions',
          channelDescription: 'Reminders for recurring transactions',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static Future<void> scheduleTransactionReminder(ExpenseTransaction tx) async {
    if (!tx.needsVerification || tx.reminderDate == null) return;
    if (tx.reminderDate!.isBefore(DateTime.now())) return;

    int notificationId = tx.id.hashCode;
    
    await _notificationsPlugin.zonedSchedule(
      id: notificationId,
      title: 'Transaction Verification',
      body: 'Verify receipt for ${tx.merchant} (₹${tx.amount.toStringAsFixed(0)})',
      scheduledDate: tz.TZDateTime.from(tx.reminderDate!, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'tallytap_verification',
          'Receipt Verification',
          channelDescription: 'Reminders to verify receipts and finish logging transactions',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static Future<void> cancelNotification(String id) async {
    await _notificationsPlugin.cancel(id: id.hashCode);
  }
}
