import 'check_in.dart';
import 'check_in_status.dart';
import 'frequency.dart';
import 'habit.dart';
import 'habit_category.dart';
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
    String? description,
    String? categoryId,
    int? targetCount,
    String? targetUnit,
    bool isQuitHabit = false,
  });

  Stream<CheckIn?> watchCheckIn({
    required String habitId,
    required String date,
  });

  /// [note] is optional free-text attached to the check-in (Feature 2).
  /// [value] is the logged quantity for a quantity habit.
  Future<void> setCheckIn({
    required String habitId,
    required String date,
    required CheckInStatus status,
    String? note,
    int? value,
  });

  /// Atomically flips a check-in's completed state — reads the current
  /// value and writes its negation within a single database transaction —
  /// and returns the new completed value together with the freshly
  /// recomputed current streak. Unlike [setCheckIn], which takes an
  /// explicit target computed by the caller from its own (possibly
  /// stale) snapshot, this is what the widget's own check-in button uses:
  /// two overlapping toggle calls for the same (habitId, date) — e.g. a
  /// rapid double-tap, where each tap spawns its own background isolate
  /// with no shared in-memory state — are serialized by the transaction
  /// instead of both reading the same pre-toggle state and colliding on
  /// the same result (a "lost toggle"). Returning the streak too lets
  /// that same caller skip a separate [getHabitById] round-trip just to
  /// read the one field a check-in actually changes.
  ///
  /// Only ever flips between `completed`/`missed` — a `skipped` day is
  /// only reachable via [setCheckIn], from the day-action sheet.
  Future<({bool completed, int currentStreak})> toggleCheckIn({
    required String habitId,
    required String date,
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
    String? description,
    String? categoryId,
    bool clearCategoryId = false,
    int? targetCount,
    bool clearTargetCount = false,
    String? targetUnit,
    bool clearTargetUnit = false,
    bool isQuitHabit = false,
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

  /// Feature 6 – Drag-to-reorder: persists new [sortOrder] values for the
  /// given habit ids. [orderedIds] is the full list in display order.
  Future<void> reorderHabits(List<String> orderedIds);

  /// Custom categories only — [kPredefinedCategories] are always available
  /// and never stored. Sorted by creation order.
  Stream<List<HabitCategory>> watchCategories();

  Future<HabitCategory> createCategory({
    required String name,
    required String emoji,
    required String colorHex,
  });

  Future<void> updateCategory({
    required String id,
    required String name,
    required String emoji,
    required String colorHex,
  });

  /// Deleting a custom category clears `categoryId` on every habit that
  /// referenced it rather than leaving a dangling id behind.
  Future<void> deleteCategory(String id);
}
