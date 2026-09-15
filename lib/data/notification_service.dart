import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/task.dart';

/// Schedules/cancels the local notification that reminds about a task's due
/// date. A task's notification id is derived from its (stable) Hive id
/// rather than tracked separately, so scheduling the same task twice simply
/// replaces the previous notification instead of stacking duplicates.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Sets up the plugin and requests permissions where the platform needs
  /// them. Failures here (an unsupported platform, a denied permission, a
  /// platform-specific setup issue) are swallowed rather than thrown —
  /// due-date reminders are a nice-to-have, not something that should be
  /// able to crash the app on startup — and simply leave every
  /// schedule/cancel call a no-op for the rest of the session.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      tz_data.initializeTimeZones();
      try {
        final localZone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(localZone.identifier));
      } catch (_) {
        // Falls back to whatever the timezone package defaults to (UTC) —
        // due-date reminders would then fire at the wrong wall-clock time,
        // but the app should still function otherwise.
      }

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const darwinSettings = DarwinInitializationSettings();
      const linuxSettings = LinuxInitializationSettings(
        defaultActionName: 'Open',
      );
      final windowsSettings = WindowsInitializationSettings(
        appName: 'ProCheck',
        appUserModelId: 'com.chdr.procheck',
        guid: 'b9f6f2f0-6f0a-4d1e-9a1c-9a6f6c7d9f0a',
      );

      await _plugin.initialize(
        settings: InitializationSettings(
          android: androidSettings,
          iOS: darwinSettings,
          macOS: darwinSettings,
          linux: linuxSettings,
          windows: windowsSettings,
        ),
      );

      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      _initialized = true;
    } catch (_) {
      // Left un-initialized; see the doc comment above.
    }
  }

  /// Schedules (or reschedules) a due-date reminder for [task]. A due date
  /// already in the past is not scheduled — there is nothing useful to
  /// remind about — and any previously-scheduled notification for this task
  /// is cancelled either way.
  ///
  /// A no-op until [initialize] has actually run (e.g. under the widget
  /// test binding, which never calls it): there's no platform channel to
  /// call into yet, and tasks are created/toggled/deleted constantly in
  /// tests without ever touching real notifications.
  Future<void> scheduleForTask(Task task) async {
    if (!_initialized) return;
    await cancelForTask(task);

    final dueDate = task.dueDate;
    if (dueDate == null) return;

    final scheduled = tz.TZDateTime.from(dueDate, tz.local);
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      id: _notificationId(task.id),
      title: task.title,
      body: 'This task is due now.',
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_due_dates',
          'Task due dates',
          channelDescription: 'Reminders for tasks with a due date',
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
        linux: LinuxNotificationDetails(),
        windows: WindowsNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelForTask(Task task) async {
    if (!_initialized) return;
    await _plugin.cancel(id: _notificationId(task.id));
  }

  /// Cancels every pending due-date reminder. Used by Settings > Wipe All
  /// Data and when replacing the whole store on backup restore.
  Future<void> cancelAll() async {
    if (!_initialized) return;
    await _plugin.cancelAll();
  }

  /// Notification ids are ints, but a task's Hive id is a UUID string —
  /// hashing it down keeps ids stable across app restarts (so cancelling
  /// later finds the right one) without needing to persist a separate
  /// int id anywhere.
  int _notificationId(String taskId) => taskId.hashCode & 0x7fffffff;
}
