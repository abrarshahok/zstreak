import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Notification channel IDs — each maps to a distinct Android channel so
/// users can silence individual categories without losing all notifications.
///
/// habitReminders/streakAlerts carry a `_v2` suffix: a channel's sound is
/// locked in the moment Android first creates it, so switching these two
/// to the alarm-stream sound below needed a fresh channel id — reusing the
/// old one would've silently kept the old default notification sound for
/// anyone who'd already received a notification through it.
class NotificationChannels {
  static const habitReminders = 'habit_reminders_v2';
  static const streakAlerts = 'streak_alerts_v2';
  static const milestones = 'milestones';
  static const weeklySummary = 'weekly_summary';
  static const proUpsell = 'pro_upsell';
}

/// Notification ID namespaces — kept well apart to avoid collisions.
/// Habit-scoped IDs use `habitId.hashCode & 0x7FFFFFFF`.
/// Fixed IDs use constants below.
class NotificationIds {
  static const weeklySummary = 900_000_001;
  static const proUpsell = 900_000_002;

  /// Streak-at-risk: per-habit, offset into a separate range.
  static int streakAtRisk(String habitId) =>
      (habitId.hashCode & 0x3FFFFFFF) + 0x40000000;

  /// Milestone: per-habit, offset into yet another range.
  static int milestone(String habitId) =>
      (habitId.hashCode & 0x1FFFFFFF) + 0x60000000;
}

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

  bool _initialized = false;

  /// Sets up the plugin, timezone data, and the notification-tap deep
  /// link — does NOT request the POST_NOTIFICATIONS permission itself;
  /// that happens at the deliberate onboarding moment (Stage 9, spec
  /// Section 3 screen 3), via [requestNotificationPermission].
  Future<void> initialize({required ValueChanged<String> onHabitTapped}) async {
    if (_initialized) return;
    this.onHabitTapped = onHabitTapped;

    tz_data.initializeTimeZones();
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));

    // Not @mipmap/ic_launcher — Android forces every notification/status-
    // bar icon to solid white, discarding all color, so the app's actual
    // full-color icon rendered as a shapeless blob there. This is a
    // dedicated white-silhouette asset (see its own doc comment).
    const androidSettings = AndroidInitializationSettings(
      '@drawable/ic_stat_notify',
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: _handleTap,
    );
    _initialized = true;
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

  /// Returns true if POST_NOTIFICATIONS is currently granted.
  /// On Android < 13 (API 33) notifications are always enabled by default.
  Future<bool> areNotificationsEnabled() async {
    return await _androidPlugin?.areNotificationsEnabled() ?? true;
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

  // ─── Schedule helpers ──────────────────────────────────────────────────────

  Future<bool> get _exactAvailable => canScheduleExactAlarms();

  AndroidScheduleMode _scheduleMode(bool exact) => exact
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;

  // ─── 1. Daily habit reminder ───────────────────────────────────────────────

  /// [scheduledWeekdays] restricts delivery to those ISO weekdays (1=Mon..
  /// 7=Sun) — pass null/empty for a habit with no such restriction (daily,
  /// or xPerWeek where any day counts). Without this, a Mon/Wed/Fri habit
  /// used to get nagged every single day regardless of its own schedule.
  Future<void> scheduleDailyReminder({
    required String habitId,
    required String habitName,
    required String habitEmoji,
    required int currentStreak,
    required TimeOfDay time,
    List<int>? scheduledWeekdays,
  }) async {
    // Clear whatever was scheduled before (either style) so switching a
    // habit between "every day" and "specific days" — or editing which
    // days — never leaves a stale schedule from the old configuration.
    await cancelReminder(habitId);

    // Smart habit-specific body: streak-aware message.
    final body = currentStreak > 0
        ? '$habitEmoji $habitName — ${currentStreak}d streak on the line!'
        : '$habitEmoji $habitName — Start your streak today!';

    NotificationDetails details() => NotificationDetails(
      android: AndroidNotificationDetails(
        NotificationChannels.habitReminders,
        'Habit reminders',
        channelDescription: 'Daily reminders for your habits',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        // The default notification blip is too easy to miss — this
        // plays the device's actual alarm sound through the alarm
        // audio stream instead, which is louder and more likely to
        // cut through silent/Do Not Disturb.
        playSound: true,
        sound: const UriAndroidNotificationSound(
          'content://settings/system/alarm_alert',
        ),
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );

    final exact = await _exactAvailable;

    if (scheduledWeekdays == null || scheduledWeekdays.isEmpty) {
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
      await _plugin.zonedSchedule(
        id: _notificationIdFor(habitId),
        title: 'Time to lock in 🔒',
        body: body,
        scheduledDate: scheduled,
        notificationDetails: details(),
        payload: habitId,
        matchDateTimeComponents: DateTimeComponents.time,
        androidScheduleMode: _scheduleMode(exact),
      );
      return;
    }

    // One repeating notification per scheduled weekday — there's no
    // single DateTimeComponents value for "a specific subset of
    // weekdays", so each day gets its own id and its own weekly repeat
    // (same dayOfWeekAndTime pattern the weekly summary already uses).
    for (final weekday in scheduledWeekdays) {
      await _plugin.zonedSchedule(
        id: _weekdayReminderId(habitId, weekday),
        title: 'Time to lock in 🔒',
        body: body,
        scheduledDate: _nextInstanceOfWeekdayTime(weekday, time),
        notificationDetails: details(),
        payload: habitId,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        androidScheduleMode: _scheduleMode(exact),
      );
    }
  }

  tz.TZDateTime _nextInstanceOfWeekdayTime(int isoWeekday, TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    while (scheduled.weekday != isoWeekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  int _weekdayReminderId(String habitId, int weekday) =>
      Object.hash(habitId, weekday) & 0x7FFFFFFF;

  // ─── 2. Streak-at-risk alert ───────────────────────────────────────────────

  /// Schedules a one-shot notification at [fireAt] warning the user their
  /// streak is at risk. Call this after a successful check-in to schedule
  /// the *next* day's risk alert, and cancel it when they check in.
  ///
  /// [fireAt] should be e.g. 9 PM local time on the habit's next due date.
  Future<void> scheduleStreakAtRisk({
    required String habitId,
    required String habitName,
    required String habitEmoji,
    required int currentStreak,
    required DateTime fireAt,
  }) async {
    if (currentStreak == 0) return; // no streak to protect

    final scheduled = tz.TZDateTime.from(fireAt, tz.local);
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) return;

    final exact = await _exactAvailable;
    await _plugin.zonedSchedule(
      id: NotificationIds.streakAtRisk(habitId),
      title: '⚠️ Streak at risk!',
      body:
          '$habitEmoji $habitName — ${currentStreak}d streak ends tonight. Log it now!',
      scheduledDate: scheduled,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationChannels.streakAlerts,
          'Streak alerts',
          channelDescription: 'Alerts when a streak is about to break',
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: true,
          // Same alarm-stream sound as the daily reminder — this is the
          // "you're about to lose your streak" moment, so it should be
          // the least missable notification in the app.
          playSound: true,
          sound: const UriAndroidNotificationSound(
            'content://settings/system/alarm_alert',
          ),
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
      ),
      payload: habitId,
      androidScheduleMode: _scheduleMode(exact),
    );
  }

  /// Cancel the streak-at-risk alert for a habit (call after check-in).
  Future<void> cancelStreakAtRisk(String habitId) =>
      _plugin.cancel(id: NotificationIds.streakAtRisk(habitId));

  // ─── 3. Milestone notification ─────────────────────────────────────────────

  /// Fire immediately when a milestone streak is reached.
  /// Milestones: 3, 7, 14, 21, 30, 60, 90, 180, 365 days.
  Future<void> fireMilestone({
    required String habitId,
    required String habitName,
    required String habitEmoji,
    required int streak,
  }) async {
    final label = _milestoneLabel(streak);
    if (label == null) return; // not a milestone streak

    await _plugin.show(
      id: NotificationIds.milestone(habitId),
      title: '🏆 $label streak!',
      body:
          '$habitEmoji $habitName — $streak days and counting. You\'re on fire!',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationChannels.milestones,
          'Milestones',
          channelDescription: 'Celebrations for streak milestones',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          enableVibration: true,
        ),
      ),
    );
  }

  static const _milestones = {3, 7, 14, 21, 30, 60, 90, 180, 365};

  static bool isMilestone(int streak) => _milestones.contains(streak);

  String? _milestoneLabel(int streak) {
    if (!_milestones.contains(streak)) return null;
    return switch (streak) {
      3 => '3-day',
      7 => '1-week',
      14 => '2-week',
      21 => '21-day',
      30 => '1-month',
      60 => '2-month',
      90 => '90-day',
      180 => '6-month',
      365 => '1-year',
      _ => '$streak-day',
    };
  }

  // ─── 4. Weekly summary (Sunday 8 PM) ──────────────────────────────────────

  /// Schedules a repeating weekly summary notification every Sunday at 8 PM.
  /// Call once on app start (idempotent — replaces any existing schedule).
  Future<void> scheduleWeeklySummary({
    required int activeHabits,
    required int completedThisWeek,
    required int totalDueThisWeek,
  }) async {
    final now = tz.TZDateTime.now(tz.local);

    // Find next Sunday at 20:00
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      20,
      0,
    );
    // Advance to Sunday (weekday 7)
    while (scheduled.weekday != DateTime.sunday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 7));
    }

    final pct = totalDueThisWeek == 0
        ? 0
        : (completedThisWeek / totalDueThisWeek * 100).round();
    final emoji = pct >= 80
        ? '🔥'
        : pct >= 50
        ? '💪'
        : '😤';
    final body = totalDueThisWeek == 0
        ? 'Add habits to start building streaks!'
        : '$completedThisWeek/$totalDueThisWeek check-ins this week ($pct%) $emoji';

    final exact = await _exactAvailable;
    await _plugin.zonedSchedule(
      id: NotificationIds.weeklySummary,
      title: 'Weekly recap 📊',
      body: body,
      scheduledDate: scheduled,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationChannels.weeklySummary,
          'Weekly summary',
          channelDescription: 'Sunday recap of your week\'s habit performance',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      androidScheduleMode: _scheduleMode(exact),
    );
  }

  Future<void> cancelWeeklySummary() =>
      _plugin.cancel(id: NotificationIds.weeklySummary);

  // ─── 5. Pro upsell (non-pro users, Wednesday 7 PM, weekly) ───────────────

  /// Schedules a weekly Pro upsell nudge for free users.
  /// Cancel this when the user upgrades to Pro.
  Future<void> scheduleProUpsell() async {
    final now = tz.TZDateTime.now(tz.local);

    // Find next Wednesday at 19:00
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      19,
      0,
    );
    while (scheduled.weekday != DateTime.wednesday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 7));
    }

    final exact = await _exactAvailable;
    await _plugin.zonedSchedule(
      id: NotificationIds.proUpsell,
      title: 'Unlock unlimited habits ✨',
      body:
          'Free plan is limited to 3 habits. Go Pro for unlimited habits, full history & more.',
      scheduledDate: scheduled,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationChannels.proUpsell,
          'Pro upgrade',
          channelDescription: 'Occasional tips about ZStreak Pro features',
          importance: Importance.low,
          priority: Priority.low,
        ),
      ),
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      androidScheduleMode: _scheduleMode(exact),
    );
  }

  Future<void> cancelProUpsell() =>
      _plugin.cancel(id: NotificationIds.proUpsell);

  // ─── Cancellation ──────────────────────────────────────────────────────────

  /// Cancels the daily reminder tied to a habit — call on archive, delete,
  /// and whenever a reminder is cleared in Edit Habit.
  /// Cancels both scheduling styles regardless of which one is currently
  /// active for this habit — cheap (cancelling an id nothing was ever
  /// scheduled under is a no-op) and avoids ever needing to know which
  /// style was last used to schedule.
  Future<void> cancelReminder(String habitId) async {
    await _plugin.cancel(id: _notificationIdFor(habitId));
    for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++) {
      await _plugin.cancel(id: _weekdayReminderId(habitId, weekday));
    }
  }

  /// Cancel all notifications for a habit (reminder + streak-at-risk).
  Future<void> cancelAllForHabit(String habitId) async {
    await cancelReminder(habitId);
    await cancelStreakAtRisk(habitId);
  }

  AndroidFlutterLocalNotificationsPlugin? get _androidPlugin => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
}
