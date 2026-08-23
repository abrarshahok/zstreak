import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/shared_preferences_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/color_hex.dart';
import '../application/habit_providers.dart';
import '../domain/habit.dart';
import '../domain/streak_calculator.dart';

// ─── ISO week key helper ──────────────────────────────────────────────────────

/// Returns a string like "2024-W42" for the given [date].
String _isoWeekKey(DateTime date) {
  // ISO week: week containing Thursday of that week belongs to that year.
  final thursday = date.add(Duration(days: 4 - date.weekday));
  final firstDayOfYear = DateTime(thursday.year, 1, 1);
  final weekNumber =
      ((thursday.difference(firstDayOfYear).inDays) / 7).floor() + 1;
  return '${thursday.year}-W${weekNumber.toString().padLeft(2, '0')}';
}

// ─── Visibility logic ─────────────────────────────────────────────────────────

/// Returns true if the weekly review card should be shown right now.
/// Condition: Sunday after 20:00 local time, OR Monday (any time).
bool _shouldShowWeeklyReview(DateTime now) {
  // Sunday = 7 in Dart's weekday (1=Mon … 7=Sun)
  if (now.weekday == DateTime.sunday && now.hour >= 20) return true;
  if (now.weekday == DateTime.monday) return true;
  return false;
}

// ─── SharedPreferences key ────────────────────────────────────────────────────

const String _kDismissedWeekKey = 'dismissedWeeklyReview';

// ─── Provider ─────────────────────────────────────────────────────────────────

/// Notifier that tracks whether the weekly review card is visible this session.
/// Reads SharedPreferences to check if the current ISO week was already dismissed.
class WeeklyReviewVisibilityNotifier extends Notifier<bool> {
  @override
  bool build() {
    final now = DateTime.now();
    if (!_shouldShowWeeklyReview(now)) return false;

    final prefs = ref.read(sharedPreferencesProvider);
    final dismissed = prefs.getString(_kDismissedWeekKey);
    final currentWeek = _isoWeekKey(now);
    return dismissed != currentWeek;
  }

  Future<void> dismiss() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final currentWeek = _isoWeekKey(DateTime.now());
    await prefs.setString(_kDismissedWeekKey, currentWeek);
    state = false;
  }
}

final weeklyReviewVisibilityProvider =
    NotifierProvider<WeeklyReviewVisibilityNotifier, bool>(
      WeeklyReviewVisibilityNotifier.new,
    );

// ─── Stats computation ────────────────────────────────────────────────────────

class _WeekStats {
  const _WeekStats({
    required this.totalCheckIns,
    required this.bestHabit,
    required this.mostMissedHabit,
  });

  final int totalCheckIns;
  final Habit? bestHabit;
  final Habit? mostMissedHabit;
}

/// Monday of the week this review recaps — the week ending *today* (shown
/// Sunday evening) or last week (shown Monday, since weekday-1 alone
/// always lands on the Monday of the CURRENT week; stepping the reference
/// date back 7 days first is what lands Monday's math on *last* week's
/// Monday instead — see [_shouldShowWeeklyReview]).
DateTime _reviewedWeekStart(DateTime now) {
  final referenceDate = now.weekday == DateTime.monday
      ? now.subtract(const Duration(days: 7))
      : now;
  return DateTime(
    referenceDate.year,
    referenceDate.month,
    referenceDate.day,
  ).subtract(Duration(days: referenceDate.weekday - 1));
}

/// Computes weekly stats from [streakDetails] keyed by habit.
/// Uses the last 7 days of each habit's day-status list.
_WeekStats _computeWeekStats(
  List<Habit> habits,
  Map<String, List<dynamic>> daysByHabit,
) {
  final weekStart = _reviewedWeekStart(DateTime.now());
  final weekDates = List.generate(7, (i) {
    final d = weekStart.add(Duration(days: i));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  });

  int totalCheckIns = 0;
  Habit? bestHabit;
  int bestCount = -1;
  Habit? mostMissedHabit;
  int mostMissed = -1;

  for (final habit in habits) {
    final days = daysByHabit[habit.id] ?? [];
    // days is List<HabitDayStatus> — we check .date and .status
    int completedThisWeek = 0;
    int missedThisWeek = 0;

    for (final day in days) {
      // HabitDayStatus has .date (DateTime) and .status (DayStatus)
      final dateStr =
          '${day.date.year}-${day.date.month.toString().padLeft(2, '0')}-${day.date.day.toString().padLeft(2, '0')}';
      if (!weekDates.contains(dateStr)) continue;

      if (day.status == DayStatus.completed) completedThisWeek++;
      if (day.status == DayStatus.missed) missedThisWeek++;
    }

    totalCheckIns += completedThisWeek;

    if (completedThisWeek > bestCount) {
      bestCount = completedThisWeek;
      bestHabit = habit;
    }
    if (missedThisWeek > mostMissed) {
      mostMissed = missedThisWeek;
      mostMissedHabit = habit;
    }
  }

  // If best and most-missed are the same habit (e.g. only one habit), clear
  // most-missed to avoid showing the same habit twice.
  if (bestHabit != null &&
      mostMissedHabit != null &&
      bestHabit.id == mostMissedHabit.id &&
      habits.length == 1) {
    mostMissedHabit = null;
  }

  return _WeekStats(
    totalCheckIns: totalCheckIns,
    bestHabit: bestCount > 0 ? bestHabit : null,
    mostMissedHabit: mostMissed > 0 ? mostMissedHabit : null,
  );
}

// ─── Weekly Review Card widget ────────────────────────────────────────────────

class WeeklyReviewCard extends ConsumerWidget {
  const WeeklyReviewCard({super.key, required this.habits});

  final List<Habit> habits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVisible = ref.watch(weeklyReviewVisibilityProvider);
    if (!isVisible) return const SizedBox.shrink();

    // Nothing to recap if every habit was created after the reviewed week
    // ended — e.g. a brand-new install on a Monday, recapping *last* week,
    // when the user's only habit was added today. Without this, a fresh
    // account sees an empty "Weekly Review" for a week it didn't exist for.
    final weekEnd = _reviewedWeekStart(
      DateTime.now(),
    ).add(const Duration(days: 6));
    final hasHistoryForReviewedWeek = habits.any((h) {
      final createdDate = DateTime(
        h.createdAt.year,
        h.createdAt.month,
        h.createdAt.day,
      );
      return !createdDate.isAfter(weekEnd);
    });
    if (!hasHistoryForReviewedWeek) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
    final border = isDark ? AppColors.border : AppColors.borderLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;
    final accent = isDark ? AppColors.accent : AppColors.accentTextOnLight;

    // Watch streak details for all habits to compute weekly stats.
    final daysByHabit = <String, List<dynamic>>{};
    for (final habit in habits) {
      final detail = ref.watch(streakDetailProvider(habit));
      detail.whenData((result) {
        daysByHabit[habit.id] = result.days;
      });
    }

    final stats = _computeWeekStats(habits, daysByHabit);

    final now = DateTime.now();
    final weekLabel = _isoWeekKey(now);

    return Padding(
          // Same bottom-only-margin rule every card in Home's stack
          // follows (see _StreakSummaryBar's comment) — was 8 here vs
          // 12 everywhere else, the exact kind of off-by-a-few-pixels
          // mismatch that reads as "inconsistent" without being
          // obviously wrong at a glance.
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: surface,
              border: Border.all(color: border, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header row ───────────────────────────────────────────────
                  Row(
                    children: [
                      Text('📋', style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Weekly Review',
                              style: TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                letterSpacing: -0.2,
                              ),
                            ),
                            Text(
                              weekLabel,
                              style: TextStyle(
                                color: textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Dismiss button
                      GestureDetector(
                        onTap: () => ref
                            .read(weeklyReviewVisibilityProvider.notifier)
                            .dismiss(),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── Divider ──────────────────────────────────────────────────
                  Container(height: 1, color: border),

                  const SizedBox(height: 12),

                  // ── Stats row ────────────────────────────────────────────────
                  Row(
                    children: [
                      _StatChip(
                        label: 'Check-ins',
                        value: '${stats.totalCheckIns}',
                        accent: accent,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                      ),
                      if (stats.bestHabit != null) ...[
                        Container(
                          width: 1,
                          height: 28,
                          color: border,
                          margin: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        _HabitChip(
                          label: 'Best habit',
                          habit: stats.bestHabit!,
                          textPrimary: textPrimary,
                          textMuted: textMuted,
                        ),
                      ],
                      if (stats.mostMissedHabit != null) ...[
                        Container(
                          width: 1,
                          height: 28,
                          color: border,
                          margin: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        _HabitChip(
                          label: 'Needs work',
                          habit: stats.mostMissedHabit!,
                          textPrimary: textPrimary,
                          textMuted: textMuted,
                        ),
                      ],
                    ],
                  ),

                  // Rendered only when there's actually a message — an
                  // always-present Text with an empty string still
                  // reserves a full line's height, which is exactly what
                  // read as "empty space below" the stats row on every
                  // week that actually has check-ins (i.e. almost always).
                  // The one thing that reservation bought — no layout
                  // jump if a check-in lands while this exact card is on
                  // screen — is a genuinely rare moment to trade against
                  // a gap that's visible on every single normal week.
                  if (stats.totalCheckIns == 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'No check-ins recorded this week yet.',
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: -0.05, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }
}

// ─── Stat chip ────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.accent,
    required this.textPrimary,
    required this.textMuted,
  });

  final String label;
  final String value;
  final Color accent;
  final Color textPrimary;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        Text(label, style: TextStyle(color: textMuted, fontSize: 10)),
      ],
    );
  }
}

// ─── Habit chip ───────────────────────────────────────────────────────────────

class _HabitChip extends StatelessWidget {
  const _HabitChip({
    required this.label,
    required this.habit,
    required this.textPrimary,
    required this.textMuted,
  });

  final String label;
  final Habit habit;
  final Color textPrimary;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    final accentColor = colorFromHex(habit.colorHex);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: readableAccent(accentColor, fallback: textMuted),
              ),
            ),
            const SizedBox(width: 5),
            Text(habit.emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 80),
              child: Text(
                habit.name,
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        Text(label, style: TextStyle(color: textMuted, fontSize: 10)),
      ],
    );
  }
}
