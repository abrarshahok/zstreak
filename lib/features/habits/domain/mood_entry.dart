/// A single day's mood/energy log — whole-day, not tied to any one habit,
/// mirroring [CheckIn]'s date-keyed, one-per-day shape so it can be joined
/// against check-in history for the Analytics "Mood & Consistency"
/// correlation section.
class MoodEntry {
  const MoodEntry({
    required this.id,
    required this.date,
    required this.moodScore,
    this.energyScore,
    this.note,
    required this.loggedAt,
  });

  final String id;

  /// Local calendar date, "YYYY-MM-DD".
  final String date;

  /// 1 (lowest) through 5 (highest).
  final int moodScore;

  /// 1 (lowest) through 5 (highest), optional.
  final int? energyScore;
  final String? note;
  final DateTime loggedAt;

  static const int minScore = 1;
  static const int maxScore = 5;

  static const List<String> moodEmoji = ['😞', '🙁', '😐', '🙂', '😄'];
}
