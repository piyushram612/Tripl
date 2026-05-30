import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/recurring_transaction_model.dart';
import '../models/transaction_model.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    print('🔔 [NotificationService] Initializing FlutterLocalNotificationsPlugin...');
    tz.initializeTimeZones();
    // Run timezone detection asynchronously to prevent blocking the Flutter main thread and causing launch black screens
    Future(() async {
      try {
        final TimezoneInfo timeZoneInfo = await FlutterTimezone.getLocalTimezone();
        final String timeZoneName = timeZoneInfo.identifier;
        tz.setLocalLocation(tz.getLocation(timeZoneName));
        print('🔔 [NotificationService] Timezone successfully set to: $timeZoneName');
      } catch (e) {
        print('⚠️ [NotificationService] Failed to set local timezone: $e. Falling back to UTC.');
      }
    });

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('ic_launcher');
    const InitializationSettings settings = InitializationSettings(android: androidSettings);
    await _notificationsPlugin.initialize(settings: settings);

    if (Platform.isAndroid) {
      Future(() async {
        try {
          final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
              _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
          await androidImplementation?.requestNotificationsPermission();
          await androidImplementation?.requestExactAlarmsPermission();
          print('🔔 [NotificationService] Android permissions requested successfully.');
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
          break;
      }
    }

    print('🔔 [NotificationService] Attempting to schedule recurring reminder for "${tx.title}" (ID: ${tx.id}) at $scheduledTime');

    if (scheduledTime.isBefore(DateTime.now())) {
      print('⚠️ [NotificationService] Scheduled time ($scheduledTime) is in the past, skipping recurring reminder.');
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
          'tallytap_recurring_v2',
          'Recurring Transactions',
          channelDescription: 'Reminders for recurring transactions',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    print('✅ [NotificationService] Successfully scheduled recurring reminder for "${tx.title}" (Notification ID: $notificationId)');
  }

  static Future<void> scheduleTransactionReminder(ExpenseTransaction tx) async {
    if (!tx.needsVerification || tx.reminderDate == null) {
      print('🔔 [NotificationService] Transaction verification reminder is disabled/null for "${tx.merchant}", skipping.');
      return;
    }
    
    print('🔔 [NotificationService] Attempting to schedule transaction verification reminder for "${tx.merchant}" (ID: ${tx.id}) at ${tx.reminderDate}');

    if (tx.reminderDate!.isBefore(DateTime.now())) {
      print('⚠️ [NotificationService] Reminder date (${tx.reminderDate}) is in the past, skipping verification reminder.');
      return;
    }

    int notificationId = tx.id.hashCode;
    
    await _notificationsPlugin.zonedSchedule(
      id: notificationId,
      title: 'Transaction Verification',
      body: 'Verify receipt for ${tx.merchant} (₹${tx.amount.toStringAsFixed(0)})',
      scheduledDate: tz.TZDateTime.from(tx.reminderDate!, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'tallytap_verification_v2',
          'Receipt Verification',
          channelDescription: 'Reminders to verify receipts and finish logging transactions',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    print('✅ [NotificationService] Successfully scheduled verification reminder for "${tx.merchant}" (Notification ID: $notificationId)');
  }

  static Future<void> cancelNotification(String id) async {
    print('🔔 [NotificationService] Cancelling notification with ID: $id (Hash: ${id.hashCode})');
    await _notificationsPlugin.cancel(id: id.hashCode);
  }

  static Future<void> showInstantNotification() async {
    print('🔔 [NotificationService] Firing instant test notification...');
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'tallytap_test_v2',
      'Test Notifications',
      channelDescription: 'Channel for testing notifications instantly',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      id: 999,
      title: 'TallyTap Test Notification',
      body: 'This is an instant test notification from TallyTap! 🚀',
      notificationDetails: details,
    );
    print('✅ [NotificationService] Instant test notification triggered.');
  }
}
