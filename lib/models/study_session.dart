class StudySession {
  final String id;
  String subject;
  final DateTime startTime;
  DateTime endTime;
  String notes;

  StudySession({
    required this.id,
    required this.subject,
    required this.startTime,
    required this.endTime,
    this.notes = '',
  });

  Duration get duration => endTime.difference(startTime);

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject': subject,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'notes': notes,
      };

  factory StudySession.fromJson(Map<String, dynamic> json) {
    try {
      final DateTime start =
          DateTime.tryParse(json['startTime'] as String) ?? DateTime.now();
      final DateTime end =
          DateTime.tryParse(json['endTime'] as String) ?? start;
      return StudySession(
        id: json['id'] as String,
        subject: (json['subject'] as String?) ?? 'Study session',
        startTime: start,
        endTime: end.isBefore(start) ? start : end,
        notes: (json['notes'] as String?) ?? '',
      );
    } catch (_) {
      final DateTime now = DateTime.now();
      return StudySession(
        id: (json['id'] as String?) ?? now.toIso8601String(),
        subject: 'Recovered session',
        startTime: now,
        endTime: now,
      );
    }
  }
}

extension DurationFormat on Duration {
  /// Formats as "1h 20m" / "45m" / "0m".
  String get compact {
    final int h = inHours;
    final int m = inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}
