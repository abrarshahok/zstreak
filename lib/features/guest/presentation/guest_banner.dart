import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/copy/app_copy.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_snack_bar.dart';
import '../../../core/utils/auth_error_messages.dart';
import '../../../core/widgets/flat_confirm_dialog.dart';
import '../../account_linking/presentation/link_account_screen.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/presentation/auth_gate.dart';
import '../../habits/application/habit_providers.dart';
import '../application/guest_providers.dart';

final _bannerDismissedProvider = StateProvider<bool>((ref) => false);

/// The low-key-then-escalating guest nudge from Home (spec Section 3a):
/// silent for the first ~20 hours, a dismissible low-key banner once a
/// habit exists, escalating to a more visible (still dismissible, still
/// non-blocking) prompt in the final 4 hours.
///
/// Also exposes a "Log out" option so guest users can return to the
/// start screen from anywhere in the app.
class GuestBanner extends ConsumerWidget {
  const GuestBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stage = ref.watch(guestWindowStageProvider);
    final hasHabits =
        ref.watch(activeHabitsProvider).valueOrNull?.isNotEmpty ?? false;
    final dismissed = ref.watch(_bannerDismissedProvider);

    if (stage == GuestWindowStage.expired) {
      return const SizedBox.shrink();
    }
    if (stage == GuestWindowStage.active && !hasHabits) {
      return const SizedBox.shrink();
    }
    if (dismissed) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWarning = stage == GuestWindowStage.warning;

    // Warning uses danger-tinted border; low-key uses subtle surface card.
    final borderColor = isWarning
        ? AppColors.danger.withValues(alpha: 0.5)
        : (isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.07));

    final bgColor = isWarning
        ? AppColors.danger.withValues(alpha: 0.08)
        : (isDark
              ? AppColors.surface.withValues(alpha: 0.75)
              : AppColors.surfaceLight.withValues(alpha: 0.9));

    final iconColor = isWarning ? AppColors.danger : AppColors.accent;
    final textColor = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final mutedColor = isDark ? AppColors.textMuted : AppColors.textMutedLight;
    final linkColor = isWarning
        ? AppColors.danger
        : (isDark ? AppColors.accent : AppColors.accentTextOnLight);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child:
          Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Row(
                  children: [
                    // ── Icon orb ───────────────────────────────────────────────
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isWarning
                            ? Icons.warning_amber_rounded
                            : Icons.person_outline_rounded,
                        color: iconColor,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),

                    // ── Message ────────────────────────────────────────────────
                    Expanded(
                      child: Text(
                        isWarning
                            ? AppCopy.guestBannerWarning
                            : AppCopy.guestBannerLowKey,
                        style: TextStyle(
                          fontSize: 11,
                          color: textColor,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // ── Link CTA ───────────────────────────────────────────────
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LinkAccountScreen(),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: linkColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: linkColor.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'Link',
                          style: TextStyle(
                            color: linkColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // ── Log out ────────────────────────────────────────────────
                    GestureDetector(
                      onTap: () => _confirmLogOut(context, ref),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Tooltip(
                          message: 'Log out',
                          child: Icon(
                            Icons.logout_rounded,
                            color: mutedColor,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),

                    // ── Dismiss ────────────────────────────────────────────────
                    GestureDetector(
                      onTap: () =>
                          ref.read(_bannerDismissedProvider.notifier).state =
                              true,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Tooltip(
                          message: 'Dismiss',
                          child: Icon(
                            Icons.close_rounded,
                            color: mutedColor,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
              .animate()
              .fadeIn(duration: 300.ms)
              .slideY(
                begin: -0.1,
                end: 0,
                duration: 300.ms,
                curve: Curves.easeOut,
              ),
    );
  }

  Future<void> _confirmLogOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showFlatConfirmDialog(
      context: context,
      title: 'Log out?',
      body:
          'You\'ll return to the start screen. Your local data stays on this device - link an account first if you want to keep it.',
      confirmLabel: 'Log out',
      isDanger: true,
    );
    if (confirmed != true) return;
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (e, st) {
      if (!kDebugMode) {
        FirebaseCrashlytics.instance.recordError(e, st, reason: 'sign out');
      } else {
        debugPrint('[GuestBanner] signOut failed: $e');
      }
      if (context.mounted) {
        AppSnackBar.show(
          context,
          authErrorMessage(e),
          type: SnackBarType.error,
        );
      }
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (_) => false,
    );
  }
}
