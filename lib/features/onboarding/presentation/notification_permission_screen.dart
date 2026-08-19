import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/copy/app_copy.dart';
import '../../../core/theme/app_theme.dart';
import '../../notifications/application/notification_providers.dart';

/// Flat notification permission prompt.
/// Shown once right after account creation or guest start, before Home.
/// Denying just means reminders won't fire; the app still works fully.
class NotificationPermissionScreen extends ConsumerWidget {
  const NotificationPermissionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.background : AppColors.backgroundLight;
    final surfaceColor = isDark ? AppColors.surface : AppColors.surfaceLight;
    final borderColor = isDark ? AppColors.border : AppColors.borderLight;
    final accent = isDark ? AppColors.accent : AppColors.accentTextOnLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;
    final buttonFg = isDark ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // ── Icon — flat rounded container, no glow ─────────────────
              Center(
                child:
                    Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            color: surfaceColor,
                            border: Border.all(color: borderColor, width: 1),
                          ),
                          child: const Center(
                            child: Text('🔔', style: TextStyle(fontSize: 41)),
                          ),
                        )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(
                          begin: const Offset(0.95, 0.95),
                          end: const Offset(1.05, 1.05),
                          duration: 1800.ms,
                          curve: Curves.easeInOut,
                        ),
              ),

              const SizedBox(height: 36),

              // ── Headline ───────────────────────────────────────────────
              Text(
                AppCopy.notificationPromptHeadline,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
              ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),

              const SizedBox(height: 14),

              // ── Body ───────────────────────────────────────────────────
              Text(
                AppCopy.notificationPromptBody,
                textAlign: TextAlign.center,
                style: TextStyle(color: textMuted, fontSize: 14, height: 1.5),
              ).animate().fadeIn(delay: 180.ms).slideY(begin: 0.1),

              const Spacer(),

              // ── Enable button — flat, no glow ──────────────────────────
              GestureDetector(
                onTap: () async {
                  await ref
                      .read(notificationServiceProvider)
                      .requestNotificationPermission();
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: accent,
                  ),
                  child: Center(
                    child: Text(
                      AppCopy.notificationPromptEnable,
                      style: TextStyle(
                        color: buttonFg,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 260.ms).slideY(begin: 0.1),

              const SizedBox(height: 14),

              // ── Skip ───────────────────────────────────────────────────
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  AppCopy.notificationPromptSkip,
                  style: TextStyle(color: textMuted, fontSize: 13),
                ),
              ).animate().fadeIn(delay: 320.ms),
            ],
          ),
        ),
      ),
    );
  }
}
