import 'package:alarm/alarm.dart';

import '../models/class_model.dart';

class ClassAlarmService {
  ClassAlarmService._();

  static final ClassAlarmService instance =
      ClassAlarmService._();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    await Alarm.init();

    _initialized = true;
  }

  // ============================================================
  // SCHEDULE NEXT WEEKLY OCCURRENCE
  // ============================================================

  Future<void> schedule(
    ClassModel classModel,
  ) async {
    await init();

    final DateTime now = DateTime.now();

    final DateTime nextClassStart =
        classModel.nextOccurrenceStart(now);

    DateTime alarmTime =
        nextClassStart.subtract(
      Duration(
        minutes: classModel.reminderLeadMinutes,
      ),
    );

    // If this week's reminder has already passed,
    // move to the next week's occurrence.
    while (!alarmTime.isAfter(now)) {
      alarmTime = alarmTime.add(
        const Duration(days: 7),
      );
    }

    final int alarmId =
        classModel.notificationId;

    // Replace any existing alarm for this class.
    await Alarm.stop(alarmId);

    final AlarmSettings settings =
        AlarmSettings(
      id: alarmId,
      dateTime: alarmTime,

      // Bundled with the APK.
      assetAudioPath:
          'assets/sounds/class_alarm.mp3',

      // 🔊 Repeat indefinitely until STOP.
      loopAudio: true,

      // 📳 Repeat vibration until STOP.
      vibrate: true,

      // Full alarm volume.
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

      // Keep the alarm alive if the Flutter
      // application process is terminated.
      androidStopAlarmOnTermination: false,

      warningNotificationOnKill: true,
    );

    await Alarm.set(
      alarmSettings: settings,
    );
  }

  // ============================================================
  // RESTORE ALL RECURRING CLASSES
  // ============================================================

  Future<void> restoreClasses(
    List<ClassModel> classes,
  ) async {
    await init();

    for (final ClassModel classModel in classes) {
      try {
        await schedule(classModel);
      } catch (_) {
        // One broken alarm must not prevent
        // the remaining classes from being restored.
      }
    }
  }

  // ============================================================
  // CANCEL
  // ============================================================

  Future<void> cancel(
    ClassModel classModel,
  ) async {
    await init();

    await Alarm.stop(
      classModel.notificationId,
    );
  }

  Future<void> cancelById(int id) async {
    await init();

    await Alarm.stop(id);
  }

  Future<void> stopAll() async {
    await init();

    await Alarm.stopAll();
  }

  // ============================================================
  // NOTIFICATION BODY
  // ============================================================

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
