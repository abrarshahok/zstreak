import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

// ignore_for_file: avoid_dynamic_calls

import '../../domain/check_in.dart';
import '../../domain/check_in_status.dart';
import '../../domain/frequency.dart';
import '../../domain/habit.dart';
import '../../domain/habit_category.dart';
import '../../domain/habit_repository.dart';
import '../../domain/streak_calculator.dart';
import 'app_database.dart';

/// Guest-mode backend: everything lives in Drift/SQLite, on-device only,
/// never touching Firestore (spec Section 2).
class DriftHabitRepository implements HabitRepository {
  DriftHabitRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;

  @override
  Stream<List<Habit>> watchActiveHabits() {
    final query = _db.select(_db.habits)
      ..where((h) => h.archivedAt.isNull())
      ..orderBy([
        (h) => OrderingTerm.asc(h.sortOrder),
        (h) => OrderingTerm.asc(h.createdAt),
      ]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Stream<List<Habit>> watchArchivedHabits() {
    final query = _db.select(_db.habits)
      ..where((h) => h.archivedAt.isNotNull())
      ..orderBy([(h) => OrderingTerm.desc(h.archivedAt)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<Habit?> getHabitById(String id) async {
    final row = await (_db.select(
      _db.habits,
    )..where((h) => h.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
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
  }) async {
    final now = DateTime.now();
    final row = HabitsCompanion.insert(
      id: _uuid.v4(),
      name: name,
      emoji: emoji,
      colorHex: colorHex,
      frequencyType: frequencyType.toDbValue(),
      frequencyConfig: jsonEncode(frequencyConfig.toJson()),
      reminderTime: Value(reminderTime),
      description: Value(description),
      createdAt: now,
      updatedAt: now,
      categoryId: Value(categoryId),
      targetCount: Value(targetCount),
      targetUnit: Value(targetUnit),
      isQuitHabit: Value(isQuitHabit),
    );
    await _db.into(_db.habits).insert(row);
    return _toDomain(
      await (_db.select(
        _db.habits,
      )..where((h) => h.id.equals(row.id.value))).getSingle(),
    );
  }

  @override
  Stream<CheckIn?> watchCheckIn({
    required String habitId,
    required String date,
  }) {
    final query = _db.select(_db.checkIns)
      ..where((c) => c.habitId.equals(habitId) & c.date.equals(date));
    return query.watchSingleOrNull().map((row) {
      if (row == null) return null;
      return _checkInFromRow(row);
    });
  }

  @override
  Stream<List<CheckIn>> watchHabitCheckIns(String habitId) {
    final query = _db.select(_db.checkIns)
      ..where((c) => c.habitId.equals(habitId));
    return query.watch().map(
      (rows) => rows.map(_checkInFromRow).toList(),
    );
  }

  CheckIn _checkInFromRow(CheckInRow row) => CheckIn(
    id: row.id,
    habitId: row.habitId,
    date: row.date,
    status: CheckInStatus.fromDbValue(row.status),
    value: row.value,
    note: row.note,
    loggedAt: row.loggedAt,
  );

  @override
  Future<void> setCheckIn({
    required String habitId,
    required String date,
    required CheckInStatus status,
    String? note,
    int? value,
  }) async {
    // The check-in row write and the streak recompute below both need to
    // see each other's effects atomically — two setCheckIn calls for the
    // same habit close together (e.g. a rapid double-tap, or two days
    // toggled back-to-back in the calendar grid) previously ran the row
    // write inside its own transaction but _recalculateStreak's
    // read-then-max-write of longestStreak afterward, in a *separate*,
    // unguarded transaction: call A could read the pre-B longestStreak,
    // then B commits a higher value, then A's stale max() write overwrites
    // it back down. One transaction around both makes SQLite's own
    // locking serialize overlapping calls instead.
    await _db.transaction(() async {
      final existing =
          await (_db.select(_db.checkIns)
                ..where((c) => c.habitId.equals(habitId) & c.date.equals(date)))
              .getSingleOrNull();

      if (status == CheckInStatus.missed && value == null) {
        if (existing != null) {
          await (_db.delete(
            _db.checkIns,
          )..where((c) => c.id.equals(existing.id))).go();
        }
      } else if (existing != null) {
        await (_db.update(
          _db.checkIns,
        )..where((c) => c.id.equals(existing.id))).write(
          CheckInsCompanion(
            completed: Value(status == CheckInStatus.completed),
            status: Value(status.toDbValue()),
            value: Value(value ?? existing.value),
            note: Value(note ?? existing.note),
            loggedAt: Value(DateTime.now()),
          ),
        );
      } else {
        await _db
            .into(_db.checkIns)
            .insert(
              CheckInsCompanion.insert(
                id: _uuid.v4(),
                habitId: habitId,
                date: date,
                completed: Value(status == CheckInStatus.completed),
                status: Value(status.toDbValue()),
                value: Value(value),
                note: Value(note),
                loggedAt: DateTime.now(),
              ),
            );
      }

      await _recalculateStreak(habitId);
    });
  }

  @override
  Future<({bool completed, int currentStreak})> toggleCheckIn({
    required String habitId,
    required String date,
  }) {
    return _db.transaction(() async {
      final existing =
          await (_db.select(_db.checkIns)
                ..where((c) => c.habitId.equals(habitId) & c.date.equals(date)))
              .getSingleOrNull();
      final newCompleted = !(existing?.completed ?? false);

      if (!newCompleted) {
        if (existing != null) {
          await (_db.delete(
            _db.checkIns,
          )..where((c) => c.id.equals(existing.id))).go();
        }
      } else if (existing != null) {
        await (_db.update(
          _db.checkIns,
        )..where((c) => c.id.equals(existing.id))).write(
          CheckInsCompanion(
            completed: const Value(true),
            status: Value(CheckInStatus.completed.toDbValue()),
            loggedAt: Value(DateTime.now()),
          ),
        );
      } else {
        await _db
            .into(_db.checkIns)
            .insert(
              CheckInsCompanion.insert(
                id: _uuid.v4(),
                habitId: habitId,
                date: date,
                completed: const Value(true),
                status: Value(CheckInStatus.completed.toDbValue()),
                loggedAt: DateTime.now(),
              ),
            );
      }

      final currentStreak = await _recalculateStreak(habitId);
      return (completed: newCompleted, currentStreak: currentStreak);
    });
  }

  /// Recomputes current/longest streak from full check-in history and
  /// persists them (spec Section 5a) — run on every check-in write, never
  /// on read, so screens can just read the stored fields. Always called
  /// from within [setCheckIn]'s transaction above. Returns the freshly
  /// computed current streak so [toggleCheckIn] can hand it straight back
  /// to callers (the widget's check-in callback in particular) without a
  /// second round-trip to re-fetch the habit just to read this one field.
  Future<int> _recalculateStreak(String habitId) async {
    final habit = _toDomain(
      await (_db.select(
        _db.habits,
      )..where((h) => h.id.equals(habitId))).getSingle(),
    );
    final rows =
        await (_db.select(
          _db.checkIns,
        )..where((c) => c.habitId.equals(habitId))).get();
    final statusByDate = {
      for (final r in rows) r.date: CheckInStatus.fromDbValue(r.status),
    };

    final result = StreakCalculator.compute(
      frequencyType: habit.frequencyType,
      frequencyConfig: habit.frequencyConfig,
      createdAtLocal: habit.createdAt,
      statusByDate: statusByDate,
      today: DateTime.now(),
    );

    await (_db.update(_db.habits)..where((h) => h.id.equals(habitId))).write(
      HabitsCompanion(
        currentStreak: Value(result.currentStreak),
        longestStreak: Value(_max(habit.longestStreak, result.longestStreak)),
      ),
    );
    return result.currentStreak;
  }

  int _max(int a, int b) => a > b ? a : b;

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
    String? categoryId,
    bool clearCategoryId = false,
    int? targetCount,
    bool clearTargetCount = false,
    String? targetUnit,
    bool clearTargetUnit = false,
    bool isQuitHabit = false,
  }) async {
    final existing = await (_db.select(
      _db.habits,
    )..where((h) => h.id.equals(id))).getSingle();
    final frequencyChanged =
        FrequencyType.fromDbValue(existing.frequencyType) != frequencyType;

    await (_db.update(_db.habits)..where((h) => h.id.equals(id))).write(
      HabitsCompanion(
        name: Value(name),
        emoji: Value(emoji),
        colorHex: Value(colorHex),
        frequencyType: Value(frequencyType.toDbValue()),
        frequencyConfig: Value(jsonEncode(frequencyConfig.toJson())),
        reminderTime: Value(reminderTime),
        description: Value(description),
        // Frequency-type changes reset the active streak, never history or
        // the longest-streak record (spec Section 5a).
        currentStreak: frequencyChanged ? const Value(0) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
        categoryId: clearCategoryId
            ? const Value(null)
            : Value(categoryId ?? existing.categoryId),
        targetCount: clearTargetCount
            ? const Value(null)
            : Value(targetCount ?? existing.targetCount),
        targetUnit: clearTargetUnit
            ? const Value(null)
            : Value(targetUnit ?? existing.targetUnit),
        isQuitHabit: Value(isQuitHabit),
      ),
    );
  }

  @override
  Future<void> archiveHabit(String id) =>
      (_db.update(_db.habits)..where((h) => h.id.equals(id))).write(
        HabitsCompanion(
          archivedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );

  @override
  Future<void> unarchiveHabit(String id) =>
      (_db.update(_db.habits)..where((h) => h.id.equals(id))).write(
        HabitsCompanion(
          archivedAt: const Value(null),
          updatedAt: Value(DateTime.now()),
        ),
      );

  @override
  Future<void> deleteHabit(String id) async {
    await _db.transaction(() async {
      await (_db.delete(_db.checkIns)..where((c) => c.habitId.equals(id))).go();
      await (_db.delete(_db.habits)..where((h) => h.id.equals(id))).go();
    });
  }

  @override
  Future<void> reorderHabits(List<String> orderedIds) async {
    await _db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (_db.update(_db.habits)..where((h) => h.id.equals(orderedIds[i])))
            .write(HabitsCompanion(sortOrder: Value(i)));
      }
    });
  }

  @override
  Stream<StreakResult> watchStreakDetail({
    required String habitId,
    required FrequencyType frequencyType,
    required FrequencyConfig frequencyConfig,
    required DateTime createdAt,
  }) {
    final checkInQuery = _db.select(_db.checkIns)
      ..where((c) => c.habitId.equals(habitId));

    return checkInQuery.watch().map((checkInRows) {
      return StreakCalculator.compute(
        frequencyType: frequencyType,
        frequencyConfig: frequencyConfig,
        createdAtLocal: createdAt,
        statusByDate: {
          for (final r in checkInRows) r.date: CheckInStatus.fromDbValue(r.status),
        },
        today: DateTime.now(),
      );
    });
  }

  @override
  Stream<List<HabitCategory>> watchCategories() {
    final query = _db.select(_db.categories)
      ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]);
    return query.watch().map(
      (rows) => rows
          .map(
            (r) => HabitCategory(
              id: r.id,
              name: r.name,
              emoji: r.emoji,
              colorHex: r.colorHex,
              isCustom: true,
            ),
          )
          .toList(),
    );
  }

  @override
  Future<HabitCategory> createCategory({
    required String name,
    required String emoji,
    required String colorHex,
  }) async {
    final id = _uuid.v4();
    await _db
        .into(_db.categories)
        .insert(
          CategoriesCompanion.insert(
            id: id,
            name: name,
            emoji: emoji,
            colorHex: colorHex,
            createdAt: DateTime.now(),
          ),
        );
    return HabitCategory(
      id: id,
      name: name,
      emoji: emoji,
      colorHex: colorHex,
      isCustom: true,
    );
  }

  @override
  Future<void> updateCategory({
    required String id,
    required String name,
    required String emoji,
    required String colorHex,
  }) => (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
    CategoriesCompanion(
      name: Value(name),
      emoji: Value(emoji),
      colorHex: Value(colorHex),
    ),
  );

  @override
  Future<void> deleteCategory(String id) async {
    await _db.transaction(() async {
      await (_db.update(_db.habits)..where((h) => h.categoryId.equals(id)))
          .write(const HabitsCompanion(categoryId: Value(null)));
      await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
    });
  }

  Habit _toDomain(HabitRow row) {
    final type = FrequencyType.fromDbValue(row.frequencyType);
    return Habit(
      id: row.id,
      name: row.name,
      emoji: row.emoji,
      colorHex: row.colorHex,
      frequencyType: type,
      frequencyConfig: FrequencyConfig.fromJson(
        type,
        jsonDecode(row.frequencyConfig) as Map<String, dynamic>,
      ),
      reminderTime: row.reminderTime,
      description: row.description,
      currentStreak: row.currentStreak,
      longestStreak: row.longestStreak,
      createdAt: row.createdAt,
      archivedAt: row.archivedAt,
      updatedAt: row.updatedAt,
      sortOrder: row.sortOrder,
      categoryId: row.categoryId,
      targetCount: row.targetCount,
      targetUnit: row.targetUnit,
      isQuitHabit: row.isQuitHabit,
    );
  }
}
