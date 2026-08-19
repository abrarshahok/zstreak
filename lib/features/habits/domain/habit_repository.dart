import 'check_in.dart';
import 'frequency.dart';
import 'habit.dart';
import 'streak_calculator.dart';

/// Storage-agnostic contract implemented by both backends (spec Section 5):
/// [DriftHabitRepository] for guests, a Firestore-backed repository once
/// Stage 7 adds signed-in support. Screens depend on this, never on Drift
/// or Firestore directly.
abstract class HabitRepository {
  Stream<List<Habit>> watchActiveHabits();

  /// The "Archived habits" section (Section 3b) — history stays visible,
  /// just off Home.
  Stream<List<Habit>> watchArchivedHabits();

  /// Used by the notification-tap deep link (Stage 8) to resolve a bare
  /// `habit_id` payload back into a [Habit]. Null if it no longer exists.
  Future<Habit?> getHabitById(String id);

  Future<Habit> createHabit({
    required String name,
    required String emoji,
    required String colorHex,
    required FrequencyType frequencyType,
    required FrequencyConfig frequencyConfig,
    String? reminderTime,
  });

  Stream<CheckIn?> watchCheckIn({
    required String habitId,
    required String date,
  });

  /// [note] is optional free-text attached to the check-in (Feature 2).
  Future<void> setCheckIn({
    required String habitId,
    required String date,
    required bool completed,
    String? note,
  });

  /// Resets `current_streak` to 0 when [frequencyType] differs from the
  /// habit's stored type (spec Section 5a) — history and longest streak
  /// are left untouched either way.
  Future<void> updateHabit({
    required String id,
    required String name,
    required String emoji,
    required String colorHex,
    required FrequencyType frequencyType,
    required FrequencyConfig frequencyConfig,
    String? reminderTime,
  });

  /// Reversible: hides the habit from Home but keeps its history (Section 3b).
  Future<void> archiveHabit(String id);

  Future<void> unarchiveHabit(String id);

  /// Permanent: removes the habit and all its check-ins (Section 3b).
  Future<void> deleteHabit(String id);

  /// Full grid + streak detail for Habit Detail (Section 3b). Takes the
  /// habit's own frequency fields directly rather than re-fetching them,
  /// since the caller already holds the [Habit].
  Stream<StreakResult> watchStreakDetail({
    required String habitId,
    required FrequencyType frequencyType,
    required FrequencyConfig frequencyConfig,
    required DateTime createdAt,
  });

  /// Feature 2 – Habit Notes: streams all check-ins for a habit so the
  /// detail screen can show note indicators on grid cells.
  Stream<List<CheckIn>> watchHabitCheckIns(String habitId);

  /// Feature 1 – Streak Freeze: consumes one freeze token for [date],
  /// appending it to [frozenDates] and decrementing [streakFreezes].
  /// No-op if [streakFreezes] is already 0.
  Future<void> useFreeze({required String habitId, required String date});

  /// Feature 6 – Drag-to-reorder: persists new [sortOrder] values for the
  /// given habit ids. [orderedIds] is the full list in display order.
  Future<void> reorderHabits(List<String> orderedIds);
}
