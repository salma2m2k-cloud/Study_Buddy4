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

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _timezoneReady = false;

  static const String _taskChannelId =
      'study_buddy_tasks';

  static const String _classChannelId =
      'study_buddy_classes';

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    try {
      final String localName =
          (await FlutterTimezone.getLocalTimezone())
              .identifier;

      tz.setLocalLocation(
        tz.getLocation(localName),
      );

      _timezoneReady = true;

      dev.log(
        'Timezone set to $localName',
        name: 'NotificationService',
      );
    } catch (e, st) {
      dev.log(
        'Failed to resolve device timezone: $e',
        name: 'NotificationService',
        error: e,
        stackTrace: st,
      );

      _timezoneReady = false;
    }

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings(
      '@drawable/ic_stat_study_buddy',
    );

    const DarwinInitializationSettings iosInit =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings =
        InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(initSettings);

    final AndroidFlutterLocalNotificationsPlugin?
        androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _taskChannelId,
          'Task reminders',
          description:
              'Reminders for tasks you\'ve scheduled.',
          importance: Importance.high,
        ),
      );

      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _classChannelId,
          'Class alarms',
          description:
              'Notifications for your upcoming classes.',
          importance: Importance.max,
        ),
      );
    }

    _initialized = true;

    dev.log(
      'NotificationService initialized',
      name: 'NotificationService',
    );
  }

  Future<bool> requestPermissions() async {
    bool granted = true;

    if (Platform.isIOS) {
      final bool? ok = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );

      granted = ok ?? false;
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin?
          androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final bool? notificationPermission =
          await androidPlugin
              ?.requestNotificationsPermission();

      granted = notificationPermission ?? false;

      final PermissionStatus exactAlarmStatus =
          await Permission.scheduleExactAlarm.status;

      if (!exactAlarmStatus.isGranted) {
        await Permission.scheduleExactAlarm.request();
      }
    }

    dev.log(
      'Notification permission result: $granted',
      name: 'NotificationService',
    );

    return granted;
  }

  Future<bool> hasPermission() async {
    await _ensureReady();

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin?
          androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final bool? enabled =
          await androidPlugin?.areNotificationsEnabled();

      return enabled ?? false;
    }

    if (Platform.isIOS) {
      final NotificationsEnabledOptions? opts =
          await _plugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.checkPermissions();

      return opts?.isEnabled ?? false;
    }

    return true;
  }

  Future<void> showTestNotification() async {
    await _ensureReady();

    if (Platform.isAndroid) {
      final bool enabled =
          await hasPermission();

      if (!enabled) {
        final bool granted =
            await requestPermissions();

        if (!granted) {
          throw Exception(
            'Notification permission was not granted.',
          );
        }
      }
    }

    await _plugin.show(
      999999,
      'Study Buddy 👋',
      'Notifications are working!',
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

    dev.log(
      'Test notification shown',
      name: 'NotificationService',
    );
  }

  Future<void> scheduleTaskReminder(
    Task task,
  ) async {
    await _ensureReady();

    await cancelTaskReminder(task);

    final DateTime? reminderTime =
        task.reminderTime;

    if (task.isCompleted) return;
    if (!task.reminderEnabled) return;
    if (reminderTime == null) return;

    if (reminderTime.isBefore(DateTime.now())) {
      return;
    }

    try {
      await _plugin.zonedSchedule(
        task.notificationId,
        '📚 ${task.title}',
        _dueInText(task.dueAt!),
        tz.TZDateTime.from(
          reminderTime,
          tz.local,
        ),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _taskChannelId,
            'Task reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode:
            AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation
                .absoluteTime,
        payload: 'task:${task.id}',
      );
    } catch (e, st) {
      dev.log(
        'FAILED to schedule task reminder: $e',
        name: 'NotificationService',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> cancelTaskReminder(
    Task task,
  ) async {
    await _ensureReady();

    try {
      await _plugin.cancel(
        task.notificationId,
      );
    } catch (e, st) {
      dev.log(
        'FAILED to cancel task reminder: $e',
        name: 'NotificationService',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> scheduleClassAlarm(
    ClassModel classModel,
  ) async {
    await _ensureReady();

    await cancelClassAlarm(classModel);

    if (!classModel.reminderEnabled) {
      return;
    }

    final DateTime now =
        DateTime.now();

    final DateTime nextClassStart =
        classModel.nextOccurrenceStart(now);

    final DateTime reminderTime =
        nextClassStart.subtract(
      Duration(
        minutes:
            classModel.reminderLeadMinutes,
      ),
    );

    DateTime effectiveReminderTime =
        reminderTime;

    DateTime effectiveClassStart =
        nextClassStart;

    if (effectiveReminderTime
        .isBefore(now)) {
      effectiveClassStart =
          nextClassStart.add(
        const Duration(days: 7),
      );

      effectiveReminderTime =
          effectiveClassStart.subtract(
        Duration(
          minutes:
              classModel.reminderLeadMinutes,
        ),
      );
    }

    dev.log(
      'Scheduling class notification | '
      'id=${classModel.id} '
      'notifId=${classModel.notificationId} '
      'weekday=${classModel.weekday.label} '
      'classStart=$effectiveClassStart '
      'reminder=$effectiveReminderTime',
      name: 'NotificationService',
    );

    try {
      await _plugin.zonedSchedule(
        classModel.notificationId,
        '🔔 ${classModel.name}',
        _classAlarmBody(classModel),
        tz.TZDateTime.from(
          effectiveReminderTime,
          tz.local,
        ),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _classChannelId,
            'Class alarms',
            importance: Importance.max,
            priority: Priority.max,
          ),
          iOS: DarwinNotificationDetails(
            interruptionLevel:
                InterruptionLevel.timeSensitive,
          ),
        ),
        androidScheduleMode:
            AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation
                .absoluteTime,
        matchDateTimeComponents:
            DateTimeComponents.dayOfWeekAndTime,
        payload: 'class:${classModel.id}',
      );

      dev.log(
        'Class notification scheduled successfully.',
        name: 'NotificationService',
      );
    } catch (e, st) {
      dev.log(
        'FAILED to schedule class notification: $e',
        name: 'NotificationService',
        error: e,
        stackTrace: st,
      );
    }
  }

  String _classAlarmBody(
    ClassModel classModel,
  ) {
    final String lead =
        classModel.reminderLeadMinutes == 0
            ? 'Starting now'
            : 'Starts in '
                '${classModel.reminderLeadMinutes} minutes';

    final String where =
        classModel.location.isNotEmpty
            ? ' • ${classModel.location}'
            : '';

    return '$lead$where';
  }

  Future<void> cancelClassAlarm(
    ClassModel classModel,
  ) async {
    await _ensureReady();

    try {
      await _plugin.cancel(
        classModel.notificationId,
      );
    } catch (e, st) {
      dev.log(
        'FAILED to cancel class notification: $e',
        name: 'NotificationService',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> restoreAll({
    required List<Task> tasks,
    required List<ClassModel> classes,
  }) async {
    await _ensureReady();

    for (final Task task in tasks) {
      await scheduleTaskReminder(task);
    }

    // IMPORTANT:
    // Classes MUST be passed here.
    // Passing classes: [] disables restoration
    // of the original class notification system.
    for (final ClassModel classModel in classes) {
      await scheduleClassAlarm(classModel);
    }

    dev.log(
      'Restored reminders: '
      '${tasks.length} tasks, '
      '${classes.length} classes.',
      name: 'NotificationService',
    );
  }

  Future<List<PendingNotificationRequest>>
      pending() async {
    await _ensureReady();

    return _plugin.pendingNotificationRequests();
  }

  String _dueInText(DateTime dueAt) {
    final Duration diff =
        dueAt.difference(DateTime.now());

    if (diff.inMinutes <= 1) {
      return 'Due now';
    }

    if (diff.inMinutes < 60) {
      return 'Due in ${diff.inMinutes} minutes';
    }

    if (diff.inHours < 24) {
      return 'Due in ${diff.inHours}h';
    }

    return 'Due soon';
  }

  Future<void> _ensureReady() async {
    if (!_initialized) {
      await init();
    }

    if (!_timezoneReady) {
      try {
        final String localName =
            (await FlutterTimezone
                    .getLocalTimezone())
                .identifier;

        tz.setLocalLocation(
          tz.getLocation(localName),
        );

        _timezoneReady = true;
      } catch (e, st) {
        dev.log(
          'Timezone retry failed: $e',
          name: 'NotificationService',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  Weekday weekdayOf(DateTime dt) {
    return Weekday.fromDateTimeWeekday(
      dt.weekday,
    );
  }
}
