/// Consistent calendar helpers so "this week" always means the same thing
/// across Home, Progress, and class-completion tracking (spec #28).
class AppDateUtils {
  AppDateUtils._();

  /// The app defines a week as Sunday 00:00:00 through the following
  /// Saturday 23:59:59, in local time. This single definition is used
  /// everywhere so a Sunday from one week is never combined with a
  /// Monday from another week.
  static DateTime startOfWeek(DateTime date) {
    final DateTime day = dateOnly(date);
    // DateTime.weekday: Mon=1..Sun=7. We want Sunday-start weeks.
    final int daysSinceSunday = day.weekday % 7; // Sun=7%7=0, Mon=1, ... Sat=6
    return day.subtract(Duration(days: daysSinceSunday));
  }

  static DateTime endOfWeek(DateTime date) {
    final DateTime start = startOfWeek(date);
    return start
        .add(const Duration(days: 7))
        .subtract(const Duration(milliseconds: 1));
  }

  static DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// ISO-ish stable key (yyyy-MM-dd) for a calendar date, used to key
  /// class-occurrence completion records to their real date.
  static String dateKey(DateTime dt) {
    final String y = dt.year.toString().padLeft(4, '0');
    final String m = dt.month.toString().padLeft(2, '0');
    final String d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static bool isInWeekOf(DateTime date, DateTime referenceDate) {
    final DateTime start = startOfWeek(referenceDate);
    final DateTime end = endOfWeek(referenceDate);
    return !date.isBefore(start) && !date.isAfter(end);
  }
}
