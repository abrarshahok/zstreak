import '../../habits/domain/check_in.dart';
import '../../habits/domain/frequency.dart';
import '../../habits/domain/habit.dart';
import '../../habits/domain/habit_repository.dart';
import '../../habits/domain/streak_calculator.dart';
import 'widget_sync_service.dart';

/// Decorates any [HabitRepository] so every mutation re-syncs the Android
/// widget data store (spec Section 2: "This sync step must happen on
/// every check-in, undo, and streak-affecting edit — a stale widget
/// showing yesterday's streak is a visible, easy-to-spot bug"). Keeps
/// that cross-cutting concern out of the Drift/Firestore backends
/// themselves, which stay focused on persistence only.
class WidgetSyncingHabitRepository implements HabitRepository {
  WidgetSyncingHabitRepository(
    this._inner,
    this._widgetSync,
    this._isPremium,
  );

  final HabitRepository _inner;
  final WidgetSyncService _widgetSync;

  /// Reads `hasActiveEntitlementProvider` (passed in by the caller,
  /// rather than an [EntitlementRepository] queried directly) so this
  /// honours the debug-mode Pro-simulation override and Riverpod's
  /// caching the same way the rest of the app does — hitting RevenueCat
  /// live on every single check-in both made the widget feel laggy and,
  /// since the override doesn't apply at that layer, flipped it back to
  /// the locked "Subscribe to continue" state on the very next sync.
  final Future<bool> Function() _isPremium;

  @override
  Stream<List<Habit>> watchActiveHabits() => _inner.watchActiveHabits();

  @override
  Stream<List<Habit>> watchArchivedHabits() => _inner.watchArchivedHabits();

  @override
  Future<Habit?> getHabitById(String id) => _inner.getHabitById(id);

  @override
  Stream<CheckIn?> watchCheckIn({
    required String habitId,
    required String date,
  }) => _inner.watchCheckIn(habitId: habitId, date: date);

  @override
  Stream<List<CheckIn>> watchHabitCheckIns(String habitId) =>
      _inner.watchHabitCheckIns(habitId);

  @override
  Stream<StreakResult> watchStreakDetail({
    required String habitId,
    required FrequencyType frequencyType,
    required FrequencyConfig frequencyConfig,
    required DateTime createdAt,
  }) => _inner.watchStreakDetail(
    habitId: habitId,
    frequencyType: frequencyType,
    frequencyConfig: frequencyConfig,
    createdAt: createdAt,
  );

  @override
  Future<Habit> createHabit({
    required String name,
    required String emoji,
    required String colorHex,
    required FrequencyType frequencyType,
    required FrequencyConfig frequencyConfig,
    String? reminderTime,
    String? description,
  }) async {
    final habit = await _inner.createHabit(
      name: name,
      emoji: emoji,
      colorHex: colorHex,
      frequencyType: frequencyType,
      frequencyConfig: frequencyConfig,
      reminderTime: reminderTime,
      description: description,
    );
    await _syncHabit(habit.id);
    return habit;
  }

  @override
  Future<void> setCheckIn({
    required String habitId,
    required String date,
    required bool completed,
    String? note,
  }) async {
    await _inner.setCheckIn(
      habitId: habitId,
      date: date,
      completed: completed,
      note: note,
    );
    await _syncHabit(habitId);
  }

  @override
  Future<bool> toggleCheckIn({
    required String habitId,
    required String date,
  }) async {
    final newCompleted = await _inner.toggleCheckIn(habitId: habitId, date: date);
    await _syncHabit(habitId);
    return newCompleted;
  }

  @override
  Future<void> updateHabit({
    required String id,
    required String name,
    required String emoji,
    required String colorHex,
    required FrequencyType frequencyType,
    required FrequencyConfig frequencyConfig,
    String? reminderTime,
    String? description,
  }) async {
    await _inner.updateHabit(
      id: id,
      name: name,
      emoji: emoji,
      colorHex: colorHex,
      frequencyType: frequencyType,
      frequencyConfig: frequencyConfig,
      reminderTime: reminderTime,
      description: description,
    );
    await _syncHabit(id);
  }

  @override
  Future<void> archiveHabit(String id) async {
    await _inner.archiveHabit(id);
    await _syncHabit(id);
  }

  @override
  Future<void> unarchiveHabit(String id) async {
    await _inner.unarchiveHabit(id);
    await _syncHabit(id);
  }

  @override
  Future<void> deleteHabit(String id) async {
    await _inner.deleteHabit(id);
    await _widgetSync.removeHabitData(id);
  }

  @override
  Future<void> reorderHabits(List<String> orderedIds) async {
    await _inner.reorderHabits(orderedIds);
    // No widget sync needed for reorder — sortOrder isn't part of what any
    // single widget instance displays (each instance shows one configured
    // habit's own name/emoji/color/streak/completedToday).
  }

  /// Syncs exactly the one habit that changed — O(1) in total habit count,
  /// unlike re-fetching and rewriting every active habit on every mutation.
  Future<void> _syncHabit(String habitId) async {
    final habit = await _inner.getHabitById(habitId);
    if (habit == null) return; // deleted mid-flight; nothing to sync
    final isPremium = await _isPremium();
    await _widgetSync.syncSingleHabit(
      habit,
      (id, date) => _inner.watchCheckIn(habitId: id, date: date).first,
      (id) => _inner.watchHabitCheckIns(id).first,
      isPremium: isPremium,
    );
  }
}
