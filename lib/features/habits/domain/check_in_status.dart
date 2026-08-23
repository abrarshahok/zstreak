/// Tri-state outcome for a single day's check-in. `skipped` is a deliberate
/// user action (long-press → Skip) distinct from `missed` (nothing logged):
/// a skip never breaks a streak and is excluded from completion-rate math,
/// the same way a non-scheduled day already is — see [StreakCalculator].
enum CheckInStatus {
  completed,
  missed,
  skipped;

  String toDbValue() => switch (this) {
    CheckInStatus.completed => 'completed',
    CheckInStatus.missed => 'missed',
    CheckInStatus.skipped => 'skipped',
  };

  static CheckInStatus fromDbValue(String value) => switch (value) {
    'completed' => CheckInStatus.completed,
    'skipped' => CheckInStatus.skipped,
    _ => CheckInStatus.missed,
  };
}
