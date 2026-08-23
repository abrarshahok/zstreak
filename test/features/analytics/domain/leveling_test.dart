import 'package:flutter_test/flutter_test.dart';
import 'package:zstreak/features/analytics/domain/leveling.dart';

void main() {
  group('Leveling.totalXp', () {
    test('10 XP per completed check-in, no milestone bonus below 3 days', () {
      final xp = Leveling.totalXp(
        totalCompletedCheckIns: 5,
        longestStreakPerHabit: [2],
      );
      expect(xp, 50);
    });

    test('adds a 50-point bonus per milestone a habit has ever crossed', () {
      // A longest streak of 10 has crossed the 3-day and 7-day milestones
      // (but not 14+) — two bonuses.
      final xp = Leveling.totalXp(
        totalCompletedCheckIns: 0,
        longestStreakPerHabit: [10],
      );
      expect(xp, 100);
    });

    test('sums bonuses independently across multiple habits', () {
      final xp = Leveling.totalXp(
        totalCompletedCheckIns: 0,
        // habit A: crossed 3,7 (2 bonuses). habit B: crossed 3,7,14,21,30 (5).
        longestStreakPerHabit: [10, 35],
      );
      expect(xp, (2 + 5) * 50);
    });
  });

  group('Leveling.compute', () {
    test('starts at level 1 with zero XP', () {
      final info = Leveling.compute(0);
      expect(info.level, 1);
      expect(info.xpIntoLevel, 0);
      expect(info.xpForThisLevel, 100); // level 1 requires 100 cumulative XP
    });

    test('reaching the cumulative threshold advances exactly one level', () {
      // Level 1 needs 100 XP total to complete.
      final info = Leveling.compute(100);
      expect(info.level, 2);
      expect(info.xpIntoLevel, 0);
    });

    test('progress reflects partial advancement within the current level', () {
      final info = Leveling.compute(50);
      expect(info.level, 1);
      expect(info.xpIntoLevel, 50);
      expect(info.progress, closeTo(0.5, 0.0001));
    });

    test('title changes every 5 levels', () {
      // Level 1 → titles[0]; level 6 → titles[1].
      final level1 = Leveling.compute(0);
      // Cumulative XP to reach level 6: sum of 100*n*(n+1)/2 for n=1..5.
      var xpForLevel6 = 0;
      for (var n = 1; n <= 5; n++) {
        xpForLevel6 = 100 * n * (n + 1) ~/ 2;
      }
      final level6 = Leveling.compute(xpForLevel6);
      expect(level1.title, isNot(level6.title));
    });
  });
}
