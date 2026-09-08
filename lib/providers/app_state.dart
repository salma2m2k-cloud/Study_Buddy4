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
import '../utils/date_utils.dart';
import '../utils/weekday.dart';

class AppState extends ChangeNotifier {
  final StorageService storage;
  final NotificationService notifications;
  final Uuid _uuid = const Uuid();

  AppState({required this.storage, required this.notifications});

  bool isLoading = true;

  List<Task> tasks = [];
  List<ClassModel> classes = [];
  List<ClassCompletion> classCompletions = [];
  List<StudySession> studySessions = [];
  List<Note> notes = [];
  AppSettings settings = AppSettings();

  /// Runs once at app startup.
  Future<void> bootstrap() async {
    try {
      debugPrint('BOOT 1: storage.init');
      await storage.init();

      debugPrint('BOOT 2: notifications.init');
      await notifications.init();

      debugPrint('BOOT 3: load tasks');
      tasks = await storage.loadTasks();

      debugPrint('BOOT 4: load classes');
      classes = await storage.loadClasses();

      debugPrint('BOOT 5: load completions');
      classCompletions = await storage.loadClassCompletions();

      debugPrint('BOOT 6: load study sessions');
      studySessions = await storage.loadStudySessions();

      debugPrint('BOOT 7: load notes');
      notes = await storage.loadNotes();

      debugPrint('BOOT 8: load settings');
      settings = await storage.loadSettings();

      debugPrint('BOOT 9: restore notifications');
      await notifications.restoreAll(
        tasks: tasks,
        classes: classes,
      );

      debugPrint('BOOT 10: COMPLETE');
    } catch (e, st) {
      debugPrint('BOOT FAILED: $e');
      debugPrint('$st');
    }

    isLoading = false;
    notifyListeners();
  }

  // ==================== TASKS ====================

  Future<Task> addTask({
    required String title,
    String description = '',
    DateTime? dueAt,
    bool reminderEnabled = false,
    int? reminderLeadMinutes,
  }) async {
    final Task task = Task(
      id: _uuid.v4(),
      title: title.trim().isEmpty ? 'Untitled task' : title.trim(),
      description: description,
      dueAt: dueAt,
      reminderEnabled: reminderEnabled,
      reminderLeadMinutes:
          reminderLeadMinutes ?? settings.defaultReminderLeadMinutes,
    );

    tasks = [...tasks, task];

    await storage.saveTasks(tasks);
    await notifications.scheduleTaskReminder(task);

    notifyListeners();

    return task;
  }

  Future<void> updateTask(
    String id,
    Task Function(Task) update,
  ) async {
    final int idx = tasks.indexWhere((t) => t.id == id);

    if (idx == -1) return;

    final Task updated = update(tasks[idx]);

    tasks = [...tasks]..[idx] = updated;

    await storage.saveTasks(tasks);

    await notifications.scheduleTaskReminder(updated);

    notifyListeners();
  }

  Future<void> toggleTaskCompleted(String id) async {
    final int idx = tasks.indexWhere((t) => t.id == id);

    if (idx == -1) return;

    final Task current = tasks[idx];

    final Task updated = current.isCompleted
        ? current.copyWith(
            isCompleted: false,
            clearCompletedAt: true,
          )
        : current.copyWith(
            isCompleted: true,
            completedAt: DateTime.now(),
          );

    tasks = [...tasks]..[idx] = updated;

    await storage.saveTasks(tasks);

    if (updated.isCompleted) {
      await notifications.cancelTaskReminder(updated);
    } else {
      await notifications.scheduleTaskReminder(updated);
    }

    notifyListeners();
  }

  Future<void> deleteTask(String id) async {
    final Task? task = tasks
        .where((t) => t.id == id)
        .cast<Task?>()
        .firstOrNull;

    tasks = tasks.where((t) => t.id != id).toList();

    await storage.saveTasks(tasks);

    if (task != null) {
      await notifications.cancelTaskReminder(task);
    }

    notifyListeners();
  }

  List<Task> get todayTasks {
    final DateTime now = DateTime.now();

    return tasks
        .where(
          (t) =>
              t.dueAt != null &&
              AppDateUtils.isSameDay(t.dueAt!, now),
        )
        .toList()
      ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
  }

  List<Task> get upcomingTasks {
    final DateTime now = DateTime.now();

    return tasks
        .where(
          (t) =>
              !t.isCompleted &&
              t.dueAt != null &&
              t.dueAt!.isAfter(now),
        )
        .toList()
      ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
  }

  List<Task> get overdueTasks {
    return tasks.where((t) => t.isOverdue).toList()
      ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
  }

  // ==================== CLASSES ====================

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
    final ClassModel classModel = ClassModel(
      id: _uuid.v4(),
      name: name.trim().isEmpty ? 'Untitled class' : name.trim(),
      subject: subject,
      teacher: teacher,
      weekday: weekday,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      location: location,
      notes: notes,
      reminderEnabled: reminderEnabled,
      reminderLeadMinutes:
          reminderLeadMinutes ?? settings.defaultReminderLeadMinutes,
    );

    classes = [...classes, classModel];

    await storage.saveClasses(classes);
    await notifications.scheduleClassAlarm(classModel);

    notifyListeners();

    return classModel;
  }

  Future<void> updateClass(
    String id,
    ClassModel Function(ClassModel) update,
  ) async {
    final int idx = classes.indexWhere((c) => c.id == id);

    if (idx == -1) return;

    final ClassModel updated = update(classes[idx]);

    classes = [...classes]..[idx] = updated;

    await storage.saveClasses(classes);

    await notifications.scheduleClassAlarm(updated);

    notifyListeners();
  }

  Future<void> deleteClass(String id) async {
    final ClassModel? classModel = classes
        .where((c) => c.id == id)
        .cast<ClassModel?>()
        .firstOrNull;

    classes = classes.where((c) => c.id != id).toList();

    await storage.saveClasses(classes);

    if (classModel != null) {
      await notifications.cancelClassAlarm(classModel);
    }

    notifyListeners();
  }

  List<ClassModel> classesFor(Weekday weekday) {
    return classes.where((c) => c.weekday == weekday).toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
  }

  List<ClassModel> get todayClasses {
    return classesFor(
      Weekday.fromDateTimeWeekday(DateTime.now().weekday),
    );
  }

  ClassModel? get nextUpcomingClass {
    if (classes.isEmpty) return null;

    final DateTime now = DateTime.now();

    ClassModel? best;
    DateTime? bestTime;

    for (final ClassModel c in classes) {
      final DateTime occurrence = c.nextOccurrenceStart(now);

      if (bestTime == null || occurrence.isBefore(bestTime)) {
        best = c;
        bestTime = occurrence;
      }
    }

    return best;
  }

  bool isClassOccurrenceCompleted(
    String classId,
    DateTime date,
  ) {
    final String key =
        '$classId::${AppDateUtils.dateKey(AppDateUtils.dateOnly(date))}';

    return classCompletions.any(
      (c) => c.key == key && c.completed,
    );
  }

  Future<void> toggleClassOccurrenceCompleted(
    String classId,
    DateTime date,
  ) async {
    final DateTime day = AppDateUtils.dateOnly(date);

    final String key =
        '$classId::${AppDateUtils.dateKey(day)}';

    final int idx =
        classCompletions.indexWhere((c) => c.key == key);

    if (idx == -1) {
      classCompletions = [
        ...classCompletions,
        ClassCompletion(
          classId: classId,
          date: day,
          completed: true,
        ),
      ];
    } else {
      final ClassCompletion existing = classCompletions[idx];

      existing.completed = !existing.completed;

      existing.completedAt =
          existing.completed ? DateTime.now() : null;

      classCompletions = [...classCompletions];
    }

    await storage.saveClassCompletions(classCompletions);

    notifyListeners();
  }

  // ==================== STUDY SESSIONS ====================

  Future<StudySession> addStudySession({
    required String subject,
    required DateTime startTime,
    required DateTime endTime,
    String notes = '',
  }) async {
    final StudySession session = StudySession(
      id: _uuid.v4(),
      subject:
          subject.trim().isEmpty ? 'Study session' : subject.trim(),
      startTime: startTime,
      endTime: endTime,
      notes: notes,
    );

    studySessions = [...studySessions, session];

    await storage.saveStudySessions(studySessions);

    notifyListeners();

    return session;
  }

  Future<void> deleteStudySession(String id) async {
    studySessions =
        studySessions.where((s) => s.id != id).toList();

    await storage.saveStudySessions(studySessions);

    notifyListeners();
  }

  Duration get studyTimeToday {
    final DateTime now = DateTime.now();

    return studySessions
        .where(
          (s) => AppDateUtils.isSameDay(s.startTime, now),
        )
        .fold(
          Duration.zero,
          (sum, s) => sum + s.duration,
        );
  }

  Duration get studyTimeThisWeek {
    final DateTime now = DateTime.now();

    return studySessions
        .where(
          (s) => AppDateUtils.isInWeekOf(s.startTime, now),
        )
        .fold(
          Duration.zero,
          (sum, s) => sum + s.duration,
        );
  }

  // ==================== NOTES ====================

  Future<Note> addNote({
    required String title,
    String content = '',
  }) async {
    final Note note = Note(
      id: _uuid.v4(),
      title:
          title.trim().isEmpty ? 'Untitled note' : title.trim(),
      content: content,
    );

    notes = [note, ...notes];

    await storage.saveNotes(notes);

    notifyListeners();

    return note;
  }

  Future<void> updateNote(
    String id,
    Note Function(Note) update,
  ) async {
    final int idx = notes.indexWhere((n) => n.id == id);

    if (idx == -1) return;

    final Note updated = update(notes[idx]);

    updated.updatedAt = DateTime.now();

    notes = [...notes]..[idx] = updated;

    await storage.saveNotes(notes);

    notifyListeners();
  }

  Future<void> deleteNote(String id) async {
    notes = notes.where((n) => n.id != id).toList();

    await storage.saveNotes(notes);

    notifyListeners();
  }

  // ==================== DATA MANAGEMENT ====================

  Future<void> clearAllData() async {
    for (final Task t in tasks) {
      await notifications.cancelTaskReminder(t);
    }

    for (final ClassModel c in classes) {
      await notifications.cancelClassAlarm(c);
    }

    await storage.clearAllData();

    tasks = [];
    classes = [];
    classCompletions = [];
    studySessions = [];
    notes = [];

    notifyListeners();
  }

  // ==================== SETTINGS ====================

  Future<void> updateSettings(
    AppSettings Function(AppSettings) update,
  ) async {
    settings = update(settings);

    await storage.saveSettings(settings);

    notifyListeners();
  }

  // ==================== PROGRESS ====================

  List<Task> get relevantTasksToday {
    final DateTime now = DateTime.now();

    return tasks
        .where(
          (t) =>
              (t.dueAt != null &&
                  AppDateUtils.isSameDay(t.dueAt!, now)) ||
              t.isOverdue,
        )
        .toList();
  }

  double get todayTaskProgress {
    final List<Task> relevant = relevantTasksToday;

    if (relevant.isEmpty) return 0;

    final int done =
        relevant.where((t) => t.isCompleted).length;

    return done / relevant.length;
  }

  ({int tasksDone, int tasksTotal}) get weeklyTaskProgress {
    final DateTime now = DateTime.now();

    final List<Task> weekTasks = tasks
        .where(
          (t) =>
              t.dueAt != null &&
              AppDateUtils.isInWeekOf(t.dueAt!, now),
        )
        .toList();

    return (
      tasksDone: weekTasks.where((t) => t.isCompleted).length,
      tasksTotal: weekTasks.length,
    );
  }

  ({int classesDone, int classesTotal}) get weeklyClassProgress {
    final DateTime now = DateTime.now();

    final DateTime weekStart =
        AppDateUtils.startOfWeek(now);

    int total = 0;
    int done = 0;

    for (final ClassModel c in classes) {
      final DateTime occurrenceThisWeek =
          weekStart.add(Duration(days: c.weekday.index));

      final DateTime occurrenceDateTime = DateTime(
        occurrenceThisWeek.year,
        occurrenceThisWeek.month,
        occurrenceThisWeek.day,
        c.startHour,
        c.startMinute,
      );

      if (occurrenceDateTime.isAfter(now)) {
        continue;
      }

      total += 1;

      if (isClassOccurrenceCompleted(
        c.id,
        occurrenceThisWeek,
      )) {
        done += 1;
      }
    }

    return (
      classesDone: done,
      classesTotal: total,
    );
  }

  String get motivationalMessage {
    final List<String> messages = [
      'Small steps still count ✨',
      'One thing at a time.',
      "You've got this.",
      'Future you will thank you.',
      'Keep going — you\'re doing great.',
      'Nice and steady wins the day.',
    ];

    final int dayIndex =
        DateTime.now().day % messages.length;

    return messages[dayIndex];
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
