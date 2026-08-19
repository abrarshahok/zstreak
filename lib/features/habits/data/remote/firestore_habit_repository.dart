import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../domain/check_in.dart';
import '../../domain/frequency.dart';
import '../../domain/habit.dart';
import '../../domain/habit_repository.dart';
import '../../domain/streak_calculator.dart';

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

  @override
  Stream<List<Habit>> watchActiveHabits() {
    // Feature 6: sort by sortOrder first, then createdAt as tiebreaker.
    return _habits
        .where('archivedAt', isNull: true)
        .orderBy('sortOrder')
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map(_toDomain).toList());
  }

  @override
  Stream<List<Habit>> watchArchivedHabits() {
    return _habits
        .where('archivedAt', isNull: false)
        .orderBy('archivedAt', descending: true)
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
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final doc = _habits.doc(id);
    await doc.set({
      'name': name,
      'emoji': emoji,
      'colorHex': colorHex,
      'frequencyType': frequencyType.toDbValue(),
      'frequencyConfig': frequencyConfig.toJson(),
      'reminderTime': reminderTime,
      'currentStreak': 0,
      'longestStreak': 0,
      'createdAt': Timestamp.fromDate(now),
      'archivedAt': null,
      'updatedAt': Timestamp.fromDate(now),
    });
    return _toDomain(await doc.get());
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
          final data = snap.data()!;
          return CheckIn(
            id: date,
            habitId: habitId,
            date: date,
            completed: data['completed'] as bool? ?? false,
            note: data['note'] as String?,
            loggedAt: (data['loggedAt'] as Timestamp).toDate(),
          );
        });
  }

  @override
  Stream<List<CheckIn>> watchHabitCheckIns(String habitId) {
    return _habits
        .doc(habitId)
        .collection('check_ins')
        .snapshots()
        .map(
          (snap) => snap.docs.map((doc) {
            final data = doc.data();
            return CheckIn(
              id: doc.id,
              habitId: habitId,
              date: doc.id,
              completed: data['completed'] as bool? ?? false,
              note: data['note'] as String?,
              loggedAt: (data['loggedAt'] as Timestamp).toDate(),
            );
          }).toList(),
        );
  }

  @override
  Future<void> setCheckIn({
    required String habitId,
    required String date,
    required bool completed,
    String? note,
  }) async {
    final doc = _habits.doc(habitId).collection('check_ins').doc(date);
    if (!completed) {
      await doc.delete();
    } else {
      // Merge so an existing note is preserved when only toggling completion.
      await doc.set({
        'completed': true,
        'note': ?note,
        'loggedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    }
    await _recalculateStreak(habitId);
  }

  Future<void> _recalculateStreak(String habitId) async {
    final habitDoc = await _habits.doc(habitId).get();
    final habit = _toDomain(habitDoc);

    final checkInsSnap = await _habits
        .doc(habitId)
        .collection('check_ins')
        .where('completed', isEqualTo: true)
        .get();
    final completedDates = checkInsSnap.docs.map((d) => d.id).toSet();

    final result = StreakCalculator.compute(
      frequencyType: habit.frequencyType,
      frequencyConfig: habit.frequencyConfig,
      createdAtLocal: habit.createdAt,
      completedDates: completedDates,
      frozenDates: habit.frozenDates,
      today: DateTime.now(),
    );

    await _habits.doc(habitId).update({
      'currentStreak': result.currentStreak,
      'longestStreak': result.longestStreak > habit.longestStreak
          ? result.longestStreak
          : habit.longestStreak,
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
  }) async {
    final existing = _toDomain(await _habits.doc(id).get());
    final frequencyChanged = existing.frequencyType != frequencyType;

    await _habits.doc(id).update({
      'name': name,
      'emoji': emoji,
      'colorHex': colorHex,
      'frequencyType': frequencyType.toDbValue(),
      'frequencyConfig': frequencyConfig.toJson(),
      'reminderTime': reminderTime,
      if (frequencyChanged) 'currentStreak': 0,
      'updatedAt': Timestamp.now(),
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
    final checkIns = await _habits.doc(id).collection('check_ins').get();
    final batch = _firestore.batch();
    for (final doc in checkIns.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_habits.doc(id));
    await batch.commit();
  }

  @override
  Future<void> useFreeze({
    required String habitId,
    required String date,
  }) async {
    final doc = await _habits.doc(habitId).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final freezes = data['streakFreezes'] as int? ?? 0;
    if (freezes <= 0) return;

    final rawFrozen = data['frozenDates'];
    final existing = rawFrozen is List
        ? rawFrozen.cast<String>().toSet()
        : <String>{};
    if (existing.contains(date)) return;

    await _habits.doc(habitId).update({
      'streakFreezes': freezes - 1,
      'frozenDates': [...existing, date],
      'updatedAt': Timestamp.now(),
    });
    await _recalculateStreak(habitId);
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
    return _habits
        .doc(habitId)
        .collection('check_ins')
        .where('completed', isEqualTo: true)
        .snapshots()
        .map((snap) {
          return StreakCalculator.compute(
            frequencyType: frequencyType,
            frequencyConfig: frequencyConfig,
            createdAtLocal: createdAt,
            completedDates: snap.docs.map((d) => d.id).toSet(),
            today: DateTime.now(),
          );
        });
  }

  Habit _toDomain(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final type = FrequencyType.fromDbValue(data['frequencyType'] as String);

    // Feature 1: parse frozen dates stored as a Firestore list of strings.
    final rawFrozen = data['frozenDates'];
    final frozenDates = rawFrozen is List
        ? rawFrozen.cast<String>().toSet()
        : const <String>{};

    return Habit(
      id: doc.id,
      name: data['name'] as String,
      emoji: data['emoji'] as String,
      colorHex: data['colorHex'] as String,
      frequencyType: type,
      frequencyConfig: FrequencyConfig.fromJson(
        type,
        Map<String, dynamic>.from(data['frequencyConfig'] as Map),
      ),
      reminderTime: data['reminderTime'] as String?,
      currentStreak: data['currentStreak'] as int? ?? 0,
      longestStreak: data['longestStreak'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      archivedAt: (data['archivedAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      streakFreezes: data['streakFreezes'] as int? ?? 1,
      frozenDates: frozenDates,
      sortOrder: data['sortOrder'] as int? ?? 0,
    );
  }
}
