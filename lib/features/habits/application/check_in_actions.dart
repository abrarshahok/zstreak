import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analytics/analytics_service.dart';
import '../../notifications/application/notification_providers.dart';
import '../../reviews/review_prompt_service.dart';
import '../domain/check_in_status.dart';
import '../domain/habit.dart';
import '../presentation/milestone_overlay.dart';
import 'habit_providers.dart';

/// Guards against a rapid double-tap on the same habit's check-in toggle
/// firing this whole pipeline twice before the first call's writes and
/// side effects (review prompt, analytics, notifications, milestone
/// overlay) finish — both taps would otherwise read the same stale
/// `isDone` snapshot (from the last provider emission, not a fresh read)
/// and fire the *same* target write, harmless for the check-in row
/// itself but capable of double-firing the one-time reactions below.
/// Module-level rather than per-widget State since [HabitTile] and
/// `HabitGridCard` are separate stateless call sites for the same
/// underlying (habit, date) target.
final Set<String> _pendingCheckIns = {};

/// The single check-in side-effect pipeline: write the check-in, and on a
/// fresh completion, refetch the habit and run every downstream reaction
/// exactly once — review prompt, analytics, the notification orchestrator,
/// and the milestone overlay.
///
/// Previously this exact sequence was copy-pasted between the list view
/// ([HabitTile]) and the grid view (`HabitGridCard`); any future check-in
/// side effect only needs to land here now, in one place, for both.
Future<void> performCheckIn({
  required BuildContext context,
  required WidgetRef ref,
  required Habit habit,
  required String date,
  required bool isDone,
}) async {
  // Defensive: callers (HabitTile, HabitGridCard) already disable the
  // toggle itself on a non-scheduled day, but this is the one write
  // path both share, so it's the right place to refuse it outright too.
  if (!habit.isScheduledOnWeekday(DateTime.parse(date).weekday)) return;

  final key = '${habit.id}|$date';
  if (!_pendingCheckIns.add(key)) return;
  try {
    final repo = ref.read(habitRepositoryProvider);

    if (isDone) {
      HapticFeedback.lightImpact();
      await repo.setCheckIn(
        habitId: habit.id,
        date: date,
        status: CheckInStatus.missed,
      );
      return;
    }

    HapticFeedback.mediumImpact();
    // For a quantity habit, `setCheckIn` leaves an omitted `value` alone —
    // it does not clear it — so writing status: completed here without
    // also touching value can leave a completed day paired with a
    // still-below-target logged amount. That's exactly what then made
    // adjusting the quantity stepper afterward immediately flip it back to
    // missed (it derives status fresh from value vs target on every tap),
    // reading as "checking it in un-checks it". Same rule as the
    // Complete button elsewhere: if what's already logged doesn't meet
    // target, assume the tap means "I hit my goal" instead of leaving
    // status and value disagreeing.
    int? valueOverride;
    if (habit.isQuantityHabit) {
      final target = habit.targetCount ?? 1;
      final loggedValue =
          ref.read(checkInProvider(CheckInQuery(habit.id, date))).valueOrNull?.value ??
          0;
      if (loggedValue < target) valueOverride = target;
    }
    await repo.setCheckIn(
      habitId: habit.id,
      date: date,
      status: CheckInStatus.completed,
      value: valueOverride,
    );

    final updated = await repo.getHabitById(habit.id);
    if (updated == null) return;

    await ref
        .read(reviewPromptServiceProvider)
        .maybePromptAfterStreakMilestone(updated.currentStreak);
    await ref
        .read(analyticsServiceProvider)
        .logStreakMilestone(habitId: habit.id, streak: updated.currentStreak);
    await ref
        .read(notificationOrchestratorProvider)
        .onCheckIn(
          habitId: habit.id,
          habitName: habit.name,
          habitEmoji: habit.emoji,
          newStreak: updated.currentStreak,
        );

    if (context.mounted) {
      await maybeShowMilestoneOverlay(
        context: context,
        ref: ref,
        habit: updated,
        streak: updated.currentStreak,
      );
    }
  } finally {
    _pendingCheckIns.remove(key);
  }
}
