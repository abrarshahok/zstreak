import 'package:flutter_test/flutter_test.dart';
import 'package:zstreak/features/habits/domain/check_in_status.dart';
import 'package:zstreak/features/habits/domain/frequency.dart';
import 'package:zstreak/features/habits/domain/streak_calculator.dart';

String _ds(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Map<String, CheckInStatus> _statusMap(
  Iterable<String> dates, [
  CheckInStatus status = CheckInStatus.completed,
]) => {for (final d in dates) d: status};

void main() {
  group('StreakCalculator — daily', () {
    test('consecutive completed days build a streak ending today', () {
      final today = DateTime(2026, 3, 10);
      final createdAt = DateTime(2026, 3, 1);
      final completed = {
        for (var d = 1; d <= 10; d++) '2026-03-${d.toString().padLeft(2, '0')}',
      };

      final result = StreakCalculator.compute(
        frequencyType: FrequencyType.daily,
        frequencyConfig: const DailyConfig(),
        createdAtLocal: createdAt,
        statusByDate: _statusMap(completed),
        today: today,
      );

      expect(result.currentStreak, 10);
      expect(result.longestStreak, 10);
    });

    test('a missed day resets the current streak but keeps the longest', () {
      final today = DateTime(2026, 3, 10);
      final createdAt = DateTime(2026, 3, 1);
      // Completed every day except March 5th.
      final completed = {
        for (var d = 1; d <= 10; d++)
          if (d != 5) '2026-03-${d.toString().padLeft(2, '0')}',
      };

      final result = StreakCalculator.compute(
        frequencyType: FrequencyType.daily,
        frequencyConfig: const DailyConfig(),
        createdAtLocal: createdAt,
        statusByDate: _statusMap(completed),
        today: today,
      );

      // March 6–10 (5 days) is the current run; it's also the longest,
      // since it's one day longer than the March 1–4 run before the miss.
      expect(result.currentStreak, 5);
      expect(result.longestStreak, 5);
    });

    test("today not yet checked in doesn't break the streak", () {
      final today = DateTime(2026, 3, 10);
      final createdAt = DateTime(2026, 3, 1);
      // Completed through March 9th; today (the 10th) has no check-in yet.
      final completed = {
        for (var d = 1; d <= 9; d++) '2026-03-${d.toString().padLeft(2, '0')}',
      };

      final result = StreakCalculator.compute(
        frequencyType: FrequencyType.daily,
        frequencyConfig: const DailyConfig(),
        createdAtLocal: createdAt,
        statusByDate: _statusMap(completed),
        today: today,
      );

      expect(result.currentStreak, 9);
      expect(result.days.last.status, DayStatus.future);
    });

    test('a day before the habit existed is never counted', () {
      final today = DateTime(2026, 3, 5);
      final createdAt = DateTime(2026, 3, 3);
      final result = StreakCalculator.compute(
        frequencyType: FrequencyType.daily,
        frequencyConfig: const DailyConfig(),
        createdAtLocal: createdAt,
        statusByDate: _statusMap(const {
          '2026-03-03',
          '2026-03-04',
          '2026-03-05',
        }),
        today: today,
      );

      // Only 3 days exist in the window at all (created on the 3rd).
      expect(result.days.length, 3);
      expect(result.currentStreak, 3);
    });

    test('a backfilled check-in before creation still gets a day entry and counts', () {
      // Habit created the 5th, but the user backfilled the 3rd and 4th too
      // ("Log a past day" allows this on Pro) — those days must still show
      // up on the grid and extend the streak, not silently vanish just
      // because they predate createdAt.
      final today = DateTime(2026, 3, 5);
      final createdAt = DateTime(2026, 3, 5);
      final result = StreakCalculator.compute(
        frequencyType: FrequencyType.daily,
        frequencyConfig: const DailyConfig(),
        createdAtLocal: createdAt,
        statusByDate: _statusMap(const {
          '2026-03-03',
          '2026-03-04',
          '2026-03-05',
        }),
        today: today,
      );

      expect(result.days.length, 3);
      expect(result.days.first.date, DateTime(2026, 3, 3));
      expect(result.currentStreak, 3);
    });
  });

  group('StreakCalculator — weekdays', () {
    // Anchored off the current-week Monday computed at runtime, so the
    // test never depends on which weekday a hardcoded literal date falls on.
    final anchor = DateTime(2026, 6, 15);
    final mondayA = anchor.subtract(Duration(days: anchor.weekday - 1));
    const weekdaysConfig = WeekdaysConfig(weekdays: [1, 2, 3, 4, 5]); // Mon–Fri

    test('non-scheduled days are notApplicable and never break the streak', () {
      final today = mondayA.add(const Duration(days: 7)); // following Monday
      final completed = {
        for (var i = 0; i <= 4; i++) _ds(mondayA.add(Duration(days: i))), // Mon–Fri
        _ds(today), // next Monday
      };

      final result = StreakCalculator.compute(
        frequencyType: FrequencyType.weekdays,
        frequencyConfig: weekdaysConfig,
        createdAtLocal: mondayA,
        statusByDate: _statusMap(completed),
        today: today,
      );

      // The intervening Saturday/Sunday must not appear as missed, and the
      // streak must run unbroken across them into the following Monday.
      expect(result.currentStreak, 6);
      expect(result.days.any((d) => d.status == DayStatus.missed), isFalse);
      expect(
        result.days.where((d) => d.status == DayStatus.notApplicable).length,
        2,
      );
    });

    test('a scheduled day with no check-in breaks the streak', () {
      final today = mondayA.add(const Duration(days: 4)); // Friday
      // Missed Wednesday.
      final completed = {
        _ds(mondayA),
        _ds(mondayA.add(const Duration(days: 1))),
        _ds(mondayA.add(const Duration(days: 3))),
        _ds(today),
      };

      final result = StreakCalculator.compute(
        frequencyType: FrequencyType.weekdays,
        frequencyConfig: weekdaysConfig,
        createdAtLocal: mondayA,
        statusByDate: _statusMap(completed),
        today: today,
      );

      expect(result.currentStreak, 2); // Thursday + Friday only
      expect(result.longestStreak, 2);
    });
  });

  group('StreakCalculator — xPerWeek', () {
    final anchor = DateTime(2026, 6, 15);
    final week0Monday = anchor.subtract(Duration(days: anchor.weekday - 1));
    const config = XPerWeekConfig(timesPerWeek: 3);

    test('an in-progress week under target is pending, not a break', () {
      final week1Monday = week0Monday.add(const Duration(days: 7));
      final week2Monday = week0Monday.add(const Duration(days: 14));
      final today = week2Monday.add(const Duration(days: 2)); // mid-week

      final completed = {
        for (var i = 0; i < 3; i++) _ds(week0Monday.add(Duration(days: i))), // week 0: meets 3
        for (var i = 0; i < 3; i++) _ds(week1Monday.add(Duration(days: i))), // week 1: meets 3
        _ds(week2Monday), // week 2 (current, in progress): only 1 of 3 so far
      };

      final result = StreakCalculator.compute(
        frequencyType: FrequencyType.xPerWeek,
        frequencyConfig: config,
        createdAtLocal: week0Monday,
        statusByDate: _statusMap(completed),
        today: today,
      );

      // Weeks 0 and 1 both met target; the in-progress week 2 must not
      // zero the streak out just because it hasn't hit target *yet*.
      expect(result.currentStreak, 2);
    });

    test('a fully-elapsed week under target breaks the streak', () {
      final week1Monday = week0Monday.add(const Duration(days: 7));
      final week2Monday = week0Monday.add(const Duration(days: 14));
      final week3Monday = week0Monday.add(const Duration(days: 21));
      final today = week3Monday;

      final completed = {
        for (var i = 0; i < 3; i++) _ds(week0Monday.add(Duration(days: i))), // week 0: meets
        _ds(week1Monday), // week 1: only 1 of 3 — misses target, fully elapsed
        for (var i = 0; i < 3; i++) _ds(week2Monday.add(Duration(days: i))), // week 2: meets
      };

      final result = StreakCalculator.compute(
        frequencyType: FrequencyType.xPerWeek,
        frequencyConfig: config,
        createdAtLocal: week0Monday,
        statusByDate: _statusMap(completed),
        today: today,
      );

      // Week 1's miss resets the streak; week 2 restarts it at 1.
      expect(result.currentStreak, 1);
      expect(result.longestStreak, 1);
    });
  });

  group('StreakResult.completionRate', () {
    test('excludes notApplicable and future days from the rate', () {
      final today = DateTime(2026, 3, 10);
      final createdAt = DateTime(2026, 3, 1);
      // Completed March 1–5; 6–9 are missed; the 10th (today) is future.
      final completed = {
        '2026-03-01', '2026-03-02', '2026-03-03', '2026-03-04', '2026-03-05',
      };

      final result = StreakCalculator.compute(
        frequencyType: FrequencyType.daily,
        frequencyConfig: const DailyConfig(),
        createdAtLocal: createdAt,
        statusByDate: _statusMap(completed),
        today: today,
      );

      expect(result.completionRate, closeTo(5 / 9, 0.0001));
    });

    test('is zero when there are no relevant days at all', () {
      final today = DateTime(2026, 3, 10);
      final result = StreakCalculator.compute(
        frequencyType: FrequencyType.daily,
        frequencyConfig: const DailyConfig(),
        createdAtLocal: today,
        statusByDate: const {},
        today: today,
      );
      expect(result.completionRate, 0);
    });
  });

  group('StreakCalculator — skipped days', () {
    test('a skipped day is streak-neutral, like a non-scheduled day', () {
      final today = DateTime(2026, 3, 10);
      final createdAt = DateTime(2026, 3, 1);
      // Completed 1–4 and 6–10; the 5th was explicitly skipped, not missed.
      final statusByDate = {
        for (var d = 1; d <= 10; d++)
          if (d != 5)
            '2026-03-${d.toString().padLeft(2, '0')}': CheckInStatus.completed,
        '2026-03-05': CheckInStatus.skipped,
      };

      final result = StreakCalculator.compute(
        frequencyType: FrequencyType.daily,
        frequencyConfig: const DailyConfig(),
        createdAtLocal: createdAt,
        statusByDate: statusByDate,
        today: today,
      );

      // The skip must not reset the streak the way a real miss would — it
      // just doesn't add to it either, so the total is the 9 actually
      // completed days (1-4, then 6-10), unbroken across the skip.
      expect(result.currentStreak, 9);
      expect(result.longestStreak, 9);
      expect(
        result.days.firstWhere((d) => d.date == DateTime(2026, 3, 5)).status,
        DayStatus.skipped,
      );
    });

    test('a skipped day is excluded from the completion rate', () {
      final today = DateTime(2026, 3, 6);
      final createdAt = DateTime(2026, 3, 1);
      // 1–4 completed, 5 skipped, 6 (today) is future.
      final statusByDate = {
        '2026-03-01': CheckInStatus.completed,
        '2026-03-02': CheckInStatus.completed,
        '2026-03-03': CheckInStatus.completed,
        '2026-03-04': CheckInStatus.completed,
        '2026-03-05': CheckInStatus.skipped,
      };

      final result = StreakCalculator.compute(
        frequencyType: FrequencyType.daily,
        frequencyConfig: const DailyConfig(),
        createdAtLocal: createdAt,
        statusByDate: statusByDate,
        today: today,
      );

      // Only the 4 completed days count toward the rate — the skip and the
      // still-future today are both excluded, not counted as misses.
      expect(result.completionRate, 1.0);
    });
  });
}
