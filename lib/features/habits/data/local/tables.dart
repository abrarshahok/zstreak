import 'package:drift/drift.dart';

/// Guest-mode local schema (spec Section 5) — deliberately mirrors the
/// Firestore schema field-for-field so linking (Stage 6) is a straight
/// copy, never a transform.
@DataClassName('HabitRow')
class Habits extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get emoji => text()();
  TextColumn get colorHex => text()();
  TextColumn get frequencyType => text()();
  TextColumn get frequencyConfig => text()();
  TextColumn get reminderTime => text().nullable()();
  IntColumn get currentStreak => integer().withDefault(const Constant(0))();
  IntColumn get longestStreak => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  /// Feature 1 – Streak Freeze: number of available freeze tokens.
  /// Defaults to 1 so new habits start with one free freeze.
  IntColumn get streakFreezes => integer().withDefault(const Constant(1))();

  /// Feature 1 – Streak Freeze: JSON-encoded list of "YYYY-MM-DD" strings
  /// for days that were frozen (missed but protected from streak reset).
  TextColumn get frozenDates => text().nullable()();

  /// Feature 6 – Drag-to-reorder: lower values appear first in the list.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CheckInRow')
class CheckIns extends Table {
  TextColumn get id => text()();
  TextColumn get habitId => text().references(Habits, #id)();

  /// Local calendar date "YYYY-MM-DD" — the check-in's identity, not a
  /// UTC timestamp (spec Section 2).
  TextColumn get date => text()();
  BoolColumn get completed => boolean().withDefault(const Constant(true))();
  TextColumn get note => text().nullable()();
  DateTimeColumn get loggedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  // One check-in per habit per day — mirrors Firestore's check_ins/{date}
  // keying (Section 5), so guest data never grows real duplicates.
  @override
  List<Set<Column>> get uniqueKeys => [
    {habitId, date},
  ];
}

/// Single-row table: the 24-hour guest clock (Stage 5) and the migration
/// bookkeeping needed for Stage 6's partial-failure resume.
@DataClassName('GuestMetaRow')
class GuestMeta extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();
  DateTimeColumn get guestStartedAt => dateTime()();
  TextColumn get firebaseAnonymousUid => text()();
  TextColumn get migrationStatus =>
      text().withDefault(const Constant('not_started'))();

  /// Persisted so a resumed migration (Stage 6, after an app close
  /// mid-migration) knows whether the free-tier archive-on-import rule
  /// applies, without the caller having to remember it across a restart.
  BoolColumn get wasMerge => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
