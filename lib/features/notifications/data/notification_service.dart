import 'dart:math';

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

    // Streak-tier-aware title + body, picked from a large pool so the same
    // habit doesn't get the identical notification every single day. The
    // pick is seeded by habit + calendar day (not fully random) so a given
    // habit shows one consistent message per day rather than flip-flopping
    // if this is called more than once — but rotates whenever the habit is
    // re-scheduled on a new day (see NotificationOrchestrator.refresh,
    // which re-schedules every active reminder once per app start).
    final title = _pickCopy(
      currentStreak > 0 ? _kActiveStreakTitles : _kNoStreakTitles,
      habitId,
      'title',
    );
    final body = _pickCopy(
      _reminderBodyPool(currentStreak, habitEmoji, habitName),
      habitId,
      'body',
    );

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
        title: title,
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
        title: title,
        body: body,
        scheduledDate: _nextInstanceOfWeekdayTime(weekday, time),
        notificationDetails: details(),
        payload: habitId,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        androidScheduleMode: _scheduleMode(exact),
      );
    }
  }

  // ─── Reminder copy pools ───────────────────────────────────────────────────
  //
  // A big pool per streak tier, rather than one fixed line, so the reminder
  // stops reading like a template. Picked deterministically per habit+day
  // (not fully random) so a habit shows one stable message per calendar
  // day instead of flip-flopping on repeated calls.

  static const _kNoStreakTitles = [
    'New habit, who\'s this? 👀',
    'Day one starts now 🌱',
    'Time to lock in 🔒',
    'Future you says thanks 🙏',
    'Small start, big streak 🔥',
    'Zero hour ⏳',
    'First rep of many 💪',
    'The streak begins here ✨',
    'Nothing lit yet 🕯️',
    'Let\'s get this going 🚀',
    'One tap away 👆',
    'Blank slate, your move ♟️',
    'Start small, stay consistent 🌊',
    'This is the moment ⏱️',
  ];

  static const _kActiveStreakTitles = [
    'Time to lock in 🔒',
    'Don\'t break the chain ⛓️',
    'Your streak is calling 📣',
    'Keep the fire burning 🔥',
    'Protect the streak 🛡️',
    'Still got it? Prove it 💪',
    'Streak check-in ✅',
    'The chain wants you 🔗',
    'Don\'t ghost the streak 👻',
    'Keep it alive tonight 🌙',
    'One more day, one more win 🏁',
    'Your future self is watching 👁️',
    'Consistency o\'clock ⏰',
    'Show up, streak stays 🔥',
  ];

  List<String> _reminderBodyPool(int streak, String emoji, String name) {
    if (streak == 0) {
      return [
        '$emoji $name - Start your streak today!',
        '$emoji $name - Every streak starts with day one.',
        '$emoji $name - One rep, one page, one step. Just start.',
        '$emoji $name - Future you is waiting on this one.',
        '$emoji $name - No streak yet. Let\'s change that.',
        '$emoji $name - The best time to start was yesterday. Second best: now.',
        '$emoji $name - Zero isn\'t a number you have to keep.',
        '$emoji $name - Show up once - that\'s the whole trick today.',
        '$emoji $name - Nothing lost, nothing missed. Perfect time to start.',
        '$emoji $name - This is the easiest day you\'ll ever start on.',
        '$emoji $name - First one\'s always the hardest. Get it over with.',
        '$emoji $name - A blank streak is just a streak that hasn\'t started.',
      ];
    }
    if (streak <= 2) {
      return [
        '$emoji $name - Day ${streak + 1} is right there. Go get it.',
        '$emoji $name - ${streak}d in. Don\'t stop now.',
        '$emoji $name - The spark is lit. Keep feeding it.',
        '$emoji $name - Momentum is fragile this early - protect it.',
        '$emoji $name - ${streak}d streak. Still warming up.',
        '$emoji $name - Two days beat one. Make it three.',
        '$emoji $name - This is the fragile part. Show up anyway.',
        '$emoji $name - Streaks are won in the first few days.',
        '$emoji $name - Keep stacking days - that\'s the whole game.',
        '$emoji $name - ${streak}d down. The hardest part is almost over.',
      ];
    }
    if (streak <= 6) {
      return [
        '$emoji $name - ${streak}d streak and climbing.',
        '$emoji $name - You\'re building something real here.',
        '$emoji $name - $streak days deep. Keep digging.',
        '$emoji $name - This is where habits get made.',
        '$emoji $name - Don\'t let $streak days go to waste.',
        '$emoji $name - Almost a full week. Don\'t slow down now.',
        '$emoji $name - $streak days of proof, one more coming.',
        '$emoji $name - You\'re past the point of "just trying it out."',
        '$emoji $name - $streak days in a row. Keep the pattern going.',
        '$emoji $name - Consistency is quietly becoming your thing.',
      ];
    }
    if (streak <= 29) {
      return [
        '$emoji $name - ${streak}d streak on the line!',
        '$emoji $name - A week+ in. This is a real habit now.',
        '$emoji $name - $streak days strong. Keep the streak alive.',
        '$emoji $name - You\'d hate to reset this one. Log it.',
        '$emoji $name - ${streak}d and no signs of stopping.',
        '$emoji $name - This streak\'s got a pulse of its own now.',
        '$emoji $name - $streak days. People are starting to notice.',
        '$emoji $name - This streak has outlasted most New Year\'s resolutions.',
        '$emoji $name - ${streak}d in - don\'t hand it back for free.',
        '$emoji $name - Real streaks are made of days like today.',
      ];
    }
    if (streak <= 99) {
      return [
        '$emoji $name - $streak days. That\'s a month+ of showing up.',
        '$emoji $name - ${streak}d streak - this is who you are now.',
        '$emoji $name - Don\'t let today be the day it ends at $streak.',
        '$emoji $name - $streak days of proof you follow through.',
        '$emoji $name - Still going. $streak days and counting.',
        '$emoji $name - $streak days. Most people quit way before this.',
        '$emoji $name - ${streak}d streak - this isn\'t luck anymore, it\'s a system.',
        '$emoji $name - $streak days of receipts. Add one more.',
      ];
    }
    return [
      '$emoji $name - $streak days. Legendary. Keep it going.',
      '$emoji $name - ${streak}d streak. You don\'t break this now.',
      '$emoji $name - $streak days in. This is your identity now.',
      '$emoji $name - $streak days - most people never make it this far.',
      '$emoji $name - $streak days. This streak has its own gravity now.',
      '$emoji $name - ${streak}d in - you\'re basically streak royalty.',
      '$emoji $name - $streak days and still showing up. Keep going.',
    ];
  }

  /// Day-scoped pick: stable for a given (habit, salt) across the current
  /// calendar day, different tomorrow. Used for the daily reminder and the
  /// streak-at-risk alert, both of which get re-picked once per day.
  String _pickCopy(List<String> options, String habitId, String salt) {
    final now = DateTime.now();
    final dayKey = now.year * 10000 + now.month * 100 + now.day;
    return _pickWithSeed(options, Object.hash(habitId, dayKey, salt));
  }

  /// Un-scoped pick: stable for whatever [key]/[salt] pair is passed in —
  /// no implicit day component, so callers with their own notion of "how
  /// often this should change" (a milestone's streak number, a week
  /// number) fully control the cadence themselves.
  String _pickScoped(List<String> options, String key, String salt) =>
      _pickWithSeed(options, Object.hash(key, salt));

  String _pickWithSeed(List<String> options, int seed) =>
      options[Random(seed).nextInt(options.length)];

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

    final title = _pickCopy(
      _streakAtRiskTitlePool(currentStreak),
      habitId,
      'risk-title',
    );
    final body = _pickCopy(
      _streakAtRiskBodyPool(currentStreak, habitEmoji, habitName),
      habitId,
      'risk-body',
    );

    final exact = await _exactAvailable;
    await _plugin.zonedSchedule(
      id: NotificationIds.streakAtRisk(habitId),
      title: title,
      body: body,
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

  // Two urgency bands — losing a fresh streak stings less than losing one
  // that's been running for weeks, so the copy leans harder the longer it
  // is rather than repeating the same line regardless of what's at stake.
  List<String> _streakAtRiskTitlePool(int streak) {
    if (streak < 7) {
      return [
        '⚠️ Streak at risk!',
        'Don\'t lose this one 😬',
        'Still time to save it ⏳',
        'Quick - before it\'s gone ⚡',
        'One check-in stands between you and zero 🕳️',
      ];
    }
    return [
      '⚠️ Streak at risk!',
      'Don\'t let $streak days slip away 😱',
      'This one actually matters 🚨',
      'Protect what you built 🛡️',
      '$streak days on the line tonight 🔥',
    ];
  }

  List<String> _streakAtRiskBodyPool(int streak, String emoji, String name) {
    if (streak < 7) {
      return [
        '$emoji $name - ${streak}d streak ends tonight. Log it now!',
        '$emoji $name - Don\'t let $streak days disappear. Check in.',
        '$emoji $name - Still time to keep this ${streak}d streak alive.',
        '$emoji $name - $streak days, gone in a blink if you skip tonight.',
        '$emoji $name - Last call for today\'s check-in.',
      ];
    }
    return [
      '$emoji $name - ${streak}d streak ends tonight. Log it now!',
      '$emoji $name - $streak days of work, one missed tap from zero.',
      '$emoji $name - Don\'t let tonight be the night $streak days end.',
      '$emoji $name - You didn\'t come this far to lose it at $streak.',
      '$emoji $name - $streak days deserve better than a missed night.',
    ];
  }

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

    // Seeded by streak (not the calendar day) — each milestone number is
    // its own one-time occasion, so a habit's 7-day and 30-day milestones
    // should each get their own message rather than sharing today's pick.
    final title = _pickScoped(
      _milestoneTitlePool(label),
      habitId,
      'ms-$streak',
    );
    final body = _pickScoped(
      _milestoneBodyPool(streak, habitEmoji, habitName),
      habitId,
      'ms-body-$streak',
    );

    await _plugin.show(
      id: NotificationIds.milestone(habitId),
      title: title,
      body: body,
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

  List<String> _milestoneTitlePool(String label) => [
    '🏆 $label streak!',
    '🎉 $label milestone!',
    '🔥 $label and counting!',
    '⭐ $label unlocked!',
    '👑 $label streak achieved!',
  ];

  List<String> _milestoneBodyPool(int streak, String emoji, String name) => [
    '$emoji $name - $streak days and counting. You\'re on fire!',
    '$emoji $name - $streak days deep. Absolutely relentless.',
    '$emoji $name - $streak days of showing up. That\'s the whole secret.',
    '$emoji $name - $streak days - this is what consistency looks like.',
    '$emoji $name - $streak days in. Keep writing the streak.',
  ];

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

    // Seeded by ISO week (not calendar day) so the pick stays put no
    // matter how many times the app is opened before Sunday's send.
    final weekKey = '${now.year}-w${_isoWeekOf(now)}';
    final title = _pickScoped(_kWeeklySummaryTitles, weekKey, 'title');
    final body = _pickScoped(
      _weeklySummaryBodyPool(
        completedThisWeek: completedThisWeek,
        totalDueThisWeek: totalDueThisWeek,
        pct: pct,
      ),
      weekKey,
      'body',
    );

    final exact = await _exactAvailable;
    await _plugin.zonedSchedule(
      id: NotificationIds.weeklySummary,
      title: title,
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

  /// Not strictly ISO-8601 correct — just needs to change once a week so
  /// the picked copy stays put no matter how many times [refresh] runs
  /// between Sundays, which is all a cosmetic seed needs.
  int _isoWeekOf(DateTime date) =>
      date.difference(DateTime(date.year, 1, 1)).inDays ~/ 7;

  static const _kWeeklySummaryTitles = [
    'Weekly recap 📊',
    'Your week in review 📈',
    'Sunday check-in 🗞️',
    'How\'d the week go? 📅',
    'Week wrapped 🎬',
    'Recap time 🔔',
  ];

  List<String> _weeklySummaryBodyPool({
    required int completedThisWeek,
    required int totalDueThisWeek,
    required int pct,
  }) {
    if (totalDueThisWeek == 0) {
      return [
        'Add habits to start building streaks!',
        'No habits tracked yet - that\'s step one.',
        'Your habit list is empty. Let\'s fix that.',
      ];
    }
    final c = completedThisWeek;
    final t = totalDueThisWeek;
    if (pct >= 80) {
      return [
        '$c/$t check-ins this week ($pct%) 🔥',
        '$pct% completion this week. That\'s an elite week.',
        '$c of $t done - you basically ran the table 🔥',
        'Best kind of week: $pct% complete.',
        '$pct% this week. Keep this energy going.',
      ];
    }
    if (pct >= 50) {
      return [
        '$c/$t check-ins this week ($pct%) 💪',
        '$pct% completion - solid week, room to push further.',
        '$c of $t done. A good week, not your best yet.',
        'Halfway and then some: $pct% this week.',
        '$pct% this week - close to a great one.',
      ];
    }
    return [
      '$c/$t check-ins this week ($pct%) 😤',
      'Only $pct% this week - next week\'s a reset.',
      '$c of $t done. Rough week - happens to everyone.',
      '$pct% this week. Tomorrow\'s a clean slate.',
      'A quiet week: $c/$t. Let\'s turn it around.',
    ];
  }

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

    final weekKey = '${now.year}-w${_isoWeekOf(now)}';
    final title = _pickScoped(_kProUpsellTitles, weekKey, 'title');
    final body = _pickScoped(_kProUpsellBodies, weekKey, 'body');

    final exact = await _exactAvailable;
    await _plugin.zonedSchedule(
      id: NotificationIds.proUpsell,
      title: title,
      body: body,
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

  static const _kProUpsellTitles = [
    'Unlock unlimited habits ✨',
    'Ready for more habits? 🚀',
    'Go further with Pro ⭐',
    'Your habit list wants to grow 🌱',
    'Level up your tracking 📈',
  ];

  static const _kProUpsellBodies = [
    'Free plan is limited to 3 habits. Go Pro for unlimited habits, full history & more.',
    'Hit your 3-habit limit? Pro removes the cap - plus full history and more.',
    'Pro unlocks unlimited habits, full history, and more - whenever you\'re ready.',
    'Building more than 3 habits? Pro has room for all of them.',
    'Full history, unlimited habits, zero limits - that\'s Pro.',
  ];

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
