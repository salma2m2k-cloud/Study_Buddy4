import 'package:alarm/alarm.dart';

import '../models/class_model.dart';

class ClassAlarmService {
  ClassAlarmService._();

  static final ClassAlarmService instance = ClassAlarmService._();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    await Alarm.init();
    _initialized = true;
  }

  Future<void> schedule(ClassModel classModel) async {
    await init();

    final DateTime now = DateTime.now();

    final DateTime nextClassStart =
        classModel.nextOccurrenceStart(now);

    DateTime alarmTime = nextClassStart.subtract(
      Duration(minutes: classModel.reminderLeadMinutes),
    );

    // If today's alarm time has already passed, use next week's occurrence.
    if (!alarmTime.isAfter(now)) {
      alarmTime = alarmTime.add(const Duration(days: 7));
    }

    // Use the same stable ID every time so editing a class
    // replaces the old alarm instead of creating duplicates.
    final int alarmId = classModel.notificationId;

    // Remove an existing alarm with this ID first.
    await Alarm.stop(alarmId);

    final AlarmSettings settings = AlarmSettings(
      id: alarmId,
      dateTime: alarmTime,
      assetAudioPath: 'assets/sounds/class_alarm.mp3',
      loopAudio: true,
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
      androidFullScreenIntent: true,
      warningNotificationOnKill: true,
    );

    await Alarm.set(alarmSettings: settings);
  }

  Future<void> cancel(ClassModel classModel) async {
    await init();
    await Alarm.stop(classModel.notificationId);
  }

  Future<void> cancelById(int id) async {
    await init();
    await Alarm.stop(id);
  }

  Future<void> stopAll() async {
    await init();
    await Alarm.stopAll();
  }

  String _body(ClassModel classModel) {
    if (classModel.location.isEmpty) {
      return 'Your class is starting soon.';
    }

    return 'Your class is starting soon • ${classModel.location}';
  }
}
