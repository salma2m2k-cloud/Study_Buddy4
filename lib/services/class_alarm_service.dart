import 'package:alarm/alarm.dart';

import '../models/class_model.dart';

class ClassAlarmService {
  ClassAlarmService._();

  static final ClassAlarmService instance =
      ClassAlarmService._();

  bool _initialized = false;

  // The alarm package does not provide native weekly recurrence.
  // We therefore schedule a rolling set of future occurrences.
  // They are refreshed whenever the app starts.
  static const int _weeksToSchedule = 52;

  Future<void> init() async {
    if (_initialized) return;

    await Alarm.init();

    _initialized = true;
  }

  Future<void> schedule(ClassModel classModel) async {
    await init();

    // If reminders are disabled, make sure old alarms are removed.
    if (!classModel.reminderEnabled) {
      await cancel(classModel);
      return;
    }

    // Remove previously scheduled occurrences for this class first.
    await cancel(classModel);

    final DateTime now = DateTime.now();

    DateTime occurrence =
        classModel.nextOccurrenceStart(now);

    for (int week = 0;
        week < _weeksToSchedule;
        week++) {
      final DateTime alarmTime =
          occurrence.subtract(
        Duration(
          minutes: classModel.reminderLeadMinutes,
        ),
      );

      if (alarmTime.isAfter(now)) {
        final int alarmId =
            _occurrenceAlarmId(
          classModel.notificationId,
          occurrence,
        );

        final AlarmSettings alarmSettings =
            AlarmSettings(
          id: alarmId,
          dateTime: alarmTime,
          assetAudioPath:
              'assets/sounds/class_alarm.mp3',
          loopAudio: true,
          vibrate: true,
          volumeSettings:
              const VolumeSettings.fixed(
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

        try {
          await Alarm.set(
            alarmSettings: alarmSettings,
          );
        } catch (_) {
          // One failed occurrence must not prevent
          // the remaining occurrences from being scheduled.
        }
      }

      occurrence =
          occurrence.add(const Duration(days: 7));
    }
  }

  Future<void> restoreClasses(
    List<ClassModel> classes,
  ) async {
    await init();

    for (final ClassModel classModel in classes) {
      try {
        await schedule(classModel);
      } catch (_) {
        // Keep restoring the other classes.
      }
    }
  }

  Future<void> cancel(
    ClassModel classModel,
  ) async {
    await init();

    final DateTime now = DateTime.now();

    DateTime occurrence =
        classModel.nextOccurrenceStart(now);

    for (int week = 0;
        week < _weeksToSchedule;
        week++) {
      final int alarmId =
          _occurrenceAlarmId(
        classModel.notificationId,
        occurrence,
      );

      try {
        await Alarm.stop(alarmId);
      } catch (_) {
        // Ignore alarms that do not exist.
      }

      occurrence =
          occurrence.add(const Duration(days: 7));
    }
  }

  Future<void> stopAll() async {
    await init();

    try {
      await Alarm.stopAll();
    } catch (_) {
      // Nothing to stop.
    }
  }

  int _occurrenceAlarmId(
    int baseId,
    DateTime occurrence,
  ) {
    final int datePart =
        occurrence.year * 10000 +
        occurrence.month * 100 +
        occurrence.day;

    final int value =
        ((baseId.abs() % 100000) * 100000) +
        (datePart % 100000);

    return value == 0 ? 1 : value;
  }

  String _body(ClassModel classModel) {
    if (classModel.location.trim().isEmpty) {
      return 'Your class is starting soon.';
    }

    return 'Your class is starting soon • '
        '${classModel.location.trim()}';
  }
}
