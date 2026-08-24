import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/color_hex.dart';
import '../../../core/utils/local_date.dart';
import '../../../core/utils/app_snack_bar.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../analytics/domain/leveling.dart';
import '../../analytics/presentation/overall_analytics_screen.dart';
import '../../home_tour/application/home_tour_providers.dart';
import '../../home_tour/presentation/home_tour_overlay.dart';
import '../../monetization/application/entitlement_providers.dart';
import '../../monetization/presentation/paywall_navigation.dart';
import '../../onboarding/application/user_profile_provider.dart';
import '../../settings/presentation/settings_screen.dart';
import '../application/check_in_actions.dart';
import '../application/habit_providers.dart';
import '../domain/frequency.dart';
import '../domain/habit.dart';
import '../domain/habit_category.dart';
import '../domain/streak_calculator.dart';
import 'archived_habits_screen.dart';
import 'edit_habit_screen.dart';
import 'habit_detail_screen.dart';
import 'habit_tile.dart';
import 'mood_card.dart';
import 'weekly_review_card.dart';

// ─── View mode provider ───────────────────────────────────────────────────────

final _homeViewModeProvider = StateProvider<_ViewMode>((_) => _ViewMode.list);

enum _ViewMode { list, grid }

// ─── Focus mode provider ──────────────────────────────────────────────────────

final _homeFocusModeProvider = StateProvider<_FocusMode>((_) => _FocusMode.all);

enum _FocusMode { all, today }

// ─── Category filter provider ─────────────────────────────────────────────────
//
// null = "All" (no filter). Cleared implicitly on nothing — a user leaving
// Home mid-filter and coming back keeps seeing the filtered view, which
// matches how the view/focus mode providers above already behave.
final _homeCategoryFilterProvider = StateProvider<String?>((_) => null);

// ─── HomeScreen ───────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, this.banner});

  final Widget? banner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(activeHabitsProvider);
    final viewMode = ref.watch(_homeViewModeProvider);
    final focusMode = ref.watch(_homeFocusModeProvider);
    final categoryFilter = ref.watch(_homeCategoryFilterProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.background : AppColors.backgroundLight;

    // Watch entitlement — treat loading/error as "not Pro" (safe default).
    final isPro = ref.watch(hasActiveEntitlementProvider).valueOrNull ?? false;
    final limit = AppConfig.freeTierHabitLimit;
    final tourKeys = ref.watch(homeTourKeysProvider);

    return HomeTourOverlay(
      child: Scaffold(
        backgroundColor: bg,
        body: CustomScrollView(
          slivers: [
            _HomeAppBar(
              banner: banner,
              isDark: isDark,
              viewMode: viewMode,
              focusMode: focusMode,
              onToggleView: () =>
                  ref
                      .read(_homeViewModeProvider.notifier)
                      .state = viewMode == _ViewMode.list
                  ? _ViewMode.grid
                  : _ViewMode.list,
              onToggleFocus: (mode) =>
                  ref.read(_homeFocusModeProvider.notifier).state = mode,
              viewToggleKey: tourKeys.viewToggleKey,
              analyticsKey: tourKeys.analyticsKey,
              archiveKey: tourKeys.archiveKey,
              settingsKey: tourKeys.settingsKey,
            ),
            SliverPadding(
              // Flat 96 (sized to clear the FAB) used to sit partly behind
              // a device's system nav bar instead of being visible space
              // above it — same fix as HabitDetailScreen's bottom padding.
              padding: EdgeInsets.fromLTRB(
                0,
                0,
                0,
                96 + MediaQuery.of(context).padding.bottom,
              ),
              sliver: habits.when(
                // Habit count isn't known yet at this point — 3 is just a
                // reasonable placeholder row count, same as the
                // _isHomeDataReady skeleton below falls back to.
                loading: () => SliverToBoxAdapter(
                  child: _HomeContentSkeleton(isDark: isDark, habitCount: 3),
                ),
                error: (error, _) =>
                    SliverToBoxAdapter(child: _HabitsLoadError(isDark: isDark)),
                data: (list) {
                  if (list.isEmpty) {
                    return SliverToBoxAdapter(
                      child: _EmptyState(
                        isDark: isDark,
                        firstTemplateKey: tourKeys.firstTemplateKey,
                      ),
                    );
                  }

                  // The habit list itself is the only thing `habits.when`
                  // above actually gates — every card below it (mood,
                  // streak bar, weekly review, each habit tile) sources
                  // its own data live and renders instantly regardless,
                  // so without this the very first frame after habits
                  // load shows each one's pre-data placeholder (MoodCard's
                  // larger "not logged yet" layout, a streak bar reading
                  // 0/0, habit tiles with no streak) and then visibly
                  // reflows a moment later as each stream's first
                  // snapshot lands. This skeleton mirrors that same
                  // mood-card / streak-bar / habit-list shape (rather than
                  // the generic habits.when one above, which has no habit
                  // count yet to size itself from) so the one moment
                  // content is still arriving reads as "this page" loading,
                  // not a different, unrelated placeholder.
                  if (!_isHomeDataReady(ref, list)) {
                    return SliverToBoxAdapter(
                      child: _HomeContentSkeleton(
                        isDark: isDark,
                        habitCount: list.length,
                      ),
                    );
                  }

                  // Only categories with at least one habit are worth
                  // offering as a filter — an empty category chip would just
                  // be a dead end.
                  final usedCategoryIds = list
                      .map((h) => h.categoryId)
                      .whereType<String>()
                      .toSet();
                  final filterableCategories = categories
                      .where((c) => usedCategoryIds.contains(c.id))
                      .toList();
                  final categoryFiltered = categoryFilter == null
                      ? list
                      : list
                            .where((h) => h.categoryId == categoryFilter)
                            .toList();

                  final categoryChips = filterableCategories.isEmpty
                      ? null
                      : SliverToBoxAdapter(
                          child: _CategoryFilterRow(
                            categories: filterableCategories,
                            selectedId: categoryFilter,
                            isDark: isDark,
                            onSelected: (id) =>
                                ref
                                    .read(_homeCategoryFilterProvider.notifier)
                                    .state = (categoryFilter == id
                                ? null
                                : id),
                          ),
                        );

                  if (categoryFiltered.isEmpty) {
                    return SliverMainAxisGroup(
                      slivers: [
                        if (categoryChips != null) categoryChips,
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 40,
                            ),
                            child: Text(
                              'No habits in this category.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.textMuted
                                    : AppColors.textMutedLight,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  // ── Determine visible vs locked habits (both focus modes) ──
                  // Computed before branching on focus mode — Today Focus
                  // used to receive the full unfiltered `list` here, which
                  // meant a free user hit their habit limit in "All" but saw
                  // every habit, paywall gate and all, the moment they
                  // switched to "Today". Same gate, both views now. Applied
                  // after the category filter, so the limit reflects what's
                  // actually being shown.
                  final visibleList =
                      (!isPro && categoryFiltered.length > limit)
                      ? categoryFiltered.sublist(0, limit)
                      : categoryFiltered;
                  final lockedCount =
                      (!isPro && categoryFiltered.length > limit)
                      ? categoryFiltered.length - limit
                      : 0;

                  // ── Today Focus mode ─────────────────────────────────────
                  if (focusMode == _FocusMode.today) {
                    return SliverMainAxisGroup(
                      slivers: [
                        if (categoryChips != null) categoryChips,
                        SliverToBoxAdapter(child: MoodCard(isDark: isDark)),
                        _TodayFocusSliver(
                          habits: visibleList,
                          isDark: isDark,
                          lockedCount: lockedCount,
                          firstHabitKey: tourKeys.firstHabitKey,
                        ),
                      ],
                    );
                  }

                  // ── All mode ─────────────────────────────────────────────
                  return SliverMainAxisGroup(
                    slivers: [
                      if (categoryChips != null) categoryChips,
                      SliverToBoxAdapter(
                        child: MoodCard(key: tourKeys.moodKey, isDark: isDark),
                      ),
                      SliverToBoxAdapter(
                        child: _StreakSummaryBar(
                          key: tourKeys.streakSummaryKey,
                          habits: visibleList,
                          isDark: isDark,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: WeeklyReviewCard(
                          key: tourKeys.weeklyReviewKey,
                          habits: visibleList,
                        ),
                      ),
                      if (viewMode == _ViewMode.list)
                        SliverToBoxAdapter(
                          child: _ReorderableHabitList(
                            habits: visibleList,
                            firstHabitKey: tourKeys.firstHabitKey,
                          ),
                        )
                      else
                        SliverToBoxAdapter(
                          child: _ReorderableHabitGrid(
                            habits: visibleList,
                            firstHabitKey: tourKeys.firstHabitKey,
                          ),
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
          key: tourKeys.fabKey,
          isDark: isDark,
          isPro: isPro,
          habitCount: habits.valueOrNull?.length ?? 0,
          limit: limit,
        ),
      ),
    );
  }
}

// ─── Add Habit FAB ────────────────────────────────────────────────────────────

class _AddHabitFab extends ConsumerWidget {
  const _AddHabitFab({
    super.key,
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

// ─── Home data readiness ──────────────────────────────────────────────────────

/// Whether every stream Home's cards read from — beyond just the habit
/// list itself — has delivered its first value: today's mood entry, and
/// each habit's streak detail and today's check-in. Watches (not reads)
/// each provider so this recomputes and flips the skeleton off the moment
/// the last one lands, the same way `habits.when`'s own loading state
/// already does for the habit list.
bool _isHomeDataReady(WidgetRef ref, List<Habit> habits) {
  final today = todayLocalDateString();
  if (!ref.watch(moodEntryProvider(today)).hasValue) return false;
  for (final h in habits) {
    if (!ref.watch(streakDetailProvider(h)).hasValue) return false;
    if (!ref.watch(checkInProvider(CheckInQuery(h.id, today))).hasValue) {
      return false;
    }
  }
  return true;
}

// ─── Home content skeleton (mood/streak/habits still loading) ────────────────

/// Mirrors the actual shape of Home's "All mode" stack — MoodCard, the
/// Level/check-ins ring row, then one row per habit — used for every stage
/// of Home still loading (the habit list itself, a transient load error,
/// and [_isHomeDataReady] waiting on mood/streak/check-in data), so there's
/// exactly one skeleton shape across all of them instead of a generic one
/// that gets swapped for this more detailed one partway through.
class _HomeContentSkeleton extends StatelessWidget {
  const _HomeContentSkeleton({
    required this.isDark,
    required this.habitCount,
  });

  final bool isDark;
  final int habitCount;

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      isDark: isDark,
      builder: (context, colors) {
        return Column(
          children: [
            // Same top breathing room as the real category-chip row this
            // stack sits under — without it the mood card placeholder sat
            // flush against the app bar instead of matching that gap.
            const SizedBox(height: 14),

            // ── Mood card ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: ShimmerCard(
                colors: colors,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    ShimmerCircle(size: 22, color: colors.border),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ShimmerBlock(
                        height: 12,
                        width: double.infinity,
                        color: colors.border,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Level / check-ins ring row ───────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(child: _ringCard(colors)),
                  const SizedBox(width: 10),
                  Expanded(child: _ringCard(colors)),
                ],
              ),
            ),

            // ── Habit rows — one per real habit, capped like the generic
            // skeleton so a large list doesn't produce an oversized one.
            ...List.generate(habitCount.clamp(1, 5), (i) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
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
                            ShimmerBlock(
                              height: 13,
                              width: double.infinity,
                              color: colors.border,
                            ),
                            const SizedBox(height: 8),
                            ShimmerBlock(
                              height: 10,
                              width: 80,
                              color: colors.border,
                            ),
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
          ],
        );
      },
    );
  }

  /// One [_RingStatCard]-shaped placeholder — same ring size, gap, and
  /// two-line text stack as the real card.
  Widget _ringCard(ShimmerColors colors) {
    return ShimmerCard(
      colors: colors,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ShimmerCircle(size: 38, color: colors.border),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBlock(
                  height: 13,
                  width: double.infinity,
                  color: colors.border,
                ),
                const SizedBox(height: 6),
                ShimmerBlock(height: 10, width: 50, color: colors.border),
              ],
            ),
          ),
        ],
      ),
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
    return _HomeContentSkeleton(isDark: widget.isDark, habitCount: 3);
  }
}

// ─── Today Focus Sliver ───────────────────────────────────────────────────────

class _TodayFocusSliver extends ConsumerWidget {
  const _TodayFocusSliver({
    required this.habits,
    required this.isDark,
    this.lockedCount = 0,
    this.firstHabitKey,
  });

  final List<Habit> habits;
  final bool isDark;
  final GlobalKey? firstHabitKey;

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
        .where((h) => h.isScheduledOnWeekday(today.weekday))
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
              return HabitTile(
                    key: index == 0 ? firstHabitKey : null,
                    habit: todayHabits[index],
                    isListMode: false,
                  )
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
                    : '${((progress) * 100).round()}% complete - keep going!',
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
  const _ReorderableHabitList({required this.habits, this.firstHabitKey});

  final List<Habit> habits;
  final GlobalKey? firstHabitKey;

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
    final previousOrder = List<Habit>.from(_local);
    setState(() {
      _reordering = true;
      final moved = _local.removeAt(oldIndex);
      _local.insert(newIndex, moved);
    });
    // Persist in background — previously fully fire-and-forget, so a
    // failed write (offline, permission error, etc.) left the optimistic
    // _local order on screen with nothing actually saved; it would look
    // like the list silently un-reordered itself on the next app launch,
    // with no indication anything had gone wrong in the meantime.
    ref
        .read(habitRepositoryProvider)
        .reorderHabits(_local.map((h) => h.id).toList())
        .catchError((e) {
          if (!mounted) return;
          setState(() {
            _local = previousOrder;
            _reordering = false;
          });
          AppSnackBar.show(
            context,
            'Could not save new order',
            type: SnackBarType.error,
          );
        });
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
          child: HabitTile(
            key: index == 0 ? widget.firstHabitKey : null,
            habit: habit,
            isListMode: true,
          ),
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
  const _ReorderableHabitGrid({required this.habits, this.firstHabitKey});

  final List<Habit> habits;
  final GlobalKey? firstHabitKey;

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
    final previousOrder = List<Habit>.from(_local);
    setState(() {
      _reordering = true;
      final moved = _local.removeAt(oldIndex);
      _local.insert(newIndex, moved);
    });
    // See the matching comment in _ReorderableHabitListState._onReorder —
    // same fire-and-forget-with-no-failure-feedback gap.
    ref
        .read(habitRepositoryProvider)
        .reorderHabits(_local.map((h) => h.id).toList())
        .catchError((e) {
          if (!mounted) return;
          setState(() {
            _local = previousOrder;
            _reordering = false;
          });
          AppSnackBar.show(
            context,
            'Could not save new order',
            type: SnackBarType.error,
          );
        });
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
            child: HabitGridCard(
              key: index == 0 ? widget.firstHabitKey : null,
              habit: habit,
            ),
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
    final isScheduledToday = habit.isScheduledOnWeekday(DateTime.now().weekday);
    final category = habit.categoryId == null
        ? null
        : (ref.watch(categoriesProvider).valueOrNull ?? const [])
              .cast<HabitCategory?>()
              .firstWhere((c) => c!.id == habit.categoryId, orElse: () => null);

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
                      if (category != null)
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colorFromHex(category.colorHex),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.background
                                    : AppColors.backgroundLight,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  // Disabled on days this habit isn't scheduled for (e.g. a
                  // Sunday for a Mon/Wed/Fri habit).
                  Semantics(
                    label: !isScheduledToday
                        ? '${habit.name}, not scheduled today'
                        : isDone
                        ? '${habit.name}, done today, tap to undo'
                        : '${habit.name}, mark done today',
                    button: true,
                    child: _GridCheckInToggle(
                      isDone: isDone,
                      color: accentColor,
                      enabled: isScheduledToday,
                      onTap: isScheduledToday
                          ? () => _toggle(context, ref, today, isDone)
                          : null,
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
          case DayStatus.skipped:
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
    this.enabled = true,
  });

  final bool isDone;
  final Color color;
  final VoidCallback? onTap;
  final bool enabled;

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

    return Opacity(
      opacity: widget.enabled ? 1.0 : 0.35,
      child: GestureDetector(
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
    this.viewToggleKey,
    this.analyticsKey,
    this.archiveKey,
    this.settingsKey,
  });

  final Widget? banner;
  final bool isDark;
  final _ViewMode viewMode;
  final _FocusMode focusMode;
  final VoidCallback onToggleView;
  final ValueChanged<_FocusMode> onToggleFocus;
  final GlobalKey? viewToggleKey;
  final GlobalKey? analyticsKey;
  final GlobalKey? archiveKey;
  final GlobalKey? settingsKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final firstName = profile.firstName;
    // Loading/error both read as "not Pro" — same safe default the rest
    // of Home already uses for the free-tier limit check.
    final isPro = ref.watch(hasActiveEntitlementProvider).valueOrNull ?? false;

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
                          key: viewToggleKey,
                          icon: viewMode == _ViewMode.list
                              ? Icons.grid_view_rounded
                              : Icons.view_list_rounded,
                          onPressed: onToggleView,
                          isDark: isDark,
                          tooltip: viewMode == _ViewMode.list
                              ? 'Switch to grid view'
                              : 'Switch to list view',
                        ),
                        // The only other way in was tapping the level/today
                        // ring cards further down with no visual hint that
                        // they were tappable at all — a persistent, always
                        // visible entry point in the app bar shouldn't
                        // depend on someone discovering that by accident.
                        _IconBtn(
                          key: analyticsKey,
                          icon: Icons.bar_chart_rounded,
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const OverallAnalyticsScreen(),
                            ),
                          ),
                          isDark: isDark,
                          tooltip: 'Analytics',
                        ),
                        _IconBtn(
                          key: archiveKey,
                          icon: Icons.archive_outlined,
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ArchivedHabitsScreen(),
                            ),
                          ),
                          isDark: isDark,
                          tooltip: 'Archived habits',
                        ),
                        _IconBtn(
                          key: settingsKey,
                          icon: Icons.settings_outlined,
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          ),
                          isDark: isDark,
                          tooltip: 'Settings',
                        ),
                      ],
                    ),

                    // Paywall was previously reachable only from deep
                    // inside Settings — this surfaces it directly on
                    // Home, right under the icon row rather than
                    // crowding it (which pushed the greeting into an
                    // early ellipsis). Hidden once purchased since
                    // there's nothing left to upsell.
                    // ── Focus mode toggle (+ PRO badge, same row —
                    // sharing this row's height instead of adding one) ──
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10, top: 6),
                      child: Row(
                        children: [
                          Container(
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
                          // Paywall was previously reachable only from
                          // deep inside Settings — this surfaces it
                          // directly on Home without adding its own row.
                          // Hidden once purchased since there's nothing
                          // left to upsell.
                          if (!isPro) ...[
                            const Spacer(),
                            _ProBadge(
                              onTap: () => navigateToPaywall(context, ref),
                            ),
                          ],
                        ],
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

class _ProBadge extends StatelessWidget {
  const _ProBadge({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 18,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.premiumGold.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: AppColors.premiumGold.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt_rounded, size: 10, color: AppColors.premiumGold),
            const SizedBox(width: 2),
            Text(
              'PRO',
              style: TextStyle(
                color: AppColors.premiumGold,
                fontWeight: FontWeight.w800,
                fontSize: 10,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.isDark,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool isDark;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final color = isDark ? AppColors.textMuted : AppColors.textMutedLight;
    return IconButton(
      icon: Icon(icon, size: 20, color: color),
      onPressed: onPressed,
      tooltip: tooltip,
      // Material 3's IconButton reserves a 48x48 tap target no matter
      // what the constraints below say unless both density AND tap
      // target size are overridden — that reserved space is what read
      // as "too much space between the icons".
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      splashRadius: 16,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }
}

// ─── Streak Summary Bar ───────────────────────────────────────────────────────

class _StreakSummaryBar extends ConsumerWidget {
  const _StreakSummaryBar({
    super.key,
    required this.habits,
    required this.isDark,
  });

  final List<Habit> habits;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Live per-habit streak result, same reasoning as HabitTile/HabitGridCard
    // — habit.currentStreak/longestStreak only refresh on a real structural
    // list change now that activeHabitsProvider suppresses check-in-only
    // re-emissions, so this bar (which aggregates across every habit)
    // needs its own live source instead of relying on those fields.
    final results = <String, StreakResult>{};
    for (final h in habits) {
      final r = ref.watch(streakDetailProvider(h)).valueOrNull;
      if (r != null) results[h.id] = r;
    }
    // Same Leveling module Analytics' level card uses — this is the one
    // level number in the app, not a second disconnected "XP" figure.
    final totalCompletedCheckIns = results.values
        .expand((r) => r.days)
        .where((d) => d.status == DayStatus.completed)
        .length;
    final longestStreakPerHabit = habits
        .map((h) => results[h.id]?.longestStreak ?? h.longestStreak)
        .toList();
    final levelInfo = Leveling.compute(
      Leveling.totalXp(
        totalCompletedCheckIns: totalCompletedCheckIns,
        longestStreakPerHabit: longestStreakPerHabit,
      ),
    );

    // Not liveStreak(h) > 0 — a habit with an existing streak still reads
    // as > 0 on a day it hasn't been checked in yet (a missed check-in
    // only zeroes the streak the *next* time it's recomputed, not
    // instantly), so that contradicted _TodayFocusSliver's progress ring
    // a few sections down, which correctly reads today's actual check-in.
    final todayStr = todayLocalDateString();
    final doneToday = habits
        .where(
          (h) =>
              ref
                  .watch(checkInProvider(CheckInQuery(h.id, todayStr)))
                  .valueOrNull
                  ?.completed ??
              false,
        )
        .length;
    final total = habits.length;
    final accent = isDark ? AppColors.accent : AppColors.accentTextOnLight;
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
    final border = isDark ? AppColors.border : AppColors.borderLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;

    final todayRatio = total == 0 ? 0.0 : doneToday / total;

    // Two distinct cards — lifetime level, today's progress — each with
    // its own ring, instead of the two ideas crammed onto one text line
    // with the previous design. A ring communicates "progress toward
    // something" at a glance the way a bare number never does, and it's
    // the same visual language Analytics' own consistency ring already
    // uses, so Home now reads as a preview of that screen rather than
    // an unrelated stat line.
    return Padding(
      // Bottom-only margin, no top — MoodCard right above already owns
      // the gap between itself and this bar. Every section in this stack
      // follows that same one rule (own your bottom margin only) so the
      // rhythm down the screen stays one consistent number instead of
      // two adjacent cards each adding their own half of the gap and
      // silently doubling it.
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const OverallAnalyticsScreen()),
        ),
        child: Row(
          children: [
            Expanded(
              child: _RingStatCard(
                ringValue: levelInfo.progress,
                ringLabel: '${levelInfo.level}',
                ringColor: accent,
                title: 'Level ${levelInfo.level}',
                // Just the title, not the lifetime XP count too — that
                // number plus "Blaze" plus "lifetime" doesn't fit this
                // compact a card at any font size worth reading, which is
                // exactly what the mid-word "X…" truncation was. The full
                // breakdown (level progress AND the lifetime total) has
                // proper room on the Analytics screen this card taps
                // through to.
                subtitle: levelInfo.title,
                surface: surface,
                border: border,
                textPrimary: textPrimary,
                textMuted: textMuted,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _RingStatCard(
                ringValue: todayRatio,
                ringLabel: '${(todayRatio * 100).round()}%',
                ringColor: accent,
                title: '$doneToday/$total today',
                subtitle: _label(doneToday, total),
                surface: surface,
                border: border,
                textPrimary: textPrimary,
                textMuted: textMuted,
              ),
            ),
          ],
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

class _RingStatCard extends StatelessWidget {
  const _RingStatCard({
    required this.ringValue,
    required this.ringLabel,
    required this.ringColor,
    required this.title,
    required this.subtitle,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textMuted,
  });

  /// 0..1 fill fraction of the ring.
  final double ringValue;

  /// Short text centered inside the ring (a level number, or a percent).
  final String ringLabel;
  final Color ringColor;
  final String title;
  final String subtitle;
  final Color surface;
  final Color border;
  final Color textPrimary;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: surface,
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: ringValue.clamp(0, 1),
                    strokeWidth: 3.5,
                    backgroundColor: border,
                    color: ringColor,
                  ),
                ),
                Text(
                  ringLabel,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: textMuted, fontSize: 10.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 2),
          // Same trailing-chevron convention Analytics' own breakdown and
          // leaderboard rows use for "this leads somewhere" — nothing on
          // this card said that otherwise, and a whole tappable card with
          // zero visual hint is exactly how that goes unnoticed.
          Icon(Icons.chevron_right_rounded, size: 16, color: textMuted),
        ],
      ),
    );
  }
}

// ─── Empty State with Templates ───────────────────────────────────────────────

// ─── Category filter row ───────────────────────────────────────────────────────

class _CategoryFilterRow extends StatelessWidget {
  const _CategoryFilterRow({
    required this.categories,
    required this.selectedId,
    required this.isDark,
    required this.onSelected,
  });

  final List<HabitCategory> categories;
  final String? selectedId;
  final bool isDark;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final border = isDark ? AppColors.border : AppColors.borderLight;
    final surfaceElevated = isDark
        ? AppColors.surfaceElevated
        : AppColors.surfaceElevatedLight;

    return Padding(
      // Top breathing room: this is the very first thing under the app
      // bar in "All" categories view — with no gap of its own it sat
      // flush against it, same mistake a cramped header always makes.
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 12),
      child: SizedBox(
        height: 34,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          // No standalone "All" chip — Home's own All/Today toggle sits
          // right above this row, and a second chip also reading "All"
          // directly under it read as a visual duplicate, not a filter.
          // Tapping the active category again already clears it; a
          // small "×" chip appears at the end only while a filter is on,
          // so clearing has an explicit target without repeating that
          // word a second time on the same screen.
          itemCount: categories.length + (selectedId != null ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final hasClear = selectedId != null;
            if (hasClear && i == 0) {
              return GestureDetector(
                onTap: () => onSelected(null),
                child: Container(
                  width: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: surfaceElevated,
                    border: Border.all(color: border),
                  ),
                  child: Icon(Icons.close_rounded, size: 16, color: textMuted),
                ),
              );
            }

            final category = categories[hasClear ? i - 1 : i];
            final selected = selectedId == category.id;
            final accent = colorFromHex(category.colorHex);
            // Every chip carries a faint permanent tint of its own
            // category color, not just when selected — otherwise every
            // unselected chip looked identically grey and the row gave
            // no sense that these were different, colorful categories
            // until you tapped one.
            return GestureDetector(
              onTap: () => onSelected(category.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(17),
                  color: accent.withValues(alpha: selected ? 0.20 : 0.09),
                  border: Border.all(
                    color: accent.withValues(alpha: selected ? 1 : 0.3),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  '${category.emoji} ${category.name}',
                  style: TextStyle(
                    color: selected ? textPrimary : textMuted,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ).animate().fadeIn(delay: 40.ms);
  }
}

/// A minimal, standalone quick-start card shown on the empty-Home state —
/// deliberately just these 3, not a browsable template library (that
/// feature was removed; only these 3 quick-start cards were asked back).
class _QuickStart {
  const _QuickStart({
    required this.emoji,
    required this.name,
    required this.colorHex,
    required this.frequencyType,
    this.frequencyConfig = const DailyConfig(),
    this.description,
  });

  final String emoji;
  final String name;
  final String colorHex;
  final FrequencyType frequencyType;
  final FrequencyConfig frequencyConfig;
  final String? description;

  String get frequencyLabel {
    switch (frequencyType) {
      case FrequencyType.daily:
        return 'Every day';
      case FrequencyType.weekdays:
        final days = (frequencyConfig as WeekdaysConfig).weekdays;
        if (days.length == 5 &&
            days.contains(1) &&
            days.contains(5) &&
            !days.contains(6)) {
          return 'Weekdays';
        }
        const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return days.map((d) => names[d - 1]).join(', ');
      case FrequencyType.xPerWeek:
        final n = (frequencyConfig as XPerWeekConfig).timesPerWeek;
        return '$n× per week';
    }
  }
}

const _kQuickStarts = [
  _QuickStart(
    emoji: '🧘',
    name: 'Meditate 10 min',
    colorHex: '#B57BFF',
    frequencyType: FrequencyType.daily,
    description:
        'Sit quietly for 10 minutes - focus on breath, body scan, or guided session.',
  ),
  _QuickStart(
    emoji: '📚',
    name: 'Read 20 pages',
    colorHex: '#B57BFF',
    frequencyType: FrequencyType.daily,
    description:
        'Read at least 20 pages of a non-fiction or fiction book every day.',
  ),
  _QuickStart(
    emoji: '🏃',
    name: 'Morning run',
    colorHex: '#FF4D4D',
    frequencyType: FrequencyType.weekdays,
    frequencyConfig: WeekdaysConfig(weekdays: [1, 2, 3, 4, 5]),
    description:
        'Run at least 3 km before work - pace doesn\'t matter, showing up does.',
  ),
];

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isDark, this.firstTemplateKey});

  final bool isDark;
  final GlobalKey? firstTemplateKey;

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
            'Start from a quick pick or create your own.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textMuted, fontSize: 14, height: 1.5),
          ).animate().fadeIn(delay: 120.ms),

          const SizedBox(height: 28),

          Row(
            children: [
              Text(
                'Quick start',
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

          ..._kQuickStarts.asMap().entries.map((entry) {
            final index = entry.key;
            final quickStart = entry.value;
            final accentColor = colorFromHex(quickStart.colorHex);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child:
                  GestureDetector(
                        key: index == 0 ? firstTemplateKey : null,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => EditHabitScreen(
                              prefillEmoji: quickStart.emoji,
                              prefillColorHex: quickStart.colorHex,
                              prefillFrequencyType: quickStart.frequencyType,
                              prefillFrequencyConfig:
                                  quickStart.frequencyConfig,
                              prefillName: quickStart.name,
                              prefillDescription: quickStart.description,
                            ),
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
                                    quickStart.emoji,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      quickStart.name,
                                      style: TextStyle(
                                        color: textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      quickStart.frequencyLabel,
                                      style: TextStyle(
                                        color: textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.06),

          const SizedBox(height: 32),
        ],
      ),
    );
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
