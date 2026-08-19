import '../../habits/domain/check_in.dart';
import '../../habits/domain/frequency.dart';
import '../../habits/domain/habit.dart';
import '../../habits/domain/habit_repository.dart';
import '../../habits/domain/streak_calculator.dart';
import '../../monetization/domain/entitlement_repository.dart';
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
    this._entitlements,
  );

  final HabitRepository _inner;
  final WidgetSyncService _widgetSync;
  final EntitlementRepository _entitlements;

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
  }) async {
    final habit = await _inner.createHabit(
      name: name,
      emoji: emoji,
      colorHex: colorHex,
      frequencyType: frequencyType,
      frequencyConfig: frequencyConfig,
      reminderTime: reminderTime,
    );
    await _syncAll();
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
    await _syncAll();
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
  }) async {
    await _inner.updateHabit(
      id: id,
      name: name,
      emoji: emoji,
      colorHex: colorHex,
      frequencyType: frequencyType,
      frequencyConfig: frequencyConfig,
      reminderTime: reminderTime,
    );
    await _syncAll();
  }

  @override
  Future<void> archiveHabit(String id) async {
    await _inner.archiveHabit(id);
    await _syncAll();
  }

  @override
  Future<void> unarchiveHabit(String id) async {
    await _inner.unarchiveHabit(id);
    await _syncAll();
  }

  @override
  Future<void> deleteHabit(String id) async {
    await _inner.deleteHabit(id);
    await _syncAll();
  }

  @override
  Future<void> useFreeze({
    required String habitId,
    required String date,
  }) async {
    await _inner.useFreeze(habitId: habitId, date: date);
    await _syncAll();
  }

  @override
  Future<void> reorderHabits(List<String> orderedIds) async {
    await _inner.reorderHabits(orderedIds);
    // No widget sync needed for reorder — widget shows top habit only.
  }

  Future<void> _syncAll() async {
    final habits = await _inner.watchActiveHabits().first;
    final isPremium = await _entitlements.hasActiveEntitlement();
    await _widgetSync.syncHabits(
      habits,
      (habitId, date) =>
          _inner.watchCheckIn(habitId: habitId, date: date).first,
      isPremium: isPremium,
    );
  }
}
