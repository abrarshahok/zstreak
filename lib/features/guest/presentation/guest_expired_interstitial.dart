import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/copy/app_copy.dart';
import '../../../core/theme/app_theme.dart';
import '../../account_linking/presentation/link_account_screen.dart';
import '../../data_export/data_export_providers.dart';

/// The one moment it's acceptable to fully block the guest (spec Section
/// 3a) — data is genuinely at risk. Replaces Home entirely so check-ins
/// and habit creation are unreachable. Flat design, theme-aware.
class GuestExpiredInterstitial extends ConsumerWidget {
  const GuestExpiredInterstitial({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.background : AppColors.backgroundLight;
    final surfaceColor = isDark ? AppColors.surface : AppColors.surfaceLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;
    final accent = isDark ? AppColors.accent : AppColors.accentTextOnLight;
    final buttonFg = isDark ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Warning icon — flat rounded container ──────────────────
              Center(
                child:
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        color: surfaceColor,
                        border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: const Center(
                        child: Text('⏰', style: TextStyle(fontSize: 39)),
                      ),
                    ).animate().scale(
                      begin: const Offset(0.7, 0.7),
                      end: const Offset(1.0, 1.0),
                      duration: 500.ms,
                      curve: Curves.elasticOut,
                    ),
              ),
              const SizedBox(height: 28),

              // ── Headline ───────────────────────────────────────────────
              Text(
                    AppCopy.guestExpiredTitle,
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

              const SizedBox(height: 12),

              // ── Body ───────────────────────────────────────────────────
              Text(
                    AppCopy.guestExpiredBody,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  )
                  .animate(delay: 180.ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.1, end: 0),

              const SizedBox(height: 40),

              // ── Primary CTA — flat, no glow ────────────────────────────
              GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LinkAccountScreen(),
                      ),
                    ),
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          AppCopy.linkWithGoogle,
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

              const SizedBox(height: 20),

              // ── Export data ────────────────────────────────────────────
              Center(
                child: TextButton(
                  onPressed: () => ref.read(dataExporterProvider).shareCsv(),
                  child: Text(
                    AppCopy.exportMyData,
                    style: TextStyle(color: textMuted, fontSize: 12),
                  ),
                ),
              ).animate(delay: 380.ms).fadeIn(duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}
