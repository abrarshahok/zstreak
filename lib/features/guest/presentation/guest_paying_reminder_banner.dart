import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/copy/app_copy.dart';
import '../../../core/theme/app_theme.dart';
import '../../account_linking/presentation/link_account_screen.dart';

/// Section 6's paying-guest exception: a guest whose 24-hour window has
/// expired but who already has an active entitlement must never be
/// blocked — this persistent (not dismissible) banner carries the
/// urgency instead of the full-screen interstitial.
class GuestPayingReminderBanner extends StatelessWidget {
  const GuestPayingReminderBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final accent = isDark ? AppColors.accent : AppColors.accentTextOnLight;

    return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  AppCopy.guestPayingReminderBanner,
                  style: TextStyle(fontSize: 12, color: textPrimary),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LinkAccountScreen()),
                ),
                child: Text(
                  'Link',
                  style: TextStyle(color: accent, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: -0.1, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }
}
