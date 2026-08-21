/// App-wide constants that multiple features need to agree on (spec
/// Section 6) — centralized so the free-tier limit can't drift between
/// the merge logic (Stage 6) and the paywall gate (Stage 11).
class AppConfig {
  AppConfig._();

  static const int freeTierHabitLimit = 3;
}
