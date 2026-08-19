import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/local_date.dart';
import '../domain/streak_calculator.dart';

/// The GitHub-contribution-style grid — spec Section 4 calls this out as
/// the star of the app, built bespoke via CustomPainter rather than a
/// generic heatmap package.
class ContributionGrid extends StatelessWidget {
  const ContributionGrid({super.key, required this.days, required this.accentColor});

  final List<HabitDayStatus> days;
  final Color accentColor;

  static const double _cellSize = 14;
  static const double _cellGap = 3;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();

    final firstWeekStart = days.first.date.subtract(
      Duration(days: days.first.date.weekday - 1),
    );
    final weekCount =
        (days.last.date.difference(firstWeekStart).inDays / 7).ceil() + 1;
    final width = weekCount * (_cellSize + _cellGap);
    const height = 7 * (_cellSize + _cellGap);

    final completedCount = days.where((d) => d.status == DayStatus.completed).length;

    return Semantics(
      label:
          'Contribution history: $completedCount completed day${completedCount == 1 ? '' : 's'} '
          'out of ${days.length} tracked.',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: CustomPaint(
            size: Size(width, height),
            painter: _GridPainter(
              days: days,
              accentColor: accentColor,
              firstWeekStart: firstWeekStart,
              cellSize: _cellSize,
              cellGap: _cellGap,
            ),
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.days,
    required this.accentColor,
    required this.firstWeekStart,
    required this.cellSize,
    required this.cellGap,
  });

  final List<HabitDayStatus> days;
  final Color accentColor;
  final DateTime firstWeekStart;
  final double cellSize,cellGap;

  static const int _maxRunForFullGlow = 7;

  @override
  void paint(Canvas canvas, Size size) {
    final today = todayLocalDateString();

    for (final day in days) {
      final col = (day.date.difference(firstWeekStart).inDays / 7).floor();
      final row = day.date.weekday - 1; // 0 = Monday .. 6 = Sunday
      final rect = Rect.fromLTWH(
        col * (cellSize + cellGap),
        row * (cellSize + cellGap),
        cellSize,
        cellSize,
      );
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));

      final paint = Paint()..color = _colorFor(day);
      canvas.drawRRect(rrect, paint);

      final isToday = localDateString(day.date) == today;
      if (day.status == DayStatus.completed && isToday) {
        final glowPaint = Paint()
          ..color = accentColor.withValues(alpha: 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawRRect(rrect.inflate(1.5), glowPaint);
        canvas.drawRRect(rrect, paint);
      }
    }
  }

  Color _colorFor(HabitDayStatus day) {
    switch (day.status) {
      case DayStatus.notApplicable:
      case DayStatus.future:
        return AppColors.textMuted.withValues(alpha: 0.08);
      case DayStatus.missed:
        // Distinguished by opacity, not hue, so it reads for colorblind
        // users too (Section 4's accessibility note).
        return AppColors.textMuted.withValues(alpha: 0.3);
      case DayStatus.completed:
        final intensity = (day.runLength / _maxRunForFullGlow).clamp(0.35, 1.0);
        return accentColor.withValues(alpha: intensity);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.days != days || oldDelegate.accentColor != accentColor;
}
