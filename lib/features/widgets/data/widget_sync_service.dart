import 'package:home_widget/home_widget.dart';

import '../../../core/utils/local_date.dart';
import '../../habits/domain/check_in.dart';
import '../../habits/domain/habit.dart';
import '../../habits/domain/streak_calculator.dart';

const String habitWidgetProviderName = 'com.zstreak.app.HabitWidgetProvider';

/// Bridges habit data to the Android widget process (spec Section 2/12).
/// A widget runs in a separate process and can't query Drift/Firestore
/// directly — it reads whatever was last written here. Every value is
/// stored as a String: Android's SharedPreferences is strongly typed per
/// key, and the native side always reads with `getString`, so writing
/// any other type from Dart would crash the widget with a
/// ClassCastException the next time it redraws.
class WidgetSyncService {
  /// Same upper bound as HabitTile's own `cols = (availableWidth /
  /// _step).floor().clamp(4, 52)` (habit_tile.dart) — 52 whole Mon–Sun
  /// weeks is the most columns the in-app grid could ever show, and
  /// HabitWidgetProvider.kt's renderer clamps to the same [4, 52] range
  /// picked from the widget's real on-screen width. RemoteViews can't do
  /// custom Canvas drawing the way the in-app grid does, so the widget
  /// renders a plain bitmap on the native side instead; the native side
  /// takes just the tail (a whole number of weeks, since this is exactly
  /// divisible by 7) it has room to draw.
  static const int maxGridWeeks = 52;
  static const int gridDays = maxGridWeeks * 7;

  /// Full re-sync of every active habit — kept for cases that genuinely
  /// need it (e.g. a cold-start reconciliation), but NOT called on every
  /// mutation: syncing all habits to answer "one habit changed" scales
  /// with total habit count on every single check-in. Prefer
  /// [syncSingleHabit] for a targeted update.
  Future<void> syncHabits(
    List<Habit> habits,
    Future<CheckIn?> Function(String habitId, String date) getTodayCheckIn,
    Future<List<CheckIn>> Function(String habitId) getCheckIns, {
    required bool isPremium,
  }) async {
    await HomeWidget.saveWidgetData<String>(
      'premium_active',
      isPremium.toString(),
    );
    for (final habit in habits) {
      final checkIn = await getTodayCheckIn(habit.id, todayLocalDateString());
      final checkIns = await getCheckIns(habit.id);
      await writeHabitData(
        habit,
        completedToday: checkIn?.completed ?? false,
        checkIns: checkIns,
      );
    }
    await HomeWidget.updateWidget(
      qualifiedAndroidName: habitWidgetProviderName,
    );
  }

  /// Syncs exactly one habit's widget data — the normal path after a
  /// create/check-in/update/archive/unarchive, since only that habit's
  /// displayed values could have changed. O(1) in habit count, unlike
  /// re-fetching and rewriting every active habit on every mutation.
  Future<void> syncSingleHabit(
    Habit habit,
    Future<CheckIn?> Function(String habitId, String date) getTodayCheckIn,
    Future<List<CheckIn>> Function(String habitId) getCheckIns, {
    required bool isPremium,
  }) async {
    await HomeWidget.saveWidgetData<String>(
      'premium_active',
      isPremium.toString(),
    );
    final checkIn = await getTodayCheckIn(habit.id, todayLocalDateString());
    final checkIns = await getCheckIns(habit.id);
    await writeHabitData(
      habit,
      completedToday: checkIn?.completed ?? false,
      checkIns: checkIns,
    );
    await HomeWidget.updateWidget(
      qualifiedAndroidName: habitWidgetProviderName,
    );
  }

  /// Writes every field a widget instance reads for [habit] — name, emoji,
  /// color, streak, completedToday, and the grid. Public (not the
  /// `syncHabits`/`syncSingleHabit` entry points above) so the headless
  /// background isolate that handles a tap on the widget's own check-in
  /// button ([widgetInteractivityCallback] in widget_background_callback.dart)
  /// can reuse the exact same write instead of hand-rolling a partial one
  /// — that isolate has no habit repository decorator or Riverpod
  /// container to go through `WidgetSyncingHabitRepository` with, and a
  /// previous partial reimplementation there (streak + completedToday
  /// only) left the grid showing stale data after every check-in made
  /// directly from the widget.
  Future<void> writeHabitData(
    Habit habit, {
    required bool completedToday,
    required List<CheckIn> checkIns,
  }) async {
    await HomeWidget.saveWidgetData<String>(
      'habit_${habit.id}_name',
      habit.name,
    );
    await HomeWidget.saveWidgetData<String>(
      'habit_${habit.id}_emoji',
      habit.emoji,
    );
    await HomeWidget.saveWidgetData<String>(
      'habit_${habit.id}_color',
      habit.colorHex,
    );
    await HomeWidget.saveWidgetData<String>(
      'habit_${habit.id}_streak',
      habit.currentStreak.toString(),
    );
    await HomeWidget.saveWidgetData<String>(
      'habit_${habit.id}_completed_today',
      completedToday.toString(),
    );
    await HomeWidget.saveWidgetData<String>(
      'habit_${habit.id}_grid',
      _buildGridString(habit, checkIns),
    );
  }

  /// One character per day, oldest first, windowed and bucketed the same
  /// way HabitTile's `_TileMiniGrid` build its `cells` list — not just
  /// the same cell styling. In particular the window ends on the
  /// upcoming Sunday (`daysUntilSunday = 7 - today.weekday`), exactly
  /// like `_TileMiniGrid.build`, not on today itself: columns are real
  /// Mon–Sun calendar weeks, so today lands on whichever row its actual
  /// weekday puts it on and the rest of this week renders as neutral
  /// "not here yet" cells — the same shape the in-app grid has — rather
  /// than today always being forced onto the bottom row.
  ///
  /// [StreakCalculator] is the same engine HabitTile's grid reads from,
  /// so weekday/xPerWeek scheduling and run-length are correct instead of
  /// re-derived here: '.' not applicable (unscheduled, before creation,
  /// or not-yet-arrived), '0' missed, '1'-'9' completed at an intensity
  /// bucket mirroring _TileMiniGridPainter's `(runLength / 7).clamp(0.4,
  /// 1.0)` alpha ramp (bucket 1 ≈ 0.4 alpha, bucket 9 = 1.0 alpha).
  String _buildGridString(Habit habit, List<CheckIn> checkIns) {
    final statusByDate = {for (final c in checkIns) c.date: c.status};
    final today = DateTime.now();
    final result = StreakCalculator.compute(
      frequencyType: habit.frequencyType,
      frequencyConfig: habit.frequencyConfig,
      createdAtLocal: habit.createdAt,
      statusByDate: statusByDate,
      today: today,
    );
    final byDate = <String, HabitDayStatus>{
      for (final d in result.days) localDateString(d.date): d,
    };

    final todayDateOnly = DateTime(today.year, today.month, today.day);
    final daysUntilSunday = 7 - today.weekday;
    final windowEnd = todayDateOnly.add(Duration(days: daysUntilSunday));
    final windowStart = windowEnd.subtract(const Duration(days: gridDays - 1));

    final buffer = StringBuffer();
    for (var i = 0; i < gridDays; i++) {
      final day = windowStart.add(Duration(days: i));
      final status = byDate[localDateString(day)];
      if (status == null) {
        buffer.write('.');
        continue;
      }
      switch (status.status) {
        case DayStatus.completed:
          final intensity = (status.runLength / 7).clamp(0.4, 1.0);
          final bucket = (((intensity - 0.4) / 0.6) * 8).round().clamp(0, 8) + 1;
          buffer.write(bucket.toString());
        case DayStatus.missed:
          buffer.write('0');
        case DayStatus.notApplicable:
        case DayStatus.skipped:
        case DayStatus.future:
          buffer.write('.');
      }
    }
    return buffer.toString();
  }

  /// Removes a deleted habit's widget data so it doesn't linger forever in
  /// the widget's SharedPreferences store with no owner to refresh it.
  Future<void> removeHabitData(String habitId) async {
    for (final suffix in [
      'name',
      'emoji',
      'color',
      'streak',
      'completed_today',
      'grid',
    ]) {
      await HomeWidget.saveWidgetData<String>('habit_${habitId}_$suffix', null);
    }
    await HomeWidget.updateWidget(
      qualifiedAndroidName: habitWidgetProviderName,
    );
  }

  /// Called by the configuration screen (Section 2) when a widget
  /// instance is placed — persists which habit that specific instance
  /// shows, keyed by its Android-assigned widget id.
  Future<void> setWidgetHabit(int widgetId, String habitId) async {
    await HomeWidget.saveWidgetData<String>('widget_habit_$widgetId', habitId);
    await HomeWidget.updateWidget(
      qualifiedAndroidName: habitWidgetProviderName,
    );
  }
}
