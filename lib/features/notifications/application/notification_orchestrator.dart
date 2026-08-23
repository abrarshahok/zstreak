import 'dart:async';

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/local_date.dart';
import '../../habits/application/habit_providers.dart';
import '../../habits/domain/check_in.dart';
import '../../habits/domain/frequency.dart';
import '../../habits/domain/habit.dart';
import '../../monetization/application/entitlement_providers.dart';
import '../data/notification_service.dart';

/// Orchestrates all smart notifications beyond the basic daily reminder:
///
/// • **Streak-at-risk** — scheduled at 9 PM each day for every active habit
///   that has a streak > 0 and hasn't been checked in yet today.
///   Cancelled immediately when the user checks in.
///
/// • **Milestone** — fired immediately when a check-in produces a streak
///   that hits 3, 7, 14, 21, 30, 60, 90, 180, or 365 days.
///
/// • **Daily reminder** — re-scheduled for every active habit with a
///   reminder time set, once per app start, so its message rotates through
///   [NotificationService]'s copy pool daily instead of repeating whatever
///   text happened to be baked in the last time the habit was edited.
///
/// • **Weekly summary** — scheduled every Sunday at 8 PM with the week's
///   completion stats. Refreshed on every app start.
///
/// • **Pro upsell** — scheduled every Wednesday at 7 PM for free users.
///   Cancelled when the user upgrades to Pro.
///
/// Call [refresh] once on app start (after [NotificationService.initialize]).
/// The habit repository's [setCheckIn] callers should call [onCheckIn] after
/// a successful check-in so milestones and streak-at-risk cancellations fire
/// at the right moment.
class NotificationOrchestrator {
  NotificationOrchestrator({required this._notifications, required this._ref});

  final NotificationService _notifications;
  final Ref _ref;

  /// Call once after [NotificationService.initialize] on app start.
  ///
  /// Fetches each habit's check-in history exactly once and reuses it for
  /// both the streak-at-risk check and the weekly summary — previously
  /// these ran as separate queries per habit (streak-at-risk) plus a
  /// nested per-day-of-week query per habit (weekly summary), for up to
  /// `habits + habits * 7` reads on every cold start.
  Future<void> refresh() async {
    final repo = _ref.read(habitRepositoryProvider);
    final habits = await repo.watchActiveHabits().first;

    final checkInsByHabit = <String, List<CheckIn>>{};
    for (final habit in habits) {
      checkInsByHabit[habit.id] = await repo.watchHabitCheckIns(habit.id).first;
    }

    await _refreshDailyReminders(habits);
    await _refreshStreakAtRisk(habits, checkInsByHabit);
    await _refreshWeeklySummary(habits, checkInsByHabit);
    await _refreshProUpsell();
  }

  // ─── Daily reminder ────────────────────────────────────────────────────────

  /// Re-rolls the reminder message for every active habit that has one
  /// scheduled, so it varies day to day instead of freezing on whatever
  /// text was picked the last time the habit was edited. Habits without a
  /// reminder time are untouched — nothing was ever scheduled for them.
  Future<void> _refreshDailyReminders(List<Habit> habits) async {
    for (final habit in habits) {
      final reminderTime = habit.reminderTime;
      if (reminderTime == null) continue;

      final parts = reminderTime.split(':');
      final time = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );

      await _notifications.scheduleDailyReminder(
        habitId: habit.id,
        habitName: habit.name,
        habitEmoji: habit.emoji,
        currentStreak: habit.currentStreak,
        time: time,
        scheduledWeekdays: habit.frequencyType == FrequencyType.weekdays
            ? (habit.frequencyConfig as WeekdaysConfig).weekdays
            : null,
      );
    }
  }

  // ─── Streak-at-risk ────────────────────────────────────────────────────────

  Future<void> _refreshStreakAtRisk(
    List<Habit> habits,
    Map<String, List<CheckIn>> checkInsByHabit,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr = localDateString(today);

    // 9 PM tonight
    final riskTime = DateTime(today.year, today.month, today.day, 21, 0);

    for (final habit in habits) {
      // Only daily / weekday habits with an active streak need this.
      // xPerWeek habits don't have a single "due today" concept.
      if (habit.frequencyType == FrequencyType.xPerWeek) {
        await _notifications.cancelStreakAtRisk(habit.id);
        continue;
      }

      // Check if today is a scheduled day for this habit.
      final isScheduledToday = _isScheduledToday(habit, today);
      if (!isScheduledToday) {
        await _notifications.cancelStreakAtRisk(habit.id);
        continue;
      }

      final checkedInToday = (checkInsByHabit[habit.id] ?? const []).any(
        (c) => c.date == todayStr && c.completed,
      );

      if (checkedInToday) {
        // Already done — cancel any pending risk alert.
        await _notifications.cancelStreakAtRisk(habit.id);
        continue;
      }

      if (habit.currentStreak > 0 && riskTime.isAfter(now)) {
        await _notifications.scheduleStreakAtRisk(
          habitId: habit.id,
          habitName: habit.name,
          habitEmoji: habit.emoji,
          currentStreak: habit.currentStreak,
          fireAt: riskTime,
        );
      }
    }
  }

  bool _isScheduledToday(Habit habit, DateTime today) {
    return switch (habit.frequencyType) {
      FrequencyType.daily => true,
      FrequencyType.weekdays => () {
        final weekdays = (habit.frequencyConfig as WeekdaysConfig).weekdays;
        return weekdays.contains(today.weekday);
      }(),
      FrequencyType.xPerWeek => false,
    };
  }

  // ─── Weekly summary ────────────────────────────────────────────────────────

  Future<void> _refreshWeeklySummary(
    List<Habit> habits,
    Map<String, List<CheckIn>> checkInsByHabit,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));

    var totalDue = 0;
    var completed = 0;

    for (final habit in habits) {
      final completedDates = (checkInsByHabit[habit.id] ?? const [])
          .where((c) => c.completed)
          .map((c) => c.date)
          .toSet();

      // Count scheduled days this week up to today.
      for (var d = 0; d <= today.weekday - 1; d++) {
        final day = weekStart.add(Duration(days: d));
        if (!_isScheduledToday(habit, day)) continue;
        totalDue++;
        if (completedDates.contains(localDateString(day))) completed++;
      }
    }

    await _notifications.scheduleWeeklySummary(
      activeHabits: habits.length,
      completedThisWeek: completed,
      totalDueThisWeek: totalDue,
    );
  }

  // ─── Pro upsell ────────────────────────────────────────────────────────────

  Future<void> _refreshProUpsell() async {
    final isPro = await _ref.read(hasActiveEntitlementProvider.future);
    if (isPro) {
      await _notifications.cancelProUpsell();
    } else {
      await _notifications.scheduleProUpsell();
    }
  }

  // ─── Called after a check-in ───────────────────────────────────────────────

  /// Call this after every successful check-in (completed = true).
  /// Fires milestone notification if applicable, cancels streak-at-risk.
  Future<void> onCheckIn({
    required String habitId,
    required String habitName,
    required String habitEmoji,
    required int newStreak,
  }) async {
    // Cancel the streak-at-risk alert — user just checked in.
    await _notifications.cancelStreakAtRisk(habitId);

    // Fire milestone if this streak hits a milestone number.
    if (NotificationService.isMilestone(newStreak)) {
      await _notifications.fireMilestone(
        habitId: habitId,
        habitName: habitName,
        habitEmoji: habitEmoji,
        streak: newStreak,
      );
    }
  }
}
