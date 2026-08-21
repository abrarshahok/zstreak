import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analytics/analytics_service.dart';
import '../../notifications/application/notification_providers.dart';
import '../../reviews/review_prompt_service.dart';
import '../domain/habit.dart';
import '../presentation/milestone_overlay.dart';
import 'habit_providers.dart';

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
  final repo = ref.read(habitRepositoryProvider);

  if (isDone) {
    HapticFeedback.lightImpact();
    await repo.setCheckIn(habitId: habit.id, date: date, completed: false);
    return;
  }

  HapticFeedback.mediumImpact();
  await repo.setCheckIn(habitId: habit.id, date: date, completed: true);

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
}
