import '../../../core/utils/local_date.dart';
import 'frequency.dart';

/// Per-day classification used by the contribution grid. `notApplicable`
/// covers both "before this habit existed" and, for weekday-scheduled
/// habits, non-scheduled days — spec Section 5a says both must render as
/// neutral, never as a miss.
enum DayStatus { notApplicable, missed, completed, future }

class HabitDayStatus {
  const HabitDayStatus({
    required this.date,
    required this.status,
    this.runLength = 0,
  });

  final DateTime date;
  final DayStatus status;

  /// For a completed day, how many consecutive qualifying periods end
  /// here — used to ramp the grid cell's glow intensity (Section 4).
  final int runLength;
}

class StreakResult {
  const StreakResult({
    required this.currentStreak,
    required this.longestStreak,
    required this.days,
  });

  final int currentStreak;
  final int longestStreak;
  final List<HabitDayStatus> days;

  /// Completed / (completed + missed) — Section 3b's "completion %",
  /// excluding not-applicable and not-yet-arrived days.
  double get completionRate {
    final completed = days.where((d) => d.status == DayStatus.completed).length;
    final missed = days.where((d) => d.status == DayStatus.missed).length;
    final relevant = completed + missed;
    return relevant == 0 ? 0 : completed / relevant;
  }
}

/// Implements the three frequency-specific streak rules from spec Section
/// 5a. Always recomputed from full check-in history on write (never on
/// read — screens read the stored `current_streak`/`longest_streak`
/// fields), so it stays correct across backfilled/out-of-order check-ins
/// without incremental-update bugs.
class StreakCalculator {
  StreakCalculator._();

  static StreakResult compute({
    required FrequencyType frequencyType,
    required FrequencyConfig frequencyConfig,
    required DateTime createdAtLocal,
    required Set<String> completedDates,
    required DateTime today,

    /// Feature 1 – Streak Freeze: dates in this set are treated as
    /// completed for streak purposes even if not in [completedDates].
    Set<String> frozenDates = const {},
  }) {
    switch (frequencyType) {
      case FrequencyType.daily:
        return _computeDaily(
          isScheduled: (_) => true,
          createdAtLocal: createdAtLocal,
          completedDates: completedDates,
          frozenDates: frozenDates,
          today: today,
        );
      case FrequencyType.weekdays:
        final weekdays = (frequencyConfig as WeekdaysConfig).weekdays.toSet();
        return _computeDaily(
          isScheduled: (day) => weekdays.contains(day.weekday),
          createdAtLocal: createdAtLocal,
          completedDates: completedDates,
          frozenDates: frozenDates,
          today: today,
        );
      case FrequencyType.xPerWeek:
        return _computeXPerWeek(
          config: frequencyConfig as XPerWeekConfig,
          createdAtLocal: createdAtLocal,
          completedDates: completedDates,
          frozenDates: frozenDates,
          today: today,
        );
    }
  }

  /// Shared engine for daily and weekday-scheduled habits: walk forward
  /// day by day, only scheduled days can extend or break the run.
  ///
  /// A day in [frozenDates] that would otherwise be a miss is treated as
  /// completed for streak continuity (Feature 1 – Streak Freeze).
  static StreakResult _computeDaily({
    required bool Function(DateTime day) isScheduled,
    required DateTime createdAtLocal,
    required Set<String> completedDates,
    required Set<String> frozenDates,
    required DateTime today,
  }) {
    final start = DateTime(
      createdAtLocal.year,
      createdAtLocal.month,
      createdAtLocal.day,
    );
    final end = DateTime(today.year, today.month, today.day);

    var streak = 0;
    var longest = 0;
    final days = <HabitDayStatus>[];

    for (
      var day = start;
      !day.isAfter(end);
      day = day.add(const Duration(days: 1))
    ) {
      final scheduled = isScheduled(day);
      if (!scheduled) {
        days.add(HabitDayStatus(date: day, status: DayStatus.notApplicable));
        continue;
      }

      final dateStr = localDateString(day);
      final isCompleted = completedDates.contains(dateStr);
      final isFrozen = frozenDates.contains(dateStr);
      final isToday = day == end;

      if (isCompleted || isFrozen) {
        streak += 1;
        if (streak > longest) longest = streak;
        // Frozen days render as completed in the grid — they kept the streak.
        days.add(
          HabitDayStatus(
            date: day,
            status: DayStatus.completed,
            runLength: streak,
          ),
        );
      } else if (isToday) {
        // Today hasn't ended yet — not a miss, just not done (yet).
        days.add(HabitDayStatus(date: day, status: DayStatus.future));
      } else {
        streak = 0;
        days.add(HabitDayStatus(date: day, status: DayStatus.missed));
      }
    }

    return StreakResult(
      currentStreak: streak,
      longestStreak: longest,
      days: days,
    );
  }

  /// For xPerWeek habits, frozen dates count toward the weekly target —
  /// a frozen day is treated as a completed check-in for that week.
  static StreakResult _computeXPerWeek({
    required XPerWeekConfig config,
    required DateTime createdAtLocal,
    required Set<String> completedDates,
    required Set<String> frozenDates,
    required DateTime today,
  }) {
    final end = DateTime(today.year, today.month, today.day);
    final start = _weekStart(
      DateTime(createdAtLocal.year, createdAtLocal.month, createdAtLocal.day),
      config.weekStartsOnMonday,
    );

    var streak = 0;
    var longest = 0;
    final days = <HabitDayStatus>[];

    for (
      var weekStart = start;
      !weekStart.isAfter(end);
      weekStart = weekStart.add(const Duration(days: 7))
    ) {
      final weekEnd = weekStart.add(const Duration(days: 6));
      final isCurrentWeek = !weekStart.isAfter(end) && !weekEnd.isBefore(end);

      var count = 0;
      for (
        var day = weekStart;
        !day.isAfter(weekEnd) && !day.isAfter(end);
        day = day.add(const Duration(days: 1))
      ) {
        final dateStr = localDateString(day);
        final completed =
            completedDates.contains(dateStr) || frozenDates.contains(dateStr);
        if (completed) count += 1;
        days.add(
          HabitDayStatus(
            date: day,
            status: completed ? DayStatus.completed : DayStatus.notApplicable,
          ),
        );
      }

      if (count >= config.timesPerWeek) {
        streak += 1;
        if (streak > longest) longest = streak;
      } else if (!isCurrentWeek) {
        // A fully-elapsed week that missed its target breaks the streak.
        streak = 0;
      }
      // An in-progress week under target is "pending" — neither counted
      // nor broken (spec Section 5a).
    }

    return StreakResult(
      currentStreak: streak,
      longestStreak: longest,
      days: days,
    );
  }

  static DateTime _weekStart(DateTime day, bool weekStartsOnMonday) {
    final isoWeekday = day.weekday; // 1 = Monday .. 7 = Sunday
    final offset = weekStartsOnMonday ? isoWeekday - 1 : isoWeekday % 7;
    return day.subtract(Duration(days: offset));
  }
}
