import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// First-run empty state (spec Section 4): a dimmed, non-interactive
/// example habit so a brand new user understands the grid concept before
/// creating their own — shown only when the active habit list is empty.
class ExampleHabitCard extends StatelessWidget {
  const ExampleHabitCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Text('🏃', style: TextStyle(fontSize: 27)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Morning run'),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.textMuted.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'EXAMPLE',
                            // Kept at 11sp, not lower — sub-11 captions
                            // are a common accessibility-audit flag.
                            style: TextStyle(fontSize: 10, letterSpacing: 0.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '4 day streak',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.textMuted, width: 2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
