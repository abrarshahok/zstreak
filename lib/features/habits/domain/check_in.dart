class CheckIn {
  const CheckIn({
    required this.id,
    required this.habitId,
    required this.date,
    this.completed = true,
    this.note,
    required this.loggedAt,
  });

  final String id;
  final String habitId;

  /// Local calendar date, "YYYY-MM-DD" — the check-in's identity (spec
  /// Section 2). Never a UTC timestamp.
  final String date;
  final bool completed;
  final String? note;
  final DateTime loggedAt;
}
