import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/class_model.dart';
import '../models/task.dart';
import '../utils/weekday.dart';

/// Wraps `flutter_local_notifications` to provide REAL, timezone-aware,
/// OS-level scheduled notifications for tasks and recurring class alarms.
///
/// Design notes (see spec #8-#23):
/// - We never use in-app timers/Futures.delayed for reminders. Every
///   reminder is registered with the OS via `zonedSchedule`, so it fires
///   even if the app is closed, backgrounded, or the phone is locked.
/// - Every scheduled notification uses a STABLE id derived from the
///   task/class id, so editing or cancelling never creates duplicates —
///   we always cancel-then-reschedule under the same id.
/// - Class alarms use `matchDateTimeComponents:
///   DateTimeComponents.dayOfWeekAndTime` so the OS itself repeats the
///   alarm weekly — we don't need to manually re-schedule every 7 days.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _timezoneReady = false;

  static const String _taskChannelId = 'study_buddy_tasks';
  static const String _classChannelId = 'study_buddy_classes';

  Future<void> init() async {
    if (_initialized) return;

    // 1. Timezone database + device local timezone (spec #13).
    tz_data.initializeTimeZones();
    try {
      final String localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName));
      _timezoneReady = true;
      dev.log('Timezone set to $localName', name: 'NotificationService');
    } catch (e) {
      // If we can't determine the device timezone, fall back to UTC
      // rather than silently mis-scheduling (spec #23 — surface errors).
      dev.log('Failed to resolve device timezone: $e',
          name: 'NotificationService');
      _timezoneReady = false;
    }

    // 2. Platform init.
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _plugin.initialize(initSettings);

    // 3. Android notification channels (spec #21).
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _taskChannelId,
          'Task reminders',
          description: 'Reminders for tasks you\'ve scheduled.',
          importance: Importance.high,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _classChannelId,
          'Class alarms',
          description: 'Alarms for your upcoming classes.',
          importance: Importance.max,
        ),
      );
    }

    _initialized = true;
  }

  /// Requests notification permission (Android 13+, iOS) and, where
  /// available, exact-alarm permission (Android 12+). Never spams — call
  /// this once from Settings or first run, and check [hasPermission]
  /// before asking again (spec #20).
  Future<bool> requestPermissions() async {
    bool granted = true;

    if (Platform.isIOS) {
      final bool? ok = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      granted = ok ?? false;
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final bool? notifOk =
          await androidPlugin?.requestNotificationsPermission();
      granted = notifOk ?? false;

      // Exact alarms are required for class alarms to fire at the exact
      // minute requested, rather than being batched by the OS.
      final PermissionStatus exactAlarmStatus =
          await Permission.scheduleExactAlarm.status;
      if (!exactAlarmStatus.isGranted) {
        await Permission.scheduleExactAlarm.request();
      }
    }

    return granted;
  }

  Future<bool> hasPermission() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final bool? enabled = await androidPlugin?.areNotificationsEnabled();
      return enabled ?? false;
    }
    if (Platform.isIOS) {
      final NotificationsEnabledOptions? opts = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.checkPermissions();
      return opts?.isEnabled ?? false;
    }
    return true;
  }

  Future<void> showTestNotification() async {
    await _ensureReady();
    await _plugin.show(
      999999,
      'Study Buddy 👋',
      'Notifications are working. You\'ll get real alerts like this.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _taskChannelId,
          'Task reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
    dev.log('Test notification shown', name: 'NotificationService');
  }

  // ---------------- Task reminders ----------------

  Future<void> scheduleTaskReminder(Task task) async {
    await _ensureReady();
    await cancelTaskReminder(task);

    final DateTime? reminderTime = task.reminderTime;
    dev.log(
      'Scheduling task reminder | id=${task.id} notifId=${task.notificationId} '
      'now=${DateTime.now()} reminderTime=$reminderTime '
      'enabled=${task.reminderEnabled} completed=${task.isCompleted}',
      name: 'NotificationService',
    );

    if (task.isCompleted) return; // spec #9
    if (!task.reminderEnabled) return; // spec #9
    if (reminderTime == null) return;
    if (reminderTime.isBefore(DateTime.now())) {
      dev.log('Reminder time is in the past — not scheduling.',
          name: 'NotificationService');
      return; // spec #9
    }

    try {
      await _plugin.zonedSchedule(
        task.notificationId,
        '📚 ${task.title}',
        _dueInText(task.dueAt!),
        tz.TZDateTime.from(reminderTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _taskChannelId,
            'Task reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'task:${task.id}',
      );
      dev.log('Task reminder scheduled successfully.',
          name: 'NotificationService');
    } catch (e, st) {
      dev.log('FAILED to schedule task reminder: $e',
          name: 'NotificationService', error: e, stackTrace: st);
    }
  }

  Future<void> cancelTaskReminder(Task task) async {
    await _ensureReady();
    await _plugin.cancel(task.notificationId);
  }

  String _dueInText(DateTime dueAt) {
    final Duration diff = dueAt.difference(DateTime.now());
    if (diff.inMinutes <= 1) return 'Due now';
    if (diff.inMinutes < 60) return 'Due in ${diff.inMinutes} minutes';
    if (diff.inHours < 24) return 'Due in ${diff.inHours}h';
    return 'Due soon';
  }

  // ---------------- Class alarms ----------------

  /// Schedules a REPEATING weekly alarm for a class. Uses
  /// `DateTimeComponents.dayOfWeekAndTime` so the OS itself handles the
  /// weekly recurrence — we compute only the first correct occurrence
  /// (spec #16-#19).
  Future<void> scheduleClassAlarm(ClassModel classModel) async {
    await _ensureReady();
    await cancelClassAlarm(classModel);

    if (!classModel.reminderEnabled) return; // spec #17

    final DateTime now = DateTime.now();
    final DateTime nextClassStart = classModel.nextOccurrenceStart(now);
    final DateTime reminderTime = nextClassStart
        .subtract(Duration(minutes: classModel.reminderLeadMinutes));

    // If subtracting the lead time pushes us into the past relative to
    // "now" (e.g. reminder is due any second now), roll to next week's
    // occurrence rather than firing immediately or skipping (spec #19).
    DateTime effectiveReminderTime = reminderTime;
    DateTime effectiveClassStart = nextClassStart;
    if (effectiveReminderTime.isBefore(now)) {
      effectiveClassStart = nextClassStart.add(const Duration(days: 7));
      effectiveReminderTime = effectiveClassStart
          .subtract(Duration(minutes: classModel.reminderLeadMinutes));
    }

    dev.log(
      'Scheduling class alarm | id=${classModel.id} notifId=${classModel.notificationId} '
      'weekday=${classModel.weekday.label} now=$now '
      'nextClassStart=$effectiveClassStart reminderTime=$effectiveReminderTime '
      'leadMin=${classModel.reminderLeadMinutes}',
      name: 'NotificationService',
    );

    try {
      await _plugin.zonedSchedule(
        classModel.notificationId,
        '🔔 ${classModel.name}',
        _classAlarmBody(classModel),
        tz.TZDateTime.from(effectiveReminderTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _classChannelId,
            'Class alarms',
            importance: Importance.max,
            priority: Priority.max,
          ),
          iOS: DarwinNotificationDetails(interruptionLevel: InterruptionLevel.timeSensitive),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: 'class:${classModel.id}',
      );
      dev.log('Class alarm scheduled successfully (repeats weekly).',
          name: 'NotificationService');
    } catch (e, st) {
      dev.log('FAILED to schedule class alarm: $e',
          name: 'NotificationService', error: e, stackTrace: st);
    }
  }

  String _classAlarmBody(ClassModel c) {
    final String lead = c.reminderLeadMinutes == 0
        ? 'Starting now'
        : 'Starts in ${c.reminderLeadMinutes} minutes';
    final String where = c.location.isNotEmpty ? ' • ${c.location}' : '';
    return '$lead$where';
  }

  Future<void> cancelClassAlarm(ClassModel classModel) async {
    await _ensureReady();
    await _plugin.cancel(classModel.notificationId);
  }

  /// Restores all reminders on app startup (spec #39). Cancel-then-
  /// reschedule under the same stable ids guarantees no duplicates.
  Future<void> restoreAll({
    required List<Task> tasks,
    required List<ClassModel> classes,
  }) async {
    await _ensureReady();
    for (final Task t in tasks) {
      await scheduleTaskReminder(t);
    }
    for (final ClassModel c in classes) {
      await scheduleClassAlarm(c);
    }
    dev.log(
      'Restored reminders on startup: ${tasks.length} tasks, ${classes.length} classes.',
      name: 'NotificationService',
    );
  }

  Future<List<PendingNotificationRequest>> pending() async {
    await _ensureReady();
    return _plugin.pendingNotificationRequests();
  }

  Future<void> _ensureReady() async {
    if (!_initialized) await init();
    if (!_timezoneReady) {
      // Best-effort retry so a transient failure at startup doesn't
      // permanently break scheduling for the rest of the session.
      try {
        final String localName = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(localName));
        _timezoneReady = true;
      } catch (_) {
        // Keep going with whatever local location is currently set
        // (defaults to UTC) rather than throwing — spec #37.
      }
    }
  }

  // Exposed for tests/diagnostics only.
  Weekday weekdayOf(DateTime dt) => Weekday.fromDateTimeWeekday(dt.weekday);
}
