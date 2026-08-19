import 'package:drift/drift.dart';

import '../../habits/data/local/app_database.dart';

/// Wraps the single-row `guest_meta` table — the 24-hour guest clock
/// (spec Section 3a) and, from Stage 6 on, the migration-resume flag.
class GuestMetaRepository {
  GuestMetaRepository(this._db);

  final AppDatabase _db;

  /// Idempotent: only the first call for a given guest session writes a
  /// row. Safe to call on every app open.
  Future<void> ensureStarted(String uid) async {
    final existing = await _db.select(_db.guestMeta).getSingleOrNull();
    if (existing != null) return;
    await _db
        .into(_db.guestMeta)
        .insert(
          GuestMetaCompanion.insert(
            guestStartedAt: DateTime.now(),
            firebaseAnonymousUid: uid,
          ),
        );
  }

  Stream<GuestMetaRow?> watchMeta() => _db.select(_db.guestMeta).watchSingleOrNull();

  Future<GuestMetaRow?> getMeta() => _db.select(_db.guestMeta).getSingleOrNull();

  /// Partial-failure resume bookkeeping for the migration (Stage 6/7, spec
  /// Section 5). [isMerge] is persisted so a resume after an app close
  /// mid-migration knows whether the free-tier archive-on-import rule
  /// applies, without the resuming caller having to remember it.
  Future<void> markMigrationStarted({required bool isMerge}) => _db
      .update(_db.guestMeta)
      .write(GuestMetaCompanion(migrationStatus: const Value('in_progress'), wasMerge: Value(isMerge)));

  Future<void> markMigrationComplete() => _db
      .update(_db.guestMeta)
      .write(const GuestMetaCompanion(migrationStatus: Value('complete')));

  Future<void> clear() => _db.delete(_db.guestMeta).go();

  /// "Clear my data" (Settings, spec Section 3a/3b) — wipes local habits
  /// and check-ins and resets the 24-hour clock fresh, without touching
  /// the Firebase anonymous session itself.
  Future<void> clearAllGuestData(String uid) async {
    await _db.transaction(() async {
      await _db.delete(_db.checkIns).go();
      await _db.delete(_db.habits).go();
      await _db.delete(_db.guestMeta).go();
      await _db
          .into(_db.guestMeta)
          .insert(
            GuestMetaCompanion.insert(guestStartedAt: DateTime.now(), firebaseAnonymousUid: uid),
          );
    });
  }
}
