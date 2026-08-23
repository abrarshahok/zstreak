import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../domain/check_in.dart';
import '../../domain/check_in_status.dart';
import '../../domain/frequency.dart';
import '../../domain/habit.dart';
import '../../domain/habit_category.dart';
import '../../domain/habit_repository.dart';
import '../../domain/streak_calculator.dart';
import 'habit_firestore_codec.dart';

/// Signed-in/linked backend (spec Section 5) — same [HabitRepository]
/// contract as [DriftHabitRepository], so every screen that depends on
/// the interface works unchanged regardless of which uid's data this is.
class FirestoreHabitRepository implements HabitRepository {
  FirestoreHabitRepository(this._firestore, this._uid, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final FirebaseFirestore _firestore;
  final String _uid;
  final Uuid _uuid;

  CollectionReference<Map<String, dynamic>> get _habits =>
      _firestore.collection('users').doc(_uid).collection('habits');

  CollectionReference<Map<String, dynamic>> get _categories =>
      _firestore.collection('users').doc(_uid).collection('categories');

  @override
  Stream<List<Habit>> watchActiveHabits() {
    // Feature 6: sort by sortOrder first, then createdAt as tiebreaker.
    // Limit to 50 — a safety cap. Free users are capped at 3 by the app;
    // Pro users realistically have 5–30. Nobody has 1000 habits.
    return _habits
        .where('archivedAt', isNull: true)
        .orderBy('sortOrder')
        .orderBy('createdAt')
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map(_toDomain).toList());
  }

  @override
  Stream<List<Habit>> watchArchivedHabits() {
    // Limit to 50 — consistent with watchActiveHabits.
    return _habits
        .where('archivedAt', isNull: false)
        .orderBy('archivedAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map(_toDomain).toList());
  }

  @override
  Future<Habit?> getHabitById(String id) async {
    final doc = await _habits.doc(id).get();
    return doc.exists ? _toDomain(doc) : null;
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
    final id = _uuid.v4();
    final now = DateTime.now();
    final doc = _habits.doc(id);
    await doc.set(
      HabitFirestoreCodec.forCreate(
        name: name,
        emoji: emoji,
        colorHex: colorHex,
        frequencyType: frequencyType,
        frequencyConfig: frequencyConfig,
        reminderTime: reminderTime,
        description: description,
        createdAt: now,
        categoryId: categoryId,
        targetCount: targetCount,
        targetUnit: targetUnit,
        isQuitHabit: isQuitHabit,
      ),
    );
    return _toDomain(await doc.get());
  }

  CheckIn _checkInFromData(String habitId, String date, Map<String, dynamic> data) {
    // Defensive: docs written before the status field existed only ever
    // have `completed` (true, since a false doc was always deleted).
    final statusStr =
        data['status'] as String? ??
        ((data['completed'] as bool? ?? false) ? 'completed' : 'missed');
    return CheckIn(
      id: date,
      habitId: habitId,
      date: date,
      status: CheckInStatus.fromDbValue(statusStr),
      value: data['value'] as int?,
      note: data['note'] as String?,
      loggedAt: (data['loggedAt'] as Timestamp).toDate(),
    );
  }

  @override
  Stream<CheckIn?> watchCheckIn({
    required String habitId,
    required String date,
  }) {
    return _habits
        .doc(habitId)
        .collection('check_ins')
        .doc(date)
        .snapshots()
        .map((snap) {
          if (!snap.exists) return null;
          return _checkInFromData(habitId, date, snap.data()!);
        });
  }

  @override
  Stream<List<CheckIn>> watchHabitCheckIns(String habitId) {
    // Order by loggedAt descending so the most recent 400 check-ins are
    // fetched — the contribution grid and analytics screen only display
    // the most recent ~365 days, so older data is never needed.
    return _habits
        .doc(habitId)
        .collection('check_ins')
        .orderBy('loggedAt', descending: true)
        .limit(400)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => _checkInFromData(habitId, doc.id, doc.data()))
              .toList(),
        );
  }

  @override
  Future<void> setCheckIn({
    required String habitId,
    required String date,
    required CheckInStatus status,
    String? note,
    int? value,
  }) async {
    final doc = _habits.doc(habitId).collection('check_ins').doc(date);
    if (status == CheckInStatus.missed && value == null) {
      await doc.delete();
    } else {
      // Merge so an existing note is preserved when only toggling completion.
      await doc.set({
        'completed': status == CheckInStatus.completed,
        'status': status.toDbValue(),
        'value': ?value,
        'note': ?note,
        'loggedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    }
    await _recalculateStreak(habitId);
  }

  @override
  Future<({bool completed, int currentStreak})> toggleCheckIn({
    required String habitId,
    required String date,
  }) async {
    final doc = _habits.doc(habitId).collection('check_ins').doc(date);
    final newCompleted = await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(doc);
      final wasCompleted =
          existing.exists && (existing.data()?['completed'] as bool? ?? false);
      final newCompleted = !wasCompleted;
      if (!newCompleted) {
        transaction.delete(doc);
      } else {
        transaction.set(doc, {
          'completed': true,
          'status': CheckInStatus.completed.toDbValue(),
          'loggedAt': Timestamp.now(),
        }, SetOptions(merge: true));
      }
      return newCompleted;
    });
    final currentStreak = await _recalculateStreak(habitId);
    return (completed: newCompleted, currentStreak: currentStreak);
  }

  /// Returns the freshly recomputed current streak so [toggleCheckIn] can
  /// hand it straight back to callers (the widget's check-in callback in
  /// particular) without a second round-trip to re-fetch the habit just
  /// to read this one field.
  Future<int> _recalculateStreak(String habitId) async {
    // No limit here on purpose: StreakCalculator recomputes from the full
    // check-in history, so truncating this query (a previous `.limit(400)`
    // here) silently fed it an arbitrary subset once a habit passed ~400
    // check-ins — wrong streaks for exactly the longest-lived habits. Reads
    // still scale with habit age, but that's an honest cost, not a silent
    // correctness bug. Every status (not just completed) is fetched now,
    // since a skip needs to be visible to the calculator too.
    final checkInsSnap = await _habits
        .doc(habitId)
        .collection('check_ins')
        .get();
    final statusByDate = {
      for (final d in checkInsSnap.docs)
        d.id: _checkInFromData(habitId, d.id, d.data()).status,
    };

    // The habit-doc read+write below runs in its own transaction — not
    // wrapped around the query above, since Firestore transactions can
    // only `.get()` individual documents, not run queries — so two
    // concurrent setCheckIn calls for the same habit (a rapid double-tap,
    // or several days toggled back-to-back in the calendar grid) can't
    // read the same stale longestStreak and overwrite each other's
    // update: the transaction retries automatically if the habit doc
    // changes between its read and commit.
    return _firestore.runTransaction((transaction) async {
      final habitDoc = await transaction.get(_habits.doc(habitId));
      final habit = _toDomain(habitDoc);

      final result = StreakCalculator.compute(
        frequencyType: habit.frequencyType,
        frequencyConfig: habit.frequencyConfig,
        createdAtLocal: habit.createdAt,
        statusByDate: statusByDate,
        today: DateTime.now(),
      );

      transaction.update(_habits.doc(habitId), {
        'currentStreak': result.currentStreak,
        'longestStreak': result.longestStreak > habit.longestStreak
            ? result.longestStreak
            : habit.longestStreak,
      });
      return result.currentStreak;
    });
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
    String? categoryId,
    bool clearCategoryId = false,
    int? targetCount,
    bool clearTargetCount = false,
    String? targetUnit,
    bool clearTargetUnit = false,
    bool isQuitHabit = false,
  }) async {
    final existing = _toDomain(await _habits.doc(id).get());
    final frequencyChanged = existing.frequencyType != frequencyType;

    await _habits.doc(id).update({
      ...HabitFirestoreCodec.forUpdate(
        name: name,
        emoji: emoji,
        colorHex: colorHex,
        frequencyType: frequencyType,
        frequencyConfig: frequencyConfig,
        reminderTime: reminderTime,
        description: description,
        categoryId: clearCategoryId ? null : (categoryId ?? existing.categoryId),
        targetCount: clearTargetCount
            ? null
            : (targetCount ?? existing.targetCount),
        targetUnit: clearTargetUnit ? null : (targetUnit ?? existing.targetUnit),
        isQuitHabit: isQuitHabit,
      ),
      if (frequencyChanged) 'currentStreak': 0,
    });
  }

  @override
  Future<void> archiveHabit(String id) => _habits.doc(id).update({
    'archivedAt': Timestamp.now(),
    'updatedAt': Timestamp.now(),
  });

  @override
  Future<void> unarchiveHabit(String id) => _habits.doc(id).update({
    'archivedAt': null,
    'updatedAt': Timestamp.now(),
  });

  @override
  Future<void> deleteHabit(String id) async {
    // Firestore doesn't cascade-delete subcollections on doc delete.
    // Firestore batch limit is 500 operations per commit. A power user
    // with years of daily check-ins can have 1000+ documents, which would
    // overflow a single batch and throw. We page through in chunks of 400
    // (leaving headroom for the final habit-doc delete).
    const batchSize = 400;
    final checkInsRef = _habits.doc(id).collection('check_ins');

    while (true) {
      final snap = await checkInsRef.limit(batchSize).get();
      if (snap.docs.isEmpty) break;

      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // If fewer docs than the page size were returned, we've deleted all.
      if (snap.docs.length < batchSize) break;
    }

    // Delete the habit document itself after all check-ins are gone.
    await _habits.doc(id).delete();
  }

  @override
  Future<void> reorderHabits(List<String> orderedIds) async {
    final batch = _firestore.batch();
    for (var i = 0; i < orderedIds.length; i++) {
      batch.update(_habits.doc(orderedIds[i]), {'sortOrder': i});
    }
    await batch.commit();
  }

  @override
  Stream<StreakResult> watchStreakDetail({
    required String habitId,
    required FrequencyType frequencyType,
    required FrequencyConfig frequencyConfig,
    required DateTime createdAt,
  }) {
    // No limit here — see the comment in _recalculateStreak(). The streak
    // detail shown to the user must reflect the same full history the
    // stored current/longest streak was computed from. Every status (not
    // just completed) is watched so a skip renders correctly.
    return _habits.doc(habitId).collection('check_ins').snapshots().map((
      snap,
    ) {
      return StreakCalculator.compute(
        frequencyType: frequencyType,
        frequencyConfig: frequencyConfig,
        createdAtLocal: createdAt,
        statusByDate: {
          for (final d in snap.docs)
            d.id: _checkInFromData(habitId, d.id, d.data()).status,
        },
        today: DateTime.now(),
      );
    });
  }

  @override
  Stream<List<HabitCategory>> watchCategories() {
    return _categories.orderBy('createdAt').snapshots().map(
      (snap) => snap.docs
          .map(
            (d) => HabitCategory(
              id: d.id,
              name: d.data()['name'] as String,
              emoji: d.data()['emoji'] as String,
              colorHex: d.data()['colorHex'] as String,
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
    await _categories.doc(id).set({
      'name': name,
      'emoji': emoji,
      'colorHex': colorHex,
      'createdAt': Timestamp.now(),
    });
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
  }) => _categories.doc(id).update({
    'name': name,
    'emoji': emoji,
    'colorHex': colorHex,
  });

  @override
  Future<void> deleteCategory(String id) async {
    final affected = await _habits.where('categoryId', isEqualTo: id).get();
    final batch = _firestore.batch();
    for (final doc in affected.docs) {
      batch.update(doc.reference, {'categoryId': null});
    }
    batch.delete(_categories.doc(id));
    await batch.commit();
  }

  Habit _toDomain(DocumentSnapshot<Map<String, dynamic>> doc) =>
      HabitFirestoreCodec.fromDocument(doc);
}
