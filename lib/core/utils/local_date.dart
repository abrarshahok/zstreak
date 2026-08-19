/// Local calendar-date identity for check-ins (spec Section 2).
///
/// Streak math must key off the device's local calendar date, not a UTC
/// timestamp — a check-in at 11pm must stay "today" even after the user
/// crosses a timezone boundary later. Compute this once, at the moment of
/// check-in, and store the result; never recompute it from a timestamp.
String todayLocalDateString() => localDateString(DateTime.now());

String localDateString(DateTime localTime) {
  final y = localTime.year.toString().padLeft(4, '0');
  final m = localTime.month.toString().padLeft(2, '0');
  final d = localTime.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
