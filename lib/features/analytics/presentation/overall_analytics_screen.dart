import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/color_hex.dart';
import '../../../core/utils/local_date.dart';
import '../../habits/application/habit_providers.dart';
import '../../habits/domain/habit.dart';
import '../../habits/domain/streak_calculator.dart';

/// Overall analytics dashboard — flat design, theme-aware.
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
          child: Container(
            height: 1,
            color: isDark ? AppColors.border : AppColors.borderLight,
          ),
        ),
      ),
      body: habitsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: accent, strokeWidth: 2),
        ),
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
  final Map<String, StreakResult> _results = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final repo = ref.read(habitRepositoryProvider);
    for (final habit in widget.habits) {
      final result = await repo
          .watchStreakDetail(
            habitId: habit.id,
            frequencyType: habit.frequencyType,
            frequencyConfig: habit.frequencyConfig,
            createdAt: habit.createdAt,
          )
          .first;
      _results[habit.id] = result;
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Center(
        child: CircularProgressIndicator(color: widget.accent, strokeWidth: 2),
      );
    }

    // ── Aggregate metrics ─────────────────────────────────────────────────
    final totalCheckIns = _results.values
        .expand((r) => r.days)
        .where((d) => d.status == DayStatus.completed)
        .length;
    final totalHabits = widget.habits.length;
    final totalXP =
        widget.habits.fold<int>(0, (s, h) => s + h.currentStreak) * 10;
    final longestEver = _results.values.fold<int>(
      0,
      (s, r) => math.max(s, r.longestStreak),
    );
    final avgCompletion = _results.isEmpty
        ? 0.0
        : _results.values.fold<double>(0, (s, r) => s + r.completionRate) /
              _results.length;

    // 30-day daily totals
    final today = DateTime.now();
    final last30 = List.generate(30, (i) {
      final d = today.subtract(Duration(days: 29 - i));
      final ds = localDateString(d);
      final count = _results.values
          .expand((r) => r.days)
          .where(
            (day) =>
                localDateString(day.date) == ds &&
                day.status == DayStatus.completed,
          )
          .length;
      return _DayCount(date: d, count: count);
    });

    // Day-of-week rates (Mon=0..Sun=6)
    final dowCounts = List.filled(7, 0);
    final dowTotals = List.filled(7, 0);
    for (final r in _results.values) {
      for (final d in r.days) {
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
      children: [
        // ── Hero stat row ─────────────────────────────────────────────
        _HeroStatRow(
          totalXP: totalXP,
          totalCheckIns: totalCheckIns,
          totalHabits: totalHabits,
          longestEver: longestEver,
          avgCompletion: avgCompletion,
          accent: widget.accent,
          textPrimary: widget.textPrimary,
          textMuted: widget.textMuted,
          surface: widget.surface,
          isDark: widget.isDark,
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.08, end: 0),

        const SizedBox(height: 24),

        // ── 30-day bar chart ──────────────────────────────────────────
        _SectionHeader('30-Day Activity', accent: widget.accent),
        const SizedBox(height: 10),
        _ChartCard(
              isDark: widget.isDark,
              surface: widget.surface,
              child: _BarChart(
                data: last30,
                maxValue: totalHabits.toDouble(),
                accent: widget.accent,
                textMuted: widget.textMuted,
              ),
            )
            .animate(delay: 60.ms)
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.08, end: 0),

        const SizedBox(height: 20),

        // ── Day-of-week heatmap ───────────────────────────────────────
        _SectionHeader('Best Days of Week', accent: widget.accent),
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
            .slideY(begin: 0.08, end: 0),

        const SizedBox(height: 20),

        // ── Per-habit completion bars ─────────────────────────────────
        _SectionHeader('Habit Completion Rates', accent: widget.accent),
        const SizedBox(height: 10),
        _ChartCard(
              isDark: widget.isDark,
              surface: widget.surface,
              child: _HabitCompletionBars(
                habits: widget.habits,
                results: _results,
                textPrimary: widget.textPrimary,
                textMuted: widget.textMuted,
              ),
            )
            .animate(delay: 180.ms)
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.08, end: 0),

        const SizedBox(height: 20),

        // ── Streak leaderboard ────────────────────────────────────────
        _SectionHeader('Streak Leaderboard 🏆', accent: widget.accent),
        const SizedBox(height: 10),
        _StreakLeaderboard(
              habits: widget.habits,
              results: _results,
              isDark: widget.isDark,
              surface: widget.surface,
              textPrimary: widget.textPrimary,
              textMuted: widget.textMuted,
            )
            .animate(delay: 240.ms)
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.08, end: 0),
      ],
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label, {required this.accent});
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: accent,
        fontWeight: FontWeight.w800,
        fontSize: 12,
        letterSpacing: 0.3,
      ),
    );
  }
}

// ── Chart card container ──────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.child,
    required this.isDark,
    required this.surface,
  });
  final Widget child;
  final bool isDark;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? AppColors.border : AppColors.borderLight;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: child,
    );
  }
}

// ── Hero stat row ─────────────────────────────────────────────────────────────

class _HeroStatRow extends StatelessWidget {
  const _HeroStatRow({
    required this.totalXP,
    required this.totalCheckIns,
    required this.totalHabits,
    required this.longestEver,
    required this.avgCompletion,
    required this.accent,
    required this.textPrimary,
    required this.textMuted,
    required this.surface,
    required this.isDark,
  });

  final int totalXP;
  final int totalCheckIns;
  final int totalHabits;
  final int longestEver;
  final double avgCompletion;
  final Color accent;
  final Color textPrimary;
  final Color textMuted;
  final Color surface;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Big XP card — flat, no gradient, no shadow
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: surface,
            border: Border.all(color: accent.withValues(alpha: 0.3), width: 1),
          ),
          child: Row(
            children: [
              const Text('⚡', style: TextStyle(fontSize: 35)),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$totalXP XP',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 31,
                    ),
                  ),
                  Text(
                    'Total experience points',
                    style: TextStyle(color: textMuted, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 4-stat mini grid
        Row(
          children: [
            Expanded(
              child: _MiniStat(
                icon: '✅',
                value: '$totalCheckIns',
                label: 'Check-ins',
                accent: accent,
                textPrimary: textPrimary,
                textMuted: textMuted,
                surface: surface,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniStat(
                icon: '🔥',
                value: '$longestEver',
                label: 'Best streak',
                accent: accent,
                textPrimary: textPrimary,
                textMuted: textMuted,
                surface: surface,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniStat(
                icon: '📈',
                value: '${(avgCompletion * 100).round()}%',
                label: 'Avg rate',
                accent: accent,
                textPrimary: textPrimary,
                textMuted: textMuted,
                surface: surface,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniStat(
                icon: '🎯',
                value: '$totalHabits',
                label: 'Habits',
                accent: accent,
                textPrimary: textPrimary,
                textMuted: textMuted,
                surface: surface,
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
    required this.textPrimary,
    required this.textMuted,
    required this.surface,
    required this.isDark,
  });

  final String icon;
  final String value;
  final String label;
  final Color accent;
  final Color textPrimary;
  final Color textMuted;
  final Color surface;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? AppColors.border : AppColors.borderLight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 17)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: textMuted, fontSize: 8),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── 30-day bar chart ──────────────────────────────────────────────────────────

class _DayCount {
  const _DayCount({required this.date, required this.count});
  final DateTime date;
  final int count;
}

class _BarChart extends StatelessWidget {
  const _BarChart({
    required this.data,
    required this.maxValue,
    required this.accent,
    required this.textMuted,
  });

  final List<_DayCount> data;
  final double maxValue;
  final Color accent;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 100,
          child: CustomPaint(
            size: const Size(double.infinity, 100),
            painter: _BarChartPainter(
              data: data,
              maxValue: maxValue == 0 ? 1 : maxValue,
              accent: accent,
              mutedColor: textMuted,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (int i = 0; i < data.length; i += 7)
              Text(
                '${data[i].date.day}/${data[i].date.month}',
                style: TextStyle(color: textMuted, fontSize: 8),
              ),
          ],
        ),
      ],
    );
  }
}

class _BarChartPainter extends CustomPainter {
  const _BarChartPainter({
    required this.data,
    required this.maxValue,
    required this.accent,
    required this.mutedColor,
  });

  final List<_DayCount> data;
  final double maxValue;
  final Color accent;
  final Color mutedColor;

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = (size.width / data.length) - 2;
    final today = DateTime.now();

    for (var i = 0; i < data.length; i++) {
      final d = data[i];
      final x = i * (size.width / data.length);
      final heightFraction = d.count / maxValue;
      final barH = math.max(
        heightFraction * size.height,
        d.count > 0 ? 4.0 : 2.0,
      );
      final isToday =
          d.date.day == today.day &&
          d.date.month == today.month &&
          d.date.year == today.year;

      final rect = Rect.fromLTWH(x + 1, size.height - barH, barWidth, barH);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));

      final paint = Paint()
        ..color = d.count == 0
            ? mutedColor.withValues(alpha: 0.12)
            : isToday
            ? accent
            : accent.withValues(alpha: 0.4 + 0.6 * heightFraction);

      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.data != data || old.accent != accent;
}

// ── Day-of-week heatmap ───────────────────────────────────────────────────────

class _DowHeatmap extends StatelessWidget {
  const _DowHeatmap({
    required this.rates,
    required this.accent,
    required this.textMuted,
    required this.textPrimary,
  });

  final List<double> rates;
  final Color accent;
  final Color textMuted;
  final Color textPrimary;

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(7, (i) {
        final rate = rates[i];
        final pct = (rate * 100).round();
        return Expanded(
          child: Column(
            children: [
              AnimatedContainer(
                duration: Duration(milliseconds: 400 + i * 60),
                curve: Curves.easeOut,
                height: 60,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: rate == 0
                      ? textMuted.withValues(alpha: 0.1)
                      : accent.withValues(alpha: 0.15 + 0.75 * rate),
                  border: Border.all(
                    color: rate > 0.7
                        ? accent.withValues(alpha: 0.5)
                        : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    rate == 0 ? '—' : '$pct%',
                    style: TextStyle(
                      color: rate > 0.5 ? accent : textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(_days[i], style: TextStyle(color: textMuted, fontSize: 9)),
            ],
          ),
        );
      }),
    );
  }
}

// ── Per-habit completion bars ─────────────────────────────────────────────────

class _HabitCompletionBars extends StatelessWidget {
  const _HabitCompletionBars({
    required this.habits,
    required this.results,
    required this.textPrimary,
    required this.textMuted,
  });

  final List<Habit> habits;
  final Map<String, StreakResult> results;
  final Color textPrimary;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    final sorted = [...habits]
      ..sort((a, b) {
        final ra = results[a.id]?.completionRate ?? 0;
        final rb = results[b.id]?.completionRate ?? 0;
        return rb.compareTo(ra);
      });

    return Column(
      children: sorted.asMap().entries.map<Widget>((entry) {
        final habit = entry.value;
        final result = results[habit.id];
        final rate = result?.completionRate ?? 0.0;
        final habitColor = colorFromHex(habit.colorHex);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(habit.emoji, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      habit.name,
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${(rate * 100).round()}%',
                    style: TextStyle(
                      color: habitColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: rate),
                  duration: Duration(milliseconds: 600 + entry.key * 80),
                  curve: Curves.easeOut,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    backgroundColor: habitColor.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(habitColor),
                    minHeight: 7,
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
    final sorted = [...habits]
      ..sort((a, b) => b.currentStreak.compareTo(a.currentStreak));

    const medals = ['🥇', '🥈', '🥉'];

    return Column(
      children: sorted.asMap().entries.map<Widget>((entry) {
        final i = entry.key;
        final habit = entry.value;
        final result = results[habit.id];
        final habitColor = colorFromHex(habit.colorHex);
        final isTop = i < 3;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isTop
                  ? habitColor.withValues(alpha: 0.3)
                  : (isDark ? AppColors.border : AppColors.borderLight),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Rank
              SizedBox(
                width: 28,
                child: Text(
                  i < 3 ? medals[i] : '${i + 1}',
                  style: TextStyle(
                    fontSize: i < 3 ? 18 : 13,
                    color: textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 10),
              Text(habit.emoji, style: const TextStyle(fontSize: 19)),
              const SizedBox(width: 10),
              Expanded(
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
              // Current streak
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${habit.currentStreak}',
                    style: TextStyle(
                      color: habitColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'current',
                    style: TextStyle(color: textMuted, fontSize: 8),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // Best streak
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${result?.longestStreak ?? 0}',
                    style: TextStyle(
                      color: textMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text('best', style: TextStyle(color: textMuted, fontSize: 8)),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
