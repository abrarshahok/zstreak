import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../account_linking/presentation/link_account_screen.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/presentation/sign_in_screen.dart';
import 'paywall_screen.dart';

/// Navigates to [PaywallScreen], but first gates guest users behind a
/// sign-up / sign-in prompt.
///
/// Flow for **guest** users:
///   Bottom sheet → "Sign up" → [LinkAccountScreen(thenPaywall: true)]
///                → "Already have an account? Sign in" → [SignInScreen]
///
/// Flow for **signed-in** users:
///   Directly pushes [PaywallScreen].
Future<void> navigateToPaywall(BuildContext context, WidgetRef ref) async {
  final isGuest =
      ref.read(authRepositoryProvider).currentUser?.isAnonymous ?? true;

  if (!isGuest) {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PaywallScreen()));
    return;
  }

  // Guest — show the gate sheet first.
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _GuestGateSheet(parentContext: context),
  );
}

// ─── Guest gate bottom sheet ──────────────────────────────────────────────────

class _GuestGateSheet extends ConsumerWidget {
  const _GuestGateSheet({required this.parentContext});

  /// We keep a reference to the screen context so we can push routes on the
  /// main navigator after the sheet is dismissed.
  final BuildContext parentContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.surface : AppColors.surfaceLight;
    final accent = isDark ? AppColors.accent : AppColors.accentTextOnLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;
    final borderColor = isDark ? AppColors.border : AppColors.borderLight;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: borderColor, width: 1)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: textMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.12),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: const Center(
              child: Text('🔥', style: TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(height: 16),

          // Headline
          Text(
            'Create an account to go Pro',
            style: TextStyle(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Sub-copy
          Text(
            'A free account keeps your streak safe and\nlets you unlock Pro features.',
            style: TextStyle(color: textMuted, fontSize: 13, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          // Primary CTA — Sign up
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // close sheet
                Navigator.of(parentContext).push(
                  MaterialPageRoute(
                    builder: (_) => const LinkAccountScreen(thenPaywall: true),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: isDark ? Colors.black : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Sign up - it\'s free',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Secondary CTA — Sign in
          GestureDetector(
            onTap: () {
              Navigator.of(context).pop(); // close sheet
              Navigator.of(parentContext).push(
                MaterialPageRoute(
                  builder: (_) => const SignInScreen(
                    fromOnboarding: false,
                    thenPaywall: true,
                  ),
                ),
              );
            },
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Already have an account? ',
                    style: TextStyle(color: textMuted, fontSize: 13),
                  ),
                  TextSpan(
                    text: 'Sign in',
                    style: TextStyle(
                      color: accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
