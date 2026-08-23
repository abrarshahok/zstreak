import 'mood_entry.dart';

/// Storage-agnostic contract for daily mood/energy logs — a sibling to
/// [HabitRepository] rather than a method bag on it, since mood entries
/// aren't scoped to any one habit. Same Drift-for-guests /
/// Firestore-for-signed-in split, switched by the same auth-based provider
/// pattern as [habitRepositoryProvider].
abstract class MoodRepository {
  Stream<List<MoodEntry>> watchMoodEntries();

  Stream<MoodEntry?> watchMoodEntry(String date);

  Future<void> logMood({
    required String date,
    required int moodScore,
    int? energyScore,
    String? note,
  });
}
