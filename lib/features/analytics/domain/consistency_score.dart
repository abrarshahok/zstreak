import 'dart:math' as math;

/// Exponentially-weighted consistency score — recent days count more than
/// older ones. A flat ratio (completed / total) treats a rough patch from
/// six weeks ago exactly the same as one from yesterday, which means a
/// genuinely-improved recent run stays diluted by old history for a long
/// time, and a habit that's just started slipping doesn't show it until
/// enough bad days pile up. This is the "smoothed strength score" gap
/// flagged against Loop's habit-strength number in the analytics audit.
class ConsistencyScore {
  ConsistencyScore._();

  /// [dailyRates] must be ordered oldest-first — one entry per relevant day
  /// in the window, each already a 0..1 completion fraction for that day
  /// (a single habit's 0-or-1, or several habits' pooled fraction).
  /// [halfLifeDays] controls how fast old days fade: a day that many days
  /// in the past carries half the weight of today.
  static double compute(List<double> dailyRates, {double halfLifeDays = 10}) {
    if (dailyRates.isEmpty) return 0;
    final decay = math.pow(0.5, 1 / halfLifeDays).toDouble();
    var weightedSum = 0.0;
    var weightTotal = 0.0;
    var weight = 1.0;
    // Walk backward from the most recent day so `weight` decays correctly
    // regardless of how long the window is.
    for (var i = dailyRates.length - 1; i >= 0; i--) {
      weightedSum += dailyRates[i] * weight;
      weightTotal += weight;
      weight *= decay;
    }
    return weightedSum / weightTotal;
  }
}
