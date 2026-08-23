import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/mood_entry.dart';
import '../../domain/mood_repository.dart';
import 'app_database.dart';

class DriftMoodRepository implements MoodRepository {
  DriftMoodRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;

  @override
  Stream<List<MoodEntry>> watchMoodEntries() {
    final query = _db.select(_db.moodEntries)
      ..orderBy([(m) => OrderingTerm.desc(m.date)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Stream<MoodEntry?> watchMoodEntry(String date) {
    final query = _db.select(_db.moodEntries)..where((m) => m.date.equals(date));
    return query.watchSingleOrNull().map((row) => row == null ? null : _toDomain(row));
  }

  @override
  Future<void> logMood({
    required String date,
    required int moodScore,
    int? energyScore,
    String? note,
  }) async {
    final existing = await (_db.select(
      _db.moodEntries,
    )..where((m) => m.date.equals(date))).getSingleOrNull();

    if (existing != null) {
      await (_db.update(
        _db.moodEntries,
      )..where((m) => m.id.equals(existing.id))).write(
        MoodEntriesCompanion(
          moodScore: Value(moodScore),
          energyScore: Value(energyScore),
          note: Value(note),
          loggedAt: Value(DateTime.now()),
        ),
      );
    } else {
      await _db
          .into(_db.moodEntries)
          .insert(
            MoodEntriesCompanion.insert(
              id: _uuid.v4(),
              date: date,
              moodScore: moodScore,
              energyScore: Value(energyScore),
              note: Value(note),
              loggedAt: DateTime.now(),
            ),
          );
    }
  }

  MoodEntry _toDomain(MoodEntryRow row) => MoodEntry(
    id: row.id,
    date: row.date,
    moodScore: row.moodScore,
    energyScore: row.energyScore,
    note: row.note,
    loggedAt: row.loggedAt,
  );
}
