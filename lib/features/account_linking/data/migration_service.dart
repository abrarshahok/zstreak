import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/app_config.dart';
import '../../guest/data/guest_meta_repository.dart';
import '../../habits/data/local/app_database.dart';
import '../../habits/data/remote/habit_firestore_codec.dart';
import '../../habits/domain/frequency.dart';

class MigrationOutcome {
  const MigrationOutcome({required this.totalHabits, required this.archivedDueToLimit});
  final int totalHabits;
  final int archivedDueToLimit;
}

/// Copies a guest's local Drift data to Firestore under their now-
/// permanent uid, then clears the local copy (spec Section 3a/5).
///
/// Both entity types use deterministic Firestore doc keys — habits use
/// their own uuid, check-ins use their local calendar date string (never
/// their own uuid) — so re-running this after a partial failure is a safe,
/// idempotent retry: rewriting a doc at the same path just overwrites it.
class MigrationService {
  MigrationService(this._db, this._firestore, this._guestMeta);

  final AppDatabase _db;
  final FirebaseFirestore _firestore;
  final GuestMetaRepository _guestMeta;

  /// [isMerge] is true only when linking hit a "credential already in
  /// use" conflict and the user chose to merge into that pre-existing
  /// account — see Section 3a's free-tier-limit-during-merge rule. A
  /// plain (non-conflict) link never needs to archive on import: once
  /// Stage 11's paywall gates habit creation at 2 for everyone, a guest
  /// can never have exceeded the limit on their own.
  Future<MigrationOutcome> migrate({
    required String uid,
    required bool isMerge,
    required bool isPremium,
  }) async {
    await _guestMeta.markMigrationStarted(isMerge: isMerge);

    final habitsCollection = _firestore.collection('users').doc(uid).collection('habits');
    var activeCount = 0;
    if (isMerge && !isPremium) {
      final existing = await habitsCollection.get();
      activeCount = existing.docs.where((d) => d.data()['archivedAt'] == null).length;
    }

    final habitRows = await _db.select(_db.habits).get();
    var archivedDueToLimit = 0;

    // Batched in groups of 400 (Firestore's per-commit limit is 500) so a
    // guest with years of daily check-ins migrates in a handful of
    // round-trips instead of one sequential await per habit *and* per
    // check-in — the previous version could mean 700+ network round-trips
    // for a two-year streak, right at the moment linking needs to be fast
    // and reliable.
    const batchSize = 400;
    var batch = _firestore.batch();
    var pending = 0;

    Future<void> flushIfFull() async {
      if (pending < batchSize) return;
      await batch.commit();
      batch = _firestore.batch();
      pending = 0;
    }

    for (final habit in habitRows) {
      var archivedAt = habit.archivedAt;
      final wasAlreadyArchived = archivedAt != null;
      if (isMerge && !isPremium && !wasAlreadyArchived) {
        if (activeCount >= AppConfig.freeTierHabitLimit) {
          archivedAt = DateTime.now();
          archivedDueToLimit += 1;
        } else {
          activeCount += 1;
        }
      }

      final frequencyType = FrequencyType.fromDbValue(habit.frequencyType);
      final habitDoc = habitsCollection.doc(habit.id);
      batch.set(
        habitDoc,
        HabitFirestoreCodec.forMigration(
          name: habit.name,
          emoji: habit.emoji,
          colorHex: habit.colorHex,
          frequencyType: frequencyType,
          frequencyConfig: FrequencyConfig.fromJson(
            frequencyType,
            jsonDecode(habit.frequencyConfig) as Map<String, dynamic>,
          ),
          reminderTime: habit.reminderTime,
          description: habit.description,
          currentStreak: habit.currentStreak,
          longestStreak: habit.longestStreak,
          createdAt: habit.createdAt,
          archivedAt: archivedAt,
          sortOrder: habit.sortOrder,
        ),
      );
      pending++;
      await flushIfFull();

      final checkIns = await (_db.select(
        _db.checkIns,
      )..where((c) => c.habitId.equals(habit.id))).get();
      for (final checkIn in checkIns) {
        batch.set(habitDoc.collection('check_ins').doc(checkIn.date), {
          'completed': checkIn.completed,
          'note': checkIn.note,
          'loggedAt': Timestamp.fromDate(checkIn.loggedAt),
        });
        pending++;
        await flushIfFull();
      }
    }

    if (pending > 0) await batch.commit();

    await _guestMeta.markMigrationComplete();
    await _db.delete(_db.checkIns).go();
    await _db.delete(_db.habits).go();
    await _guestMeta.clear();

    return MigrationOutcome(totalHabits: habitRows.length, archivedDueToLimit: archivedDueToLimit);
  }
}
