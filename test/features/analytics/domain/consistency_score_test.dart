import 'package:flutter_test/flutter_test.dart';
import 'package:zstreak/features/analytics/domain/consistency_score.dart';

void main() {
  group('ConsistencyScore.compute', () {
    test('is zero for an empty history', () {
      expect(ConsistencyScore.compute([]), 0);
    });

    test('is the flat rate when every day is identical', () {
      final allDone = List.filled(20, 1.0);
      expect(ConsistencyScore.compute(allDone), closeTo(1.0, 0.0001));

      final allMissed = List.filled(20, 0.0);
      expect(ConsistencyScore.compute(allMissed), closeTo(0.0, 0.0001));
    });

    test('weights recent days more than older ones', () {
      // Same 10 days, same total count of good/bad days (5 each), but the
      // good days are recent in one case and old in the other — the
      // smoothed score must be higher when the good days are recent.
      final goodRecently = [
        0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0,
      ];
      final goodLongAgo = [1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0];

      final recentScore = ConsistencyScore.compute(goodRecently);
      final oldScore = ConsistencyScore.compute(goodLongAgo);

      expect(recentScore, greaterThan(oldScore));
      // Both are flat 50% under a plain ratio — the smoothing is what
      // must separate them.
      expect(recentScore, greaterThan(0.5));
      expect(oldScore, lessThan(0.5));
    });
  });
}
