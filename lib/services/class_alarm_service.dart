import 'package:alarm/alarm.dart';

import '../models/class_model.dart';

class ClassAlarmService {
  ClassAlarmService._();

  static final ClassAlarmService instance =
      ClassAlarmService._();

  bool _initialized = false;

  // Schedule 52 future weekly occurrences.
  static const int _weeksToSchedule = 52;

  Future<void> init() async {
    if (_initialized) return;

    await Alarm.init();

    _initialized = true;
  }

  Future<void> schedule(
    ClassModel classModel,
  ) async {
    await init();

    // Remove any old alarms for this class first.
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

        final AlarmSettings settings =
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

        await Alarm.set(
          alarmSettings: settings,
        );
      }

      occurrence = occurrence.add(
        const Duration(days: 7),
      );
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
        // Do not let one failed class stop
        // the remaining classes from being restored.
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

      occurrence = occurrence.add(
        const Duration(days: 7),
      );
    }
  }

  Future<void> cancelById(int id) async {
    await init();

    // Kept for compatibility.
    //
    // AppState normally uses cancel(ClassModel), because
    // the class date is needed to calculate occurrence IDs.
    try {
      await Alarm.stop(id);
    } catch (_) {
      // Ignore missing alarms.
    }
  }

  Future<void> stopAll() async {
    await init();

    await Alarm.stopAll();
  }

  int _occurrenceAlarmId(
    int baseId,
    DateTime occurrence,
  ) {
    final int datePart =
        occurrence.year * 10000 +
        occurrence.month * 100 +
        occurrence.day;

    // Keep the ID positive and inside Android's int range.
    final int value =
        ((baseId.abs() % 100000) * 100000) +
        (datePart % 100000);

    return value == 0 ? 1 : value;
  }

  String _body(
    ClassModel classModel,
  ) {
    if (classModel.location.isEmpty) {
      return 'Your class is starting soon.';
    }

    return 'Your class is starting soon • '
        '${classModel.location}';
  }
}
