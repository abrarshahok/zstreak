import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// A purely illustrative contribution grid for onboarding — not real
/// data, just an organic scatter of "activity" that reads the same way
/// a real GitHub-style contribution graph does. Deliberately plain: the
/// grid itself is the brand's visual signature, so onboarding shouldn't
/// dress it up into something else.
class DecorativeGrid extends StatelessWidget {
  const DecorativeGrid({super.key, required this.seed});

  /// Varies the fixed pattern slightly between onboarding slides.
  final int seed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.accent : AppColors.accentTextOnLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;

    final values = List.generate(112, (i) => (i * 31 + seed * 17) % 10);
    return SizedBox(
      width: 260,
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final value in values)
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: value < 4
                    ? textMuted.withValues(alpha: 0.12)
                    : accent.withValues(alpha: (value / 10).clamp(0.3, 1.0)),
              ),
            ),
        ],
      ),
    );
  }
}
