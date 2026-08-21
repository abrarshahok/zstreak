import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/color_hex.dart';
import '../../../core/utils/local_date.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../analytics/presentation/overall_analytics_screen.dart';
import '../../monetization/application/entitlement_providers.dart';
import '../../monetization/presentation/paywall_navigation.dart';
import '../../onboarding/application/user_profile_provider.dart';
import '../../settings/presentation/settings_screen.dart';
import '../application/check_in_actions.dart';
import '../application/habit_providers.dart';
import '../domain/frequency.dart';
import '../domain/habit.dart';
import '../domain/streak_calculator.dart';
import '../domain/habit_template.dart';
import 'archived_habits_screen.dart';
import 'edit_habit_screen.dart';
import 'habit_detail_screen.dart';
import 'habit_tile.dart';
import 'weekly_review_card.dart';

// ─── View mode provider ───────────────────────────────────────────────────────

final _homeViewModeProvider = StateProvider<_ViewMode>((_) => _ViewMode.list);

enum _ViewMode { list, grid }

// ─── Focus mode provider ──────────────────────────────────────────────────────

final _homeFocusModeProvider = StateProvider<_FocusMode>((_) => _FocusMode.all);

enum _FocusMode { all, today }

// ─── Scheduling helper ────────────────────────────────────────────────────────

/// Returns true if [habit] is scheduled for [weekday] (ISO 1=Mon..7=Sun).
bool _isScheduledForDay(Habit habit, int weekday) {
  switch (habit.frequencyType) {
    case FrequencyType.daily:
      return true;
    case FrequencyType.weekdays:
      final cfg = habit.frequencyConfig as WeekdaysConfig;
      return cfg.weekdays.contains(weekday);
    case FrequencyType.xPerWeek:
      // xPerWeek habits are always eligible on any day of the week.
      return true;
  }
}

// ─── HomeScreen ───────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, this.banner});

  final Widget? banner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(activeHabitsProvider);
    final viewMode = ref.watch(_homeViewModeProvider);
    final focusMode = ref.watch(_homeFocusModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.background : AppColors.backgroundLight;

    // Watch entitlement — treat loading/error as "not Pro" (safe default).
    final isPro = ref.watch(hasActiveEntitlementProvider).valueOrNull ?? false;
    final limit = AppConfig.freeTierHabitLimit;

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          _HomeAppBar(
            banner: banner,
            isDark: isDark,
            viewMode: viewMode,
            focusMode: focusMode,
            onToggleView: () => ref.read(_homeViewModeProvider.notifier).state =
                viewMode == _ViewMode.list ? _ViewMode.grid : _ViewMode.list,
            onToggleFocus: (mode) =>
                ref.read(_homeFocusModeProvider.notifier).state = mode,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 96),
            sliver: habits.when(
              loading: () =>
                  SliverToBoxAdapter(child: _HabitListSkeleton(isDark: isDark)),
              error: (error, _) =>
                  SliverToBoxAdapter(child: _HabitsLoadError(isDark: isDark)),
              data: (list) {
                if (list.isEmpty) {
                  return SliverToBoxAdapter(
                    child: _EmptyStateWithTemplates(isDark: isDark),
                  );
                }

                // ── Determine visible vs locked habits (both focus modes) ──
                // Computed before branching on focus mode — Today Focus
                // used to receive the full unfiltered `list` here, which
                // meant a free user hit their habit limit in "All" but saw
                // every habit, paywall gate and all, the moment they
                // switched to "Today". Same gate, both views now.
                final visibleList = (!isPro && list.length > limit)
                    ? list.sublist(0, limit)
                    : list;
                final lockedCount = (!isPro && list.length > limit)
                    ? list.length - limit
                    : 0;

                // ── Today Focus mode ─────────────────────────────────────
                if (focusMode == _FocusMode.today) {
                  return _TodayFocusSliver(
                    habits: visibleList,
                    isDark: isDark,
                    lockedCount: lockedCount,
                  );
                }

                // ── All mode ─────────────────────────────────────────────
                return SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _StreakSummaryBar(
                        habits: visibleList,
                        isDark: isDark,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 8)),
                    SliverToBoxAdapter(
                      child: WeeklyReviewCard(habits: visibleList),
                    ),
                    if (viewMode == _ViewMode.list)
                      SliverToBoxAdapter(
                        child: _ReorderableHabitList(habits: visibleList),
                      )
                    else
                      SliverToBoxAdapter(
                        child: _ReorderableHabitGrid(habits: visibleList),
                      ),
                    // ── Paywall gate card (free tier / expired) ──────────
                    if (lockedCount > 0)
                      SliverToBoxAdapter(
                        child: _PaywallGateCard(
                          lockedCount: lockedCount,
                          isDark: isDark,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _AddHabitFab(
        isDark: isDark,
        isPro: isPro,
        habitCount: habits.valueOrNull?.length ?? 0,
        limit: limit,
      ),
    );
  }
}

// ─── Add Habit FAB ────────────────────────────────────────────────────────────

class _AddHabitFab extends ConsumerWidget {
  const _AddHabitFab({
    required this.isDark,
    required this.isPro,
    required this.habitCount,
    required this.limit,
  });

  final bool isDark;
  final bool isPro;
  final int habitCount;
  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final atLimit = !isPro && habitCount >= limit;
    final bg = isDark ? AppColors.textPrimary : AppColors.textPrimaryLight;
    final fg = isDark ? AppColors.background : AppColors.backgroundLight;
    final border = isDark ? AppColors.border : AppColors.borderLight;

    return GestureDetector(
      onTap: () {
        if (atLimit) {
          // Free tier at limit — open paywall instead.
          navigateToPaywall(context, ref);
        } else {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const EditHabitScreen()));
        }
      },
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              atLimit ? Icons.lock_outline_rounded : Icons.add_rounded,
              color: fg,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              atLimit ? 'Unlock more' : 'New habit',
              style: TextStyle(
                color: fg,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Habit list skeleton (loading state) ─────────────────────────────────────

class _HabitListSkeleton extends StatelessWidget {
  const _HabitListSkeleton({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      isDark: isDark,
      builder: (context, colors) {
        return Column(
          children: List.generate(5, (i) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ShimmerCard(
                colors: colors,
                height: 80,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    ShimmerCircle(size: 44, color: colors.border),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ShimmerBlock(height: 13, width: double.infinity, color: colors.border),
                          const SizedBox(height: 8),
                          ShimmerBlock(height: 10, width: 80, color: colors.border),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ShimmerCircle(size: 40, color: colors.border),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ─── Habits load error (self-healing) ────────────────────────────────────────
//
// A permission-denied right here immediately after a status change (e.g.
// reactivating a deactivated account) is usually just Firestore's local
// cache reacting to that write before the server has finished propagating
// it to this listener's own rule evaluation — a transient race, not a
// real failure. A Riverpod StreamProvider won't recover on its own once
// the underlying stream has already terminated with an error, even once
// the data source would allow it again, so this retries automatically
// once instead of leaving a raw error message stuck until the user finds
// a manual refresh — or, as happened before this existed, a full hot
// restart, since that's the only thing that recreates the provider fresh.
// Shown as the same shimmer skeleton as a normal load (not a spinner +
// retry button) since to the user this is indistinguishable from habits
// just taking a moment to load.
class _HabitsLoadError extends ConsumerStatefulWidget {
  const _HabitsLoadError({required this.isDark});

  final bool isDark;

  @override
  ConsumerState<_HabitsLoadError> createState() => _HabitsLoadErrorState();
}

class _HabitsLoadErrorState extends ConsumerState<_HabitsLoadError> {
  bool _retried = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted || _retried) return;
      _retried = true;
      ref.invalidate(activeHabitsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _HabitListSkeleton(isDark: widget.isDark);
  }
}

// ─── Today Focus Sliver ───────────────────────────────────────────────────────

class _TodayFocusSliver extends ConsumerWidget {
  const _TodayFocusSliver({
    required this.habits,
    required this.isDark,
    this.lockedCount = 0,
  });

  final List<Habit> habits;
  final bool isDark;

  /// Habits withheld by the free-tier limit — already excluded from
  /// [habits] by the caller. Shown here as a lock card, same as "All" mode,
  /// instead of just quietly not appearing.
  final int lockedCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    final todayStr = todayLocalDateString();

    // Filter to habits scheduled for today.
    final todayHabits = habits
        .where((h) => _isScheduledForDay(h, today.weekday))
        .toList();

    // Watch check-ins for all today's habits to compute done count.
    final doneCount = todayHabits.where((h) {
      final checkIn = ref.watch(checkInProvider(CheckInQuery(h.id, todayStr)));
      return checkIn.valueOrNull?.completed ?? false;
    }).length;

    final total = todayHabits.length;
    final allDone = total > 0 && doneCount == total;

    // Accent color: most-streaked habit's color, or AppColors.accent.
    // Live per-habit streak — see the comment on _StreakSummaryBar.
    int liveStreak(Habit h) =>
        ref.watch(streakDetailProvider(h)).valueOrNull?.currentStreak ??
        h.currentStreak;
    Color ringColor = AppColors.accent;
    if (todayHabits.isNotEmpty) {
      final mostStreaked = todayHabits.reduce(
        (a, b) => liveStreak(a) >= liveStreak(b) ? a : b,
      );
      if (liveStreak(mostStreaked) > 0) {
        ringColor = colorFromHex(mostStreaked.colorHex);
      }
    }

    return SliverMainAxisGroup(
      slivers: [
        // ── Progress ring ──────────────────────────────────────────────────
        SliverToBoxAdapter(
          child:
              _TodayProgressRing(
                    done: doneCount,
                    total: total,
                    ringColor: ringColor,
                    isDark: isDark,
                    allDone: allDone,
                  )
                  .animate()
                  .fadeIn(delay: 80.ms)
                  .scale(
                    begin: const Offset(0.92, 0.92),
                    duration: 300.ms,
                    curve: Curves.easeOut,
                  ),
        ),

        // ── Habit list ─────────────────────────────────────────────────────
        if (todayHabits.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Text(
                'No habits scheduled for today.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark
                      ? AppColors.textMuted
                      : AppColors.textMutedLight,
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          SliverList.builder(
            itemCount: todayHabits.length,
            itemBuilder: (context, index) {
              return HabitTile(habit: todayHabits[index], isListMode: false)
                  .animate()
                  .fadeIn(delay: (60 + 40 * index).ms)
                  .slideY(begin: 0.06, duration: 250.ms, curve: Curves.easeOut);
            },
          ),

        // ── Paywall gate card (free tier / expired) — same as All mode ──
        if (lockedCount > 0)
          SliverToBoxAdapter(
            child: _PaywallGateCard(lockedCount: lockedCount, isDark: isDark),
          ),
      ],
    );
  }
}

// ─── Today Progress Ring ──────────────────────────────────────────────────────

class _TodayProgressRing extends StatelessWidget {
  const _TodayProgressRing({
    required this.done,
    required this.total,
    required this.ringColor,
    required this.isDark,
    required this.allDone,
  });

  final int done;
  final int total;
  final Color ringColor;
  final bool isDark;
  final bool allDone;

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
    final border = isDark ? AppColors.border : AppColors.borderLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;

    final progress = total == 0 ? 0.0 : done / total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 1),
        ),
        child: Column(
          children: [
            // ── Ring ────────────────────────────────────────────────────
            SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(140, 140),
                    painter: _RingPainter(
                      progress: progress,
                      ringColor: ringColor,
                      trackColor: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.07),
                      strokeWidth: 10,
                    ),
                  ),
                  // Center text
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (allDone)
                        const Text('🔥', style: TextStyle(fontSize: 32))
                      else ...[
                        Text(
                          '$done',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                        Text(
                          'of $total',
                          style: TextStyle(
                            color: textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Label ────────────────────────────────────────────────────
            if (allDone)
              Text(
                'All done for today! 🔥',
                style: TextStyle(
                  color: ringColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              )
            else
              Text(
                total == 0
                    ? 'Nothing scheduled today'
                    : done == 0
                    ? "Let's get started!"
                    : '${((progress) * 100).round()}% complete — keep going!',
                style: TextStyle(
                  color: textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Ring Painter ─────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.ringColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color ringColor;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    const startAngle = -math.pi / 2; // top

    // Track (background ring)
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // Progress arc
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..color = ringColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.ringColor != ringColor ||
      old.trackColor != trackColor;
}

// ─── Reorderable Habit List ───────────────────────────────────────────────────
//
// Optimistic local state + reorder-in-flight guard:
//  1. On drag-end, _local is updated immediately in setState() — instant UI.
//  2. DB write fires in the background (no await).
//  3. _reordering flag is set for 800 ms; while set, didUpdateWidget ignores
//     stream emissions so the DB-write-triggered rebuild doesn't re-render
//     the list a second time.

class _ReorderableHabitList extends ConsumerStatefulWidget {
  const _ReorderableHabitList({required this.habits});

  final List<Habit> habits;

  @override
  ConsumerState<_ReorderableHabitList> createState() =>
      _ReorderableHabitListState();
}

class _ReorderableHabitListState extends ConsumerState<_ReorderableHabitList> {
  late List<Habit> _local;
  bool _reordering = false;

  @override
  void initState() {
    super.initState();
    _local = List<Habit>.from(widget.habits);
  }

  @override
  void didUpdateWidget(_ReorderableHabitList old) {
    super.didUpdateWidget(old);
    // While a reorder is in flight, ignore stream updates entirely so the
    // DB-write-triggered rebuild doesn't flash the list back to the old order.
    if (_reordering) return;
    // Outside of a reorder, sync only when the habit set changes (add/remove).
    final oldIds = old.habits.map((h) => h.id).toSet();
    final newIds = widget.habits.map((h) => h.id).toSet();
    if (oldIds != newIds) {
      _local = List<Habit>.from(widget.habits);
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    setState(() {
      _reordering = true;
      final moved = _local.removeAt(oldIndex);
      _local.insert(newIndex, moved);
    });
    // Persist in background.
    ref
        .read(habitRepositoryProvider)
        .reorderHabits(_local.map((h) => h.id).toList());
    // Clear the guard after the stream has had time to settle.
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _reordering = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _local.length,
      // ignore: deprecated_member_use
      onReorder: _onReorder,
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) => AnimatedBuilder(
        animation: animation,
        builder: (context, child) => Opacity(opacity: 0.85, child: child),
        child: child,
      ),
      itemBuilder: (context, index) {
        final habit = _local[index];
        return ReorderableDelayedDragStartListener(
          key: ValueKey(habit.id),
          index: index,
          child: HabitTile(habit: habit, isListMode: true),
        );
      },
    );
  }
}

// ─── Reorderable Habit Grid ───────────────────────────────────────────────────
//
// Uses ReorderableGridView for true per-card drag-and-drop in a 2-column grid.
// Optimistic local state + _reordering guard prevent stream-driven re-renders.

class _ReorderableHabitGrid extends ConsumerStatefulWidget {
  const _ReorderableHabitGrid({required this.habits});

  final List<Habit> habits;

  @override
  ConsumerState<_ReorderableHabitGrid> createState() =>
      _ReorderableHabitGridState();
}

class _ReorderableHabitGridState extends ConsumerState<_ReorderableHabitGrid> {
  late List<Habit> _local;
  bool _reordering = false;

  @override
  void initState() {
    super.initState();
    _local = List<Habit>.from(widget.habits);
  }

  @override
  void didUpdateWidget(_ReorderableHabitGrid old) {
    super.didUpdateWidget(old);
    if (_reordering) return;
    final oldIds = old.habits.map((h) => h.id).toSet();
    final newIds = widget.habits.map((h) => h.id).toSet();
    if (oldIds != newIds) {
      _local = List<Habit>.from(widget.habits);
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      _reordering = true;
      final moved = _local.removeAt(oldIndex);
      _local.insert(newIndex, moved);
    });
    ref
        .read(habitRepositoryProvider)
        .reorderHabits(_local.map((h) => h.id).toList());
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _reordering = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const hPad = 16.0;
    const gap = 10.0;
    final cardWidth = (screenWidth - hPad * 2 - gap) / 2;
    final cardHeight = cardWidth / 0.75;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: hPad),
      child: ReorderableGridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.only(top: 4),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: gap,
          mainAxisSpacing: gap,
          childAspectRatio: cardWidth / cardHeight,
        ),
        itemCount: _local.length,
        onReorder: _onReorder,
        dragWidgetBuilder: (index, child) =>
            Opacity(opacity: 0.88, child: child),
        itemBuilder: (context, index) {
          final habit = _local[index];
          return ReorderableItemView(
            key: ValueKey(habit.id),
            index: index,
            child: HabitGridCard(habit: habit),
          );
        },
      ),
    );
  }
}

// ─── Habit Grid Card ──────────────────────────────────────────────────────────

class HabitGridCard extends ConsumerWidget {
  const HabitGridCard({super.key, required this.habit});

  final Habit habit;

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    String today,
    bool isDone,
  ) => performCheckIn(
    context: context,
    ref: ref,
    habit: habit,
    date: today,
    isDone: isDone,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = todayLocalDateString();
    final checkIn = ref.watch(checkInProvider(CheckInQuery(habit.id, today)));
    final isDone = checkIn.valueOrNull?.completed ?? false;
    final accentColor = colorFromHex(habit.colorHex);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final streakDetail = ref.watch(streakDetailProvider(habit));
    // See the matching comment in HabitTile — sourced from streakDetail
    // (already watched, live per-habit) instead of habit.currentStreak,
    // which only refreshes when the whole habit list re-emits.
    final currentStreak =
        streakDetail.valueOrNull?.currentStreak ?? habit.currentStreak;
    final isOnFire = currentStreak >= 7;

    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
    final border = isDark ? AppColors.border : AppColors.borderLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => HabitDetailScreen(habit: habit)),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: surface,
          border: Border.all(
            color: isDone ? accentColor.withValues(alpha: 0.5) : border,
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row: emoji + check-in toggle ──────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? AppColors.surfaceElevated
                              : AppColors.surfaceElevatedLight,
                        ),
                        child: Center(
                          child: Text(
                            habit.emoji,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                      if (isOnFire)
                        Positioned(
                          top: -4,
                          right: -4,
                          child:
                              const Text('🔥', style: TextStyle(fontSize: 11))
                                  .animate(
                                    onPlay: (c) => c.repeat(reverse: true),
                                  )
                                  .scale(
                                    begin: const Offset(0.9, 0.9),
                                    end: const Offset(1.1, 1.1),
                                    duration: 900.ms,
                                  ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Semantics(
                    label: isDone
                        ? '${habit.name}, done today, tap to undo'
                        : '${habit.name}, mark done today',
                    button: true,
                    child: _GridCheckInToggle(
                      isDone: isDone,
                      color: accentColor,
                      onTap: () => _toggle(context, ref, today, isDone),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ── Name ───────────────────────────────────────────────────
              Text(
                habit.name,
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),

              // ── Streak row ─────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: readableAccent(accentColor, fallback: textMuted),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${currentStreak}d streak',
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (isOnFire) ...[
                    const SizedBox(width: 5),
                    Text(
                      'ON FIRE',
                      style: TextStyle(
                        color: const Color(0xFFFF6B00),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ],
              ),

              const Spacer(),

              // ── Mini contribution grid ─────────────────────────────────
              streakDetail.when(
                loading: () => const SizedBox(height: 32),
                error: (_, _) => const SizedBox(height: 32),
                data: (result) => _MiniGrid(
                  days: result.days,
                  accentColor: accentColor,
                  textMuted: textMuted,
                  isDark: isDark,
                ),
              ),

              // ── Done indicator bar ─────────────────────────────────────
              // Space is always reserved (only the fill color toggles) —
              // conditionally inserting this used to change the card's
              // total content height, which a fixed-aspect-ratio grid
              // cell has no slack for. The Spacer above absorbed the
              // difference by resizing, which visibly nudged the mini
              // grid up/down the instant you tapped check-in.
              const SizedBox(height: 8),
              Container(
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: isDone
                      ? accentColor.withValues(alpha: 0.6)
                      : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Mini contribution grid ───────────────────────────────────────────────────

class _MiniGrid extends StatelessWidget {
  const _MiniGrid({
    required this.days,
    required this.accentColor,
    required this.textMuted,
    required this.isDark,
  });

  final List<HabitDayStatus> days;
  final Color accentColor;
  final Color textMuted;
  final bool isDark;

  static const double _cell = 8.0;
  static const double _gap = 2.0;
  static const double _step = _cell + _gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final cols = (availableWidth / _step).floor().clamp(2, 52);

        final Map<String, HabitDayStatus> dayMap = {
          for (final d in days) _dateKey(d.date): d,
        };

        final today = DateTime.now();
        final daysUntilSunday = 7 - today.weekday;
        final windowEnd = today.add(Duration(days: daysUntilSunday));
        final windowStart = windowEnd.subtract(Duration(days: cols * 7 - 1));

        final cells = <_MiniGridCell>[];
        for (int i = 0; i < cols * 7; i++) {
          final date = windowStart.add(Duration(days: i));
          final key = _dateKey(date);
          final status = dayMap[key];
          final isFuture = date.isAfter(today);
          cells.add(
            _MiniGridCell(date: date, status: status, isFuture: isFuture),
          );
        }

        return SizedBox(
          height: 7 * _step,
          width: double.infinity,
          child: CustomPaint(
            painter: _MiniGridPainter(
              cells: cells,
              accentColor: accentColor,
              emptyColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.07),
              missedColor: isDark
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.black.withValues(alpha: 0.12),
              futureColor: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.04),
            ),
          ),
        );
      },
    );
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _MiniGridCell {
  const _MiniGridCell({
    required this.date,
    required this.status,
    required this.isFuture,
  });
  final DateTime date;
  final HabitDayStatus? status;
  final bool isFuture;
}

class _MiniGridPainter extends CustomPainter {
  const _MiniGridPainter({
    required this.cells,
    required this.accentColor,
    required this.emptyColor,
    required this.missedColor,
    required this.futureColor,
  });

  final List<_MiniGridCell> cells;
  final Color accentColor;
  final Color emptyColor;
  final Color missedColor;
  final Color futureColor;

  static const double _cell = 8.0;
  static const double _gap = 2.0;
  static const double _step = _cell + _gap;

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < cells.length; i++) {
      final cell = cells[i];
      final col = i ~/ 7;
      final row = i % 7;
      final rect = Rect.fromLTWH(col * _step, row * _step, _cell, _cell);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(2));

      Color color;
      if (cell.isFuture) {
        color = futureColor;
      } else if (cell.status == null) {
        color = emptyColor;
      } else {
        switch (cell.status!.status) {
          case DayStatus.completed:
            final intensity = (cell.status!.runLength / 7).clamp(0.4, 1.0);
            color = accentColor.withValues(alpha: intensity);
          case DayStatus.missed:
            color = missedColor;
          case DayStatus.notApplicable:
          case DayStatus.future:
            color = futureColor;
        }
      }

      canvas.drawRRect(rrect, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_MiniGridPainter old) =>
      old.cells != cells || old.accentColor != accentColor;
}

// ─── Grid check-in toggle ─────────────────────────────────────────────────────

class _GridCheckInToggle extends StatefulWidget {
  const _GridCheckInToggle({
    required this.isDone,
    required this.color,
    required this.onTap,
  });

  final bool isDone;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_GridCheckInToggle> createState() => _GridCheckInToggleState();
}

class _GridCheckInToggleState extends State<_GridCheckInToggle>
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
  void didUpdateWidget(_GridCheckInToggle oldWidget) {
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
    final checkColor = contrastForeground(widget.color);

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Transform.scale(
            scale: widget.isDone ? _scale.value : 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isDone ? widget.color : Colors.transparent,
                border: Border.all(
                  color: widget.isDone ? widget.color : borderColor,
                  width: 1.5,
                ),
              ),
              child: widget.isDone
                  ? Icon(Icons.check_rounded, color: checkColor, size: 16)
                  : Icon(
                      Icons.add_rounded,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.25)
                          : Colors.black.withValues(alpha: 0.2),
                      size: 14,
                    ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Home App Bar ─────────────────────────────────────────────────────────────

class _HomeAppBar extends ConsumerWidget {
  const _HomeAppBar({
    this.banner,
    required this.isDark,
    required this.viewMode,
    required this.focusMode,
    required this.onToggleView,
    required this.onToggleFocus,
  });

  final Widget? banner;
  final bool isDark;
  final _ViewMode viewMode;
  final _FocusMode focusMode;
  final VoidCallback onToggleView;
  final ValueChanged<_FocusMode> onToggleFocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final firstName = profile.firstName;

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final title = firstName.isNotEmpty ? '$greeting, $firstName' : greeting;

    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;
    final bg = isDark ? AppColors.background : AppColors.backgroundLight;
    final border = isDark ? AppColors.border : AppColors.borderLight;
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;

    return SliverToBoxAdapter(
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border(bottom: BorderSide(color: border, width: 1)),
        ),
        // SafeArea wraps the entire header (banner + title) so the status
        // bar inset is applied exactly once to the whole block.
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Guest banner (if any) — inside SafeArea so it clears the status bar
              ?banner,
              // Title + controls
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Title row ──────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _dateLabel(),
                                style: TextStyle(
                                  color: textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _IconBtn(
                          icon: viewMode == _ViewMode.list
                              ? Icons.grid_view_rounded
                              : Icons.view_list_rounded,
                          onPressed: onToggleView,
                          isDark: isDark,
                        ),
                        _IconBtn(
                          icon: Icons.archive_outlined,
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ArchivedHabitsScreen(),
                            ),
                          ),
                          isDark: isDark,
                        ),
                        _IconBtn(
                          icon: Icons.settings_outlined,
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          ),
                          isDark: isDark,
                        ),
                      ],
                    ),

                    // ── Focus mode toggle ──────────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10, top: 6),
                      child: Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: border, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _FocusTab(
                              label: 'All',
                              selected: focusMode == _FocusMode.all,
                              isDark: isDark,
                              onTap: () => onToggleFocus(_FocusMode.all),
                            ),
                            _FocusTab(
                              label: 'Today',
                              selected: focusMode == _FocusMode.today,
                              isDark: isDark,
                              onTap: () => onToggleFocus(_FocusMode.today),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _dateLabel() {
    final now = DateTime.now();
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
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
    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }
}

// ─── Focus Tab ────────────────────────────────────────────────────────────────

class _FocusTab extends StatelessWidget {
  const _FocusTab({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = isDark ? AppColors.accent : AppColors.accentTextOnLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
    final border = isDark ? AppColors.border : AppColors.borderLight;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? accent : surface,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: selected ? accent : border, width: 1),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? (isDark ? Colors.black : Colors.white)
                : textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─── Icon Button ──────────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.onPressed,
    required this.isDark,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final color = isDark ? AppColors.textMuted : AppColors.textMutedLight;
    return IconButton(
      icon: Icon(icon, size: 20, color: color),
      onPressed: onPressed,
      splashRadius: 20,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}

// ─── Streak Summary Bar ───────────────────────────────────────────────────────

class _StreakSummaryBar extends ConsumerWidget {
  const _StreakSummaryBar({required this.habits, required this.isDark});

  final List<Habit> habits;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Live per-habit streak, same reasoning as HabitTile/HabitGridCard —
    // habit.currentStreak only refreshes on a real structural list
    // change now that activeHabitsProvider suppresses check-in-only
    // re-emissions, so this bar (which aggregates across every habit)
    // needs its own live source instead of relying on that field.
    int liveStreak(Habit h) =>
        ref.watch(streakDetailProvider(h)).valueOrNull?.currentStreak ??
        h.currentStreak;

    final totalStreaks = habits.fold<int>(
      0,
      (sum, h) => sum + liveStreak(h),
    );
    final doneToday = habits.where((h) => liveStreak(h) > 0).length;
    final total = habits.length;
    final accent = isDark ? AppColors.accent : AppColors.accentTextOnLight;
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
    final border = isDark ? AppColors.border : AppColors.borderLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const OverallAnalyticsScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: surface,
            border: Border.all(color: border, width: 1),
          ),
          child: Row(
            children: [
              _Chip(
                label: 'XP',
                value: '${totalStreaks * 10}',
                textPrimary: textPrimary,
                textMuted: textMuted,
              ),
              Container(
                width: 1,
                height: 28,
                color: border,
                margin: const EdgeInsets.symmetric(horizontal: 14),
              ),
              _Chip(
                label: 'Today',
                value: '$doneToday/$total',
                textPrimary: textPrimary,
                textMuted: textMuted,
              ),
              const Spacer(),
              Text(
                _label(doneToday, total),
                style: TextStyle(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right_rounded, color: textMuted, size: 16),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 50.ms);
  }

  String _label(int done, int total) {
    if (total == 0) return '';
    if (done == total) return 'All done 🔥';
    if (done == 0) return "Let's go!";
    return '${((done / total) * 100).round()}% done';
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.value,
    required this.textPrimary,
    required this.textMuted,
  });

  final String label;
  final String value;
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

// ─── Empty State with Templates ───────────────────────────────────────────────

class _EmptyStateWithTemplates extends StatelessWidget {
  const _EmptyStateWithTemplates({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
    final border = isDark ? AppColors.border : AppColors.borderLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),

          // ── Headline ─────────────────────────────────────────────────────
          Text(
            'No habits yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ).animate().fadeIn(delay: 80.ms),
          const SizedBox(height: 6),
          Text(
            'Start from a template or create your own.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textMuted, fontSize: 14, height: 1.5),
          ).animate().fadeIn(delay: 120.ms),

          const SizedBox(height: 28),

          // ── Featured templates label ──────────────────────────────────────
          Row(
            children: [
              Text(
                'Featured templates',
                style: TextStyle(
                  color: textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ).animate().fadeIn(delay: 160.ms),

          const SizedBox(height: 8),

          // ── 3 featured template cards ─────────────────────────────────────
          ...kFeaturedTemplates.asMap().entries.map((entry) {
            final index = entry.key;
            final template = entry.value;
            final accentColor = colorFromHex(template.colorHex);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child:
                  GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => EditHabitScreen(template: template),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: border, width: 1),
                          ),
                          child: Row(
                            children: [
                              // Emoji badge
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(
                                    alpha: isDark ? 0.15 : 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(
                                    color: accentColor.withValues(alpha: 0.25),
                                    width: 1,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    template.emoji,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Name + frequency
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      template.name,
                                      style: TextStyle(
                                        color: textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _frequencyLabel(template),
                                      style: TextStyle(
                                        color: textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Arrow
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 13,
                                color: textMuted,
                              ),
                            ],
                          ),
                        ),
                      )
                      .animate()
                      .fadeIn(delay: (200 + 60 * index).ms)
                      .slideY(
                        begin: 0.08,
                        duration: 220.ms,
                        curve: Curves.easeOut,
                      ),
            );
          }),

          const SizedBox(height: 16),

          // ── Create from scratch button ─────────────────────────────────────
          GestureDetector(
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const EditHabitScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, size: 16, color: textMuted),
                  const SizedBox(width: 8),
                  Text(
                    'Create from scratch',
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 480.ms).slideY(begin: 0.06),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _frequencyLabel(HabitTemplate template) {
    switch (template.frequencyType) {
      case FrequencyType.daily:
        return 'Daily';
      case FrequencyType.weekdays:
        final days = template.weekdays ?? [1, 2, 3, 4, 5];
        if (days.length == 5 &&
            days.contains(1) &&
            days.contains(5) &&
            !days.contains(6)) {
          return 'Weekdays';
        }
        const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return days.map((d) => names[d - 1]).join(', ');
      case FrequencyType.xPerWeek:
        final n = template.timesPerWeek ?? 3;
        return '$n× per week';
    }
  }
}

// ─── Paywall Gate Card ────────────────────────────────────────────────────────
//
// Shown below the free-tier habit list when the user has more habits than the
// free limit (either never subscribed, or subscription has expired).
// Tapping it opens the PaywallScreen.

class _PaywallGateCard extends ConsumerWidget {
  const _PaywallGateCard({required this.lockedCount, required this.isDark});

  final int lockedCount;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
    final border = isDark ? AppColors.border : AppColors.borderLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;
    final accent = isDark ? AppColors.accent : AppColors.accentTextOnLight;

    final headline = lockedCount == 1
        ? '1 habit is locked'
        : '$lockedCount habits are locked';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: GestureDetector(
        onTap: () => navigateToPaywall(context, ref),
        child: Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accent.withValues(alpha: 0.45),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Blurred ghost rows ──────────────────────────────────────
              ...List.generate(lockedCount.clamp(0, 2), (i) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: Opacity(
                    opacity: 0.28 - i * 0.08,
                    child: Container(
                      height: 64,
                      decoration: BoxDecoration(
                        color: border,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                );
              }),

              // ── Lock message ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: 0.12),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.lock_outline_rounded,
                        color: accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      headline,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Subscribe again to see all your habits\nand keep your streaks alive.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // ── CTA button ────────────────────────────────────────
                    Container(
                      width: double.infinity,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          'Restore Pro access →',
                          style: TextStyle(
                            color: isDark ? Colors.black : Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.06, duration: 280.ms);
  }
}
