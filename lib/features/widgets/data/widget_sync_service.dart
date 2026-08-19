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
  Future<void> syncHabits(
    List<Habit> habits,
    Future<CheckIn?> Function(String habitId, String date) getTodayCheckIn, {
    required bool isPremium,
  }) async {
    final today = todayLocalDateString();

    await HomeWidget.saveWidgetData<String>('premium_active', isPremium.toString());

    for (final habit in habits) {
      final checkIn = await getTodayCheckIn(habit.id, today);
      final completedToday = checkIn?.completed ?? false;

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
