import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/color_hex.dart';
import '../../../core/utils/local_date.dart';
import '../application/habit_providers.dart';
import '../domain/frequency.dart';
import '../domain/habit.dart';
import '../domain/streak_calculator.dart';
import 'edit_habit_screen.dart';

/// Minimal flat Habit Detail screen.
/// No gradients, no glow — clean typography, flat cards, thin borders.
class HabitDetailScreen extends ConsumerWidget {
  const HabitDetailScreen({super.key, required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(streakDetailProvider(habit));
    final accentColor = colorFromHex(habit.colorHex);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.background : AppColors.backgroundLight;
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
    final border = isDark ? AppColors.border : AppColors.borderLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;

    // Determine if today is missed (not completed) and whether it's frozen
    final today = todayLocalDateString();
    final todayCheckIn = ref.watch(
      checkInProvider(CheckInQuery(habit.id, today)),
    );
    final isTodayDone = todayCheckIn.valueOrNull?.completed ?? false;
    final isTodayMissed = !isTodayDone;
    final isTodayFrozen = habit.frozenDates.contains(today);

    return Scaffold(
      backgroundColor: bg,
      body: detail.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: accentColor, strokeWidth: 2),
        ),
        error: (error, _) => Center(child: Text('$error')),
        data: (result) => CustomScrollView(
          slivers: [
            _HeroHeader(habit: habit, accentColor: accentColor, isDark: isDark),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Stat cards ─────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Current Streak',
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

                    // ── Streak Freeze card — show when freezes available or
                    // today is already frozen (so user sees the protected state)
                    if (habit.streakFreezes > 0 || isTodayFrozen)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _FreezeCard(
                          habit: habit,
                          isTodayMissed: isTodayMissed,
                          isTodayFrozen: isTodayFrozen,
                          today: today,
                          accentColor: accentColor,
                          surface: surface,
                          border: border,
                          textPrimary: textPrimary,
                          textMuted: textMuted,
                          isDark: isDark,
                        ).animate().fadeIn(delay: 220.ms),
                      ),

                    if (habit.frequencyType == FrequencyType.xPerWeek)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _WeekProgressChip(
                          habit: habit,
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

                    const SizedBox(height: 10),

                    // ── Monthly contribution grid ───────────────────────────
                    _MonthlyContributionGrid(
                      habit: habit,
                      days: result.days,
                      accentColor: accentColor,
                      surface: surface,
                      border: border,
                      isDark: isDark,
                      textPrimary: textPrimary,
                      textMuted: textMuted,
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

                    const SizedBox(height: 24),

                    // ── Log past day ───────────────────────────────────────
                    OutlinedButton.icon(
                      onPressed: () => _logPastDay(context, ref),
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

  Future<void> _logPastDay(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(
        habit.createdAt.year,
        habit.createdAt.month,
        habit.createdAt.day,
      ),
      lastDate: DateTime(now.year, now.month, now.day - 1),
      initialDate: DateTime(now.year, now.month, now.day - 1),
    );
    if (picked == null) return;
    await ref
        .read(habitRepositoryProvider)
        .setCheckIn(
          habitId: habit.id,
          date: localDateString(picked),
          completed: true,
        );
  }
}

// ─── Freeze Card ──────────────────────────────────────────────────────────────

class _FreezeCard extends ConsumerWidget {
  const _FreezeCard({
    required this.habit,
    required this.isTodayMissed,
    required this.isTodayFrozen,
    required this.today,
    required this.accentColor,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textMuted,
    required this.isDark,
  });

  final Habit habit;
  final bool isTodayMissed;
  final bool isTodayFrozen;
  final String today;
  final Color accentColor;
  final Color surface;
  final Color border;
  final Color textPrimary;
  final Color textMuted;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const iceBlue = Color(0xFF00BFFF);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: surface,
        border: Border.all(color: iceBlue.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          const Text('🧊', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isTodayFrozen
                      ? 'Streak frozen today'
                      : '${habit.streakFreezes} freeze${habit.streakFreezes == 1 ? '' : 's'} available',
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isTodayFrozen
                      ? 'Your streak is protected for today'
                      : 'Use a freeze to protect your streak on a missed day',
                  style: TextStyle(color: textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          if (isTodayMissed && !isTodayFrozen && habit.streakFreezes > 0) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () async {
                HapticFeedback.mediumImpact();
                await ref
                    .read(habitRepositoryProvider)
                    .useFreeze(habitId: habit.id, date: today);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  color: iceBlue.withValues(alpha: 0.12),
                  border: Border.all(
                    color: iceBlue.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: const Text(
                  'Use Freeze',
                  style: TextStyle(
                    color: iceBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
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
  });

  final Habit habit;
  final List<HabitDayStatus> days;
  final Color accentColor;
  final Color surface;
  final Color border;
  final bool isDark;
  final Color textPrimary;
  final Color textMuted;

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
    HapticFeedback.lightImpact();
    await ref
        .read(habitRepositoryProvider)
        .setCheckIn(
          habitId: widget.habit.id,
          date: _dateKey(date),
          completed: currentStatus != DayStatus.completed,
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
                    onTap: isFuture
                        ? null
                        : () => _toggleDay(date, dayStatus?.status),
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
        child: Center(
          child: Text(
            '$dayNum',
            style: TextStyle(
              color: textColor,
              fontSize: 9,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
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
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final Color textMuted;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? accentColor : textMuted.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

// ─── Hero Header ──────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.habit,
    required this.accentColor,
    required this.isDark,
  });

  final Habit habit;
  final Color accentColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.background : AppColors.backgroundLight;
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
    final border = isDark ? AppColors.border : AppColors.borderLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;

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
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.edit_outlined, size: 18, color: textPrimary),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => EditHabitScreen(existing: habit)),
          ),
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
                        Row(
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
                              style: TextStyle(color: textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
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
                        rate == 0 ? '—' : '$pct%',
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
