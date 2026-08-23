import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../data/migration_service.dart';

/// Shown only when a merge pushed the combined habit count over the
/// free-tier limit — nothing was dropped, but some habits landed archived.
/// Flat design, theme-aware.
class MergeSummaryScreen extends StatelessWidget {
  const MergeSummaryScreen({super.key, required this.outcome});

  final MigrationOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.background : AppColors.backgroundLight;
    final surfaceColor = isDark ? AppColors.surface : AppColors.surfaceLight;
    final borderColor = isDark ? AppColors.border : AppColors.borderLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;
    final accent = isDark ? AppColors.accent : AppColors.accentTextOnLight;
    final buttonFg = isDark ? Colors.black : Colors.white;

    final archivedCount = outcome.archivedDueToLimit;
    final habitWord = archivedCount == 1 ? 'habit' : 'habits';

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        // See LinkAccountScreen's matching comment — no scroll fallback
        // here either, previously.
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Icon — flat rounded container ─────────────────────────
                Center(
                  child:
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          color: surfaceColor,
                          border: Border.all(color: borderColor, width: 1),
                        ),
                        child: const Center(
                          child: Text('🔀', style: TextStyle(fontSize: 39)),
                        ),
                      ).animate().scale(
                        begin: const Offset(0.7, 0.7),
                        end: const Offset(1.0, 1.0),
                        duration: 500.ms,
                        curve: Curves.elasticOut,
                      ),
                ),
                const SizedBox(height: 28),

                // ── Headline ──────────────────────────────────────────────
                Text(
                      'You had habits on both',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 25,
                        height: 1.2,
                      ),
                    )
                    .animate(delay: 100.ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.1, end: 0),

                const SizedBox(height: 14),

                // ── Info card — flat ──────────────────────────────────────
                Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.archive_outlined,
                                  color: accent,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '$archivedCount $habitWord archived',
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "We kept everything, but your free plan covers "
                            '${AppConfig.freeTierHabitLimit} active habits. '
                            '$archivedCount $habitWord landed archived - reactivate them from '
                            "that habit's edit screen, or upgrade to activate them all.",
                            style: TextStyle(
                              color: textMuted,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    )
                    .animate(delay: 180.ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.1, end: 0),

                const SizedBox(height: 32),

                // ── CTA — flat, no glow ───────────────────────────────────
                GestureDetector(
                      onTap: () => Navigator.of(
                        context,
                      ).popUntil((route) => route.isFirst),
                      child: Container(
                        height: 54,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            'Got it ⚡',
                            style: TextStyle(
                              color: buttonFg,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    )
                    .animate(delay: 260.ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.1, end: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
