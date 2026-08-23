import 'check_in_status.dart';

class CheckIn {
  const CheckIn({
    required this.id,
    required this.habitId,
    required this.date,
    this.status = CheckInStatus.completed,
    this.value,
    this.note,
    required this.loggedAt,
  });

  final String id;
  final String habitId;

  /// Local calendar date, "YYYY-MM-DD" — the check-in's identity (spec
  /// Section 2). Never a UTC timestamp.
  final String date;
  final CheckInStatus status;

  /// Today's logged quantity for a quantity/numeric habit (spec: Habit
  /// Flows audit). Null for a plain yes/no habit.
  final int? value;
  final String? note;
  final DateTime loggedAt;

  bool get completed => status == CheckInStatus.completed;
}
