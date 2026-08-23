import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/app_config.dart';
import '../../../core/copy/app_copy.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/color_hex.dart';
import '../../../core/utils/local_date.dart';
import '../../../core/widgets/flat_confirm_dialog.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../monetization/application/entitlement_providers.dart';
import '../../monetization/presentation/paywall_navigation.dart';
import '../../notifications/application/notification_providers.dart';
import '../application/check_in_actions.dart';
import '../application/habit_providers.dart';
import '../domain/check_in.dart';
import '../domain/check_in_status.dart';
import '../domain/frequency.dart';
import '../domain/habit.dart';
import '../domain/habit_category.dart';
import '../domain/streak_calculator.dart';
import 'edit_habit_screen.dart';
import 'widgets/year_heatmap.dart';

/// Minimal flat Habit Detail screen.
/// No gradients, no glow — clean typography, flat cards, thin borders.
class HabitDetailScreen extends ConsumerWidget {
  const HabitDetailScreen({super.key, required this.habit});

  final Habit habit;

  // Both actions previously lived only behind EditHabitScreen's overflow
  // menu — a habit's own detail page is where people are most likely to
  // reach for "archive this" or "delete this", so this mirrors that same
  // confirm-dialog flow directly here instead of requiring a detour
  // through Edit first.

  Future<void> _archive(
    BuildContext context,
    WidgetRef ref,
    Habit currentHabit,
  ) async {
    final confirmed = await showFlatConfirmDialog(
      context: context,
      title: 'Archive habit?',
      body:
          'This habit will be hidden from your list. You can restore it from the archived habits screen.',
      confirmLabel: 'Archive',
      isDanger: false,
    );
    if (confirmed != true) return;
    await ref.read(habitRepositoryProvider).archiveHabit(currentHabit.id);
    // An archived habit must not still fire its streak-at-risk alert
    // tonight — same reasoning as EditHabitScreen's _archive().
    await ref
        .read(notificationServiceProvider)
        .cancelAllForHabit(currentHabit.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Habit currentHabit,
  ) async {
    final confirmed = await showFlatConfirmDialog(
      context: context,
      title: AppCopy.deleteHabitConfirmTitle,
      body: AppCopy.deleteHabitConfirmBody,
      confirmLabel: 'Delete',
      isDanger: true,
    );
    if (confirmed != true) return;
    await ref.read(habitRepositoryProvider).deleteHabit(currentHabit.id);
    await ref
        .read(notificationServiceProvider)
        .cancelAllForHabit(currentHabit.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // [habit] is a snapshot from whenever this screen was pushed — it
    // never updates on its own, so without this, editing the habit's
    // name/emoji/color/frequency via EditHabitScreen and popping back
    // kept showing the pre-edit values until the screen was closed and
    // reopened. activeHabitsProvider already has the live copy; fall
    // back to the pushed-in snapshot if it's not in the loaded list yet
    // (e.g. the first frame, while it's still loading).
    final liveHabits = ref.watch(activeHabitsProvider).valueOrNull;
    final currentHabit =
        liveHabits?.firstWhere((h) => h.id == habit.id, orElse: () => habit) ??
        habit;

    final detail = ref.watch(streakDetailProvider(currentHabit));
    final accentColor = colorFromHex(currentHabit.colorHex);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.background : AppColors.backgroundLight;
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
    final border = isDark ? AppColors.border : AppColors.borderLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;

    final isPro = ref.watch(hasActiveEntitlementProvider).valueOrNull ?? false;

    // Feature 2 – Habit Notes: keyed by date so the monthly grid can show a
    // note dot and the day-action sheet can prefill an existing note/value.
    final checkInsByDate = <String, CheckIn>{
      for (final c
          in ref.watch(habitCheckInsProvider(currentHabit.id)).valueOrNull ??
              const <CheckIn>[])
        c.date: c,
    };

    // Same check-in toggle HabitTile/HabitGridCard have on Home — this
    // screen had no quick way to check today off without scrolling down
    // to the calendar grid and tapping today's cell. Independent of
    // [detail] (streakDetailProvider), so it's ready even while that's
    // still loading.
    final today = todayLocalDateString();
    final checkIn = ref.watch(
      checkInProvider(CheckInQuery(currentHabit.id, today)),
    );
    final isDone = checkIn.valueOrNull?.completed ?? false;
    final isScheduledToday = currentHabit.isScheduledOnWeekday(
      DateTime.now().weekday,
    );
    void toggleCheckIn() => performCheckIn(
      context: context,
      ref: ref,
      habit: currentHabit,
      date: today,
      isDone: isDone,
    );

    return Scaffold(
      backgroundColor: bg,
      body: detail.when(
        loading: () => CustomScrollView(
          slivers: [
            _HeroHeader(
              habit: currentHabit,
              accentColor: accentColor,
              isDark: isDark,
              isDone: isDone,
              isScheduledToday: isScheduledToday,
              onToggleCheckIn: toggleCheckIn,
              onArchive: () => _archive(context, ref, currentHabit),
              onDelete: () => _confirmDelete(context, ref, currentHabit),
            ),
            SliverToBoxAdapter(child: _HabitDetailSkeleton(isDark: isDark)),
          ],
        ),
        error: (error, _) => Center(child: Text('$error')),
        data: (result) => CustomScrollView(
          slivers: [
            _HeroHeader(
              habit: currentHabit,
              accentColor: accentColor,
              isDark: isDark,
              isDone: isDone,
              isScheduledToday: isScheduledToday,
              onToggleCheckIn: toggleCheckIn,
              onArchive: () => _archive(context, ref, currentHabit),
              onDelete: () => _confirmDelete(context, ref, currentHabit),
            ),
            SliverToBoxAdapter(
              child: Padding(
                // Flat 40 bottom padding used to sit mostly *behind* a
                // device's system nav bar instead of being visible space
                // above it, so "Log a past day" ended up flush against
                // the edge instead of having real breathing room.
                padding: EdgeInsets.fromLTRB(
                  16,
                  20,
                  16,
                  40 + MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Stat cards ─────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: currentHabit.isQuitHabit
                                ? 'Days Clean'
                                : 'Current Streak',
                            value: '${result.currentStreak}',
                            suffix: 'days',
                            icon: '🔥',
                            accentColor: accentColor,
                            surface: surface,
                            border: border,
                            textPrimary: textPrimary,
                            textMuted: textMuted,
                            isPrimary: true,
                          ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.1),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatCard(
                            label: 'Best Streak',
                            value: '${result.longestStreak}',
                            suffix: 'days',
                            icon: '🏆',
                            accentColor: accentColor,
                            surface: surface,
                            border: border,
                            textPrimary: textPrimary,
                            textMuted: textMuted,
                          ).animate().fadeIn(delay: 140.ms).slideY(begin: 0.1),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatCard(
                            label: 'Completion',
                            value: '${(result.completionRate * 100).round()}',
                            suffix: '%',
                            icon: '📊',
                            accentColor: accentColor,
                            surface: surface,
                            border: border,
                            textPrimary: textPrimary,
                            textMuted: textMuted,
                          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
                        ),
                      ],
                    ),

                    // ── Description ────────────────────────────────────────
                    if (currentHabit.description != null &&
                        currentHabit.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: surface,
                            border: Border.all(color: border, width: 1),
                          ),
                          child: Text(
                            currentHabit.description!,
                            style: TextStyle(
                              color: textMuted,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ).animate().fadeIn(delay: 210.ms),
                      ),

                    if (currentHabit.isQuantityHabit)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _QuantityProgressCard(
                          habit: currentHabit,
                          value: checkIn.valueOrNull?.value ?? 0,
                          surface: surface,
                          border: border,
                          textPrimary: textPrimary,
                          textMuted: textMuted,
                          accentColor: accentColor,
                          onChange: (newValue) async {
                            final target = currentHabit.targetCount ?? 1;
                            await ref
                                .read(habitRepositoryProvider)
                                .setCheckIn(
                                  habitId: currentHabit.id,
                                  date: today,
                                  status: newValue >= target
                                      ? CheckInStatus.completed
                                      : CheckInStatus.missed,
                                  value: newValue,
                                );
                          },
                        ).animate().fadeIn(delay: 220.ms),
                      ),

                    if (currentHabit.frequencyType == FrequencyType.xPerWeek)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _WeekProgressChip(
                          habit: currentHabit,
                          result: result,
                          accentColor: accentColor,
                          surface: surface,
                          border: border,
                          textMuted: textMuted,
                        ),
                      ),

                    const SizedBox(height: 28),

                    // ── History header ─────────────────────────────────────
                    Row(
                      children: [
                        Text(
                          'History',
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: accentColor.withValues(alpha: 0.12),
                          ),
                          child: Text(
                            '${result.days.where((d) => d.status == DayStatus.completed).length} check-ins',
                            style: TextStyle(
                              color: readableAccent(
                                accentColor,
                                fallback: textMuted,
                              ),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 240.ms),
                    const SizedBox(height: 4),
                    Text(
                      'Tap a day to log it. Long-press for a note, quantity, or to mark it skipped.',
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ).animate().fadeIn(delay: 240.ms),

                    const SizedBox(height: 10),

                    // ── Monthly contribution grid ───────────────────────────
                    _MonthlyContributionGrid(
                      habit: currentHabit,
                      days: result.days,
                      accentColor: accentColor,
                      surface: surface,
                      border: border,
                      isDark: isDark,
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                      isPro: isPro,
                      checkInsByDate: checkInsByDate,
                    ).animate().fadeIn(delay: 280.ms),

                    const SizedBox(height: 24),

                    // ── 30-day activity ────────────────────────────────────
                    _SectionLabel(
                      label: '30-Day Activity',
                      textMuted: textMuted,
                    ).animate().fadeIn(delay: 320.ms),
                    const SizedBox(height: 8),
                    _FlatCard(
                      surface: surface,
                      border: border,
                      child: _DetailBarChart(
                        days: result.days,
                        accentColor: accentColor,
                        textMuted: textMuted,
                        isDark: isDark,
                      ),
                    ).animate().fadeIn(delay: 360.ms),

                    const SizedBox(height: 20),

                    // ── Day-of-week heatmap ────────────────────────────────
                    _SectionLabel(
                      label: 'Best Days of Week',
                      textMuted: textMuted,
                    ).animate().fadeIn(delay: 400.ms),
                    const SizedBox(height: 8),
                    _FlatCard(
                      surface: surface,
                      border: border,
                      child: _DetailDowHeatmap(
                        days: result.days,
                        accentColor: accentColor,
                        textMuted: textMuted,
                        textPrimary: textPrimary,
                      ),
                    ).animate().fadeIn(delay: 440.ms),

                    const SizedBox(height: 20),

                    // ── This year ───────────────────────────────────────────
                    _SectionLabel(
                      label: 'This Year',
                      textMuted: textMuted,
                    ).animate().fadeIn(delay: 480.ms),
                    const SizedBox(height: 8),
                    _FlatCard(
                      surface: surface,
                      border: border,
                      child: YearHeatmap(
                        intensityByDate: {
                          for (final d in result.days)
                            if (d.status == DayStatus.completed)
                              '${d.date.year.toString().padLeft(4, '0')}-${d.date.month.toString().padLeft(2, '0')}-${d.date.day.toString().padLeft(2, '0')}':
                                  (d.runLength / 7).clamp(0.4, 1.0),
                        },
                        accent: accentColor,
                        emptyColor: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.05),
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                      ),
                    ).animate().fadeIn(delay: 500.ms),

                    const SizedBox(height: 24),

                    // ── Log past day ───────────────────────────────────────
                    OutlinedButton.icon(
                      onPressed: () => _logPastDay(context, ref, isPro: isPro),
                      icon: const Icon(Icons.history_rounded, size: 16),
                      label: const Text('Log a past day'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textMuted,
                        side: BorderSide(color: border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        textStyle: TextStyle(
                          fontSize: 13,
                          fontFamily: GoogleFonts.outfit().fontFamily,
                        ),
                      ),
                    ).animate().fadeIn(delay: 460.ms),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logPastDay(
    BuildContext context,
    WidgetRef ref, {
    required bool isPro,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Free tier: only the past 7 days. Pro: unlimited history — not tied
    // to the habit's own creation date, since a habit created today
    // should still let you backfill days before it existed (you were
    // presumably doing the thing, just hadn't started tracking it yet).
    // Bounding this to createdAt instead used to make firstDate land
    // *after* lastDate for any habit created today, which showDatePicker
    // asserts on and crashes.
    // 7 days total including today: today itself is logged via the normal
    // tap-to-check-in flow, not this picker, so the picker's own past-day
    // range only needs to reach back 6 days to make the combined window
    // exactly 7 (today - 6 days ago).
    final firstDate = isPro
        ? DateTime(2000, 1, 1)
        : today.subtract(
            const Duration(days: AppConfig.freeTierBackfillDays - 1),
          );

    final lastDate = today.subtract(const Duration(days: 1));

    // If free user has no eligible days at all (the app itself is less
    // than a day old — never happens in practice, but keeps the picker
    // call below safe regardless).
    if (!isPro && firstDate.isAfter(lastDate)) {
      if (!context.mounted) return;
      await navigateToPaywall(context, ref);
      return;
    }

    // showDatePicker asserts that initialDate satisfies
    // selectableDayPredicate, so lastDate (usually "yesterday") can't be
    // used blindly — a sparse weekdays schedule (e.g. Mondays only) may
    // not land on it. Walk back to the nearest day this habit is actually
    // scheduled for; a weekdays habit is guaranteed one within any 7-day
    // span, but the free tier's 6-day window is one short of that
    // guarantee, so there's a real (rare) chance none exists at all.
    DateTime? initialDate;
    for (
      var d = lastDate;
      !d.isBefore(firstDate);
      d = d.subtract(const Duration(days: 1))
    ) {
      if (habit.isScheduledOnWeekday(d.weekday)) {
        initialDate = d;
        break;
      }
    }
    if (initialDate == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No eligible days to log in this range.')),
      );
      return;
    }

    if (!context.mounted) return;
    final picked = await showDatePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDate: initialDate,
      // Days this habit isn't scheduled for (e.g. picking a Sunday for a
      // Mon/Wed/Fri habit) aren't valid backfill targets at all.
      selectableDayPredicate: (day) => habit.isScheduledOnWeekday(day.weekday),
    );
    if (picked == null) return;
    if (!context.mounted) return;
    final dateKey = localDateString(picked);
    final existing = await ref
        .read(habitRepositoryProvider)
        .watchCheckIn(habitId: habit.id, date: dateKey)
        .first;
    if (!context.mounted) return;
    await showDayActionSheet(
      context,
      ref,
      habit: habit,
      date: dateKey,
      existing: existing,
    );
  }
}

// ─── Day action sheet (Complete / Skip / Clear + note + quantity) ─────────────
//
// Feature 2 – Habit Notes, plus the "skip" tri-state and quantity-habit
// value entry — all three are extensions of "log a specific day," so they
// share one bottom sheet rather than three separate flows. Reachable from
// the monthly grid (long-press a day) and from "Log a past day."
Future<void> showDayActionSheet(
  BuildContext context,
  WidgetRef ref, {
  required Habit habit,
  required String date,
  required CheckIn? existing,
}) async {
  final noteController = TextEditingController(text: existing?.note ?? '');
  final valueController = TextEditingController(
    text: existing?.value?.toString() ?? '',
  );
  CheckInStatus? chosen;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
  final textPrimary = isDark
      ? AppColors.textPrimary
      : AppColors.textPrimaryLight;
  final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;
  final accent = colorFromHex(habit.colorHex);
  final parsed = DateTime.parse(date);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: 20 + MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_weekdayName(parsed.weekday)}, ${_monthName(parsed.month)} ${parsed.day}',
              style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${habit.emoji}  ${habit.name}',
              style: TextStyle(color: textMuted, fontSize: 13),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _DaySheetActionButton(
                    label: habit.isQuitHabit ? 'Stayed strong' : 'Complete',
                    icon: Icons.check_rounded,
                    color: accent,
                    onTap: () {
                      chosen = CheckInStatus.completed;
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DaySheetActionButton(
                    label: 'Skip',
                    icon: Icons.remove_rounded,
                    color: textMuted,
                    onTap: () {
                      chosen = CheckInStatus.skipped;
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DaySheetActionButton(
                    label: habit.isQuitHabit ? 'Slipped' : 'Clear',
                    icon: Icons.close_rounded,
                    color: AppColors.danger,
                    onTap: () {
                      chosen = CheckInStatus.missed;
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                ),
              ],
            ),
            if (habit.isQuantityHabit) ...[
              const SizedBox(height: 16),
              TextField(
                controller: valueController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  labelText:
                      'Logged ${habit.targetUnit ?? "amount"} (target ${habit.targetCount})',
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLength: 200,
              maxLines: 2,
              style: TextStyle(color: textPrimary),
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            // Only when the day already has a status - editing the note on
            // a fresh, never-logged day still needs Complete/Skip/Clear to
            // give it one. Reuses the exact same save path as those
            // buttons (set chosen, then pop) so there's one save codepath,
            // not two.
            if (existing != null) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    chosen = existing.status;
                    Navigator.of(sheetContext).pop();
                  },
                  icon: Icon(Icons.check_rounded, size: 16, color: accent),
                  label: Text(
                    'Save note',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 4),
          ],
        ),
      );
    },
  );

  final note = noteController.text.trim();
  final value = int.tryParse(valueController.text.trim());
  final noteChanged = note != (existing?.note?.trim() ?? '');
  final valueChanged = habit.isQuantityHabit && value != existing?.value;

  if (chosen == null) {
    // No Complete/Skip/Clear button tapped - the sheet was dismissed some
    // other way (tap outside, swipe down, back gesture). If the day
    // already has a status and the user only edited the note or the
    // logged quantity, save that against its existing status instead of
    // silently discarding it - re-tapping the same status just to keep a
    // note isn't something a user should have to do.
    if (existing == null || !(noteChanged || valueChanged)) return;
    chosen = existing.status;
  }

  await ref
      .read(habitRepositoryProvider)
      .setCheckIn(
        habitId: habit.id,
        date: date,
        status: chosen!,
        note: note.isEmpty ? null : note,
        value: habit.isQuantityHabit ? value : null,
      );
}

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
String _weekdayName(int weekday) => _weekdayNames[weekday - 1];
String _monthName(int month) => _monthNames[month - 1];

class _DaySheetActionButton extends StatelessWidget {
  const _DaySheetActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
          color: color.withValues(alpha: 0.08),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Loading skeleton ─────────────────────────────────────────────────────────
//
// The hero header renders instantly from [habit] (already known — passed
// in from the tapped tile), so only the part that depends on the async
// [streakDetailProvider] result needs a placeholder: the 3 stat cards, the
// monthly grid, and the two chart cards below it.
class _HabitDetailSkeleton extends StatelessWidget {
  const _HabitDetailSkeleton({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      isDark: isDark,
      builder: (context, colors) {
        return Padding(
          // Same fix as the data path a bit further up — flat 40 sat
          // partly behind a device's system nav bar during loading.
          padding: EdgeInsets.fromLTRB(
            16,
            20,
            16,
            40 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: List.generate(3, (i) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: i == 0 ? 0 : 4,
                        right: i == 2 ? 0 : 4,
                      ),
                      child: ShimmerCard(
                        colors: colors,
                        height: 76,
                        child: const SizedBox(),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 28),
              ShimmerBlock(height: 16, width: 90, color: colors.border),
              const SizedBox(height: 10),
              ShimmerCard(colors: colors, height: 160, child: const SizedBox()),
              const SizedBox(height: 24),
              ShimmerBlock(height: 11, width: 130, color: colors.border),
              const SizedBox(height: 8),
              ShimmerCard(colors: colors, height: 110, child: const SizedBox()),
              const SizedBox(height: 20),
              ShimmerBlock(height: 11, width: 150, color: colors.border),
              const SizedBox(height: 8),
              ShimmerCard(colors: colors, height: 90, child: const SizedBox()),
            ],
          ),
        );
      },
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.textMuted});
  final String label;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: textMuted,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}

// ─── Flat card wrapper ────────────────────────────────────────────────────────

class _FlatCard extends StatelessWidget {
  const _FlatCard({
    required this.child,
    required this.surface,
    required this.border,
  });
  final Widget child;
  final Color surface;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: 1),
      ),
      child: child,
    );
  }
}

// ─── Monthly Contribution Grid (PageView-based) ───────────────────────────────

class _MonthlyContributionGrid extends ConsumerStatefulWidget {
  const _MonthlyContributionGrid({
    required this.habit,
    required this.days,
    required this.accentColor,
    required this.surface,
    required this.border,
    required this.isDark,
    required this.textPrimary,
    required this.textMuted,
    required this.isPro,
    required this.checkInsByDate,
  });

  final Habit habit;
  final List<HabitDayStatus> days;
  final bool isPro;
  final Color accentColor;
  final Color surface;
  final Color border;
  final bool isDark;
  final Color textPrimary;
  final Color textMuted;

  /// "YYYY-MM-DD" → that day's check-in, so the grid can show a note dot
  /// and the day-action sheet can prefill an existing note/value.
  final Map<String, CheckIn> checkInsByDate;

  @override
  ConsumerState<_MonthlyContributionGrid> createState() =>
      _MonthlyContributionGridState();
}

class _MonthlyContributionGridState
    extends ConsumerState<_MonthlyContributionGrid> {
  static const List<String> _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static const List<String> _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  late PageController _pageController;
  late int _totalPages;
  late int _currentPageIndex;
  late int _displayYear;
  late int _displayMonth;

  /// Guards against a rapid double-tap on the *same* day cell firing two
  /// overlapping [setCheckIn] calls before the grid rebuilds with the new
  /// status — both would otherwise read the same stale [DayStatus] snapshot
  /// and write the same target value, harmless in itself but a wasted
  /// duplicate write. Different days toggle independently and aren't
  /// guarded against each other.
  final Set<String> _pendingToggles = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final first = _firstMonth;
    _totalPages = (now.year - first.year) * 12 + (now.month - first.month) + 1;
    if (_totalPages < 1) _totalPages = 1;
    _currentPageIndex = _totalPages - 1;
    _displayYear = now.year;
    _displayMonth = now.month;
    _pageController = PageController(initialPage: _currentPageIndex);
    _pageController.addListener(_onPageChanged);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged() {
    final page = _pageController.page?.round() ?? _currentPageIndex;
    if (page != _currentPageIndex) {
      setState(() {
        _currentPageIndex = page;
        final monthDate = _monthForIndex(page);
        _displayYear = monthDate.year;
        _displayMonth = monthDate.month;
      });
    }
  }

  DateTime get _firstMonth {
    if (widget.days.isEmpty) {
      final now = DateTime.now();
      return DateTime(now.year, now.month);
    }
    final d = widget.days.first.date;
    return DateTime(d.year, d.month);
  }

  DateTime _monthForIndex(int index) {
    final first = _firstMonth;
    final totalMonths = first.month - 1 + index;
    final year = first.year + totalMonths ~/ 12;
    final month = totalMonths % 12 + 1;
    return DateTime(year, month);
  }

  bool get _canGoBack => _currentPageIndex > 0;
  bool get _canGoForward => _currentPageIndex < _totalPages - 1;

  void _prev() {
    if (!_canGoBack) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _next() {
    if (!_canGoForward) return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _toggleDay(DateTime date, DayStatus? currentStatus) async {
    final key = _dateKey(date);
    if (!_pendingToggles.add(key)) return;
    try {
      HapticFeedback.lightImpact();
      await ref
          .read(habitRepositoryProvider)
          .setCheckIn(
            habitId: widget.habit.id,
            date: key,
            status: currentStatus != DayStatus.completed
                ? CheckInStatus.completed
                : CheckInStatus.missed,
          );
    } finally {
      _pendingToggles.remove(key);
    }
  }

  /// Same free-tier backfill window as [HabitDetailScreen._logPastDay] —
  /// the last 7 days *including* today are toggleable; anything older
  /// needs Pro. This grid used to let a tap on *any* past cell (in *any*
  /// month the pager could reach, with no bound of its own) toggle it
  /// directly, which bypassed that limit entirely regardless of what the
  /// "Log a past day" button enforced.
  bool _isDateLocked(DateTime date) {
    if (widget.isPro) return false;
    final today = DateTime.now();
    final oldestFreeDate = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: AppConfig.freeTierBackfillDays - 1));
    return date.isBefore(oldestFreeDate);
  }

  Future<void> _handleDayTap(DateTime date, DayStatus? currentStatus) async {
    // Defensive: the day-cell's onTap is already null for a non-scheduled
    // date, but this is the one entry point for toggling a day, so it's
    // the right place to refuse it outright too.
    if (!widget.habit.isScheduledOnWeekday(date.weekday)) return;
    if (_isDateLocked(date)) {
      await navigateToPaywall(context, ref);
      return;
    }
    await _toggleDay(date, currentStatus);
  }

  Future<void> _handleDayLongPress(
    DateTime date,
    DayStatus? currentStatus,
  ) async {
    if (!widget.habit.isScheduledOnWeekday(date.weekday)) return;
    if (_isDateLocked(date)) {
      await navigateToPaywall(context, ref);
      return;
    }
    final key = _dateKey(date);
    await showDayActionSheet(
      context,
      ref,
      habit: widget.habit,
      date: key,
      existing: widget.checkInsByDate[key],
    );
  }

  Widget _buildMonthGrid(int pageIndex) {
    final monthDate = _monthForIndex(pageIndex);
    final year = monthDate.year;
    final month = monthDate.month;

    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstDayOfMonth = DateTime(year, month, 1);
    final startCol = firstDayOfMonth.weekday - 1;
    final totalCols = ((startCol + daysInMonth) / 7).ceil();

    final statusMap = <String, HabitDayStatus>{};
    for (final d in widget.days) {
      if (d.date.year == year && d.date.month == month) {
        statusMap[_dateKey(d.date)] = d;
      }
    }

    const cellSize = 34.0;
    const cellGap = 4.0;
    const step = cellSize + cellGap;

    final today = DateTime.now();
    final todayKey = _dateKey(today);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day-of-week labels
        Column(
          children: List.generate(7, (row) {
            return SizedBox(
              width: 14,
              height: step,
              child: Center(
                child: Text(
                  _dayLabels[row],
                  style: TextStyle(
                    color: widget.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(totalCols, (col) {
              return Column(
                children: List.generate(7, (row) {
                  final dayNum = col * 7 + row - startCol + 1;
                  if (dayNum < 1 || dayNum > daysInMonth) {
                    return SizedBox(width: cellSize, height: step);
                  }
                  final date = DateTime(year, month, dayNum);
                  final key = _dateKey(date);
                  final dayStatus = statusMap[key];
                  final isToday = todayKey == key;
                  final isFuture = date.isAfter(today);
                  final isScheduled = widget.habit.isScheduledOnWeekday(
                    date.weekday,
                  );
                  return _DayCell(
                    dayNum: dayNum,
                    status: dayStatus?.status,
                    runLength: dayStatus?.runLength ?? 0,
                    isToday: isToday,
                    isFuture: isFuture,
                    accentColor: widget.accentColor,
                    textMuted: widget.textMuted,
                    isDark: widget.isDark,
                    cellSize: cellSize,
                    gap: cellGap,
                    hasNote: widget.checkInsByDate[key]?.note != null,
                    onTap: (isFuture || !isScheduled)
                        ? null
                        : () => _handleDayTap(date, dayStatus?.status),
                    onLongPress: (isFuture || !isScheduled)
                        ? null
                        : () => _handleDayLongPress(date, dayStatus?.status),
                  );
                }),
              );
            }),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const cellSize = 34.0;
    const cellGap = 4.0;
    const gridHeight = 7 * (cellSize + cellGap);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: widget.surface,
        border: Border.all(color: widget.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Month navigator ────────────────────────────────────────────
          Row(
            children: [
              _NavArrow(
                icon: Icons.chevron_left_rounded,
                enabled: _canGoBack,
                onTap: _prev,
                textMuted: widget.textMuted,
                accentColor: widget.accentColor,
                label: 'Previous month',
              ),
              Expanded(
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      '${_monthNames[_displayMonth - 1]} $_displayYear',
                      key: ValueKey('$_displayYear-$_displayMonth'),
                      style: TextStyle(
                        color: widget.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
              _NavArrow(
                icon: Icons.chevron_right_rounded,
                enabled: _canGoForward,
                onTap: _next,
                textMuted: widget.textMuted,
                accentColor: widget.accentColor,
                label: 'Next month',
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── PageView grid ──────────────────────────────────────────────
          SizedBox(
            height: gridHeight,
            child: PageView.builder(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              itemCount: _totalPages,
              itemBuilder: (context, index) => _buildMonthGrid(index),
            ),
          ),

          const SizedBox(height: 10),

          // ── Legend ────────────────────────────────────────────────────
          Row(
            children: [
              Text(
                'Less',
                style: TextStyle(color: widget.textMuted, fontSize: 9),
              ),
              const SizedBox(width: 4),
              ...List.generate(5, (i) {
                return Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: widget.accentColor.withValues(
                      alpha: 0.15 + i * 0.17,
                    ),
                  ),
                );
              }),
              const SizedBox(width: 4),
              Text(
                'More',
                style: TextStyle(color: widget.textMuted, fontSize: 9),
              ),
              const Spacer(),
              Text(
                'Tap to toggle',
                style: TextStyle(
                  color: widget.textMuted.withValues(alpha: 0.5),
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Day Cell ─────────────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.dayNum,
    required this.status,
    required this.runLength,
    required this.isToday,
    required this.isFuture,
    required this.accentColor,
    required this.textMuted,
    required this.isDark,
    required this.cellSize,
    required this.gap,
    this.onTap,
    this.onLongPress,
    this.hasNote = false,
  });

  final int dayNum;
  final DayStatus? status;
  final int runLength;
  final bool isToday;
  final bool isFuture;
  final Color accentColor;
  final Color textMuted;
  final bool isDark;
  final double cellSize;
  final double gap;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Feature 2 – Habit Notes: shows a small dot when this day has one.
  final bool hasNote;

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;

    switch (status) {
      case DayStatus.completed:
        final intensity = (runLength / 7).clamp(0.35, 1.0);
        bgColor = accentColor.withValues(alpha: intensity);
        textColor = contrastForeground(bgColor);
      case DayStatus.missed:
        bgColor = isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.07);
        textColor = textMuted;
      case DayStatus.skipped:
        bgColor = isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.05);
        textColor = textMuted.withValues(alpha: 0.7);
      case DayStatus.future:
      case DayStatus.notApplicable:
      case null:
        bgColor = isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.04);
        textColor = textMuted.withValues(alpha: isFuture ? 0.3 : 0.5);
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: cellSize,
        height: cellSize,
        margin: EdgeInsets.only(bottom: gap),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          color: bgColor,
          border: isToday ? Border.all(color: accentColor, width: 1.5) : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '$dayNum',
              style: TextStyle(
                color: textColor,
                fontSize: 9,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            if (hasNote)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: textColor.withValues(alpha: 0.9),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Nav Arrow ────────────────────────────────────────────────────────────────

class _NavArrow extends StatelessWidget {
  const _NavArrow({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.textMuted,
    required this.accentColor,
    required this.label,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final Color textMuted;
  final Color accentColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: 20,
            color: enabled ? accentColor : textMuted.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}

// ─── Hero Header ──────────────────────────────────────────────────────────────

class _HeroHeader extends ConsumerWidget {
  const _HeroHeader({
    required this.habit,
    required this.accentColor,
    required this.isDark,
    required this.isDone,
    required this.isScheduledToday,
    required this.onToggleCheckIn,
    required this.onArchive,
    required this.onDelete,
  });

  final Habit habit;
  final Color accentColor;
  final bool isDark;
  final bool isDone;
  final bool isScheduledToday;
  final VoidCallback onToggleCheckIn;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bg = isDark ? AppColors.background : AppColors.backgroundLight;
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
    final border = isDark ? AppColors.border : AppColors.borderLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;
    final category = habit.categoryId == null
        ? null
        : (ref.watch(categoriesProvider).valueOrNull ?? const [])
              .cast<HabitCategory?>()
              .firstWhere((c) => c!.id == habit.categoryId, orElse: () => null);

    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: textPrimary,
        ),
        tooltip: 'Back',
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.edit_outlined, size: 18, color: textPrimary),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => EditHabitScreen(existing: habit)),
          ),
        ),
        // Previously only reachable via EditHabitScreen's own overflow
        // menu — a habit's own detail page is where people are most
        // likely to reach for this, so it's mirrored here directly.
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, size: 18, color: textPrimary),
          color: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          onSelected: (value) {
            if (value == 'archive') onArchive();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'archive',
              child: Row(
                children: [
                  Icon(Icons.archive_outlined, size: 18, color: textMuted),
                  const SizedBox(width: 10),
                  Text('Archive', style: TextStyle(color: textPrimary)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: AppColors.danger,
                  ),
                  const SizedBox(width: 10),
                  Text('Delete', style: TextStyle(color: AppColors.danger)),
                ],
              ),
            ),
          ],
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: border),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: bg,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 52, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: surface,
                      border: Border.all(color: border, width: 1),
                    ),
                    child: Center(
                      child: Text(
                        habit.emoji,
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.name,
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: accentColor,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _frequencyLabel(habit),
                                  style: TextStyle(
                                    color: textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            if (habit.reminderTime != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  color: accentColor.withValues(alpha: 0.12),
                                  border: Border.all(
                                    color: accentColor.withValues(alpha: 0.25),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.notifications_outlined,
                                      size: 10,
                                      color: accentColor,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      _formatReminderTime(habit.reminderTime!),
                                      style: TextStyle(
                                        color: accentColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (category != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  color: textMuted.withValues(alpha: 0.1),
                                ),
                                child: Text(
                                  '${category.emoji} ${category.name}',
                                  style: TextStyle(
                                    color: textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Semantics(
                    label: !isScheduledToday
                        ? '${habit.name}, not scheduled today'
                        : isDone
                        ? '${habit.name}, done today, tap to undo'
                        : '${habit.name}, mark done today',
                    button: true,
                    child: _DetailCheckInToggle(
                      isDone: isDone,
                      color: accentColor,
                      enabled: isScheduledToday,
                      onTap: isScheduledToday ? onToggleCheckIn : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _frequencyLabel(Habit habit) {
    return switch (habit.frequencyType) {
      FrequencyType.daily => 'Every day',
      FrequencyType.weekdays => 'Weekdays',
      FrequencyType.xPerWeek => () {
        final config = habit.frequencyConfig as XPerWeekConfig;
        return '${config.timesPerWeek}× per week';
      }(),
    };
  }

  /// Converts stored "HH:mm" to a human-readable "9:00 AM" / "9:00 PM" string.
  String _formatReminderTime(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final period = hour < 12 ? 'AM' : 'PM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');
    return '$displayHour:$displayMinute $period';
  }
}

// ─── Hero header check-in toggle ───────────────────────────────────────────────
//
// Mirrors HabitTile's _CheckInToggle exactly (same size, animation, and
// enabled/muted states) — this screen otherwise had no quick way to check
// today off without scrolling to the calendar grid and tapping today's cell.

class _DetailCheckInToggle extends StatefulWidget {
  const _DetailCheckInToggle({
    required this.isDone,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  final bool isDone;
  final Color color;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<_DetailCheckInToggle> createState() => _DetailCheckInToggleState();
}

class _DetailCheckInToggleState extends State<_DetailCheckInToggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 40),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.25,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 60,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(_DetailCheckInToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDone && !oldWidget.isDone) {
      _controller.forward(from: 0);
    } else if (!widget.isDone) {
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.2)
        : Colors.black.withValues(alpha: 0.15);
    final checkIconColor = contrastForeground(widget.color);

    return Opacity(
      opacity: widget.enabled ? 1.0 : 0.35,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: widget.isDone ? _scale.value : 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: widget.isDone ? widget.color : Colors.transparent,
                  border: Border.all(
                    color: widget.isDone ? widget.color : borderColor,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.isDone ? Icons.check_rounded : Icons.add_rounded,
                      size: 16,
                      color: widget.isDone
                          ? checkIconColor
                          : (isDark ? Colors.white70 : Colors.black54),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      widget.isDone ? 'Done' : 'Check in',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: widget.isDone
                            ? checkIconColor
                            : (isDark ? Colors.white70 : Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.suffix,
    required this.icon,
    required this.accentColor,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textMuted,
    this.isPrimary = false,
  });

  final String label;
  final String value;
  final String suffix;
  final String icon;
  final Color accentColor;
  final Color surface;
  final Color border;
  final Color textPrimary;
  final Color textMuted;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: isPrimary ? accentColor.withValues(alpha: 0.08) : surface,
        border: Border.all(
          color: isPrimary ? accentColor.withValues(alpha: 0.3) : border,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: isPrimary
                        ? readableAccent(accentColor, fallback: textPrimary)
                        : textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                TextSpan(
                  text: ' $suffix',
                  style: TextStyle(color: textMuted, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              color: textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Quantity Progress Card ───────────────────────────────────────────────────

/// Today's tally for a quantity habit (e.g. "3 / 8 glasses") — a stepper
/// rather than the plain check-in toggle, since "done" here means "reached
/// the target," not "tapped once."
class _QuantityProgressCard extends StatelessWidget {
  const _QuantityProgressCard({
    required this.habit,
    required this.value,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textMuted,
    required this.accentColor,
    required this.onChange,
  });

  final Habit habit;
  final int value;
  final Color surface;
  final Color border;
  final Color textPrimary;
  final Color textMuted;
  final Color accentColor;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    final target = habit.targetCount ?? 1;
    final unit = habit.targetUnit ?? 'today';
    final ratio = (value / target).clamp(0.0, 1.0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: surface,
        border: Border.all(color: border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$value',
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              Text(
                ' / $target $unit today',
                style: TextStyle(color: textMuted, fontSize: 13),
              ),
              const Spacer(),
              _StepperButton(
                icon: Icons.remove_rounded,
                color: textMuted,
                onTap: value > 0 ? () => onChange(value - 1) : null,
              ),
              const SizedBox(width: 8),
              _StepperButton(
                icon: Icons.add_rounded,
                color: accentColor,
                onTap: () => onChange(value + 1),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: border,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: enabled ? 1 : 0.3)),
        ),
        child: Icon(
          icon,
          size: 18,
          color: color.withValues(alpha: enabled ? 1 : 0.3),
        ),
      ),
    );
  }
}

// ─── Week Progress Chip ───────────────────────────────────────────────────────

class _WeekProgressChip extends StatelessWidget {
  const _WeekProgressChip({
    required this.habit,
    required this.result,
    required this.accentColor,
    required this.surface,
    required this.border,
    required this.textMuted,
  });

  final Habit habit;
  final StreakResult result;
  final Color accentColor;
  final Color surface;
  final Color border;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    final config = habit.frequencyConfig as XPerWeekConfig;
    final today = DateTime.now();
    final weekStart = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: today.weekday - 1));
    final completedThisWeek = result.days
        .where(
          (d) => !d.date.isBefore(weekStart) && d.status == DayStatus.completed,
        )
        .length;
    final progress = (completedThisWeek / config.timesPerWeek).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: surface,
        border: Border.all(color: border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'This week',
                style: TextStyle(color: textMuted, fontSize: 11),
              ),
              Text(
                '$completedThisWeek / ${config.timesPerWeek}',
                style: TextStyle(
                  color: readableAccent(accentColor, fallback: textMuted),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: accentColor.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 30-day bar chart ─────────────────────────────────────────────────────────

class _DetailBarChart extends StatelessWidget {
  const _DetailBarChart({
    required this.days,
    required this.accentColor,
    required this.textMuted,
    required this.isDark,
  });

  final List<HabitDayStatus> days;
  final Color accentColor;
  final Color textMuted;
  final bool isDark;

  static const _monthAbbr = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    // Build 30-day dataset
    final data = List.generate(30, (i) {
      final d = today.subtract(Duration(days: 29 - i));
      final ds = localDateString(d);
      final match = days.where((day) => localDateString(day.date) == ds);
      final status = match.isEmpty ? null : match.first.status;
      final isToday =
          d.day == today.day && d.month == today.month && d.year == today.year;
      return (date: d, status: status, isToday: isToday);
    });

    // Summary counts
    final doneCount = data.where((d) => d.status == DayStatus.completed).length;
    final missedCount = data.where((d) => d.status == DayStatus.missed).length;

    // Week-boundary label indices (every 7 days, starting at 0)
    final labelIndices = [0, 7, 14, 21, 28];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Summary pills ──────────────────────────────────────────────────
        Row(
          children: [
            _SummaryPill(
              label: '$doneCount done',
              color: accentColor,
              isDark: isDark,
            ),
            const SizedBox(width: 6),
            _SummaryPill(
              label: '$missedCount missed',
              color: textMuted,
              isDark: isDark,
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Bar chart ──────────────────────────────────────────────────────
        SizedBox(
          height: 80,
          child: CustomPaint(
            size: const Size(double.infinity, 80),
            painter: _DetailBarPainter(
              data: data,
              accent: accentColor,
              mutedColor: textMuted,
              isDark: isDark,
            ),
          ),
        ),
        const SizedBox(height: 5),

        // ── Week labels (Mon dd MMM) ───────────────────────────────────────
        LayoutBuilder(
          builder: (context, constraints) {
            final slotW = constraints.maxWidth / 30;
            return SizedBox(
              height: 14,
              child: Stack(
                children: [
                  for (final idx in labelIndices)
                    Positioned(
                      left: idx * slotW,
                      child: Text(
                        '${data[idx].date.day} ${_monthAbbr[data[idx].date.month - 1]}',
                        style: TextStyle(color: textMuted, fontSize: 8),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Small pill showing a count summary.
class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.color,
    required this.isDark,
  });
  final String label;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: color.withValues(alpha: isDark ? 0.15 : 0.10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DetailBarPainter extends CustomPainter {
  const _DetailBarPainter({
    required this.data,
    required this.accent,
    required this.mutedColor,
    required this.isDark,
  });

  final List<({DateTime date, DayStatus? status, bool isToday})> data;
  final Color accent;
  final Color mutedColor;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 2.0;
    final barWidth = (size.width - gap * (data.length - 1)) / data.length;
    const maxBarH = 72.0;
    const minBarH = 6.0;
    const missedBarH = 18.0; // visible but clearly shorter than done

    for (var i = 0; i < data.length; i++) {
      final d = data[i];
      final x = i * (barWidth + gap);

      final Color barColor;
      final double barH;

      switch (d.status) {
        case DayStatus.completed:
          barColor = d.isToday ? accent : accent.withValues(alpha: 0.75);
          barH = maxBarH;
        case DayStatus.missed:
          barColor = mutedColor.withValues(alpha: isDark ? 0.22 : 0.18);
          barH = missedBarH;
        default:
          // future / notApplicable / null — tiny baseline tick
          barColor = mutedColor.withValues(alpha: 0.08);
          barH = minBarH;
      }

      final rect = Rect.fromLTWH(x, size.height - barH, barWidth, barH);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
      canvas.drawRRect(rrect, Paint()..color = barColor);

      // Today marker dot above bar
      if (d.isToday) {
        final dotX = x + barWidth / 2;
        final dotY = size.height - barH - 5;
        canvas.drawCircle(Offset(dotX, dotY), 2.5, Paint()..color = accent);
      }
    }
  }

  @override
  bool shouldRepaint(_DetailBarPainter old) =>
      old.data != data || old.accent != accent || old.isDark != isDark;
}

// ─── Day-of-week heatmap ──────────────────────────────────────────────────────

class _DetailDowHeatmap extends StatelessWidget {
  const _DetailDowHeatmap({
    required this.days,
    required this.accentColor,
    required this.textMuted,
    required this.textPrimary,
  });

  final List<HabitDayStatus> days;
  final Color accentColor;
  final Color textMuted;
  final Color textPrimary;

  static const _labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final counts = List.filled(7, 0);
    final totals = List.filled(7, 0);
    for (final d in days) {
      if (d.status == DayStatus.future || d.status == DayStatus.notApplicable) {
        continue;
      }
      final idx = d.date.weekday - 1;
      totals[idx]++;
      if (d.status == DayStatus.completed) counts[idx]++;
    }
    final rates = List.generate(
      7,
      (i) => totals[i] == 0 ? 0.0 : counts[i] / totals[i],
    );

    return Row(
      children: List.generate(7, (i) {
        final rate = rates[i];
        final pct = (rate * 100).round();
        return Expanded(
          child: Column(
            children: [
              AnimatedContainer(
                duration: Duration(milliseconds: 350 + i * 50),
                curve: Curves.easeOut,
                height: 48,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: rate == 0
                      ? textMuted.withValues(alpha: 0.08)
                      : accentColor.withValues(alpha: 0.12 + 0.78 * rate),
                ),
                child: Center(
                  child: Builder(
                    builder: (context) {
                      final barColor = rate == 0
                          ? textMuted.withValues(alpha: 0.08)
                          : accentColor.withValues(alpha: 0.12 + 0.78 * rate);
                      final labelColor = rate == 0
                          ? textMuted.withValues(alpha: 0.4)
                          : contrastForeground(barColor);
                      return Text(
                        rate == 0 ? '-' : '$pct%',
                        style: TextStyle(
                          color: labelColor,
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(_labels[i], style: TextStyle(color: textMuted, fontSize: 8)),
            ],
          ),
        );
      }),
    );
  }
}
