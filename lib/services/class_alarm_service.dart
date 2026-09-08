import 'dart:async';

import 'package:alarm/alarm.dart';

import '../models/class_model.dart';

class ClassAlarmService {
  ClassAlarmService._();

  static final ClassAlarmService instance = ClassAlarmService._();

  bool _initialized = false;

  final Map<int, ClassModel> _classes = {};

  StreamSubscription<AlarmSet>? _ringingSubscription;

  Future<void> init() async {
    if (_initialized) return;

    await Alarm.init();

    _ringingSubscription = Alarm.ringing.listen(
      _handleRingingAlarms,
    );

    _initialized = true;
  }

  // ============================================================
  // REGISTER / SCHEDULE
  // ============================================================

  Future<void> schedule(ClassModel classModel) async {
    await init();

    _classes[classModel.notificationId] = classModel;

    final DateTime now = DateTime.now();

    DateTime nextClassStart =
        classModel.nextOccurrenceStart(now);

    DateTime alarmTime = nextClassStart.subtract(
      Duration(
        minutes: classModel.reminderLeadMinutes,
      ),
    );

    // If this week's reminder has already passed,
    // schedule the same class for next week.
    if (!alarmTime.isAfter(now)) {
      alarmTime = alarmTime.add(
        const Duration(days: 7),
      );
    }

    final int alarmId = classModel.notificationId;

    // Replace an existing alarm for this class.
    await Alarm.stop(alarmId);

    final AlarmSettings settings = AlarmSettings(
      id: alarmId,
      dateTime: alarmTime,
      assetAudioPath: 'assets/sounds/class_alarm.mp3',

      // 🔊 Keep ringing until STOP.
      loopAudio: true,

      // 📳 Keep vibrating until STOP.
      vibrate: true,

      volumeSettings: const VolumeSettings(
        volume: 1.0,
        volumeEnforced: true,
      ),

      notificationSettings: NotificationSettings(
        title: '🔔 ${classModel.name}',
        body: _body(classModel),
        stopButton: 'STOP',
      ),

      // Wake the screen for the class alarm.
      androidFullScreenIntent: true,

      // Do not stop the alarm simply because the
      // Flutter task was terminated.
      androidStopAlarmOnTermination: false,

      warningNotificationOnKill: true,
    );

    await Alarm.set(
      alarmSettings: settings,
    );
  }

  // ============================================================
  // WHEN AN ALARM STARTS RINGING
  // ============================================================

  void _handleRingingAlarms(AlarmSet alarmSet) {
    for (final AlarmSettings alarm in alarmSet.alarms) {
      final ClassModel? classModel =
          _classes[alarm.id];

      if (classModel == null) {
        continue;
      }

      // The current alarm is now ringing.
      //
      // Immediately prepare the NEXT week's occurrence.
      // The current alarm continues ringing until the
      // user presses STOP.
      unawaited(
        _scheduleNextWeek(classModel),
      );
    }
  }

  Future<void> _scheduleNextWeek(
    ClassModel classModel,
  ) async {
    final DateTime now = DateTime.now();

    final DateTime currentOccurrence =
        classModel.nextOccurrenceStart(
      now.subtract(
        const Duration(seconds: 1),
      ),
    );

    DateTime nextOccurrence =
        currentOccurrence.add(
      const Duration(days: 7),
    );

    DateTime nextAlarmTime =
        nextOccurrence.subtract(
      Duration(
        minutes: classModel.reminderLeadMinutes,
      ),
    );

    // Make absolutely sure we never schedule
    // something in the past.
    while (!nextAlarmTime.isAfter(now)) {
      nextOccurrence = nextOccurrence.add(
        const Duration(days: 7),
      );

      nextAlarmTime =
          nextOccurrence.subtract(
        Duration(
          minutes: classModel.reminderLeadMinutes,
        ),
      );
    }

    final AlarmSettings nextAlarm =
        AlarmSettings(
      id: classModel.notificationId,
      dateTime: nextAlarmTime,
      assetAudioPath:
          'assets/sounds/class_alarm.mp3',
      loopAudio: true,
      vibrate: true,
      volumeSettings: const VolumeSettings(
        volume: 1.0,
        volumeEnforced: true,
      ),
      notificationSettings:
          NotificationSettings(
        title: '🔔 ${classModel.name}',
        body: _body(classModel),
        stopButton: 'STOP',
      ),
      androidFullScreenIntent: true,
      androidStopAlarmOnTermination: false,
      warningNotificationOnKill: true,
    );

    await Alarm.set(
      alarmSettings: nextAlarm,
    );
  }

  // ============================================================
  // CANCEL
  // ============================================================

  Future<void> cancel(
    ClassModel classModel,
  ) async {
    await init();

    _classes.remove(
      classModel.notificationId,
    );

    await Alarm.stop(
      classModel.notificationId,
    );
  }

  Future<void> cancelById(int id) async {
    await init();

    _classes.remove(id);

    await Alarm.stop(id);
  }

  Future<void> stopAll() async {
    await init();

    _classes.clear();

    await Alarm.stopAll();
  }

  // ============================================================
  // RESTORE RECURRING CLASSES
  // ============================================================

  Future<void> restoreClasses(
    List<ClassModel> classes,
  ) async {
    await init();

    for (final ClassModel classModel in classes) {
      await schedule(classModel);
    }
  }

  // ============================================================
  // BODY
  // ============================================================

  String _body(ClassModel classModel) {
    if (classModel.location.isEmpty) {
      return 'Your class is starting soon.';
    }

    return 'Your class is starting soon • '
        '${classModel.location}';
  }
}
