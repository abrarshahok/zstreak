import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/color_hex.dart';
import '../../../core/utils/local_date.dart';
import '../application/check_in_actions.dart';
import '../application/habit_providers.dart';
import '../domain/habit.dart';
import '../domain/streak_calculator.dart';
import 'habit_detail_screen.dart';

/// Minimal flat habit tile.
/// Flat card with thin border, no gradients, no glow.
/// Accent color used only for the check-in button and completion indicator.
class HabitTile extends ConsumerWidget {
  const HabitTile({super.key, required this.habit, this.isListMode = true});

  final Habit habit;

  /// When true (list mode), shows the drag handle on the right.
  final bool isListMode;

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
    final isOnFire = habit.currentStreak >= 7;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
    final border = isDark ? AppColors.border : AppColors.borderLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;
    final streakDetail = ref.watch(streakDetailProvider(habit));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GestureDetector(
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
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top row ──────────────────────────────────────────────
                Row(
                  children: [
                    // Emoji with accent dot indicator
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? AppColors.surfaceElevated
                                : AppColors.surfaceElevatedLight,
                          ),
                          child: Center(
                            child: Text(
                              habit.emoji,
                              style: const TextStyle(fontSize: 21),
                            ),
                          ),
                        ),
                        if (isOnFire)
                          Positioned(
                            top: -4,
                            right: -4,
                            child:
                                const Text('🔥', style: TextStyle(fontSize: 12))
                                    .animate(
                                      onPlay: (c) => c.repeat(reverse: true),
                                    )
                                    .scale(
                                      begin: const Offset(0.9, 0.9),
                                      end: const Offset(1.1, 1.1),
                                      duration: 900.ms,
                                      curve: Curves.easeInOut,
                                    ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),

                    // Name + streak
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            habit.name,
                            style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              // Accent dot
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: readableAccent(
                                    accentColor,
                                    fallback: textMuted,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${habit.currentStreak} day streak',
                                style: TextStyle(
                                  color: textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (isOnFire) ...[
                                const SizedBox(width: 6),
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
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Check-in toggle
                    Semantics(
                      label: isDone
                          ? '${habit.name}, done today, tap to undo'
                          : '${habit.name}, mark done today',
                      button: true,
                      child: _CheckInToggle(
                        isDone: isDone,
                        color: accentColor,
                        onTap: () => _toggle(context, ref, today, isDone),
                      ),
                    ),

                    // Drag handle — list mode only.
                    // The parent ReorderableDragStartListener wraps the whole
                    // tile, so this icon is purely visual.
                    if (isListMode) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.drag_handle_rounded,
                        size: 20,
                        color: textMuted.withValues(alpha: 0.5),
                      ),
                    ],
                  ],
                ),

                // ── Mini contribution grid ────────────────────────────────
                const SizedBox(height: 10),
                streakDetail.when(
                  loading: () => const SizedBox(height: 26),
                  error: (_, _) => const SizedBox(height: 26),
                  data: (result) => _TileMiniGrid(
                    days: result.days,
                    accentColor: accentColor,
                    textMuted: textMuted,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Tile mini contribution grid ─────────────────────────────────────────────

class _TileMiniGrid extends StatelessWidget {
  const _TileMiniGrid({
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
        final cols = (availableWidth / _step).floor().clamp(4, 52);

        final Map<String, HabitDayStatus> dayMap = {
          for (final d in days) _dateKey(d.date): d,
        };

        final today = DateTime.now();
        final daysUntilSunday = 7 - today.weekday;
        final windowEnd = today.add(Duration(days: daysUntilSunday));
        final windowStart = windowEnd.subtract(Duration(days: cols * 7 - 1));

        final cells = <_GridCell>[];
        for (int i = 0; i < cols * 7; i++) {
          final date = windowStart.add(Duration(days: i));
          final key = _dateKey(date);
          final status = dayMap[key];
          final isFuture = date.isAfter(today);
          cells.add(_GridCell(date: date, status: status, isFuture: isFuture));
        }

        return SizedBox(
          height: 7 * _step,
          width: double.infinity,
          child: CustomPaint(
            painter: _TileMiniGridPainter(
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

class _GridCell {
  const _GridCell({
    required this.date,
    required this.status,
    required this.isFuture,
  });
  final DateTime date;
  final HabitDayStatus? status;
  final bool isFuture;
}

class _TileMiniGridPainter extends CustomPainter {
  const _TileMiniGridPainter({
    required this.cells,
    required this.accentColor,
    required this.emptyColor,
    required this.missedColor,
    required this.futureColor,
  });

  final List<_GridCell> cells;
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
  bool shouldRepaint(_TileMiniGridPainter old) =>
      old.cells != cells || old.accentColor != accentColor;
}

// ─── Check-in toggle ──────────────────────────────────────────────────────────

class _CheckInToggle extends StatefulWidget {
  const _CheckInToggle({
    required this.isDone,
    required this.color,
    required this.onTap,
  });

  final bool isDone;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_CheckInToggle> createState() => _CheckInToggleState();
}

class _CheckInToggleState extends State<_CheckInToggle>
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
    _scale = TweenSequence([
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
  void didUpdateWidget(_CheckInToggle oldWidget) {
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

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.isDone ? _scale.value : 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isDone ? widget.color : Colors.transparent,
                border: Border.all(
                  color: widget.isDone ? widget.color : borderColor,
                  width: 1.5,
                ),
              ),
              child: widget.isDone
                  ? Icon(Icons.check_rounded, color: checkIconColor, size: 20)
                  : Icon(
                      Icons.add_rounded,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: 0.25),
                      size: 18,
                    ),
            ),
          );
        },
      ),
    );
  }
}
