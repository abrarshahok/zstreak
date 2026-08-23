import 'package:flutter/material.dart';

const _kMonthAbbr = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// GitHub-style year contribution grid — the gap the analytics audit
/// flagged against HabitKit/Loop Habits/LifeGrid: nothing in ZStreak
/// showed a full year of history at a glance. Horizontally scrollable so
/// it works at any width without a bespoke CustomPainter; ends on the
/// upcoming Sunday so full calendar weeks line up column-by-column, the
/// same convention the home-screen widget's own grid already uses.
///
/// Framed with the date range it covers and an active-day count above,
/// and a "Less → More" legend below — a bare grid of colored squares
/// with no key and no sense of what period it spans doesn't actually
/// tell anyone anything, however good it looks.
class YearHeatmap extends StatelessWidget {
  const YearHeatmap({
    super.key,
    required this.intensityByDate,
    required this.accent,
    required this.emptyColor,
    required this.textPrimary,
    required this.textMuted,
    this.days = 371, // 53 whole weeks
  });

  /// "YYYY-MM-DD" → 0..1 intensity for that day. A missing key renders as
  /// [emptyColor] (no data / not applicable / before history began).
  final Map<String, double> intensityByDate;
  final Color accent;
  final Color emptyColor;
  final Color textPrimary;
  final Color textMuted;
  final int days;

  static const _cell = 11.0;
  static const _gap = 3.0;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    final daysUntilSunday = 7 - todayDateOnly.weekday;
    final windowEnd = todayDateOnly.add(Duration(days: daysUntilSunday));
    final windowStart = windowEnd.subtract(Duration(days: days - 1));
    final weeks = (days / 7).ceil();

    final activeDays = intensityByDate.values.where((v) => v > 0).length;
    final rangeLabel = windowStart.year == todayDateOnly.year
        ? '${_kMonthAbbr[windowStart.month - 1]} – ${_kMonthAbbr[todayDateOnly.month - 1]} ${todayDateOnly.year}'
        : '${_kMonthAbbr[windowStart.month - 1]} ${windowStart.year} – ${_kMonthAbbr[todayDateOnly.month - 1]} ${todayDateOnly.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(rangeLabel, style: TextStyle(color: textMuted, fontSize: 11)),
            const Spacer(),
            Text(
              '$activeDays active day${activeDays == 1 ? '' : 's'}',
              style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 7 * (_cell + _gap),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse:
                true, // starts scrolled to the most recent (rightmost) week
            child: Row(
              children: List.generate(weeks, (week) {
                return Padding(
                  padding: const EdgeInsets.only(right: _gap),
                  child: Column(
                    children: List.generate(7, (dow) {
                      final date = windowStart.add(
                        Duration(days: week * 7 + dow),
                      );
                      final key =
                          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                      final isFuture = date.isAfter(todayDateOnly);
                      final intensity = intensityByDate[key];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: _gap),
                        child: Container(
                          width: _cell,
                          height: _cell,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2.5),
                            color: isFuture || intensity == null
                                ? emptyColor
                                : accent.withValues(
                                    alpha: 0.12 + intensity.clamp(0, 1) * 0.78,
                                  ),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Less', style: TextStyle(color: textMuted, fontSize: 10)),
            const SizedBox(width: 5),
            ...List.generate(4, (i) {
              final alpha = 0.12 + (i / 3) * 0.78;
              return Padding(
                padding: const EdgeInsets.only(left: 3),
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: accent.withValues(alpha: alpha),
                  ),
                ),
              );
            }),
            const SizedBox(width: 5),
            Text('More', style: TextStyle(color: textMuted, fontSize: 10)),
          ],
        ),
      ],
    );
  }
}
