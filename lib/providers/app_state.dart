import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/task.dart';
import '../models/class_model.dart';
import '../models/class_completion.dart';
import '../models/study_session.dart';
import '../models/note.dart';
import '../models/app_settings.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/class_alarm_service.dart';
import '../utils/date_utils.dart';
import '../utils/weekday.dart';

class AppState extends ChangeNotifier {
  final StorageService storage;
  final NotificationService notifications;

  final ClassAlarmService classAlarms =
      ClassAlarmService.instance;

  final Uuid _uuid = const Uuid();

  AppState({
    required this.storage,
    required this.notifications,
  });

  bool isLoading = true;

  List<Task> tasks = [];
  List<ClassModel> classes = [];
  List<ClassCompletion> classCompletions = [];
  List<StudySession> studySessions = [];
  List<Note> notes = [];

  AppSettings settings = AppSettings();

  // ============================================================
  // BOOTSTRAP
  // ============================================================

  Future<void> bootstrap() async {
    try {
      debugPrint('BOOT 1: storage.init');
      await storage.init();

      debugPrint('BOOT 2: notifications.init');
      await notifications.init();

      debugPrint('BOOT 2.5: class alarms.init');
      await classAlarms.init();

      debugPrint('BOOT 3: load tasks');
      tasks = await storage.loadTasks();

      debugPrint('BOOT 4: load classes');
      classes = await storage.loadClasses();

      debugPrint('BOOT 5: load completions');
      classCompletions =
          await storage.loadClassCompletions();

      debugPrint('BOOT 6: load study sessions');
      studySessions =
          await storage.loadStudySessions();

      debugPrint('BOOT 7: load notes');
      notes = await storage.loadNotes();

      debugPrint('BOOT 8: load settings');
      settings = await storage.loadSettings();

      // Restore the original notification system.
      // IMPORTANT: classes MUST be passed here.
      debugPrint(
        'BOOT 9: restore task + class notifications',
      );

      await notifications.restoreAll(
        tasks: tasks,
        classes: classes,
      );

      // Restore the full class alarms.
      debugPrint(
        'BOOT 9.5: restore recurring class alarms',
      );

      await classAlarms.restoreClasses(classes);

      debugPrint('BOOT 10: COMPLETE');
    } catch (e, st) {
      debugPrint('BOOT FAILED: $e');
      debugPrint('$st');
    }

    isLoading = false;
    notifyListeners();
  }

  // ============================================================
  // TASKS
  // ============================================================

  Future<void> addTask({
    required String title,
    String description = '',
    required DateTime dueAt,
    bool reminderEnabled = true,
    int? reminderLeadMinutes,
  }) async {
    final Task task = Task(
      id: _uuid.v4(),
      title: title.trim().isEmpty
          ? 'Untitled task'
          : title.trim(),
      description: description,
      dueAt: dueAt,
      reminderEnabled: reminderEnabled,
      reminderLeadMinutes:
          reminderLeadMinutes ??
              settings.defaultReminderLeadMinutes,
    );

    tasks = [
      ...tasks,
      task,
    ];

    await storage.saveTasks(tasks);

    unawaited(
      _safeScheduleTaskReminder(task),
    );

    notifyListeners();
  }

  Future<void> updateTask(
    String id,
    Task Function(Task) update,
  ) async {
    final int idx =
        tasks.indexWhere((t) => t.id == id);

    if (idx == -1) return;

    final Task oldTask = tasks[idx];
    final Task updated = update(oldTask);

    tasks = [
      ...tasks,
    ]..[idx] = updated;

    await storage.saveTasks(tasks);

    unawaited(
      _replaceTaskReminder(
        oldTask,
        updated,
      ),
    );

    notifyListeners();
  }

  Future<void> _replaceTaskReminder(
    Task oldTask,
    Task updatedTask,
  ) async {
    try {
      await notifications.cancelTaskReminder(
        oldTask,
      );

      await notifications.scheduleTaskReminder(
        updatedTask,
      );
    } catch (e, st) {
      debugPrint(
        'Task reminder replacement failed: $e',
      );
      debugPrint('$st');
    }
  }

  Future<void> toggleTaskCompleted(
    String id,
  ) async {
    final int idx =
        tasks.indexWhere((t) => t.id == id);

    if (idx == -1) return;

    final Task updated = tasks[idx].copyWith(
      isCompleted:
          !tasks[idx].isCompleted,
    );

    tasks = [
      ...tasks,
    ]..[idx] = updated;

    await storage.saveTasks(tasks);

    if (updated.isCompleted) {
      unawaited(
        notifications.cancelTaskReminder(
          updated,
        ),
      );
    } else {
      unawaited(
        _safeScheduleTaskReminder(
          updated,
        ),
      );
    }

    notifyListeners();
  }

  Future<void> deleteTask(
    String id,
  ) async {
    final Task? task = tasks
        .where((t) => t.id == id)
        .firstOrNull;

    if (task == null) return;

    tasks = tasks
        .where((t) => t.id != id)
        .toList();

    await storage.saveTasks(tasks);

    unawaited(
      notifications.cancelTaskReminder(
        task,
      ),
    );

    notifyListeners();
  }

  Future<void> _safeScheduleTaskReminder(
    Task task,
  ) async {
    try {
      await notifications.scheduleTaskReminder(
        task,
      );
    } catch (e, st) {
      debugPrint(
        'Task reminder failed: $e',
      );
      debugPrint('$st');
    }
  }

  // ============================================================
  // TASK GETTERS
  // ============================================================

  List<Task> get relevantTasksToday {
    final DateTime now =
        DateTime.now();

    return tasks.where((task) {
      final DateTime? dueAt =
          task.dueAt;

      if (dueAt == null) {
        return false;
      }

      return AppDateUtils.isSameDay(
        dueAt,
        now,
      );
    }).toList();
  }

  List<Task> get todayTasks {
    return relevantTasksToday;
  }

  List<Task> get upcomingTasks {
    final DateTime now =
        DateTime.now();

    final List<Task> result =
        tasks.where((task) {
      final DateTime? dueAt =
          task.dueAt;

      if (dueAt == null) {
        return false;
      }

      if (task.isCompleted) {
        return false;
      }

      return dueAt.isAfter(now);
    }).toList();

    result.sort(
      (a, b) =>
          a.dueAt!.compareTo(
        b.dueAt!,
      ),
    );

    return result;
  }

  List<Task> get overdueTasks {
    final DateTime now =
        DateTime.now();

    final List<Task> result =
        tasks.where((task) {
      final DateTime? dueAt =
          task.dueAt;

      if (dueAt == null) {
        return false;
      }

      if (task.isCompleted) {
        return false;
      }

      return dueAt.isBefore(now);
    }).toList();

    result.sort(
      (a, b) =>
          a.dueAt!.compareTo(
        b.dueAt!,
      ),
    );

    return result;
  }

  // ============================================================
  // CLASSES
  // ============================================================

  Future<ClassModel> addClass({
    required String name,
    String subject = '',
    String teacher = '',
    required Weekday weekday,
    required int startMinutes,
    required int endMinutes,
    String location = '',
    String notes = '',
    bool reminderEnabled = true,
    int? reminderLeadMinutes,
  }) async {
    final ClassModel classModel =
        ClassModel(
      id: _uuid.v4(),
      name: name.trim().isEmpty
          ? 'Untitled class'
          : name.trim(),
      subject: subject,
      teacher: teacher,
      weekday: weekday,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      location: location,
      notes: notes,
      reminderEnabled:
          reminderEnabled,
      reminderLeadMinutes:
          reminderLeadMinutes ??
              settings
                  .defaultReminderLeadMinutes,
    );

    classes = [
      ...classes,
      classModel,
    ];

    await storage.saveClasses(
      classes,
    );

    // Original working notification.
    unawaited(
      _safeScheduleClassNotification(
        classModel,
      ),
    );

    // New looping alarm.
    unawaited(
      _safeScheduleClassAlarm(
        classModel,
      ),
    );

    notifyListeners();

    return classModel;
  }

  Future<void> updateClass(
    String id,
    ClassModel Function(ClassModel) update,
  ) async {
    final int idx =
        classes.indexWhere(
      (c) => c.id == id,
    );

    if (idx == -1) return;

    final ClassModel oldClass =
        classes[idx];

    final ClassModel updated =
        update(oldClass);

    classes = [
      ...classes,
    ]..[idx] = updated;

    await storage.saveClasses(
      classes,
    );

    unawaited(
      _replaceClassReminders(
        oldClass,
        updated,
      ),
    );

    notifyListeners();
  }

  Future<void> _replaceClassReminders(
    ClassModel oldClass,
    ClassModel updatedClass,
  ) async {
    try {
      // Remove old notification.
      await notifications.cancelClassAlarm(
        oldClass,
      );

      // Remove old looping alarms.
      await classAlarms.cancel(
        oldClass,
      );

      // Schedule updated notification.
      await notifications.scheduleClassAlarm(
        updatedClass,
      );

      // Schedule updated looping alarms.
      await classAlarms.schedule(
        updatedClass,
      );
    } catch (e, st) {
      debugPrint(
        'Class reminder replacement failed: $e',
      );
      debugPrint('$st');
    }
  }

  Future<void> deleteClass(
    String id,
  ) async {
    final ClassModel? classModel =
        classes
            .where((c) => c.id == id)
            .firstOrNull;

    if (classModel == null) {
      return;
    }

    classes = classes
        .where((c) => c.id != id)
        .toList();

    await storage.saveClasses(
      classes,
    );

    unawaited(
      _safeCancelClassReminders(
        classModel,
      ),
    );

    notifyListeners();
  }

  Future<void> _safeScheduleClassNotification(
    ClassModel classModel,
  ) async {
    try {
      await notifications.scheduleClassAlarm(
        classModel,
      );
    } catch (e, st) {
      debugPrint(
        'Class notification failed: $e',
      );
      debugPrint('$st');
    }
  }

  Future<void> _safeScheduleClassAlarm(
    ClassModel classModel,
  ) async {
    try {
      await classAlarms.schedule(
        classModel,
      );
    } catch (e, st) {
      debugPrint(
        'Class alarm failed: $e',
      );
      debugPrint('$st');
    }
  }

  Future<void> _safeCancelClassReminders(
    ClassModel classModel,
  ) async {
    try {
      await notifications.cancelClassAlarm(
        classModel,
      );

      await classAlarms.cancel(
        classModel,
      );
    } catch (e, st) {
      debugPrint(
        'Class reminder cancellation failed: $e',
      );
      debugPrint('$st');
    }
  }

  // ============================================================
  // CLASS GETTERS
  // ============================================================

  List<ClassModel> classesFor(
    Weekday weekday,
  ) {
    final List<ClassModel> result =
        classes
            .where(
              (c) => c.weekday == weekday,
            )
            .toList();

    result.sort(
      (a, b) =>
          a.startMinutes.compareTo(
        b.startMinutes,
      ),
    );

    return result;
  }

  List<ClassModel> get todayClasses {
    final Weekday today =
        Weekday.fromDateTimeWeekday(
      DateTime.now().weekday,
    );

    return classesFor(today);
  }

  ClassModel? get nextUpcomingClass {
    if (classes.isEmpty) {
      return null;
    }

    final DateTime now =
        DateTime.now();

    ClassModel? result;
    DateTime? resultTime;

    for (final ClassModel classModel
        in classes) {
      final DateTime occurrence =
          classModel
              .nextOccurrenceStart(now);

      if (resultTime == null ||
          occurrence.isBefore(
            resultTime,
          )) {
        result = classModel;
        resultTime = occurrence;
      }
    }

    return result;
  }

  // ============================================================
  // CLASS COMPLETIONS
  // ============================================================

  bool isClassOccurrenceCompleted(
    String classId,
    DateTime occurrenceDate,
  ) {
    return classCompletions.any(
      (completion) =>
          completion.classId ==
              classId &&
          AppDateUtils.isSameDay(
            completion.date,
            occurrenceDate,
          ),
    );
  }

  Future<void>
      toggleClassOccurrenceCompleted(
    String classId,
    DateTime occurrenceDate,
  ) async {
    final bool alreadyCompleted =
        isClassOccurrenceCompleted(
      classId,
      occurrenceDate,
    );

    if (alreadyCompleted) {
      classCompletions =
          classCompletions
              .where(
                (completion) =>
                    !(
                      completion.classId ==
                          classId &&
                      AppDateUtils.isSameDay(
                        completion.date,
                        occurrenceDate,
                      )
                    ),
              )
              .toList();
    } else {
      classCompletions = [
        ...classCompletions,
        ClassCompletion(
          classId: classId,
          date: DateTime(
            occurrenceDate.year,
            occurrenceDate.month,
            occurrenceDate.day,
          ),
        ),
      ];
    }

    await storage.saveClassCompletions(
      classCompletions,
    );

    notifyListeners();
  }

  // ============================================================
  // STUDY SESSIONS
  // ============================================================

  Future<void> addStudySession({
    required DateTime startedAt,
    required DateTime endedAt,
    String subject = '',
    String note = '',
  }) async {
    final StudySession session =
        StudySession(
      id: _uuid.v4(),
      subject: subject,
      startTime: startedAt,
      endTime: endedAt,
      notes: note,
    );

    studySessions = [
      ...studySessions,
      session,
    ];

    await storage.saveStudySessions(
      studySessions,
    );

    notifyListeners();
  }

  Future<void> deleteStudySession(
    String id,
  ) async {
    studySessions =
        studySessions
            .where(
              (session) =>
                  session.id != id,
            )
            .toList();

    await storage.saveStudySessions(
      studySessions,
    );

    notifyListeners();
  }

  Duration get studyTimeToday {
    final DateTime now =
        DateTime.now();

    return studySessions
        .where(
          (session) =>
              AppDateUtils.isSameDay(
            session.startTime,
            now,
          ),
        )
        .fold<Duration>(
      Duration.zero,
      (total, session) =>
          total + session.duration,
    );
  }

  Duration get studyTimeThisWeek {
    final DateTime weekStart =
        AppDateUtils.startOfWeek(
      DateTime.now(),
    );

    return studySessions
        .where(
          (session) =>
              !session.startTime.isBefore(
            weekStart,
          ),
        )
        .fold<Duration>(
      Duration.zero,
      (total, session) =>
          total + session.duration,
    );
  }

  // ============================================================
  // NOTES
  // ============================================================

  Future<void> addNote({
    required String title,
    required String content,
  }) async {
    final Note note = Note(
      id: _uuid.v4(),
      title: title.trim().isEmpty
          ? 'Untitled note'
          : title.trim(),
      content: content,
    );

    notes = [
      ...notes,
      note,
    ];

    await storage.saveNotes(
      notes,
    );

    notifyListeners();
  }

  Future<void> updateNote(
    String id,
    Note Function(Note) update,
  ) async {
    final int idx =
        notes.indexWhere(
      (n) => n.id == id,
    );

    if (idx == -1) return;

    final Note updated =
        update(notes[idx]);

    notes = [
      ...notes,
    ]..[idx] = updated;

    await storage.saveNotes(
      notes,
    );

    notifyListeners();
  }

  Future<void> deleteNote(
    String id,
  ) async {
    notes = notes
        .where((n) => n.id != id)
        .toList();

    await storage.saveNotes(
      notes,
    );

    notifyListeners();
  }

  // ============================================================
  // SETTINGS
  // ============================================================

  Future<void> updateSettings(
    AppSettings Function(AppSettings) update,
  ) async {
    settings = update(settings);

    await storage.saveSettings(
      settings,
    );

    notifyListeners();
  }

  // ============================================================
  // PROGRESS
  // ============================================================

  WeeklyTaskProgress get weeklyTaskProgress {
    final DateTime weekStart =
        AppDateUtils.startOfWeek(
      DateTime.now(),
    );

    final DateTime weekEnd =
        weekStart.add(
      const Duration(days: 7),
    );

    final List<Task> weekTasks =
        tasks.where((task) {
      final DateTime? dueAt =
          task.dueAt;

      if (dueAt == null) {
        return false;
      }

      return !dueAt.isBefore(
            weekStart,
          ) &&
          dueAt.isBefore(
            weekEnd,
          );
    }).toList();

    return WeeklyTaskProgress(
      tasksDone: weekTasks
          .where(
            (task) =>
                task.isCompleted,
          )
          .length,
      tasksTotal: weekTasks.length,
    );
  }

  WeeklyClassProgress
      get weeklyClassProgress {
    final DateTime weekStart =
        AppDateUtils.startOfWeek(
      DateTime.now(),
    );

    int total = 0;
    int done = 0;

    for (final ClassModel classModel
        in classes) {
      final DateTime occurrence =
          _occurrenceForWeek(
        classModel,
        weekStart,
      );

      total++;

      if (isClassOccurrenceCompleted(
        classModel.id,
        occurrence,
      )) {
        done++;
      }
    }

    return WeeklyClassProgress(
      classesDone: done,
      classesTotal: total,
    );
  }

  DateTime _occurrenceForWeek(
    ClassModel classModel,
    DateTime weekStart,
  ) {
    return weekStart.add(
      Duration(
        days: classModel.weekday.index,
        minutes: classModel.startMinutes,
      ),
    );
  }

  // ============================================================
  // MOTIVATION
  // ============================================================

  String get motivationalMessage {
    final int done =
        relevantTasksToday
            .where(
              (t) => t.isCompleted,
            )
            .length;

    final int total =
        relevantTasksToday.length;

    if (total == 0) {
      return 'Nothing due today. Enjoy the breathing room 🎉';
    }

    if (done == 0) {
      return 'Start small. You’ve got this.';
    }

    if (done >= total) {
      return 'Everything due today is done. Amazing work! 🎉';
    }

    if (done >= total / 2) {
      return 'You’re more than halfway there. Keep going!';
    }

    return 'Nice and steady wins the day.';
  }

  // ============================================================
  // CLEAR ALL DATA
  // ============================================================

  Future<void> clearAllData() async {
    for (final Task task in tasks) {
      await notifications.cancelTaskReminder(
        task,
      );
    }

    for (final ClassModel classModel
        in classes) {
      await notifications.cancelClassAlarm(
        classModel,
      );

      await classAlarms.cancel(
        classModel,
      );
    }

    tasks = [];
    classes = [];
    classCompletions = [];
    studySessions = [];
    notes = [];

    await storage.clearAllData();

    notifyListeners();
  }
}

// ================================================================
// PROGRESS MODELS
// ================================================================

class WeeklyTaskProgress {
  final int tasksDone;
  final int tasksTotal;

  const WeeklyTaskProgress({
    required this.tasksDone,
    required this.tasksTotal,
  });
}

class WeeklyClassProgress {
  final int classesDone;
  final int classesTotal;

  const WeeklyClassProgress({
    required this.classesDone,
    required this.classesTotal,
  });
}

// ================================================================
// firstOrNull
// ================================================================

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull =>
      isEmpty ? null : first;
}
