import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Daily habit reminders (spec Section 2/8) — local scheduling only, so
/// it works identically for guest and signed-in users.
///
/// Two Android-specific realities this handles explicitly rather than
/// assuming away: posting notifications on API 33+ needs a runtime
/// `POST_NOTIFICATIONS` grant, not just the manifest permission; and
/// precise delivery needs `SCHEDULE_EXACT_ALARM`, which the user can
/// revoke at any time in system settings, so every schedule call checks
/// current availability rather than assuming a permission granted once
/// stays granted.
class NotificationService {
  NotificationService() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  ValueChanged<String>? onHabitTapped;

  /// Sets up the plugin, timezone data, and the notification-tap deep
  /// link — does NOT request the POST_NOTIFICATIONS permission itself;
  /// that happens at the deliberate onboarding moment (Stage 9, spec
  /// Section 3 screen 3), via [requestNotificationPermission].
  Future<void> initialize({required ValueChanged<String> onHabitTapped}) async {
    this.onHabitTapped = onHabitTapped;

    tz_data.initializeTimeZones();
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: _handleTap,
    );
  }

  void _handleTap(NotificationResponse response) {
    final habitId = response.payload;
    if (habitId != null) onHabitTapped?.call(habitId);
  }

  /// Returns false if the user denies it — reminders simply won't fire;
  /// the app must (and does) still function fully without them.
  Future<bool> requestNotificationPermission() async {
    final granted = await _androidPlugin?.requestNotificationsPermission();
    return granted ?? false;
  }

  /// The user can revoke `SCHEDULE_EXACT_ALARM` at any time in system
  /// settings, so this is checked fresh on every schedule call rather
  /// than cached from an earlier grant.
  Future<bool> canScheduleExactAlarms() async {
    return await _androidPlugin?.canScheduleExactNotifications() ?? false;
  }

  Future<void> requestExactAlarmPermission() async {
    await _androidPlugin?.requestExactAlarmsPermission();
  }

  /// Deterministic per-habit notification id so re-scheduling or
  /// cancelling always targets the right one.
  int _notificationIdFor(String habitId) => habitId.hashCode & 0x7FFFFFFF;

  Future<void> scheduleDailyReminder({
    required String habitId,
    required String habitName,
    required String habitEmoji,
    required int currentStreak,
    required TimeOfDay time,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    // Smart habit-specific body: streak-aware message.
    final body = currentStreak > 0
        ? '$habitEmoji $habitName — ${currentStreak}d streak on the line!'
        : '$habitEmoji $habitName — Start your streak today!';

    final exactAvailable = await canScheduleExactAlarms();
    await _plugin.zonedSchedule(
      id: _notificationIdFor(habitId),
      title: 'Time to lock in',
      body: body,
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'habit_reminders',
          'Habit reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: habitId,
      matchDateTimeComponents: DateTimeComponents.time,
      androidScheduleMode: exactAvailable
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Cancels the reminder tied to a habit — call on archive, delete, and
  /// whenever a reminder is cleared in Edit Habit (Section 3b: a
  /// reminder firing for an archived/deleted habit is a visible bug).
  Future<void> cancelReminder(String habitId) =>
      _plugin.cancel(id: _notificationIdFor(habitId));

  AndroidFlutterLocalNotificationsPlugin? get _androidPlugin => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
}
