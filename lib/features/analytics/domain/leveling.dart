/// A simple, deterministic leveling system computed entirely from existing
/// check-in history — no new persisted state. Replaces the old flat
/// "XP Earned" stat, which had no system behind it (a number that never
/// went anywhere).
///
/// XP: 10 per completed check-in, across every habit, ever — plus a 50-point
/// bonus each time any habit's longest streak has crossed one of the app's
/// existing streak milestones (3/7/14/21/30/50/66/100 days).
///
/// Levels: a triangular curve — level `n` requires `100 * n*(n+1)/2`
/// cumulative XP to reach, so each level costs progressively more than the
/// last (level 2 needs 100 more XP than level 1, level 3 needs 200 more than
/// level 2, and so on).
class LevelInfo {
  const LevelInfo({
    required this.level,
    required this.title,
    required this.xpIntoLevel,
    required this.xpForThisLevel,
    required this.totalXp,
  });

  final int level;
  final String title;

  /// XP earned since this level started.
  final int xpIntoLevel;

  /// Total XP this level requires (the denominator for [progress]).
  final int xpForThisLevel;
  final int totalXp;

  double get progress =>
      xpForThisLevel == 0 ? 1 : (xpIntoLevel / xpForThisLevel).clamp(0, 1);
}

class Leveling {
  Leveling._();

  static const milestones = [3, 7, 14, 21, 30, 50, 66, 100];

  static const List<String> _titles = [
    'Spark',
    'Flicker',
    'Flame',
    'Blaze',
    'Bonfire',
    'Wildfire',
    'Inferno',
  ];

  static int totalXp({
    required int totalCompletedCheckIns,
    required List<int> longestStreakPerHabit,
  }) {
    var milestoneBonus = 0;
    for (final longest in longestStreakPerHabit) {
      milestoneBonus += milestones.where((m) => longest >= m).length * 50;
    }
    return totalCompletedCheckIns * 10 + milestoneBonus;
  }

  static int _cumulativeXpToReach(int level) => 100 * level * (level + 1) ~/ 2;

  static LevelInfo compute(int xp) {
    var level = 1;
    while (_cumulativeXpToReach(level) <= xp) {
      level++;
    }
    final xpAtLevelStart = level == 1 ? 0 : _cumulativeXpToReach(level - 1);
    final xpForThisLevel = _cumulativeXpToReach(level) - xpAtLevelStart;
    final titleIndex = ((level - 1) ~/ 5).clamp(0, _titles.length - 1);
    return LevelInfo(
      level: level,
      title: _titles[titleIndex],
      xpIntoLevel: xp - xpAtLevelStart,
      xpForThisLevel: xpForThisLevel,
      totalXp: xp,
    );
  }
}
