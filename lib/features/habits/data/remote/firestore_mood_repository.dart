import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../domain/mood_entry.dart';
import '../../domain/mood_repository.dart';

class FirestoreMoodRepository implements MoodRepository {
  FirestoreMoodRepository(this._firestore, this._uid, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final FirebaseFirestore _firestore;
  final String _uid;
  final Uuid _uuid;

  CollectionReference<Map<String, dynamic>> get _entries =>
      _firestore.collection('users').doc(_uid).collection('mood_entries');

  MoodEntry _fromDoc(String date, Map<String, dynamic> data) => MoodEntry(
    id: data['id'] as String? ?? _uuid.v4(),
    date: date,
    moodScore: data['moodScore'] as int,
    energyScore: data['energyScore'] as int?,
    note: data['note'] as String?,
    loggedAt: (data['loggedAt'] as Timestamp).toDate(),
  );

  @override
  Stream<List<MoodEntry>> watchMoodEntries() {
    return _entries
        .orderBy('date', descending: true)
        .limit(400)
        .snapshots()
        .map((snap) => snap.docs.map((d) => _fromDoc(d.id, d.data())).toList());
  }

  @override
  Stream<MoodEntry?> watchMoodEntry(String date) {
    return _entries
        .doc(date)
        .snapshots()
        .map((snap) => snap.exists ? _fromDoc(date, snap.data()!) : null);
  }

  @override
  Future<void> logMood({
    required String date,
    required int moodScore,
    int? energyScore,
    String? note,
  }) async {
    await _entries.doc(date).set({
      'moodScore': moodScore,
      'energyScore': ?energyScore,
      // Written unconditionally (not the null-aware `?note`) so clearing
      // the note in the UI actually clears it instead of merge preserving
      // whatever was previously stored.
      'note': note,
      'loggedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }
}
