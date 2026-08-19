import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/color_hex.dart';
import '../../monetization/application/entitlement_providers.dart';
import '../../monetization/presentation/paywall_screen.dart';
import '../../notifications/application/notification_providers.dart';
import '../application/habit_providers.dart';
import '../domain/habit.dart';

/// Archived habits screen — flat design, theme-aware.
class ArchivedHabitsScreen extends ConsumerWidget {
  const ArchivedHabitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archived = ref.watch(archivedHabitsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.background : AppColors.backgroundLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;
    final accent = isDark ? AppColors.accent : AppColors.accentTextOnLight;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Archived',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: isDark ? AppColors.border : AppColors.borderLight,
          ),
        ),
      ),
      body: archived.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: accent, strokeWidth: 2),
        ),
        error: (error, _) => Center(
          child: Text('$error', style: TextStyle(color: textMuted)),
        ),
        data: (habits) {
          if (habits.isEmpty) {
            return _EmptyState(textMuted: textMuted, accent: accent);
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
            itemCount: habits.length,
            itemBuilder: (context, index) =>
                _ArchivedHabitTile(
                      habit: habits[index],
                      isDark: isDark,
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                      accent: accent,
                    )
                    .animate(delay: (index * 50).ms)
                    .fadeIn(duration: 300.ms)
                    .slideY(
                      begin: 0.08,
                      end: 0,
                      duration: 300.ms,
                      curve: Curves.easeOut,
                    ),
          );
        },
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.textMuted, required this.accent});
  final Color textMuted;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📦', style: TextStyle(fontSize: 55)).animate().scale(
              begin: const Offset(0.7, 0.7),
              end: const Offset(1.0, 1.0),
              duration: 400.ms,
              curve: Curves.elasticOut,
            ),
            const SizedBox(height: 16),
            Text(
              'Nothing archived yet',
              style: TextStyle(
                color: textMuted,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Habits you archive will show up here.\nYou can reactivate them anytime.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textMuted.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Archived habit tile ───────────────────────────────────────────────────────

class _ArchivedHabitTile extends ConsumerWidget {
  const _ArchivedHabitTile({
    required this.habit,
    required this.isDark,
    required this.textPrimary,
    required this.textMuted,
    required this.accent,
  });

  final Habit habit;
  final bool isDark;
  final Color textPrimary;
  final Color textMuted;
  final Color accent;

  Future<void> _reactivate(BuildContext context, WidgetRef ref) async {
    final activeCount =
        (await ref.read(habitRepositoryProvider).watchActiveHabits().first)
            .length;
    final isPremium = await ref.read(hasActiveEntitlementProvider.future);
    if (!isPremium && activeCount >= AppConfig.freeTierHabitLimit) {
      if (context.mounted) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const PaywallScreen()));
      }
      return;
    }

    await ref.read(habitRepositoryProvider).unarchiveHabit(habit.id);
    final reminder = habit.reminderTime;
    if (reminder == null) return;
    final parts = reminder.split(':');
    // Fetch the latest habit after unarchiving to get the current streak.
    final latestHabit = await ref
        .read(habitRepositoryProvider)
        .getHabitById(habit.id);
    await ref
        .read(notificationServiceProvider)
        .scheduleDailyReminder(
          habitId: habit.id,
          habitName: habit.name,
          habitEmoji: habit.emoji,
          currentStreak: latestHabit?.currentStreak ?? habit.currentStreak,
          time: TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          ),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitColor = colorFromHex(habit.colorHex);
    final surfaceColor = isDark ? AppColors.surface : AppColors.surfaceLight;
    final borderColor = isDark ? AppColors.border : AppColors.borderLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // ── Emoji container ───────────────────────────────────────────
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: habitColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: habitColor.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(habit.emoji, style: const TextStyle(fontSize: 21)),
              ),
            ),
            const SizedBox(width: 14),

            // ── Name + streak info ────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.name,
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 11)),
                      const SizedBox(width: 4),
                      Text(
                        'Best streak: ${habit.longestStreak}',
                        style: TextStyle(
                          color: textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Reactivate button ─────────────────────────────────────────
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _reactivate(context, ref),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: habitColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: habitColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Restore',
                  style: TextStyle(
                    color: habitColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
