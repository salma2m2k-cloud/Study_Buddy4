import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';
import '../models/class_model.dart';
import '../models/class_completion.dart';
import '../models/study_session.dart';
import '../models/note.dart';
import '../models/app_settings.dart';

/// Local-first persistence layer.
///
/// Deliberately simple (spec #3, #42): everything is stored as JSON
/// under a handful of SharedPreferences keys. No backend, no cloud, no
/// database engine — this is reliable enough for a single-user, local
/// student app and survives app restarts and phone reboots because
/// SharedPreferences is backed by the platform's persistent storage.
class StorageService {
  static const String _kTasks = 'sb_tasks_v1';
  static const String _kClasses = 'sb_classes_v1';
  static const String _kClassCompletions = 'sb_class_completions_v1';
  static const String _kStudySessions = 'sb_study_sessions_v1';
  static const String _kNotes = 'sb_notes_v1';
  static const String _kSettings = 'sb_settings_v1';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get _p {
    final SharedPreferences? p = _prefs;
    if (p == null) {
      throw StateError('StorageService.init() must be called before use.');
    }
    return p;
  }

  List<Map<String, dynamic>> _readList(String key) {
    final String? raw = _p.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    } catch (_) {
      // Corrupt data must never crash startup (spec #37).
      return [];
    }
  }

  Future<void> _writeList(
      String key, List<Map<String, dynamic>> items) async {
    await _p.setString(key, jsonEncode(items));
  }

  // ---------------- Tasks ----------------

  Future<List<Task>> loadTasks() async =>
      _readList(_kTasks).map(Task.fromJson).toList();

  Future<void> saveTasks(List<Task> tasks) async =>
      _writeList(_kTasks, tasks.map((t) => t.toJson()).toList());

  // ---------------- Classes ----------------

  Future<List<ClassModel>> loadClasses() async =>
      _readList(_kClasses).map(ClassModel.fromJson).toList();

  Future<void> saveClasses(List<ClassModel> classes) async =>
      _writeList(_kClasses, classes.map((c) => c.toJson()).toList());

  // ---------------- Class completions ----------------

  Future<List<ClassCompletion>> loadClassCompletions() async =>
      _readList(_kClassCompletions).map(ClassCompletion.fromJson).toList();

  Future<void> saveClassCompletions(List<ClassCompletion> items) async =>
      _writeList(_kClassCompletions, items.map((c) => c.toJson()).toList());

  // ---------------- Study sessions ----------------

  Future<List<StudySession>> loadStudySessions() async =>
      _readList(_kStudySessions).map(StudySession.fromJson).toList();

  Future<void> saveStudySessions(List<StudySession> items) async =>
      _writeList(_kStudySessions, items.map((s) => s.toJson()).toList());

  // ---------------- Notes ----------------

  Future<List<Note>> loadNotes() async =>
      _readList(_kNotes).map(Note.fromJson).toList();

  Future<void> saveNotes(List<Note> notes) async =>
      _writeList(_kNotes, notes.map((n) => n.toJson()).toList());

  // ---------------- Settings ----------------

  Future<AppSettings> loadSettings() async {
    final String? raw = _p.getString(_kSettings);
    if (raw == null || raw.isEmpty) return AppSettings();
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map) return AppSettings();
      return AppSettings.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {
      return AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _p.setString(_kSettings, jsonEncode(settings.toJson()));
  }

  // ---------------- Danger zone ----------------

  /// Clears all locally stored app data. Callers must confirm with the
  /// user first (spec #30) — this service does not ask on its own.
  Future<void> clearAllData() async {
    await Future.wait([
      _p.remove(_kTasks),
      _p.remove(_kClasses),
      _p.remove(_kClassCompletions),
      _p.remove(_kStudySessions),
      _p.remove(_kNotes),
      // Settings are intentionally preserved across a data wipe — a
      // "clear my content" action shouldn't reset appearance/reminder
      // preferences too.
    ]);
  }
}
