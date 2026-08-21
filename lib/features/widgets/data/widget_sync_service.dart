import 'package:home_widget/home_widget.dart';

import '../../../core/utils/local_date.dart';
import '../../habits/domain/check_in.dart';
import '../../habits/domain/habit.dart';

const String habitWidgetProviderName = 'com.zstreak.app.HabitWidgetProvider';

/// Bridges habit data to the Android widget process (spec Section 2/12).
/// A widget runs in a separate process and can't query Drift/Firestore
/// directly — it reads whatever was last written here. Every value is
/// stored as a String: Android's SharedPreferences is strongly typed per
/// key, and the native side always reads with `getString`, so writing
/// any other type from Dart would crash the widget with a
/// ClassCastException the next time it redraws.
class WidgetSyncService {
  /// Full re-sync of every active habit — kept for cases that genuinely
  /// need it (e.g. a cold-start reconciliation), but NOT called on every
  /// mutation: syncing all habits to answer "one habit changed" scales
  /// with total habit count on every single check-in. Prefer
  /// [syncSingleHabit] for a targeted update.
  Future<void> syncHabits(
    List<Habit> habits,
    Future<CheckIn?> Function(String habitId, String date) getTodayCheckIn, {
    required bool isPremium,
  }) async {
    await HomeWidget.saveWidgetData<String>('premium_active', isPremium.toString());
    for (final habit in habits) {
      final checkIn = await getTodayCheckIn(habit.id, todayLocalDateString());
      await _writeHabit(habit, completedToday: checkIn?.completed ?? false);
    }
    await HomeWidget.updateWidget(qualifiedAndroidName: habitWidgetProviderName);
  }

  /// Syncs exactly one habit's widget data — the normal path after a
  /// create/check-in/update/archive/unarchive, since only that habit's
  /// displayed values could have changed. O(1) in habit count, unlike
  /// re-fetching and rewriting every active habit on every mutation.
  Future<void> syncSingleHabit(
    Habit habit,
    Future<CheckIn?> Function(String habitId, String date) getTodayCheckIn, {
    required bool isPremium,
  }) async {
    await HomeWidget.saveWidgetData<String>('premium_active', isPremium.toString());
    final checkIn = await getTodayCheckIn(habit.id, todayLocalDateString());
    await _writeHabit(habit, completedToday: checkIn?.completed ?? false);
    await HomeWidget.updateWidget(qualifiedAndroidName: habitWidgetProviderName);
  }

  Future<void> _writeHabit(Habit habit, {required bool completedToday}) async {
    await HomeWidget.saveWidgetData<String>('habit_${habit.id}_name', habit.name);
    await HomeWidget.saveWidgetData<String>('habit_${habit.id}_emoji', habit.emoji);
    await HomeWidget.saveWidgetData<String>('habit_${habit.id}_color', habit.colorHex);
    await HomeWidget.saveWidgetData<String>(
      'habit_${habit.id}_streak',
      habit.currentStreak.toString(),
    );
    await HomeWidget.saveWidgetData<String>(
      'habit_${habit.id}_completed_today',
      completedToday.toString(),
    );
  }

  /// Removes a deleted habit's widget data so it doesn't linger forever in
  /// the widget's SharedPreferences store with no owner to refresh it.
  Future<void> removeHabitData(String habitId) async {
    for (final suffix in ['name', 'emoji', 'color', 'streak', 'completed_today']) {
      await HomeWidget.saveWidgetData<String>('habit_${habitId}_$suffix', null);
    }
    await HomeWidget.updateWidget(qualifiedAndroidName: habitWidgetProviderName);
  }

  /// Called by the configuration screen (Section 2) when a widget
  /// instance is placed — persists which habit that specific instance
  /// shows, keyed by its Android-assigned widget id.
  Future<void> setWidgetHabit(int widgetId, String habitId) async {
    await HomeWidget.saveWidgetData<String>('widget_habit_$widgetId', habitId);
    await HomeWidget.updateWidget(qualifiedAndroidName: habitWidgetProviderName);
  }
}
