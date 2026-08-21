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
  }) {
    switch (frequencyType) {
      case FrequencyType.daily:
        return _computeDaily(
          isScheduled: (_) => true,
          createdAtLocal: createdAtLocal,
          completedDates: completedDates,
          today: today,
        );
      case FrequencyType.weekdays:
        final weekdays = (frequencyConfig as WeekdaysConfig).weekdays.toSet();
        return _computeDaily(
          isScheduled: (day) => weekdays.contains(day.weekday),
          createdAtLocal: createdAtLocal,
          completedDates: completedDates,
          today: today,
        );
      case FrequencyType.xPerWeek:
        return _computeXPerWeek(
          config: frequencyConfig as XPerWeekConfig,
          createdAtLocal: createdAtLocal,
          completedDates: completedDates,
          today: today,
        );
    }
  }

  /// Shared engine for daily and weekday-scheduled habits: walk forward
  /// day by day, only scheduled days can extend or break the run.
  static StreakResult _computeDaily({
    required bool Function(DateTime day) isScheduled,
    required DateTime createdAtLocal,
    required Set<String> completedDates,
    required DateTime today,
  }) {
    final createdDateOnly = DateTime(
      createdAtLocal.year,
      createdAtLocal.month,
      createdAtLocal.day,
    );
    final start = _earliestRelevantDate(createdDateOnly, completedDates);
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
      final isToday = day == end;

      if (isCompleted) {
        streak += 1;
        if (streak > longest) longest = streak;
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

  static StreakResult _computeXPerWeek({
    required XPerWeekConfig config,
    required DateTime createdAtLocal,
    required Set<String> completedDates,
    required DateTime today,
  }) {
    final end = DateTime(today.year, today.month, today.day);
    final createdDateOnly = DateTime(
      createdAtLocal.year,
      createdAtLocal.month,
      createdAtLocal.day,
    );
    final start = _weekStart(
      _earliestRelevantDate(createdDateOnly, completedDates),
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
        final completed = completedDates.contains(dateStr);
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

  /// The earliest day the grid/streak walk needs to consider — normally
  /// the habit's own creation date, but extended earlier when a
  /// backfilled check-in predates it ("Log a past day" and the
  /// calendar grid both allow logging before a habit's creation date on
  /// Pro), so that day actually gets a [HabitDayStatus] entry to render
  /// instead of the check-in existing in storage with nowhere to show.
  static DateTime _earliestRelevantDate(
    DateTime createdDateOnly,
    Set<String> completedDates,
  ) {
    var earliest = createdDateOnly;
    for (final dateStr in completedDates) {
      final date = DateTime.parse(dateStr);
      if (date.isBefore(earliest)) earliest = date;
    }
    return earliest;
  }

  static DateTime _weekStart(DateTime day, bool weekStartsOnMonday) {
    final isoWeekday = day.weekday; // 1 = Monday .. 7 = Sunday
    final offset = weekStartsOnMonday ? isoWeekday - 1 : isoWeekday % 7;
    return day.subtract(Duration(days: offset));
  }
}
