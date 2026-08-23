/// App-wide constants that multiple features need to agree on (spec
/// Section 6) — centralized so the free-tier limit can't drift between
/// the merge logic (Stage 6) and the paywall gate (Stage 11).
class AppConfig {
  AppConfig._();

  static const int freeTierHabitLimit = 3;

  /// Free tier can only backfill the last N days (including today) via
  /// "Log a past day" or the monthly grid's day-action sheet; Pro is
  /// unbounded. Previously duplicated as a bare `6` in two places in
  /// `habit_detail_screen.dart` — centralized here so it can't drift.
  static const int freeTierBackfillDays = 7;
}
