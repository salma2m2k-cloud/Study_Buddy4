import '../utils/weekday.dart';

/// A recurring weekly class (spec #10-11). This describes the recurring
/// pattern only — individual occurrence completion lives in
/// [ClassCompletion] records, kept separate on purpose (spec #15).
class ClassModel {
  final String id;
  String name;
  String subject;
  String teacher;
  Weekday weekday;

  /// Minutes since midnight, local time, e.g. 9:00 AM = 540.
  int startMinutes;
  int endMinutes;

  String location;
  String notes;

  bool reminderEnabled;
  int reminderLeadMinutes;

  final DateTime createdAt;
  DateTime updatedAt;

  ClassModel({
    required this.id,
    required this.name,
    this.subject = '',
    this.teacher = '',
    required this.weekday,
    required this.startMinutes,
    required this.endMinutes,
    this.location = '',
    this.notes = '',
    this.reminderEnabled = true,
    this.reminderLeadMinutes = 15,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  int get startHour => startMinutes ~/ 60;
  int get startMinute => startMinutes % 60;
  int get endHour => endMinutes ~/ 60;
  int get endMinute => endMinutes % 60;

  /// Stable notification id derived from the class id (spec #17: no dupes).
  int get notificationId => id.hashCode & 0x7fffffff;

  /// Given "today", find the DateTime of the class's start time on the
  /// NEXT occurrence of [weekday] — including today if the class hasn't
  /// started yet today, otherwise 7 days from now at the latest.
  DateTime nextOccurrenceStart(DateTime from) {
    final DateTime candidateToday =
        DateTime(from.year, from.month, from.day, startHour, startMinute);
    final int fromWeekdayIdx = Weekday.fromDateTimeWeekday(from.weekday).index;
    int deltaDays = weekday.index - fromWeekdayIdx;
    if (deltaDays < 0) deltaDays += 7;
    if (deltaDays == 0 && candidateToday.isBefore(from)) {
      deltaDays = 7;
    }
    return DateTime(from.year, from.month, from.day, startHour, startMinute)
        .add(Duration(days: deltaDays));
  }

  ClassModel copyWith({
    String? name,
    String? subject,
    String? teacher,
    Weekday? weekday,
    int? startMinutes,
    int? endMinutes,
    String? location,
    String? notes,
    bool? reminderEnabled,
    int? reminderLeadMinutes,
  }) {
    return ClassModel(
      id: id,
      name: name ?? this.name,
      subject: subject ?? this.subject,
      teacher: teacher ?? this.teacher,
      weekday: weekday ?? this.weekday,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderLeadMinutes: reminderLeadMinutes ?? this.reminderLeadMinutes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'subject': subject,
        'teacher': teacher,
        'weekday': weekday.storageIndex,
        'startMinutes': startMinutes,
        'endMinutes': endMinutes,
        'location': location,
        'notes': notes,
        'reminderEnabled': reminderEnabled,
        'reminderLeadMinutes': reminderLeadMinutes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ClassModel.fromJson(Map<String, dynamic> json) {
    try {
      return ClassModel(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? 'Untitled class',
        subject: (json['subject'] as String?) ?? '',
        teacher: (json['teacher'] as String?) ?? '',
        weekday: Weekday.fromStorageIndex((json['weekday'] as int?) ?? 1),
        startMinutes: (json['startMinutes'] as int?) ?? 9 * 60,
        endMinutes: (json['endMinutes'] as int?) ?? 10 * 60,
        location: (json['location'] as String?) ?? '',
        notes: (json['notes'] as String?) ?? '',
        reminderEnabled: (json['reminderEnabled'] as bool?) ?? true,
        reminderLeadMinutes: (json['reminderLeadMinutes'] as int?) ?? 15,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt']) ?? DateTime.now()
            : DateTime.now(),
      );
    } catch (_) {
      return ClassModel(
        id: (json['id'] as String?) ?? DateTime.now().toIso8601String(),
        name: 'Recovered class',
        weekday: Weekday.monday,
        startMinutes: 9 * 60,
        endMinutes: 10 * 60,
      );
    }
  }
}
