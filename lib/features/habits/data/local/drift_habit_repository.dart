import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

// ignore_for_file: avoid_dynamic_calls

import '../../domain/check_in.dart';
import '../../domain/frequency.dart';
import '../../domain/habit.dart';
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
      createdAt: now,
      updatedAt: now,
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
      return CheckIn(
        id: row.id,
        habitId: row.habitId,
        date: row.date,
        completed: row.completed,
        note: row.note,
        loggedAt: row.loggedAt,
      );
    });
  }

  @override
  Stream<List<CheckIn>> watchHabitCheckIns(String habitId) {
    final query = _db.select(_db.checkIns)
      ..where((c) => c.habitId.equals(habitId));
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => CheckIn(
              id: row.id,
              habitId: row.habitId,
              date: row.date,
              completed: row.completed,
              note: row.note,
              loggedAt: row.loggedAt,
            ),
          )
          .toList(),
    );
  }

  @override
  Future<void> setCheckIn({
    required String habitId,
    required String date,
    required bool completed,
    String? note,
  }) async {
    await _db.transaction(() async {
      final existing =
          await (_db.select(_db.checkIns)
                ..where((c) => c.habitId.equals(habitId) & c.date.equals(date)))
              .getSingleOrNull();

      if (!completed) {
        if (existing != null) {
          await (_db.delete(
            _db.checkIns,
          )..where((c) => c.id.equals(existing.id))).go();
        }
        return;
      }

      if (existing != null) {
        await (_db.update(
          _db.checkIns,
        )..where((c) => c.id.equals(existing.id))).write(
          CheckInsCompanion(
            completed: const Value(true),
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
                completed: const Value(true),
                note: Value(note),
                loggedAt: DateTime.now(),
              ),
            );
      }
    });
    await _recalculateStreak(habitId);
  }

  /// Recomputes current/longest streak from full check-in history and
  /// persists them (spec Section 5a) — run on every check-in write, never
  /// on read, so screens can just read the stored fields.
  Future<void> _recalculateStreak(String habitId) async {
    final habit = _toDomain(
      await (_db.select(
        _db.habits,
      )..where((h) => h.id.equals(habitId))).getSingle(),
    );
    final completedRows =
        await (_db.select(_db.checkIns)..where(
              (c) => c.habitId.equals(habitId) & c.completed.equals(true),
            ))
            .get();
    final completedDates = completedRows.map((r) => r.date).toSet();

    final result = StreakCalculator.compute(
      frequencyType: habit.frequencyType,
      frequencyConfig: habit.frequencyConfig,
      createdAtLocal: habit.createdAt,
      completedDates: completedDates,
      frozenDates: habit.frozenDates,
      today: DateTime.now(),
    );

    await (_db.update(_db.habits)..where((h) => h.id.equals(habitId))).write(
      HabitsCompanion(
        currentStreak: Value(result.currentStreak),
        longestStreak: Value(_max(habit.longestStreak, result.longestStreak)),
      ),
    );
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
        // Frequency-type changes reset the active streak, never history or
        // the longest-streak record (spec Section 5a).
        currentStreak: frequencyChanged ? const Value(0) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
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
  Future<void> useFreeze({
    required String habitId,
    required String date,
  }) async {
    final row = await (_db.select(
      _db.habits,
    )..where((h) => h.id.equals(habitId))).getSingleOrNull();
    if (row == null || row.streakFreezes <= 0) return;

    final existing = _parseFrozenDates(row.frozenDates);
    if (existing.contains(date)) return; // already frozen

    final updated = {...existing, date};
    await (_db.update(_db.habits)..where((h) => h.id.equals(habitId))).write(
      HabitsCompanion(
        streakFreezes: Value(row.streakFreezes - 1),
        frozenDates: Value(jsonEncode(updated.toList())),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _recalculateStreak(habitId);
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
    // Watch both check-ins and the habit row so frozen-date changes also
    // trigger a recompute.
    final checkInQuery = _db.select(_db.checkIns)
      ..where((c) => c.habitId.equals(habitId) & c.completed.equals(true));
    final habitQuery = _db.select(_db.habits)
      ..where((h) => h.id.equals(habitId));

    return checkInQuery.watch().asyncExpand((checkInRows) {
      return habitQuery.watchSingleOrNull().map((habitRow) {
        final frozenDates = habitRow != null
            ? _parseFrozenDates(habitRow.frozenDates)
            : const <String>{};
        return StreakCalculator.compute(
          frequencyType: frequencyType,
          frequencyConfig: frequencyConfig,
          createdAtLocal: createdAt,
          completedDates: checkInRows.map((r) => r.date).toSet(),
          frozenDates: frozenDates,
          today: DateTime.now(),
        );
      });
    });
  }

  /// Parses the JSON-encoded frozen-dates string stored in the DB.
  /// Returns an empty set if the value is null or malformed.
  static Set<String> _parseFrozenDates(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<String>().toSet();
    } catch (_) {
      return const {};
    }
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
      currentStreak: row.currentStreak,
      longestStreak: row.longestStreak,
      createdAt: row.createdAt,
      archivedAt: row.archivedAt,
      updatedAt: row.updatedAt,
      streakFreezes: row.streakFreezes,
      frozenDates: _parseFrozenDates(row.frozenDates),
      sortOrder: row.sortOrder,
    );
  }
}
