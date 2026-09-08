class Task {
  final String id;
  String title;
  String description;

  /// Due date/time is stored as a single local DateTime, or null if the
  /// task has no specific due date/time.
  DateTime? dueAt;

  bool reminderEnabled;

  /// Minutes before [dueAt] that the reminder should fire.
  int reminderLeadMinutes;

  bool isCompleted;
  DateTime? completedAt;

  final DateTime createdAt;
  DateTime updatedAt;

  Task({
    required this.id,
    required this.title,
    this.description = '',
    this.dueAt,
    this.reminderEnabled = false,
    this.reminderLeadMinutes = 10,
    this.isCompleted = false,
    this.completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// The exact moment the reminder notification should fire.
  DateTime? get reminderTime {
    if (dueAt == null || !reminderEnabled) return null;
    return dueAt!.subtract(Duration(minutes: reminderLeadMinutes));
  }

  /// Stable notification id derived from the task id (spec #9: no dupes).
  int get notificationId => id.hashCode & 0x7fffffff;

  bool get isOverdue =>
      !isCompleted && dueAt != null && dueAt!.isBefore(DateTime.now());

  Task copyWith({
    String? title,
    String? description,
    DateTime? dueAt,
    bool clearDueAt = false,
    bool? reminderEnabled,
    int? reminderLeadMinutes,
    bool? isCompleted,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueAt: clearDueAt ? null : (dueAt ?? this.dueAt),
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderLeadMinutes: reminderLeadMinutes ?? this.reminderLeadMinutes,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt:
          clearCompletedAt ? null : (completedAt ?? this.completedAt),
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'dueAt': dueAt?.toIso8601String(),
        'reminderEnabled': reminderEnabled,
        'reminderLeadMinutes': reminderLeadMinutes,
        'isCompleted': isCompleted,
        'completedAt': completedAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Task.fromJson(Map<String, dynamic> json) {
    try {
      return Task(
        id: json['id'] as String,
        title: (json['title'] as String?) ?? 'Untitled task',
        description: (json['description'] as String?) ?? '',
        dueAt:
            json['dueAt'] != null ? DateTime.tryParse(json['dueAt']) : null,
        reminderEnabled: (json['reminderEnabled'] as bool?) ?? false,
        reminderLeadMinutes: (json['reminderLeadMinutes'] as int?) ?? 10,
        isCompleted: (json['isCompleted'] as bool?) ?? false,
        completedAt: json['completedAt'] != null
            ? DateTime.tryParse(json['completedAt'])
            : null,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt']) ?? DateTime.now()
            : DateTime.now(),
      );
    } catch (_) {
      // Corrupt record: fall back to a minimal safe task rather than
      // crashing the whole list load (spec #37).
      return Task(
        id: (json['id'] as String?) ?? DateTime.now().toIso8601String(),
        title: 'Recovered task',
      );
    }
  }
}
