import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/color_hex.dart';
import '../../../core/utils/local_date.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../habits/application/habit_providers.dart';
import '../../habits/domain/habit.dart';
import '../../habits/domain/streak_calculator.dart';
import '../../monetization/application/entitlement_providers.dart';
import '../../monetization/presentation/paywall_navigation.dart';

// ─── Time filter ──────────────────────────────────────────────────────────────

enum _TimeFilter { week, month, quarter, all }

extension _TimeFilterX on _TimeFilter {
  String get label {
    switch (this) {
      case _TimeFilter.week:
        return '7D';
      case _TimeFilter.month:
        return '30D';
      case _TimeFilter.quarter:
        return '90D';
      case _TimeFilter.all:
        return 'All';
    }
  }

  int? get days {
    switch (this) {
      case _TimeFilter.week:
        return 7;
      case _TimeFilter.month:
        return 30;
      case _TimeFilter.quarter:
        return 90;
      case _TimeFilter.all:
        return null;
    }
  }
}

// ─── Overall Analytics Screen ─────────────────────────────────────────────────

class OverallAnalyticsScreen extends ConsumerWidget {
  const OverallAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(activeHabitsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.background : AppColors.backgroundLight;
    final accent = isDark ? AppColors.accent : AppColors.accentTextOnLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
    final border = isDark ? AppColors.border : AppColors.borderLight;

    final isPro = ref.watch(hasActiveEntitlementProvider).valueOrNull ?? false;

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
          'Analytics',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: border),
        ),
      ),
      body: !isPro
          ? _AnalyticsProLock(
              isDark: isDark,
              accent: accent,
              textPrimary: textPrimary,
              textMuted: textMuted,
              surface: surface,
            )
          : habitsAsync.when(
              loading: () => _AnalyticsSkeleton(isDark: isDark),
              error: (e, _) => Center(child: Text('$e')),
              data: (habits) {
                if (habits.isEmpty) {
                  return _EmptyAnalytics(textMuted: textMuted, accent: accent);
                }
                return _AnalyticsBody(
                  habits: habits,
                  isDark: isDark,
                  accent: accent,
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                  surface: surface,
                );
              },
            ),
    );
  }
}

// ── Analytics Pro lock screen ─────────────────────────────────────────────────

class _AnalyticsProLock extends ConsumerWidget {
  const _AnalyticsProLock({
    required this.isDark,
    required this.accent,
    required this.textPrimary,
    required this.textMuted,
    required this.surface,
  });

  final bool isDark;
  final Color accent;
  final Color textPrimary;
  final Color textMuted;
  final Color surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final border = isDark ? AppColors.border : AppColors.borderLight;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border, width: 1),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(14, (i) {
                      final h = 20.0 + (i % 5) * 14.0;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Container(
                            height: h,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        (isDark
                                ? AppColors.background
                                : AppColors.backgroundLight)
                            .withValues(alpha: 0.1),
                        (isDark
                                ? AppColors.background
                                : AppColors.backgroundLight)
                            .withValues(alpha: 0.85),
                      ],
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: 28),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.12),
                border: Border.all(color: accent.withValues(alpha: 0.3)),
              ),
              child: Icon(Icons.lock_outline_rounded, color: accent, size: 24),
            ).animate().scale(
              begin: const Offset(0.8, 0.8),
              duration: 350.ms,
              curve: Curves.easeOutBack,
            ),
            const SizedBox(height: 16),
            Text(
              'Analytics is Pro',
              style: TextStyle(
                color: textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ).animate().fadeIn(delay: 80.ms),
            const SizedBox(height: 8),
            Text(
              'Unlock deep insights — consistency scores,\ntrend analysis, habit sparklines & more.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textMuted, fontSize: 13, height: 1.5),
            ).animate().fadeIn(delay: 120.ms),
            const SizedBox(height: 28),
            GestureDetector(
                  onTap: () => navigateToPaywall(context, ref),
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'Unlock Analytics →',
                        style: TextStyle(
                          color: isDark ? Colors.black : Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                  ),
                )
                .animate()
                .fadeIn(delay: 160.ms)
                .slideY(begin: 0.08, duration: 280.ms),
            const SizedBox(height: 12),
            Text(
              'Cancel anytime · Managed by Google Play',
              style: TextStyle(color: textMuted, fontSize: 11),
            ).animate().fadeIn(delay: 200.ms),
          ],
        ),
      ),
    );
  }
}

// ── Loading skeleton ─────────────────────────────────────────────────────────
//
// Mirrors _AnalyticsBody's real layout (filter row, consistency ring card,
// 4-stat grid, two chart cards, a breakdown list) so the page doesn't jump
// around once real data arrives. Used both for the outer habits-list load
// and the inner per-habit streakDetailProvider load.
class _AnalyticsSkeleton extends StatelessWidget {
  const _AnalyticsSkeleton({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      isDark: isDark,
      builder: (context, colors) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
          children: [
            ShimmerCard(colors: colors, height: 36, radius: 10, padding: EdgeInsets.zero, child: const SizedBox()),
            const SizedBox(height: 16),
            ShimmerCard(
              colors: colors,
              height: 120,
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  ShimmerCircle(size: 80, color: colors.border),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBlock(height: 14, width: 100, color: colors.border),
                        const SizedBox(height: 10),
                        ShimmerBlock(height: 11, width: double.infinity, color: colors.border),
                        const SizedBox(height: 10),
                        ShimmerBlock(height: 5, width: double.infinity, radius: 4, color: colors.border),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.0,
              children: List.generate(4, (i) {
                return ShimmerCard(
                  colors: colors,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      ShimmerCircle(size: 22, color: colors.border),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ShimmerBlock(height: 9, width: 50, color: colors.border),
                            const SizedBox(height: 6),
                            ShimmerBlock(height: 16, width: 36, color: colors.border),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            ShimmerBlock(height: 13, width: 90, color: colors.border),
            const SizedBox(height: 10),
            ShimmerCard(colors: colors, height: 130, child: const SizedBox()),
            const SizedBox(height: 20),
            ShimmerBlock(height: 13, width: 90, color: colors.border),
            const SizedBox(height: 10),
            ShimmerCard(colors: colors, height: 80, child: const SizedBox()),
            const SizedBox(height: 20),
            ShimmerBlock(height: 13, width: 120, color: colors.border),
            const SizedBox(height: 10),
            ShimmerCard(
              colors: colors,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: List.generate(3, (i) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        ShimmerCircle(size: 8, color: colors.border),
                        const SizedBox(width: 10),
                        Expanded(child: ShimmerBlock(height: 13, color: colors.border)),
                        const SizedBox(width: 10),
                        ShimmerBlock(height: 20, width: 40, radius: 6, color: colors.border),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyAnalytics extends StatelessWidget {
  const _EmptyAnalytics({required this.textMuted, required this.accent});
  final Color textMuted;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('📊', style: TextStyle(fontSize: 55)).animate().scale(
            begin: const Offset(0.7, 0.7),
            duration: 400.ms,
            curve: Curves.elasticOut,
          ),
          const SizedBox(height: 16),
          Text(
            'No data yet',
            style: TextStyle(
              color: textMuted,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add habits and start checking in\nto see your analytics here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textMuted.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Main analytics body ───────────────────────────────────────────────────────

class _AnalyticsBody extends ConsumerStatefulWidget {
  const _AnalyticsBody({
    required this.habits,
    required this.isDark,
    required this.accent,
    required this.textPrimary,
    required this.textMuted,
    required this.surface,
  });

  final List<Habit> habits;
  final bool isDark;
  final Color accent;
  final Color textPrimary;
  final Color textMuted;
  final Color surface;

  @override
  ConsumerState<_AnalyticsBody> createState() => _AnalyticsBodyState();
}

class _AnalyticsBodyState extends ConsumerState<_AnalyticsBody> {
  _TimeFilter _filter = _TimeFilter.month;

  List<HabitDayStatus> _filteredDays(StreakResult r) {
    final days = _filter.days;
    if (days == null) return r.days;
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return r.days.where((d) => d.date.isAfter(cutoff)).toList();
  }

  double _windowRate(StreakResult r) {
    final relevant = _filteredDays(r)
        .where(
          (d) =>
              d.status != DayStatus.future &&
              d.status != DayStatus.notApplicable,
        )
        .toList();
    if (relevant.isEmpty) return 0;
    final done = relevant.where((d) => d.status == DayStatus.completed).length;
    return done / relevant.length;
  }

  double _prevWindowRate(StreakResult r) {
    final days = _filter.days;
    if (days == null) return 0;
    final now = DateTime.now();
    final windowStart = now.subtract(Duration(days: days));
    final prevStart = now.subtract(Duration(days: days * 2));
    final prev = r.days
        .where(
          (d) =>
              d.date.isAfter(prevStart) &&
              d.date.isBefore(windowStart) &&
              d.status != DayStatus.future &&
              d.status != DayStatus.notApplicable,
        )
        .toList();
    if (prev.isEmpty) return 0;
    final done = prev.where((d) => d.status == DayStatus.completed).length;
    return done / prev.length;
  }

  @override
  Widget build(BuildContext context) {
    // Watch the same streakDetailProvider family Home's tiles already
    // populate, instead of hand-rolling a parallel fetch of the same
    // Firestore/Drift query outside Riverpod's cache.
    final asyncResults = {
      for (final habit in widget.habits) habit.id: ref.watch(streakDetailProvider(habit)),
    };

    if (asyncResults.values.any((a) => a.isLoading && !a.hasValue)) {
      return _AnalyticsSkeleton(isDark: widget.isDark);
    }

    final results = <String, StreakResult>{
      for (final entry in asyncResults.entries)
        if (entry.value.hasValue) entry.key: entry.value.value!,
    };

    final border = widget.isDark ? AppColors.border : AppColors.borderLight;

    // ── Aggregate metrics ─────────────────────────────────────────────────
    final totalCheckIns = results.values
        .expand((r) => _filteredDays(r))
        .where((d) => d.status == DayStatus.completed)
        .length;

    final avgRate = results.isEmpty
        ? 0.0
        : results.values.fold<double>(0, (s, r) => s + _windowRate(r)) /
              results.length;

    final prevAvgRate = results.isEmpty
        ? 0.0
        : results.values.fold<double>(0, (s, r) => s + _prevWindowRate(r)) /
              results.length;

    final rateTrend = avgRate - prevAvgRate;

    final longestEver = results.values.fold<int>(
      0,
      (s, r) => math.max(s, r.longestStreak),
    );

    // Live per-habit streak from `results` (already watched above via
    // streakDetailProvider) rather than habit.currentStreak, which only
    // refreshes on a real structural list change now that
    // activeHabitsProvider suppresses check-in-only re-emissions.
    final totalXP =
        widget.habits.fold<int>(
          0,
          (s, h) => s + (results[h.id]?.currentStreak ?? h.currentStreak),
        ) *
        10;

    final consistencyScore = (avgRate * 100).round().clamp(0, 100);

    // Chart data for selected window
    final chartDays = _filter.days ?? 30;
    final today = DateTime.now();
    final chartData = List.generate(chartDays, (i) {
      final d = today.subtract(Duration(days: chartDays - 1 - i));
      final ds = localDateString(d);
      final count = results.values
          .expand((r) => r.days)
          .where(
            (day) =>
                localDateString(day.date) == ds &&
                day.status == DayStatus.completed,
          )
          .length;
      return _DayCount(date: d, count: count);
    });

    // Day-of-week rates
    final dowCounts = List.filled(7, 0);
    final dowTotals = List.filled(7, 0);
    for (final r in results.values) {
      for (final d in _filteredDays(r)) {
        if (d.status == DayStatus.future ||
            d.status == DayStatus.notApplicable) {
          continue;
        }
        final idx = d.date.weekday - 1;
        dowTotals[idx]++;
        if (d.status == DayStatus.completed) dowCounts[idx]++;
      }
    }
    final dowRates = List.generate(
      7,
      (i) => dowTotals[i] == 0 ? 0.0 : dowCounts[i] / dowTotals[i],
    );

    final insight = _buildInsight(
      consistencyScore: consistencyScore,
      rateTrend: rateTrend,
      longestEver: longestEver,
      totalCheckIns: totalCheckIns,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
      children: [
        // ── Time filter tabs ──────────────────────────────────────────────
        _TimeFilterRow(
          selected: _filter,
          onSelect: (f) => setState(() => _filter = f),
          accent: widget.accent,
          isDark: widget.isDark,
          surface: widget.surface,
          border: border,
        ).animate().fadeIn(duration: 200.ms),

        const SizedBox(height: 16),

        // ── Consistency score card ────────────────────────────────────────
        _ConsistencyCard(
          score: consistencyScore,
          trend: rateTrend,
          insight: insight,
          accent: widget.accent,
          textPrimary: widget.textPrimary,
          textMuted: widget.textMuted,
          surface: widget.surface,
          isDark: widget.isDark,
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.06, end: 0),

        const SizedBox(height: 12),

        // ── 4-stat mini grid ──────────────────────────────────────────────
        _StatGrid(
              totalXP: totalXP,
              totalCheckIns: totalCheckIns,
              longestEver: longestEver,
              avgRate: avgRate,
              rateTrend: rateTrend,
              accent: widget.accent,
              textPrimary: widget.textPrimary,
              textMuted: widget.textMuted,
              surface: widget.surface,
              isDark: widget.isDark,
            )
            .animate(delay: 40.ms)
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.06, end: 0),

        const SizedBox(height: 20),

        // ── Activity chart ────────────────────────────────────────────────
        _SectionHeader(
          'Activity',
          subtitle: _filter == _TimeFilter.all
              ? 'All time'
              : 'Last ${_filter.days} days',
          accent: widget.accent,
          textMuted: widget.textMuted,
        ),
        const SizedBox(height: 10),
        _ChartCard(
              isDark: widget.isDark,
              surface: widget.surface,
              child: _BarChart(
                data: chartData,
                maxValue: widget.habits.length.toDouble(),
                accent: widget.accent,
                textMuted: widget.textMuted,
                isDark: widget.isDark,
              ),
            )
            .animate(delay: 80.ms)
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.06, end: 0),

        const SizedBox(height: 20),

        // ── Day-of-week heatmap ───────────────────────────────────────────
        _SectionHeader(
          'Best Days',
          subtitle: 'Completion rate by weekday',
          accent: widget.accent,
          textMuted: widget.textMuted,
        ),
        const SizedBox(height: 10),
        _ChartCard(
              isDark: widget.isDark,
              surface: widget.surface,
              child: _DowHeatmap(
                rates: dowRates,
                accent: widget.accent,
                textMuted: widget.textMuted,
                textPrimary: widget.textPrimary,
              ),
            )
            .animate(delay: 120.ms)
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.06, end: 0),

        const SizedBox(height: 20),

        // ── Per-habit breakdown with sparklines ───────────────────────────
        _SectionHeader(
          'Habit Breakdown',
          subtitle: 'Rate + 7-day activity dots',
          accent: widget.accent,
          textMuted: widget.textMuted,
        ),
        const SizedBox(height: 10),
        _ChartCard(
              isDark: widget.isDark,
              surface: widget.surface,
              child: _HabitBreakdown(
                habits: widget.habits,
                results: results,
                textPrimary: widget.textPrimary,
                textMuted: widget.textMuted,
                windowRate: _windowRate,
              ),
            )
            .animate(delay: 160.ms)
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.06, end: 0),

        const SizedBox(height: 20),

        // ── Streak leaderboard ────────────────────────────────────────────
        _SectionHeader(
          'Streak Leaderboard 🏆',
          subtitle: 'Current vs best streak',
          accent: widget.accent,
          textMuted: widget.textMuted,
        ),
        const SizedBox(height: 10),
        _StreakLeaderboard(
              habits: widget.habits,
              results: results,
              isDark: widget.isDark,
              surface: widget.surface,
              textPrimary: widget.textPrimary,
              textMuted: widget.textMuted,
            )
            .animate(delay: 200.ms)
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.06, end: 0),
      ],
    );
  }

  String _buildInsight({
    required int consistencyScore,
    required double rateTrend,
    required int longestEver,
    required int totalCheckIns,
  }) {
    if (consistencyScore >= 90) {
      return '🔥 You\'re on fire! Near-perfect consistency.';
    }
    if (consistencyScore >= 75) {
      return rateTrend > 0.05
          ? '📈 Great momentum — you\'re improving!'
          : '💪 Strong consistency. Keep it up!';
    }
    if (consistencyScore >= 50) {
      return rateTrend > 0
          ? '↗️ Trending up — you\'re building the habit!'
          : '🎯 Halfway there. Small steps every day.';
    }
    if (totalCheckIns == 0) {
      return '🌱 Start checking in to see your progress here.';
    }
    return '💡 Every check-in counts. You\'ve got this!';
  }
}

// ── Time filter row ───────────────────────────────────────────────────────────

class _TimeFilterRow extends StatelessWidget {
  const _TimeFilterRow({
    required this.selected,
    required this.onSelect,
    required this.accent,
    required this.isDark,
    required this.surface,
    required this.border,
  });

  final _TimeFilter selected;
  final ValueChanged<_TimeFilter> onSelect;
  final Color accent;
  final bool isDark;
  final Color surface;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        children: _TimeFilter.values.map((f) {
          final isSelected = f == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isSelected ? accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Center(
                  child: Text(
                    f.label,
                    style: TextStyle(
                      color: isSelected
                          ? (isDark ? Colors.black : Colors.white)
                          : (isDark
                                ? AppColors.textMuted
                                : AppColors.textMutedLight),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Consistency score card ────────────────────────────────────────────────────

class _ConsistencyCard extends StatelessWidget {
  const _ConsistencyCard({
    required this.score,
    required this.trend,
    required this.insight,
    required this.accent,
    required this.textPrimary,
    required this.textMuted,
    required this.surface,
    required this.isDark,
  });

  final int score;
  final double trend;
  final String insight;
  final Color accent;
  final Color textPrimary;
  final Color textMuted;
  final Color surface;
  final bool isDark;

  Color get _scoreColor {
    if (score >= 80) return const Color(0xFF4CAF50);
    if (score >= 60) return const Color(0xFFFFB300);
    if (score >= 40) return const Color(0xFFFF7043);
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final scoreColor = _scoreColor;
    final trendUp = trend > 0.02;
    final trendDown = trend < -0.02;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scoreColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          // ── Ring indicator ─────────────────────────────────────────────
          SizedBox(
            width: 80,
            height: 80,
            child: CustomPaint(
              painter: _RingPainter(
                progress: score / 100,
                color: scoreColor,
                trackColor: scoreColor.withValues(alpha: 0.12),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<int>(
                      tween: IntTween(begin: 0, end: score),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOut,
                      builder: (_, v, _) => Text(
                        '$v',
                        style: TextStyle(
                          color: scoreColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          height: 1,
                        ),
                      ),
                    ),
                    Text(
                      '%',
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 20),

          // ── Label + trend + insight ────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Consistency',
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (trendUp || trendDown)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: trendUp
                              ? const Color(0xFF4CAF50).withValues(alpha: 0.12)
                              : AppColors.danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              trendUp
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              size: 11,
                              color: trendUp
                                  ? const Color(0xFF4CAF50)
                                  : AppColors.danger,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${(trend.abs() * 100).round()}%',
                              style: TextStyle(
                                color: trendUp
                                    ? const Color(0xFF4CAF50)
                                    : AppColors.danger,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  insight,
                  style: TextStyle(color: textMuted, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 10),
                // Score progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: score / 100),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOut,
                    builder: (_, v, _) => LinearProgressIndicator(
                      value: v,
                      backgroundColor: scoreColor.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                      minHeight: 5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ring painter ──────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = (size.shortestSide / 2) - 6;
    const strokeWidth = 7.0;
    const startAngle = -math.pi / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(cx, cy), radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      startAngle,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

// ── 4-stat mini grid ──────────────────────────────────────────────────────────

class _StatGrid extends StatelessWidget {
  const _StatGrid({
    required this.totalXP,
    required this.totalCheckIns,
    required this.longestEver,
    required this.avgRate,
    required this.rateTrend,
    required this.accent,
    required this.textPrimary,
    required this.textMuted,
    required this.surface,
    required this.isDark,
  });

  final int totalXP;
  final int totalCheckIns;
  final int longestEver;
  final double avgRate;
  final double rateTrend;
  final Color accent;
  final Color textPrimary;
  final Color textMuted;
  final Color surface;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final border = isDark ? AppColors.border : AppColors.borderLight;
    final trendColor = rateTrend >= 0
        ? const Color(0xFF4CAF50)
        : AppColors.danger;
    final trendIcon = rateTrend >= 0
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;

    final stats = [
      _StatItem(
        icon: '🔥',
        label: 'Check-ins',
        value: '$totalCheckIns',
        sub: null,
      ),
      _StatItem(
        icon: '🏆',
        label: 'Best Streak',
        value: '${longestEver}d',
        sub: null,
      ),
      _StatItem(
        icon: '⚡',
        label: 'Avg Rate',
        value: '${(avgRate * 100).round()}%',
        sub: rateTrend.abs() > 0.01
            ? _TrendSub(
                icon: trendIcon,
                color: trendColor,
                label: '${(rateTrend.abs() * 100).round()}%',
              )
            : null,
      ),
      _StatItem(icon: '✨', label: 'XP Earned', value: '$totalXP', sub: null),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.0,
      children: stats.map((s) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: 1),
          ),
          child: Row(
            children: [
              Text(s.icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      s.label,
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          s.value,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                        if (s.sub != null) ...[
                          const SizedBox(width: 4),
                          Icon(
                            (s.sub! as _TrendSub).icon,
                            size: 11,
                            color: (s.sub! as _TrendSub).color,
                          ),
                          Text(
                            (s.sub! as _TrendSub).label,
                            style: TextStyle(
                              color: (s.sub! as _TrendSub).color,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _StatItem {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
  });
  final String icon;
  final String label;
  final String value;
  final Object? sub;
}

class _TrendSub {
  const _TrendSub({
    required this.icon,
    required this.color,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final String label;
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(
    this.title, {
    required this.subtitle,
    required this.accent,
    required this.textMuted,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: textMuted.withValues(alpha: 1.0),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            subtitle,
            style: TextStyle(
              color: textMuted.withValues(alpha: 0.6),
              fontSize: 11,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Chart card container ──────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.isDark,
    required this.surface,
    required this.child,
  });

  final bool isDark;
  final Color surface;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final border = isDark ? AppColors.border : AppColors.borderLight;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 1),
      ),
      child: child,
    );
  }
}

// ── Day count data class ──────────────────────────────────────────────────────

class _DayCount {
  const _DayCount({required this.date, required this.count});
  final DateTime date;
  final int count;
}

// ── Bar chart ─────────────────────────────────────────────────────────────────

class _BarChart extends StatelessWidget {
  const _BarChart({
    required this.data,
    required this.maxValue,
    required this.accent,
    required this.textMuted,
    required this.isDark,
  });

  final List<_DayCount> data;
  final double maxValue;
  final Color accent;
  final Color textMuted;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: 100,
        child: Center(
          child: Text(
            'No data',
            style: TextStyle(color: textMuted, fontSize: 12),
          ),
        ),
      );
    }

    // Show at most 30 bars to avoid crowding
    final display = data.length > 30 ? data.sublist(data.length - 30) : data;
    final peak = display.fold<int>(0, (m, d) => math.max(m, d.count));
    final effectiveMax = math.max(peak.toDouble(), maxValue);

    return SizedBox(
      height: 110,
      child: Column(
        children: [
          Expanded(
            child: CustomPaint(
              painter: _BarChartPainter(
                data: display,
                maxValue: effectiveMax,
                accent: accent,
                trackColor: accent.withValues(alpha: 0.10),
              ),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 6),
          // X-axis: show first, middle, last date labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmt(display.first.date),
                style: TextStyle(color: textMuted, fontSize: 9),
              ),
              Text(
                _fmt(display[display.length ~/ 2].date),
                style: TextStyle(color: textMuted, fontSize: 9),
              ),
              Text(
                _fmt(display.last.date),
                style: TextStyle(color: textMuted, fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) => '${d.month}/${d.day}';
}

class _BarChartPainter extends CustomPainter {
  const _BarChartPainter({
    required this.data,
    required this.maxValue,
    required this.accent,
    required this.trackColor,
  });

  final List<_DayCount> data;
  final double maxValue;
  final Color accent;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || maxValue == 0) return;

    final barWidth = (size.width / data.length) * 0.6;
    final gap = size.width / data.length;

    final trackPaint = Paint()..color = trackColor;
    final barPaint = Paint()..color = accent;

    for (int i = 0; i < data.length; i++) {
      final x = gap * i + (gap - barWidth) / 2;
      final fillRatio = (data[i].count / maxValue).clamp(0.0, 1.0);
      final trackH = size.height;
      final barH = math.max(
        fillRatio * size.height,
        data[i].count > 0 ? 3.0 : 0.0,
      );

      final rr = Radius.circular(barWidth / 2);

      // Track
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, 0, barWidth, trackH), rr),
        trackPaint,
      );

      // Fill
      if (barH > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, trackH - barH, barWidth, barH),
            rr,
          ),
          barPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.data != data || old.maxValue != maxValue;
}

// ── Day-of-week heatmap ───────────────────────────────────────────────────────

class _DowHeatmap extends StatelessWidget {
  const _DowHeatmap({
    required this.rates,
    required this.accent,
    required this.textMuted,
    required this.textPrimary,
  });

  final List<double> rates; // 7 values, Mon=0 … Sun=6
  final Color accent;
  final Color textMuted;
  final Color textPrimary;

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(7, (i) {
        final rate = rates[i];
        final pct = (rate * 100).round();
        return Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Heat cell
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08 + rate * 0.72),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '$pct%',
                    style: TextStyle(
                      color: rate > 0.5 ? textPrimary : textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _labels[i],
                style: TextStyle(
                  color: textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ── Per-habit breakdown with sparklines ───────────────────────────────────────

class _HabitBreakdown extends StatelessWidget {
  const _HabitBreakdown({
    required this.habits,
    required this.results,
    required this.textPrimary,
    required this.textMuted,
    required this.windowRate,
  });

  final List<Habit> habits;
  final Map<String, StreakResult> results;
  final Color textPrimary;
  final Color textMuted;
  final double Function(StreakResult) windowRate;

  @override
  Widget build(BuildContext context) {
    if (habits.isEmpty) return const SizedBox.shrink();

    return Column(
      children: habits.asMap().entries.map((entry) {
        final i = entry.key;
        final habit = entry.value;
        final result = results[habit.id];
        final rate = result != null ? windowRate(result) : 0.0;
        final pct = (rate * 100).round();

        // 7-day sparkline dots
        final today = DateTime.now();
        final spark = List.generate(7, (j) {
          final d = today.subtract(Duration(days: 6 - j));
          final ds = localDateString(d);
          if (result == null) return DayStatus.notApplicable;
          final match = result.days.where(
            (day) => localDateString(day.date) == ds,
          );
          return match.isEmpty ? DayStatus.notApplicable : match.first.status;
        });

        // Color from habit's hex color
        Color habitColor;
        try {
          habitColor = colorFromHex(habit.colorHex);
        } catch (_) {
          habitColor = const Color(0xFF7C3AED);
        }

        return Padding(
          padding: EdgeInsets.only(bottom: i < habits.length - 1 ? 14 : 0),
          child: Row(
            children: [
              // Color dot
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: habitColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              // Name
              Expanded(
                child: Text(
                  habit.name,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // 7-day sparkline dots
              Row(
                children: spark.map((status) {
                  Color dotColor;
                  switch (status) {
                    case DayStatus.completed:
                      dotColor = habitColor;
                      break;
                    case DayStatus.missed:
                      dotColor = AppColors.danger.withValues(alpha: 0.5);
                      break;
                    default:
                      dotColor = textMuted.withValues(alpha: 0.2);
                  }
                  return Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(width: 10),
              // Rate badge
              Container(
                width: 40,
                padding: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  color: habitColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '$pct%',
                    style: TextStyle(
                      color: habitColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Streak leaderboard ────────────────────────────────────────────────────────

class _StreakLeaderboard extends StatelessWidget {
  const _StreakLeaderboard({
    required this.habits,
    required this.results,
    required this.isDark,
    required this.surface,
    required this.textPrimary,
    required this.textMuted,
  });

  final List<Habit> habits;
  final Map<String, StreakResult> results;
  final bool isDark;
  final Color surface;
  final Color textPrimary;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    final border = isDark ? AppColors.border : AppColors.borderLight;

    // Sort by current streak descending — live from `results`, not
    // habit.currentStreak (see the comment on _AnalyticsBodyState's
    // totalXP for why that field alone can't be trusted here).
    int liveStreak(Habit h) => results[h.id]?.currentStreak ?? h.currentStreak;
    final sorted = [...habits]
      ..sort((a, b) => liveStreak(b).compareTo(liveStreak(a)));

    final medals = ['🥇', '🥈', '🥉'];

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 1),
      ),
      child: Column(
        children: sorted.asMap().entries.map((entry) {
          final i = entry.key;
          final habit = entry.value;
          final result = results[habit.id];
          final current = liveStreak(habit);
          final best = result?.longestStreak ?? current;
          final isLast = i == sorted.length - 1;

          Color habitColor;
          try {
            habitColor = colorFromHex(habit.colorHex);
          } catch (_) {
            habitColor = const Color(0xFF7C3AED);
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    // Medal or rank
                    SizedBox(
                      width: 24,
                      child: Text(
                        i < 3 ? medals[i] : '${i + 1}',
                        style: TextStyle(
                          fontSize: i < 3 ? 16 : 12,
                          color: textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Color dot
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: habitColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Name
                    Expanded(
                      child: Text(
                        habit.name,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Current streak
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🔥', style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 2),
                            Text(
                              '${current}d',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'best ${best}d',
                          style: TextStyle(color: textMuted, fontSize: 9),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: border,
                  indent: 16,
                  endIndent: 16,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
