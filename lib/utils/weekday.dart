/// Single, consistent representation of the days of the week used
/// EVERYWHERE in the app (UI, storage, progress, notifications).
///
/// We deliberately do NOT reuse `DateTime.weekday` directly in app code,
/// because `DateTime.weekday` is 1=Monday..7=Sunday, which is an easy
/// source of off-by-one bugs when mixed with "Sunday-first" UI pickers.
/// Instead we define our own explicit enum and convert at the boundary.
enum Weekday {
  sunday,
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday;

  /// Convert from Dart's `DateTime.weekday` (1=Mon..7=Sun) to our enum.
  static Weekday fromDateTimeWeekday(int dtWeekday) {
    // DateTime.weekday: Mon=1, Tue=2, Wed=3, Thu=4, Fri=5, Sat=6, Sun=7
    switch (dtWeekday) {
      case DateTime.monday:
        return Weekday.monday;
      case DateTime.tuesday:
        return Weekday.tuesday;
      case DateTime.wednesday:
        return Weekday.wednesday;
      case DateTime.thursday:
        return Weekday.thursday;
      case DateTime.friday:
        return Weekday.friday;
      case DateTime.saturday:
        return Weekday.saturday;
      case DateTime.sunday:
      default:
        return Weekday.sunday;
    }
  }

  /// Convert our enum back to Dart's `DateTime.weekday` (1=Mon..7=Sun).
  int toDateTimeWeekday() {
    switch (this) {
      case Weekday.monday:
        return DateTime.monday;
      case Weekday.tuesday:
        return DateTime.tuesday;
      case Weekday.wednesday:
        return DateTime.wednesday;
      case Weekday.thursday:
        return DateTime.thursday;
      case Weekday.friday:
        return DateTime.friday;
      case Weekday.saturday:
        return DateTime.saturday;
      case Weekday.sunday:
        return DateTime.sunday;
    }
  }

  String get label {
    switch (this) {
      case Weekday.sunday:
        return 'Sunday';
      case Weekday.monday:
        return 'Monday';
      case Weekday.tuesday:
        return 'Tuesday';
      case Weekday.wednesday:
        return 'Wednesday';
      case Weekday.thursday:
        return 'Thursday';
      case Weekday.friday:
        return 'Friday';
      case Weekday.saturday:
        return 'Saturday';
    }
  }

  String get short {
    switch (this) {
      case Weekday.sunday:
        return 'Sun';
      case Weekday.monday:
        return 'Mon';
      case Weekday.tuesday:
        return 'Tue';
      case Weekday.wednesday:
        return 'Wed';
      case Weekday.thursday:
        return 'Thu';
      case Weekday.friday:
        return 'Fri';
      case Weekday.saturday:
        return 'Sat';
    }
  }

  /// Stable index used for JSON storage (0=Sunday..6=Saturday). This is
  /// independent from `DateTime.weekday` on purpose, so storage never
  /// silently breaks if we ever change how we talk to `dart:core`.
  int get storageIndex => index; // enum declared Sun..Sat above, index 0..6

  static Weekday fromStorageIndex(int i) => Weekday.values[i];
}
