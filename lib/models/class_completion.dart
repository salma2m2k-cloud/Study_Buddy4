import '../utils/date_utils.dart';

/// Records that a specific occurrence of a recurring [ClassModel] was
/// completed on a specific real calendar date (spec #15, #28).
///
/// One record = one class, one real date. The recurring class itself is
/// never touched when an occurrence is completed or uncompleted.
class ClassCompletion {
  final String classId;

  /// The real calendar date (date-only) of the occurrence, e.g. the
  /// actual Monday this record refers to.
  final DateTime date;

  bool completed;
  DateTime? completedAt;

  ClassCompletion({
    required this.classId,
    required DateTime date,
    this.completed = true,
    DateTime? completedAt,
  })  : date = AppDateUtils.dateOnly(date),
        completedAt = completedAt ?? DateTime.now();

  /// Composite key so completion records are keyed to the exact
  /// (class, real-date) pair — never ambiguous across weeks.
  String get key => '$classId::${AppDateUtils.dateKey(date)}';

  Map<String, dynamic> toJson() => {
        'classId': classId,
        'date': AppDateUtils.dateKey(date),
        'completed': completed,
        'completedAt': completedAt?.toIso8601String(),
      };

  factory ClassCompletion.fromJson(Map<String, dynamic> json) {
    final String dateStr = json['date'] as String;
    final DateTime parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();
    return ClassCompletion(
      classId: json['classId'] as String,
      date: parsedDate,
      completed: (json['completed'] as bool?) ?? true,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'])
          : null,
    );
  }
}
