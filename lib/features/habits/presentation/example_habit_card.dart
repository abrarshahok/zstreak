import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_theme.dart';

/// First-run empty state (spec Section 4): a dimmed, non-interactive
/// example habit so a brand new user understands the grid concept before
/// creating their own — shown only when the active habit list is empty.
///
/// Deliberately mirrors HabitTile's real dimensions (44px emoji circle,
/// 40px/1.5px check toggle) rather than approximating them — this card's
/// whole job is to preview what a real tile looks like, so it should
/// actually match one.
class ExampleHabitCard extends StatelessWidget {
  const ExampleHabitCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;
    final border = isDark ? AppColors.border : AppColors.borderLight;

    return Opacity(
      opacity: 0.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: 1),
          ),
          child: Row(
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
                child: const Center(
                  child: Text('🏃', style: TextStyle(fontSize: 21)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Morning run',
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: textMuted.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'EXAMPLE',
                            // Kept at 10sp with letterSpacing, not lower —
                            // sub-10 captions are a common a11y-audit flag.
                            style: TextStyle(
                              color: textMuted,
                              fontSize: 10,
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '4 day streak',
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Matches HabitTile's real check-in toggle exactly (40px,
              // 1.5px border) — this is meant to preview the real thing.
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.25),
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.08, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }
}
